import 'dotenv/config';
import express from 'express';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import admin from 'firebase-admin';
import { google } from 'googleapis';
import multer from 'multer';
import { Readable } from 'node:stream';
import { fileURLToPath } from 'node:url';

const currentDirectory = typeof __dirname != 'undefined'
  ? __dirname
  : path.dirname(fileURLToPath(import.meta.url));
const isPackagedExecutable = Boolean(process.pkg);
const projectDirectory = isPackagedExecutable
  ? path.dirname(process.execPath)
  : path.resolve(currentDirectory, '..');
const localServiceAccountPath = path.join(projectDirectory, 'service-account.json');
const adcCredentialsPath = path.join(
  os.homedir(),
  '.config',
  'gcloud',
  'application_default_credentials.json',
);
const windowsAdcCredentialsPath = path.join(
  os.homedir(),
  'AppData',
  'Roaming',
  'gcloud',
  'application_default_credentials.json',
);
const configuredCredentialsPath = normalizeOptionalString(
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  null,
);
const effectiveCredentialsPath =
  configuredCredentialsPath ??
  (fs.existsSync(localServiceAccountPath)
    ? localServiceAccountPath
    : fs.existsSync(adcCredentialsPath)
      ? adcCredentialsPath
      : fs.existsSync(windowsAdcCredentialsPath)
        ? windowsAdcCredentialsPath
      : null);

if (effectiveCredentialsPath) {
  process.env.GOOGLE_APPLICATION_CREDENTIALS = effectiveCredentialsPath;
}

const port = Number.parseInt(process.env.PORT ?? '8787', 10);
const host = normalizeOptionalString(process.env.HOST, '127.0.0.1');
const rootFolderId = (process.env.GOOGLE_DRIVE_ROOT_FOLDER_ID ?? '').trim();
const sharedDriveId = (
  process.env.GOOGLE_DRIVE_SHARED_DRIVE_ID ?? ''
).trim();
const verifyFirebaseToken =
  (process.env.VERIFY_FIREBASE_TOKEN ?? 'true').trim().toLowerCase() != 'false';

if (!rootFolderId) {
  throw new Error(
    'Defina GOOGLE_DRIVE_ROOT_FOLDER_ID para a pasta raiz do Drive corporativo.',
  );
}

const app = express();
const upload = multer({ storage: multer.memoryStorage() });

initializeFirebaseAdmin();

app.get('/health', async (_request, response) => {
  response.json({
    ok: true,
    sharedDriveId: sharedDriveId || null,
    rootFolderId,
    verifyFirebaseToken,
    credentialsConfigured: Boolean(effectiveCredentialsPath),
    credentialsPath: effectiveCredentialsPath,
  });
});

app.post('/drive/upload', upload.single('file'), async (request, response) => {
  try {
    const authContext = await authenticateRequest(request);
    const uploadedFile = request.file;

    if (!uploadedFile) {
      response.status(400).json({ error: 'Arquivo ausente no campo "file".' });
      return;
    }

    const orderCode = normalizeRequiredField(request.body.orderCode, 'orderCode');
    const slot = normalizeRequiredField(request.body.slot, 'slot');
    const slotMetadata = resolveSlotMetadata(slot);
    const originalFileName = normalizeOptionalString(
      request.body.fileName,
      uploadedFile.originalname,
    );

    const drive = await createDriveClient();
    const orderFolderId = await ensureChildFolder({
      drive,
      name: orderCode,
      parentId: rootFolderId,
    });
    const slotFolderId = await ensureChildFolder({
      drive,
      name: slotMetadata.folderName,
      parentId: orderFolderId,
    });

    const driveFile = await drive.files.create({
      requestBody: {
        name: originalFileName,
        parents: [slotFolderId],
        description: [
          `Pedido: ${orderCode}`,
          `Pasta de anexo: ${slotMetadata.folderName}`,
          `Slot interno: ${slot}`,
          `Usuario: ${authContext.userEmail ?? authContext.userUid ?? 'desconhecido'}`,
        ].join(' | '),
      },
      media: {
        mimeType: pickMimeType(request.body.contentType, uploadedFile.mimetype),
        body: bufferToStream(uploadedFile.buffer),
      },
      fields: 'id,name,webViewLink,webContentLink,parents',
      supportsAllDrives: true,
    });

    const fileId = driveFile.data.id;
    if (!fileId) {
      throw new Error('O Google Drive nao retornou o ID do arquivo criado.');
    }

    if (slot === 'profile_photo') {
      await ensurePublicReadPermission({ drive, fileId });
    }

    response.status(201).json({
      fileId,
      fileName: driveFile.data.name ?? originalFileName,
      viewUrl:
        driveFile.data.webViewLink ??
        `https://drive.google.com/file/d/${fileId}/view`,
      downloadUrl:
        driveFile.data.webContentLink ??
        `https://drive.google.com/uc?id=${fileId}&export=download`,
      parentFolderId: slotFolderId,
    });
  } catch (error) {
    console.error('[drive-upload]', error);
    response.status(resolveStatusCode(error)).json({
      error: error instanceof Error ? error.message : 'Falha inesperada.',
    });
  }
});

app.listen(port, host, () => {
  console.log(`company-drive-server listening on http://${host}:${port}`);
  if (effectiveCredentialsPath) {
    console.log(`google credentials: ${effectiveCredentialsPath}`);
  } else {
    console.log(
      'google credentials: ausentes. Defina GOOGLE_APPLICATION_CREDENTIALS, adicione service-account.json nesta pasta ou rode gcloud auth application-default login.',
    );
  }
});

function initializeFirebaseAdmin() {
  if (!verifyFirebaseToken || admin.apps.length > 0) {
    return;
  }

  const options = {};
  if (process.env.FIREBASE_PROJECT_ID) {
    options.projectId = process.env.FIREBASE_PROJECT_ID;
  }
  admin.initializeApp(options);
}

async function authenticateRequest(request) {
  const userEmail = normalizeOptionalString(request.body.userEmail, null);
  const userUid = normalizeOptionalString(request.body.userUid, null);

  if (!verifyFirebaseToken) {
    return { userEmail, userUid };
  }

  const header = request.headers.authorization ?? '';
  if (!header.startsWith('Bearer ')) {
    throw createHttpError(
      401,
      'Authorization Bearer token obrigatorio para enviar ao Drive corporativo.',
    );
  }

  const idToken = header.replace('Bearer ', '').trim();
  if (!idToken) {
    throw createHttpError(401, 'Token Firebase vazio.');
  }

  const decoded = await admin.auth().verifyIdToken(idToken);
  return {
    userEmail: decoded.email ?? userEmail,
    userUid: decoded.uid ?? userUid,
  };
}

async function createDriveClient() {
  ensureGoogleCredentialsConfigured();

  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/drive'],
  });

  const client = await auth.getClient();
  return google.drive({
    version: 'v3',
    auth: client,
  });
}

function ensureGoogleCredentialsConfigured() {
  if (effectiveCredentialsPath) {
    return;
  }
}

function resolveSlotMetadata(slot) {
  const normalizedSlot = normalizeOptionalString(slot, '') ?? '';

  return (
    SLOT_FOLDER_BY_KEY[normalizedSlot] ?? {
      folderName: humanizeSlot(normalizedSlot),
    }
  );
}

function humanizeSlot(slot) {
  return slot
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

async function ensureChildFolder({ drive, name, parentId }) {
  const escapedName = name.replace(/'/g, "\\'");
  const queryParts = [
    "mimeType='application/vnd.google-apps.folder'",
    `name='${escapedName}'`,
    `'${parentId}' in parents`,
    'trashed=false',
  ];

  const listResponse = await drive.files.list({
    q: queryParts.join(' and '),
    fields: 'files(id,name)',
    pageSize: 1,
    includeItemsFromAllDrives: true,
    supportsAllDrives: true,
    corpora: sharedDriveId ? 'drive' : 'user',
    driveId: sharedDriveId || undefined,
  });

  const existingFolder = listResponse.data.files?.[0];
  if (existingFolder?.id) {
    return existingFolder.id;
  }

  const created = await drive.files.create({
    requestBody: {
      name,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId],
    },
    fields: 'id',
    supportsAllDrives: true,
  });

  const folderId = created.data.id;
  if (!folderId) {
    throw new Error(`Nao foi possivel criar a pasta "${name}" no Drive.`);
  }

  return folderId;
}

async function ensurePublicReadPermission({ drive, fileId }) {
  const permissions = await drive.permissions.list({
    fileId,
    fields: 'permissions(id,type,role)',
    supportsAllDrives: true,
  });

  const alreadyPublic = permissions.data.permissions?.some(
    (permission) => permission.type === 'anyone' && permission.role === 'reader',
  );
  if (alreadyPublic) {
    return;
  }

  await drive.permissions.create({
    fileId,
    requestBody: {
      type: 'anyone',
      role: 'reader',
    },
    supportsAllDrives: true,
  });
}

function normalizeRequiredField(value, fieldName) {
  const normalized = normalizeOptionalString(value, null);
  if (!normalized) {
    throw createHttpError(400, `Campo obrigatorio ausente: ${fieldName}.`);
  }
  return normalized;
}

function normalizeOptionalString(value, fallback) {
  const text = value?.toString().trim();
  if (!text) {
    return fallback;
  }

  return text;
}

function pickMimeType(requestMimeType, uploadedMimeType) {
  return (
    normalizeOptionalString(requestMimeType, null) ??
    normalizeOptionalString(uploadedMimeType, null) ??
    'application/octet-stream'
  );
}

function createHttpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function resolveStatusCode(error) {
  if (
    error &&
    typeof error === 'object' &&
    'statusCode' in error &&
    typeof error.statusCode === 'number'
  ) {
    return error.statusCode;
  }

  return 500;
}

function bufferToStream(buffer) {
  return Readable.from(buffer);
}

const SLOT_FOLDER_BY_KEY = {
  proposal: {
    folderName: 'Cadastro de Clientes - Proposta',
  },
  details: {
    folderName: 'Cadastro de Clientes - Detalhamento',
  },
  materials: {
    folderName: 'Orçamentista - Materiais',
  },
  consolidated_proposal: {
    folderName: 'Financeiro - Proposta Consolidada',
  },
  contract: {
    folderName: 'Financeiro - Contrato',
  },
  electrical_project: {
    folderName: 'Engenharia - Projeto Elétrico',
  },
  engineering_data: {
    folderName: 'Engenharia - Dados',
  },
  profile_photo: {
    folderName: 'Usuários - Fotos',
  },
};
