# Company Drive Backend Contract

O app nao envia arquivos direto para o Google Drive. Ele envia para uma API interna da empresa, e essa API grava no Drive corporativo.

Backend incluido neste repositorio:

- [backend/company-drive-server/README.md](/Users/danf/ERP%20DANF/backend/company-drive-server/README.md)
- [backend/company-drive-server/src/server.js](/Users/danf/ERP%20DANF/backend/company-drive-server/src/server.js)

Configuracao no app:

```bash
flutter run \
  --dart-define=COMPANY_DRIVE_UPLOAD_URL=https://seu-backend.exemplo.com/drive/upload
```

Requisicao esperada:

- Metodo: `POST`
- Content-Type: `multipart/form-data`
- Campo de arquivo: `file`
- Campos extras:
  - `orderCode`
  - `slot`
  - `fileName`
  - `contentType`
  - `userEmail`
  - `userUid`
- Header opcional:
  - `Authorization: Bearer <firebase-id-token>`

Resposta JSON minima:

```json
{
  "fileId": "1AbCdEfGhIjKlMn",
  "fileName": "proposta_cliente.pdf",
  "viewUrl": "https://drive.google.com/file/d/1AbCdEfGhIjKlMn/view"
}
```

Observacoes de arquitetura:

- Para conta corporativa, o ideal e usar uma `Shared Drive`.
- A service account nao deve ficar no app.
- O backend deve usar a service account e ter permissao de escrita na pasta ou Shared Drive da empresa.
- O app salva no Firestore apenas a referencia do arquivo retornada pelo backend.
