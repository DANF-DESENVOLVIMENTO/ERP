import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../app/app_version.dart';

class SoftwareUpdateService {
  SoftwareUpdateService({http.Client? client})
    : _client = client ?? http.Client();

  static const String manifestUrl = String.fromEnvironment(
    'ERP_DANF_UPDATE_MANIFEST_URL',
    defaultValue:
        'https://drive.google.com/open?id=1IqOBq-_AJZlayEEDeV-AqsLs4M7gOVw_&usp=drive_fs',
  );

  final http.Client _client;

  bool get isConfigured => manifestUrl.trim().isNotEmpty;

  Future<SoftwareUpdateCheckResult> checkForUpdate() async {
    if (!isConfigured) {
      return const SoftwareUpdateCheckResult.notConfigured();
    }

    final uri = Uri.tryParse(_normalizeGoogleDriveDownloadUrl(manifestUrl));
    if (uri == null) {
      throw StateError('URL do manifesto de atualizacao invalida.');
    }

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'O manifesto de atualizacao respondeu ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(_stripUtf8Bom(utf8.decode(response.bodyBytes)));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('O manifesto de atualizacao precisa ser um JSON.');
    }

    final manifest = SoftwareUpdateManifest.fromJson(decoded);
    final hasUpdate = _compareVersions(manifest.version, erpDanfAppVersion) > 0;
    return SoftwareUpdateCheckResult(
      configured: true,
      hasUpdate: hasUpdate,
      manifest: manifest,
    );
  }

  Future<File> downloadUpdatePackage(
    SoftwareUpdateManifest manifest, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final normalizedUrl = _normalizeGoogleDriveDownloadUrl(
      manifest.downloadUrl,
    );
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      throw StateError('URL do pacote de atualizacao invalida.');
    }

    final response = await _openUpdatePackageDownload(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'O pacote de atualizacao respondeu ${response.statusCode}.',
      );
    }

    final packageName = manifest.fileName.trim().isEmpty
        ? 'erp_danf_update_${manifest.version}.zip'
        : manifest.fileName;
    final safePackageName = packageName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final packageFile = File(
      _joinPath(Directory.systemTemp.path, safePackageName),
    );
    final sink = packageFile.openWrite();
    var received = 0;
    final total = response.contentLength;

    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }

    final expectedHash = manifest.sha256.trim().toLowerCase();
    if (expectedHash.isNotEmpty) {
      final actualHash = await sha256.bind(packageFile.openRead()).first;
      if (actualHash.toString().toLowerCase() != expectedHash) {
        await packageFile.delete().catchError((_) => packageFile);
        throw StateError(
          'O pacote baixado nao confere com o SHA-256 informado.',
        );
      }
    }

    return packageFile;
  }

  Future<http.StreamedResponse> _openUpdatePackageDownload(Uri uri) async {
    final response = await _sendDownloadRequest(uri);
    if (!_isGoogleDriveVirusWarning(response)) {
      return response;
    }

    final warningBody = await response.stream.bytesToString();
    final confirmedUri = _extractGoogleDriveConfirmedDownloadUri(warningBody);
    if (confirmedUri == null) {
      throw StateError(
        'O Google Drive retornou uma pagina de confirmacao, mas o app nao conseguiu encontrar o link final do download.',
      );
    }

    return _sendDownloadRequest(confirmedUri);
  }

  Future<http.StreamedResponse> _sendDownloadRequest(Uri uri) {
    final request = http.Request('GET', uri);
    return _client.send(request).timeout(const Duration(seconds: 20));
  }

  bool _isGoogleDriveVirusWarning(http.StreamedResponse response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    return contentType.contains('text/html');
  }

  Uri? _extractGoogleDriveConfirmedDownloadUri(String html) {
    if (!html.contains('Google Drive') ||
        !html.contains('Virus scan warning')) {
      return null;
    }

    final id = _extractHtmlInputValue(html, 'id');
    if (id == null || id.isEmpty) {
      return null;
    }

    final queryParameters = <String, String>{
      'id': id,
      'export': _extractHtmlInputValue(html, 'export') ?? 'download',
    };

    final confirm = _extractHtmlInputValue(html, 'confirm');
    if (confirm != null && confirm.isNotEmpty) {
      queryParameters['confirm'] = confirm;
    }

    final uuid = _extractHtmlInputValue(html, 'uuid');
    if (uuid != null && uuid.isNotEmpty) {
      queryParameters['uuid'] = uuid;
    }

    return Uri.https(
      'drive.usercontent.google.com',
      '/download',
      queryParameters,
    );
  }

  Future<void> installDownloadedPackage(File packageFile) async {
    if (!Platform.isWindows) {
      throw StateError('A atualizacao automatica esta disponivel no Windows.');
    }

    if (!await packageFile.exists()) {
      throw StateError('O pacote baixado nao foi encontrado.');
    }

    final executablePath = Platform.resolvedExecutable;
    final installDirectory = File(executablePath).parent.path;
    final scriptFile = File(
      _joinPath(
        Directory.systemTemp.path,
        'erp_danf_apply_update_${DateTime.now().millisecondsSinceEpoch}.ps1',
      ),
    );
    final launcherFile = File(
      _joinPath(
        Directory.systemTemp.path,
        'erp_danf_apply_update_${DateTime.now().millisecondsSinceEpoch}.cmd',
      ),
    );

    final script = _buildWindowsUpdaterScript(
      executablePath: executablePath,
      installDirectory: installDirectory,
      packagePath: packageFile.path,
      executableName: 'erp_danf.exe',
    );
    await scriptFile.writeAsBytes(<int>[
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(script),
    ]);

    final launcherLog = _joinPath(
      Directory.systemTemp.path,
      'erp_danf_update_launcher_${DateTime.now().millisecondsSinceEpoch}.log',
    );
    await launcherFile.writeAsString(
      _buildWindowsUpdaterLauncherScript(
        scriptPath: scriptFile.path,
        launcherLogPath: launcherLog,
      ),
    );

    await Process.start('cmd.exe', [
      '/c',
      launcherFile.path,
    ], mode: ProcessStartMode.detached);

    exit(0);
  }

  void dispose() {
    _client.close();
  }
}

class SoftwareUpdateCheckResult {
  const SoftwareUpdateCheckResult({
    required this.configured,
    required this.hasUpdate,
    this.manifest,
  });

  const SoftwareUpdateCheckResult.notConfigured()
    : configured = false,
      hasUpdate = false,
      manifest = null;

  final bool configured;
  final bool hasUpdate;
  final SoftwareUpdateManifest? manifest;
}

class SoftwareUpdateManifest {
  const SoftwareUpdateManifest({
    required this.version,
    required this.downloadUrl,
    required this.fileName,
    required this.sha256,
    required this.notes,
  });

  factory SoftwareUpdateManifest.fromJson(Map<String, dynamic> json) {
    final windows = json['windows'];
    final platformMap = windows is Map<String, dynamic> ? windows : json;
    final version = _pickFirstString(json, const ['version', 'appVersion']);
    final downloadUrl = _pickFirstString(platformMap, const [
      'downloadUrl',
      'url',
      'zipUrl',
      'fileUrl',
    ]);

    if (version == null || downloadUrl == null) {
      throw StateError(
        'O manifesto precisa informar "version" e "windows.downloadUrl".',
      );
    }

    return SoftwareUpdateManifest(
      version: version,
      downloadUrl: downloadUrl,
      fileName:
          _pickFirstString(platformMap, const ['fileName', 'name']) ??
          'erp_danf_update_$version.zip',
      sha256: _pickFirstString(platformMap, const ['sha256', 'hash']) ?? '',
      notes: _pickFirstString(json, const ['notes', 'description']) ?? '',
    );
  }

  final String version;
  final String downloadUrl;
  final String fileName;
  final String sha256;
  final String notes;
}

String? _pickFirstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String _stripUtf8Bom(String value) {
  if (value.startsWith('\uFEFF')) {
    return value.substring(1);
  }
  return value;
}

String? _extractHtmlInputValue(String html, String name) {
  final pattern = RegExp(
    '<input[^>]*name=["\\\']${RegExp.escape(name)}["\\\'][^>]*>',
    caseSensitive: false,
  );
  final input = pattern.firstMatch(html)?.group(0);
  if (input == null) {
    return null;
  }

  final valuePattern = RegExp(
    'value=["\\\']([^"\\\']*)["\\\']',
    caseSensitive: false,
  );
  return valuePattern.firstMatch(input)?.group(1);
}

int _compareVersions(String left, String right) {
  final leftParts = _splitVersion(left);
  final rightParts = _splitVersion(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < length; index++) {
    final leftValue = index < leftParts.length ? leftParts[index] : 0;
    final rightValue = index < rightParts.length ? rightParts[index] : 0;
    final comparison = leftValue.compareTo(rightValue);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}

List<int> _splitVersion(String value) {
  final normalized = value.trim().replaceAll('+', '.').replaceAll('-', '.');
  return normalized
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList(growable: false);
}

String _normalizeGoogleDriveDownloadUrl(String rawUrl) {
  final text = rawUrl.trim();
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.host.contains('drive.google.com')) {
    return text;
  }

  final queryId = uri.queryParameters['id'];
  if (queryId != null && queryId.isNotEmpty) {
    return Uri.https('drive.google.com', '/uc', {
      'export': 'download',
      'id': queryId,
    }).toString();
  }

  final match = RegExp(r'/file/d/([^/]+)').firstMatch(uri.path);
  final pathId = match?.group(1);
  if (pathId == null || pathId.isEmpty) {
    return text;
  }

  return Uri.https('drive.google.com', '/uc', {
    'export': 'download',
    'id': pathId,
  }).toString();
}

String _buildWindowsUpdaterLauncherScript({
  required String scriptPath,
  required String launcherLogPath,
}) {
  String cmd(String value) => value.replaceAll('"', '""');

  return '''
@echo off
setlocal
echo %DATE% %TIME% Iniciando aplicador > "${cmd(launcherLogPath)}"
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${cmd(scriptPath)}"
echo %DATE% %TIME% PowerShell solicitado >> "${cmd(launcherLogPath)}"
endlocal
''';
}

String _buildWindowsUpdaterScript({
  required String executablePath,
  required String installDirectory,
  required String packagePath,
  required String executableName,
}) {
  String ps(String value) => "'${value.replaceAll("'", "''")}'";

  return '''
\$ErrorActionPreference = 'Stop'
\$exe = ${ps(executablePath)}
\$installDir = ${ps(installDirectory)}
\$zip = ${ps(packagePath)}
\$exeName = ${ps(executableName)}
\$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
\$log = Join-Path ([IO.Path]::GetTempPath()) "erp_danf_update_\$stamp.log"
\$backupDir = Join-Path \$installDir "backup_\$stamp"
\$extractDir = Join-Path ([IO.Path]::GetTempPath()) "erp_danf_update_\$stamp"

function Write-UpdateLog([string]\$message) {
  Add-Content -LiteralPath \$log -Value "\$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) \$message"
}

function Invoke-UpdateRobocopy([string]\$source, [string]\$destination, [string[]]\$extraArgs) {
  Write-UpdateLog "Copiando de \$source para \$destination"
  & robocopy \$source \$destination /E /R:3 /W:1 @extraArgs | Out-Null
  \$code = \$LASTEXITCODE
  Write-UpdateLog "Robocopy finalizado com codigo \$code"
  if (\$code -gt 7) {
    throw "Robocopy falhou com codigo \$code."
  }
}

try {
  Write-UpdateLog "Iniciando atualizacao. Aplicador v2."
  Write-UpdateLog "Instalacao: \$installDir"
  Write-UpdateLog "Pacote: \$zip"

  \$processName = [IO.Path]::GetFileNameWithoutExtension(\$exeName)
  for (\$attempt = 0; \$attempt -lt 60; \$attempt++) {
    \$running = Get-Process -Name \$processName -ErrorAction SilentlyContinue | Where-Object {
      \$_.Path -eq \$exe
    }
    if (\$null -eq \$running) {
      break
    }
    Write-UpdateLog "Aguardando o app fechar. Tentativa \$attempt."
    Start-Sleep -Milliseconds 500
  }

  \$stillRunning = Get-Process -Name \$processName -ErrorAction SilentlyContinue | Where-Object {
    \$_.Path -eq \$exe
  }
  if (\$null -ne \$stillRunning) {
    throw "O app ainda esta em execucao e nao pode ser substituido."
  }

  New-Item -ItemType Directory -Path \$backupDir -Force | Out-Null
  New-Item -ItemType Directory -Path \$extractDir -Force | Out-Null
  Expand-Archive -LiteralPath \$zip -DestinationPath \$extractDir -Force

  \$newExe = Get-ChildItem -LiteralPath \$extractDir -Recurse -Filter \$exeName | Select-Object -First 1
  if (\$null -eq \$newExe) {
    throw "O pacote de atualizacao nao contem \$exeName."
  }

  \$sourceDir = \$newExe.Directory.FullName
  Write-UpdateLog "Origem extraida: \$sourceDir"

  Invoke-UpdateRobocopy \$installDir \$backupDir @('/XD', 'backup_*', 'backup_manual_*')

  Invoke-UpdateRobocopy \$sourceDir \$installDir @()
  Write-UpdateLog "Arquivos copiados."

  \$updatedExe = Join-Path \$installDir \$exeName
  if (-not (Test-Path -LiteralPath \$updatedExe)) {
    throw "O executavel atualizado nao foi encontrado em \$updatedExe."
  }

  Start-Process -FilePath \$updatedExe -WorkingDirectory \$installDir
  Write-UpdateLog "App reiniciado: \$updatedExe"
} catch {
  Write-UpdateLog "ERRO: \$_"
  throw
}
''';
}

String _joinPath(String first, String second) {
  if (first.endsWith(Platform.pathSeparator)) {
    return '$first$second';
  }
  return '$first${Platform.pathSeparator}$second';
}
