import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class CompanyDriveStorageService {
  CompanyDriveStorageService({
    String? uploadUrl,
    http.Client? client,
    FirebaseAuth? auth,
  }) : _uploadUrl = uploadUrl ?? _defaultUploadUrl(),
       _client = client ?? http.Client(),
       _auth = auth ?? FirebaseAuth.instance;

  final String _uploadUrl;
  final http.Client _client;
  final FirebaseAuth _auth;
  Process? _localBackendProcess;
  Future<LocalDriveBackendBootstrapResult>? _bootstrapOperation;
  Future<DriveAuthReconnectResult>? _driveReconnectOperation;

  bool get isConfigured => _uploadUrl.trim().isNotEmpty;
  String get uploadUrl => _uploadUrl;
  bool get isLocalDebugEndpoint {
    if (!isConfigured) {
      return false;
    }

    final uri = Uri.tryParse(_uploadUrl);
    if (uri == null) {
      return false;
    }

    return uri.host == '127.0.0.1' || uri.host == 'localhost';
  }

  Future<String?> checkAvailability() async {
    if (!isConfigured) {
      return null;
    }

    final uri = Uri.tryParse(_uploadUrl);
    if (uri == null) {
      return 'A URL da API do Drive corporativo é inválida: $_uploadUrl';
    }

    final healthUri = uri.replace(path: '/health', query: null);

    try {
      final response = await _client
          .get(healthUri)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }

      return 'A API do Drive em $healthUri respondeu ${response.statusCode}.';
    } on TimeoutException {
      return 'A API do Drive em $healthUri demorou para responder.';
    } on SocketException catch (error) {
      return 'Não foi possível conectar à API do Drive em $healthUri. ${error.message}';
    } on http.ClientException catch (error) {
      return 'Falha ao acessar a API do Drive em $healthUri: ${error.message}';
    }
  }

  Future<LocalDriveBackendBootstrapResult> ensureLocalDebugBackendRunning() {
    if (!isLocalDebugEndpoint || kIsWeb) {
      return Future.value(
        const LocalDriveBackendBootstrapResult(
          isAvailable: false,
          didLaunch: false,
          errorMessage: 'O auto-start local só é suportado no app desktop.',
        ),
      );
    }

    final pendingOperation = _bootstrapOperation;
    if (pendingOperation != null) {
      return pendingOperation;
    }

    final operation = _ensureLocalDebugBackendRunning();
    _bootstrapOperation = operation.whenComplete(() {
      _bootstrapOperation = null;
    });
    return _bootstrapOperation!;
  }

  Future<DriveAuthReconnectResult> reconnectLocalDriveAuthentication() {
    if (kIsWeb) {
      return Future.value(
        const DriveAuthReconnectResult(
          didStart: false,
          errorMessage:
              'A reautenticacao automatica do Google Drive so e suportada no app desktop.',
        ),
      );
    }

    final pendingOperation = _driveReconnectOperation;
    if (pendingOperation != null) {
      return pendingOperation;
    }

    final operation = _reconnectLocalDriveAuthentication().whenComplete(() {
      _driveReconnectOperation = null;
    });
    _driveReconnectOperation = operation;
    return operation;
  }

  Future<CompanyDriveStoredFile> uploadFile({
    required String orderCode,
    required String slot,
    required File localFile,
    required String originalFileName,
    required String? contentType,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Configure a URL da API interna que envia arquivos para o Drive da empresa.',
      );
    }

    if (!await localFile.exists()) {
      throw StateError(
        'O arquivo "$originalFileName" não foi encontrado para envio ao Drive da empresa.',
      );
    }

    return _uploadFileWithRetry(
      orderCode: orderCode,
      slot: slot,
      localFile: localFile,
      originalFileName: originalFileName,
      contentType: contentType,
      allowBootstrapRetry: isLocalDebugEndpoint,
    );
  }

  Future<CompanyDriveStoredFile> _uploadFileWithRetry({
    required String orderCode,
    required String slot,
    required File localFile,
    required String originalFileName,
    required String? contentType,
    required bool allowBootstrapRetry,
  }) async {
    final uri = Uri.parse(_uploadUrl);
    final request = await _buildUploadRequest(
      uri: uri,
      orderCode: orderCode,
      slot: slot,
      localFile: localFile,
      originalFileName: originalFileName,
      contentType: contentType,
    );

    late final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } on SocketException catch (error) {
      if (allowBootstrapRetry && isLocalDebugEndpoint) {
        final bootstrapResult = await ensureLocalDebugBackendRunning();
        if (bootstrapResult.isAvailable) {
          return _uploadFileWithRetry(
            orderCode: orderCode,
            slot: slot,
            localFile: localFile,
            originalFileName: originalFileName,
            contentType: contentType,
            allowBootstrapRetry: false,
          );
        }

        throw StateError(
          'Não foi possível conectar à API do Drive em $_uploadUrl. '
          'O app também não conseguiu iniciar o backend local automaticamente. '
          'Detalhe: ${bootstrapResult.errorMessage ?? error.message}',
        );
      }

      throw StateError(
        'Não foi possível conectar à API do Drive em $_uploadUrl. Inicie o backend local de upload. Detalhe: ${error.message}',
      );
    } on http.ClientException catch (error) {
      throw StateError(
        'Falha ao enviar para a API do Drive em $_uploadUrl: ${error.message}',
      );
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_requiresDriveAuthenticationReconnect(response)) {
        throw const DriveAuthExpiredException();
      }
      throw StateError(
        'A API do Drive corporativo respondeu ${response.statusCode}: ${response.body}',
      );
    }

    if (response.body.trim().isEmpty) {
      throw StateError(
        'A API do Drive corporativo não retornou os metadados do arquivo enviado.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'A API do Drive corporativo retornou um formato inválido.',
      );
    }

    final fileId = _pickFirstString(decoded, const ['fileId', 'id']);
    final viewUrl = _pickFirstString(decoded, const [
      'viewUrl',
      'webViewLink',
      'url',
    ]);
    final downloadUrl = _pickFirstString(decoded, const [
      'downloadUrl',
      'webContentLink',
    ]);

    if (fileId == null || viewUrl == null) {
      throw StateError(
        'A API do Drive corporativo precisa retornar pelo menos "fileId" e "viewUrl".',
      );
    }

    return CompanyDriveStoredFile(
      fileId: fileId,
      fileName:
          _pickFirstString(decoded, const ['fileName', 'name']) ??
          originalFileName,
      viewUrl: viewUrl,
      downloadUrl: downloadUrl,
    );
  }

  Future<http.MultipartRequest> _buildUploadRequest({
    required Uri uri,
    required String orderCode,
    required String slot,
    required File localFile,
    required String originalFileName,
    required String? contentType,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..fields['orderCode'] = orderCode
      ..fields['slot'] = slot
      ..fields['fileName'] = originalFileName;

    if (contentType != null && contentType.trim().isNotEmpty) {
      request.fields['contentType'] = contentType;
    }

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final token = await currentUser.getIdToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final email = currentUser.email;
      if (email != null && email.isNotEmpty) {
        request.fields['userEmail'] = email;
      }
      request.fields['userUid'] = currentUser.uid;
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        localFile.path,
        filename: originalFileName,
      ),
    );

    return request;
  }

  Future<LocalDriveBackendBootstrapResult>
  _ensureLocalDebugBackendRunning() async {
    final initialAvailabilityError = await checkAvailability();
    if (initialAvailabilityError == null) {
      return const LocalDriveBackendBootstrapResult(
        isAvailable: true,
        didLaunch: false,
      );
    }

    final backendDirectory = _findBackendDirectory();
    if (backendDirectory == null) {
      return const LocalDriveBackendBootstrapResult(
        isAvailable: false,
        didLaunch: false,
        errorMessage:
            'A pasta `backend/company-drive-server` nao foi encontrada a partir do diretorio atual do app.',
      );
    }

    final outputBuffer = StringBuffer();
    Future<void> collectProcessOutput(Stream<List<int>> stream) async {
      await for (final chunk in stream.transform(utf8.decoder)) {
        outputBuffer.write(chunk);
      }
    }

    try {
      final existingProcess = _localBackendProcess;
      if (existingProcess == null) {
        final launchCommand = await _resolveBackendLaunchCommand(
          backendDirectory,
        );
        if (launchCommand == null) {
          return const LocalDriveBackendBootstrapResult(
            isAvailable: false,
            didLaunch: false,
            errorMessage:
                'Nenhum executavel do backend local foi encontrado e o Node.js nao esta disponivel para iniciar `src/server.js`.',
          );
        }

        final process = await Process.start(
          launchCommand.executable,
          launchCommand.arguments,
          workingDirectory: backendDirectory.path,
        );
        _localBackendProcess = process;
        unawaited(collectProcessOutput(process.stdout));
        unawaited(collectProcessOutput(process.stderr));
        unawaited(
          process.exitCode.then((_) {
            if (identical(_localBackendProcess, process)) {
              _localBackendProcess = null;
            }
          }),
        );
      }
    } on ProcessException catch (error) {
      return LocalDriveBackendBootstrapResult(
        isAvailable: false,
        didLaunch: false,
        errorMessage:
            'Falha ao iniciar o backend local do Drive: ${error.message}',
      );
    }

    var lastAvailabilityError = initialAvailabilityError;
    for (var attempt = 0; attempt < 12; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final availabilityError = await checkAvailability();
      if (availabilityError == null) {
        return const LocalDriveBackendBootstrapResult(
          isAvailable: true,
          didLaunch: true,
        );
      }
      lastAvailabilityError = availabilityError;
    }

    final processExitCode = await _localBackendProcess?.exitCode.timeout(
      const Duration(milliseconds: 100),
      onTimeout: () => -1,
    );
    final processOutput = outputBuffer.toString().trim();
    final processDetail = processExitCode != null && processExitCode >= 0
        ? ' Processo saiu com codigo $processExitCode.'
        : '';
    final outputDetail = processOutput.isEmpty
        ? ''
        : ' Saida do processo: $processOutput';

    return LocalDriveBackendBootstrapResult(
      isAvailable: false,
      didLaunch: false,
      errorMessage:
          'O backend local foi iniciado, mas nao respondeu ao health check. '
          'Ultimo detalhe: $lastAvailabilityError$processDetail$outputDetail',
    );
  }

  Directory? _findBackendDirectory() {
    const configuredBackendDirectory = String.fromEnvironment(
      'COMPANY_DRIVE_SERVER_DIR',
    );
    final configuredPath = configuredBackendDirectory.trim();
    if (configuredPath.isNotEmpty) {
      final configuredDirectory = Directory(configuredPath).absolute;
      if (_isBackendDirectory(configuredDirectory)) {
        return configuredDirectory;
      }
    }

    final executableDirectory = File(Platform.resolvedExecutable).parent.absolute;
    final startDirectories = <Directory>[
      Directory.current.absolute,
      executableDirectory,
    ];

    final directCandidates = <Directory>[
      Directory(_joinPath(executableDirectory.path, 'company-drive-server')),
      Directory(_joinPath(executableDirectory.path, 'data', 'company-drive-server')),
      Directory(
        _joinPath(
          executableDirectory.path,
          'data',
          'backend',
          'company-drive-server',
        ),
      ),
    ];
    for (final candidate in directCandidates) {
      if (_isBackendDirectory(candidate)) {
        return candidate;
      }
    }

    final visited = <String>{};
    for (final startDirectory in startDirectories) {
      final backendDirectory = _findBackendDirectoryAbove(
        startDirectory,
        visited,
      );
      if (backendDirectory != null) {
        return backendDirectory;
      }
    }

    return null;
  }

  Directory? _findBackendDirectoryAbove(
    Directory startDirectory,
    Set<String> visited,
  ) {
    var currentDirectory = startDirectory;

    for (var depth = 0; depth < 12; depth++) {
      if (!visited.add(currentDirectory.path)) {
        return null;
      }

      final candidate = Directory(
        _joinPath(currentDirectory.path, 'backend', 'company-drive-server'),
      );
      if (_isBackendDirectory(candidate)) {
        return candidate;
      }

      final parent = currentDirectory.parent;
      if (parent.path == currentDirectory.path) {
        break;
      }
      currentDirectory = parent;
    }

    return null;
  }

  bool _isBackendDirectory(Directory directory) {
    final bundledExecutable = File(
      _joinPath(directory.path, _bundledBackendExecutableName),
    );
    final serverEntry = File(_joinPath(directory.path, 'src', 'server.js'));
    final packageManifest = File(_joinPath(directory.path, 'package.json'));
    return bundledExecutable.existsSync() ||
        (serverEntry.existsSync() && packageManifest.existsSync());
  }

  Future<_BackendLaunchCommand?> _resolveBackendLaunchCommand(
    Directory backendDirectory,
  ) async {
    final bundledExecutable = File(
      _joinPath(backendDirectory.path, _bundledBackendExecutableName),
    );
    if (bundledExecutable.existsSync()) {
      return _BackendLaunchCommand(
        executable: bundledExecutable.path,
        arguments: const [],
      );
    }

    final nodeExecutable = await _resolveNodeExecutable();
    if (nodeExecutable == null) {
      return null;
    }

    return _BackendLaunchCommand(
      executable: nodeExecutable,
      arguments: const ['src/server.js'],
    );
  }

  Future<String?> _resolveNodeExecutable() async {
    final candidates = <String>[
      if (Platform.isWindows) 'node.exe' else 'node',
      if (Platform.isMacOS) '/opt/homebrew/bin/node',
      if (Platform.isMacOS || Platform.isLinux) '/usr/local/bin/node',
      if (Platform.isMacOS || Platform.isLinux) '/usr/bin/node',
    ];

    final tested = <String>{};
    for (final candidate in candidates) {
      if (!tested.add(candidate)) {
        continue;
      }

      final resolved = await _canRunCommand(candidate);
      if (resolved) {
        return candidate;
      }
    }

    return null;
  }

  Future<bool> _canRunCommand(String executable) async {
    try {
      final result = await Process.run(executable, const [
        '--version',
      ]).timeout(const Duration(seconds: 2));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<DriveAuthReconnectResult> _reconnectLocalDriveAuthentication() async {
    final gcloudExecutable = await _resolveGcloudExecutable();
    if (gcloudExecutable == null) {
      return const DriveAuthReconnectResult(
        didStart: false,
        errorMessage:
            'O executavel do gcloud nao foi encontrado. Instale o Google Cloud CLI para reautenticar o Drive.',
      );
    }

    final oauthClientFile = _resolveOauthClientFile();
    if (oauthClientFile == null) {
      return const DriveAuthReconnectResult(
        didStart: false,
        errorMessage:
            'O arquivo oauth-client.json nao foi encontrado. Salve o OAuth Client Desktop em backend/company-drive-server/oauth-client.json.',
      );
    }

    try {
      final process = await Process.start(gcloudExecutable, [
        'auth',
        'application-default',
        'login',
        '--client-id-file=${oauthClientFile.path}',
        '--scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/drive',
      ], mode: ProcessStartMode.inheritStdio);
      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        return const DriveAuthReconnectResult(didStart: true);
      }

      return DriveAuthReconnectResult(
        didStart: true,
        errorMessage:
            'O login do Google Cloud CLI terminou com codigo $exitCode.',
      );
    } on ProcessException catch (error) {
      return DriveAuthReconnectResult(
        didStart: false,
        errorMessage:
            'Falha ao iniciar o Google Cloud CLI com `$gcloudExecutable`: ${error.message}',
      );
    }
  }

  File? _resolveOauthClientFile() {
    const configuredOauthClientFile = String.fromEnvironment(
      'COMPANY_DRIVE_OAUTH_CLIENT_FILE',
    );
    final configuredPath = configuredOauthClientFile.trim();
    if (configuredPath.isNotEmpty) {
      final configuredFile = File(configuredPath).absolute;
      if (configuredFile.existsSync()) {
        return configuredFile;
      }
    }

    final backendDirectory = _findBackendDirectory();
    if (backendDirectory == null) {
      return null;
    }

    final defaultFile = File(
      _joinPath(backendDirectory.path, 'oauth-client.json'),
    );
    if (defaultFile.existsSync()) {
      return defaultFile;
    }

    return null;
  }

  Future<String?> _resolveGcloudExecutable() async {
    final candidates = <String>[
      if (Platform.isWindows) 'gcloud.cmd' else 'gcloud',
      if (Platform.isWindows)
        r'C:\Users\danfd\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd',
      if (Platform.isWindows)
        r'C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd',
      if (Platform.isWindows)
        r'C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd',
      if (Platform.isMacOS)
        '/Users/${Platform.environment['USER'] ?? ''}/google-cloud-sdk/bin/gcloud',
      if (Platform.isMacOS) '/opt/homebrew/bin/gcloud',
      if (Platform.isMacOS || Platform.isLinux) '/usr/local/bin/gcloud',
      if (Platform.isMacOS || Platform.isLinux) '/usr/bin/gcloud',
    ];

    final tested = <String>{};
    for (final candidate in candidates) {
      if (candidate.trim().isEmpty || !tested.add(candidate)) {
        continue;
      }

      final resolved = await _canRunCommand(candidate);
      if (resolved) {
        return candidate;
      }
    }

    return null;
  }

  bool _requiresDriveAuthenticationReconnect(http.Response response) {
    final body = response.body.toLowerCase();
    return body.contains('invalid_grant') ||
        body.contains('token has been expired or revoked') ||
        body.contains('expired or revoked') ||
        body.contains('application_default_credentials.json') ||
        body.contains('could not load the default credentials') ||
        body.contains('default credentials') ||
        body.contains('insufficient authentication scopes') ||
        body.contains('request had insufficient authentication scopes') ||
        body.contains('enoent');
  }

  String _joinPath(
    String first,
    String second, [
    String? third,
    String? fourth,
  ]) {
    final buffer = StringBuffer(first);
    for (final segment in [second, third, fourth]) {
      if (segment == null || segment.isEmpty) {
        continue;
      }

      if (!buffer.toString().endsWith(Platform.pathSeparator)) {
        buffer.write(Platform.pathSeparator);
      }
      buffer.write(segment);
    }
    return buffer.toString();
  }

  void dispose() {
    _client.close();
    final process = _localBackendProcess;
    _localBackendProcess = null;
    process?.kill();
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
}

class DriveAuthExpiredException implements Exception {
  const DriveAuthExpiredException();

  @override
  String toString() {
    return 'A autenticacao local do Google Drive expirou. Refaça o login para continuar.';
  }
}

String _defaultUploadUrl() {
  const configuredUploadUrl = String.fromEnvironment(
    'COMPANY_DRIVE_UPLOAD_URL',
  );
  if (configuredUploadUrl.trim().isNotEmpty) {
    return configuredUploadUrl;
  }

  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    return 'http://127.0.0.1:8787/drive/upload';
  }

  return '';
}

const String _bundledBackendExecutableName = 'company-drive-server.exe';

class _BackendLaunchCommand {
  const _BackendLaunchCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

class CompanyDriveStoredFile {
  const CompanyDriveStoredFile({
    required this.fileId,
    required this.fileName,
    required this.viewUrl,
    this.downloadUrl,
  });

  final String fileId;
  final String fileName;
  final String viewUrl;
  final String? downloadUrl;
}

class LocalDriveBackendBootstrapResult {
  const LocalDriveBackendBootstrapResult({
    required this.isAvailable,
    required this.didLaunch,
    this.errorMessage,
  });

  final bool isAvailable;
  final bool didLaunch;
  final String? errorMessage;
}

class DriveAuthReconnectResult {
  const DriveAuthReconnectResult({required this.didStart, this.errorMessage});

  final bool didStart;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

