# Company Drive Server

Backend minimo para receber anexos do app Flutter e gravar no Google Drive da empresa.

## O que voce precisa pegar do Google

1. `GOOGLE_DRIVE_ROOT_FOLDER_ID`
   - ID da pasta raiz onde os arquivos do ERP vao ficar.
   - Exemplo de URL:
     `https://drive.google.com/drive/folders/1AbCdEfGhIjKlMn`
   - O ID e a parte final: `1AbCdEfGhIjKlMn`

2. `GOOGLE_DRIVE_SHARED_DRIVE_ID` se usar Shared Drive
   - Recomendado, porque service account nao deve ser dona de arquivos em "Meu Drive".
   - Pegue o ID da Shared Drive na URL dela.

3. `Service Account JSON`
   - Crie uma service account no Google Cloud do projeto.
   - Gere a chave JSON e salve no servidor.
   - Exporte no ambiente:
     `GOOGLE_APPLICATION_CREDENTIALS=/caminho/credenciais.json`
   - Ou salve o arquivo diretamente como:
     `backend/company-drive-server/service-account.json`
   - Se sua organizacao bloquear criacao de chaves JSON, use credenciais locais:
     `gcloud auth application-default login`
     Nesse modo, o backend usa sua conta Google autenticada no terminal.

4. Permissao da service account na Shared Drive ou pasta
   - Adicione o email da service account como `Content manager` ou acima.

5. `Drive API` habilitada
   - No Google Cloud Console, habilite a API:
     `Google Drive API`

6. `FIREBASE_PROJECT_ID`
   - Se quiser validar o token do usuario do app no backend.

## Recomendacao de estrutura no Drive

- Shared Drive: `ERP DANF`
- Pasta raiz: `Clientes`
- O backend cria subpastas assim:
  - `OP-2401/proposal`
  - `OP-2401/details`
  - `OP-2401/materials`
  - `OP-2401/consolidated_proposal`
  - `OP-2401/contract`

## Variaveis de ambiente

Copie `.env.example` e configure:

```bash
PORT=8787
HOST=127.0.0.1
GOOGLE_DRIVE_ROOT_FOLDER_ID=SEU_FOLDER_ID
GOOGLE_DRIVE_SHARED_DRIVE_ID=SEU_SHARED_DRIVE_ID
VERIFY_FIREBASE_TOKEN=true
FIREBASE_PROJECT_ID=erp-danf
GOOGLE_APPLICATION_CREDENTIALS=/caminho/service-account.json
```

Se voce salvar a credencial em `backend/company-drive-server/service-account.json`,
nao precisa preencher `GOOGLE_APPLICATION_CREDENTIALS`.

Se a criacao de chaves estiver bloqueada pela politica da organizacao, rode:

```bash
gcloud auth application-default login
```

e compartilhe a pasta do Drive com a sua conta Google autenticada.

## Rodando

```bash
npm install
npm run dev
```

Health check:

```bash
GET /health
```

Upload:

```bash
POST /drive/upload
```

Campos multipart esperados:

- `file`
- `orderCode`
- `slot`
- `fileName`
- `contentType`
- `userEmail`
- `userUid`

Header esperado:

- `Authorization: Bearer <firebase-id-token>`

## Resposta esperada

```json
{
  "fileId": "1AbCdEfGhIjKlMn",
  "fileName": "proposta_cliente.pdf",
  "viewUrl": "https://drive.google.com/file/d/1AbCdEfGhIjKlMn/view",
  "downloadUrl": "https://drive.google.com/uc?id=1AbCdEfGhIjKlMn&export=download",
  "parentFolderId": "1FolderInsideDrive"
}
```
