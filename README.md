# ERP DANF

Projeto base do sistema `ERP DANF`.

## Estrutura

- `src/`: código-fonte da aplicação
- `tests/`: testes automatizados
- `docs/`: documentação técnica e funcional

## Próximos passos

1. Definir a stack do projeto.
2. Implementar os módulos iniciais do ERP.
3. Configurar ambiente de desenvolvimento e testes.

## Atualizacao automatica no Windows

O app pode verificar um manifesto JSON publico e avisar quando houver uma
versao diferente da instalada.

1. Atualize a versao em `pubspec.yaml` e em `lib/app/app_version.dart`.
2. Gere a build Windows.
3. Compacte o conteudo da pasta `build/windows/x64/runner/Release` em um ZIP.
4. Suba o ZIP no Drive e deixe o arquivo acessivel por link.
5. Suba um manifesto JSON publico no Drive com este formato:

```json
{
  "version": "1.0.1+2",
  "notes": "Resumo curto das mudancas.",
  "windows": {
    "downloadUrl": "https://drive.google.com/file/d/ID_DO_ZIP/view?usp=sharing",
    "fileName": "erp_danf_windows_1.0.1.zip",
    "sha256": ""
  }
}
```

O campo `sha256` e opcional. Para ativar a verificacao no app, compile com:

```powershell
flutter build windows --dart-define=ERP_DANF_UPDATE_MANIFEST_URL="LINK_PUBLICO_DO_JSON"
```

Quando o usuario clicar em **Atualizar**, o app baixa o ZIP, fecha, substitui os
arquivos na pasta do executavel e abre novamente. Uma copia da versao anterior
fica em uma pasta `backup_...` dentro da pasta de instalacao.
