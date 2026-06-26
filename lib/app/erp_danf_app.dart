import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_version.dart';
import '../auth/firebase_auth_shell.dart';
import '../auth/workspace_credentials.dart';
import '../auth/workspace_session.dart';
import '../data/mock_data.dart';
import '../models/erp_models.dart';
import '../services/company_drive_storage_service.dart';
import '../services/firebase_workflow_repository.dart';
import '../services/software_update_service.dart';

part 'erp_danf_app_customer_registration.dart';
part 'erp_danf_app_estimating.dart';
part 'erp_danf_app_installation.dart';
part 'erp_danf_app_engineering.dart';
part 'erp_danf_app_assembly.dart';
part 'erp_danf_app_checkers.dart';
part 'erp_danf_app_gartic.dart';

Future<void> _openLocalFile(BuildContext context, String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Arquivo local não disponível para abrir.')),
    );
    return;
  }

  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abertura de arquivo indisponível na web.')),
    );
    return;
  }

  final uri = Uri.tryParse(filePath);
  final isRemoteUrl =
      uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

  if (!isRemoteUrl) {
    final file = io.File(filePath);
    if (!await file.exists()) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arquivo não encontrado no caminho salvo.'),
        ),
      );
      return;
    }
  }

  try {
    if (io.Platform.isMacOS) {
      await io.Process.start('open', [filePath]);
    } else if (io.Platform.isWindows) {
      await io.Process.start('cmd', [
        '/c',
        'start',
        '',
        filePath,
      ], runInShell: true);
    } else if (io.Platform.isLinux) {
      await io.Process.start('xdg-open', [filePath]);
    } else {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plataforma sem suporte para abrir arquivo.'),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir o arquivo selecionado.'),
      ),
    );
  }
}

String _stageOwnerSummaryLabel(WorkflowStage stage) {
  return switch (stage) {
    WorkflowStage.customerRegistration => 'Vendedor',
    WorkflowStage.estimating => 'Orçamentista',
    WorkflowStage.finance => 'Financeiro',
    WorkflowStage.relationship => 'Relacionamento',
    WorkflowStage.engineering => 'Engenharia',
    WorkflowStage.assembly => 'Montagem',
    WorkflowStage.installation => 'Instalação',
    WorkflowStage.warehouse => 'Almoxarifado',
    WorkflowStage.stock => 'Estoque',
  };
}

String _workspaceProfileOwnerLabel(EmployeeWorkspaceProfile profile) {
  final name = profile.name.trim();
  final login = profile.login.trim();

  if (name.isEmpty && login.isEmpty) {
    return '';
  }

  if (name.isEmpty) {
    return login;
  }

  if (login.isEmpty) {
    return name;
  }

  return '$name (@$login)';
}

class _ServiceOrderFlowStepData {
  const _ServiceOrderFlowStepData({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

const List<_ServiceOrderFlowStepData> _serviceOrderFlowSteps = [
  _ServiceOrderFlowStepData(
    label: 'Solicitada OS',
    icon: Icons.assignment_outlined,
    color: Color(0xFFB45309),
  ),
  _ServiceOrderFlowStepData(
    label: 'PDF da OS',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFF2563EB),
  ),
  _ServiceOrderFlowStepData(
    label: 'OS Aprovada',
    icon: Icons.verified_outlined,
    color: Color(0xFF15803D),
  ),
  _ServiceOrderFlowStepData(
    label: 'Instalação',
    icon: Icons.home_repair_service_outlined,
    color: Color(0xFFBE123C),
  ),
  _ServiceOrderFlowStepData(
    label: 'OS Realizada',
    icon: Icons.assignment_turned_in_outlined,
    color: Color(0xFF4F46E5),
  ),
  _ServiceOrderFlowStepData(
    label: 'OS Concluída',
    icon: Icons.task_alt_rounded,
    color: Color(0xFF2563EB),
  ),
  _ServiceOrderFlowStepData(
    label: 'OS Paga',
    icon: Icons.paid_outlined,
    color: Color(0xFF0F766E),
  ),
];

int _serviceOrderFlowStageIndex(WorkflowOrder order) {
  if (order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.paid) {
    return 6;
  }
  if (order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.concluded) {
    return 5;
  }
  if (order.installationWorkflowStatus == InstallationWorkflowStatus.done &&
      order.currentStage == WorkflowStage.estimating &&
      order.financeClientApproved) {
    return 4;
  }
  if (order.currentStage == WorkflowStage.installation ||
      order.installationWorkflowStatus != InstallationWorkflowStatus.waiting) {
    return 3;
  }
  if (order.financeClientApproved ||
      order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.approved) {
    return 2;
  }
  if (order.serviceOrderFileName.trim().isNotEmpty) {
    return 1;
  }
  return 0;
}

String _serviceOrderFlowHistory(WorkflowOrder order, int stepIndex) {
  switch (stepIndex) {
    case 0:
      return order.history[WorkflowStage.relationship] ??
          'Aguardando criação da OS';
    case 1:
      return order.serviceOrderFileName.trim().isNotEmpty
          ? (order.history[WorkflowStage.estimating] ?? 'PDF da OS emitido')
          : 'Aguardando PDF da OS';
    case 2:
      return order.financeClientApproved
          ? (order.history[WorkflowStage.finance] ??
                'OS aprovada no Financeiro')
          : 'Aguardando aprovação do cliente';
    case 3:
      return order.installationWorkflowStatus ==
              InstallationWorkflowStatus.waiting
          ? 'Aguardando instalação'
          : (order.history[WorkflowStage.installation] ??
                'Instalação em andamento');
    case 4:
      return order.installationWorkflowStatus == InstallationWorkflowStatus.done
          ? (order.history[WorkflowStage.estimating] ?? 'OS realizada')
          : 'Aguardando OS realizada';
    case 5:
      return order.serviceOrderFinanceStatus.index >=
              ServiceOrderFinanceStatus.concluded.index
          ? (order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.paid
                ? 'OS concluída e enviada para pagamento.'
                : (order.history[WorkflowStage.finance] ?? 'OS concluída'))
          : 'Aguardando OS concluída';
    case 6:
      return order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.paid
          ? (order.history[WorkflowStage.finance] ??
                'Pagamento da OS registrado')
          : 'Aguardando pagamento da OS';
    default:
      return 'Aguardando etapa';
  }
}

List<EmployeeWorkspaceProfile> _assemblyAssignedProfilesForOrder(
  WorkflowOrder order,
  List<EmployeeWorkspaceProfile> profiles,
) {
  final assignedEmails = order.assemblyAssignedEmployeeEmails
      .map((email) => email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toSet();
  if (assignedEmails.isEmpty) {
    return const <EmployeeWorkspaceProfile>[];
  }

  return profiles
      .where(
        (profile) =>
            assignedEmails.contains(profile.email.trim().toLowerCase()),
      )
      .toList(growable: false);
}

List<EmployeeWorkspaceProfile> _profilesForEmails(
  List<String> emails,
  List<EmployeeWorkspaceProfile> profiles,
) {
  final normalizedEmails = emails
      .map((email) => email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toList(growable: false);
  if (normalizedEmails.isEmpty) {
    return const <EmployeeWorkspaceProfile>[];
  }

  return normalizedEmails
      .map((email) {
        final matches = profiles.where(
          (profile) => profile.email.trim().toLowerCase() == email,
        );
        return matches.isEmpty ? null : matches.first;
      })
      .whereType<EmployeeWorkspaceProfile>()
      .toList(growable: false);
}

enum _DriveSyncStatus { checking, synced, offline, notConfigured }

enum _InstallationProgressAction { complete, scheduleReturn }

class ErpDanfApp extends StatefulWidget {
  const ErpDanfApp({
    super.key,
    this.firebaseInitializationError,
    required this.runtimeErrorListenable,
  });

  final Object? firebaseInitializationError;
  final ValueListenable<Object?> runtimeErrorListenable;

  @override
  State<ErpDanfApp> createState() => _ErpDanfAppState();
}

class _ErpDanfAppState extends State<ErpDanfApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6B4F);

    return ValueListenableBuilder<Object?>(
      valueListenable: widget.runtimeErrorListenable,
      builder: (context, runtimeError, _) {
        final firebaseError =
            widget.firebaseInitializationError ??
            (_looksLikeFirebaseConfigurationError(runtimeError)
                ? runtimeError
                : null);

        final home = firebaseError != null
            ? FirebaseConfigurationScreen(error: firebaseError)
            : FirebaseAuthShell(
                firebaseInitializationError: widget.firebaseInitializationError,
                authenticatedBuilder: (context) => ErpDashboardPage(
                  themeMode: _themeMode,
                  onThemeModeChanged: _setThemeMode,
                ),
              );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ERP DANF',
          theme: _buildTheme(seed: seed, brightness: Brightness.light),
          darkTheme: _buildTheme(seed: seed, brightness: Brightness.dark),
          themeMode: _themeMode,
          home: home,
        );
      },
    );
  }
}

bool _looksLikeFirebaseConfigurationError(Object? error) {
  if (error == null) {
    return false;
  }

  final message = error.toString().toLowerCase();
  return message.contains('firebase') ||
      message.contains('google-service-info') ||
      message.contains('google_service_info') ||
      message.contains('defaultfirebaseoptions') ||
      message.contains('core/no-app');
}

bool _hasEstimatingWorksheetData(WorkflowOrder order) {
  final requiredLabels = _estimatingIncludedVisitLabelsForOrder(order);
  final hasAllVisitDays = requiredLabels.every(
    (label) => order.estimatingIncludedVisits.any(
      (entry) => entry.label == label && entry.days.trim().isNotEmpty,
    ),
  );
  if (!hasAllVisitDays) {
    return false;
  }
  if (order.estimatingMaterials.isEmpty) {
    return false;
  }
  return order.estimatingMaterials.every(
        (entry) =>
            entry.quantity.trim().isNotEmpty &&
            entry.description.trim().isNotEmpty &&
            entry.model.trim().isNotEmpty,
      ) &&
      (order.estimatingWasEstimate.trim() == 'Sim' ||
          order.estimatingWasEstimate.trim() == 'Não');
}

int _plannedVisitCountForOrder(WorkflowOrder order) {
  return order.estimatingIncludedVisits.fold<int>(0, (total, entry) {
    return total + (int.tryParse(entry.days.trim()) ?? 0);
  });
}

int _completedVisitCountForOrder(WorkflowOrder order) {
  var completedCount = 0;
  if (_normalizeEngineeringChecklistStatus(
        order.engineeringChecklistStatuses['meeting_electrician'] ??
            EngineeringChecklistStatus.notStarted,
      ) ==
      EngineeringChecklistStatus.done) {
    completedCount += 1;
  }
  if (_normalizeEngineeringChecklistStatus(
        order.engineeringChecklistStatuses['conference_done'] ??
            EngineeringChecklistStatus.notStarted,
      ) ==
      EngineeringChecklistStatus.done) {
    completedCount += 1;
  }
  completedCount += order.installationVisitHistory
      .where((visit) => visit.plannedItems.isNotEmpty)
      .length;
  return completedCount;
}

int _remainingVisitCountForOrder(WorkflowOrder order) {
  final plannedCount = _plannedVisitCountForOrder(order);
  final completedCount = _completedVisitCountForOrder(order);
  final remainingCount = plannedCount - completedCount;
  return remainingCount < 0 ? 0 : remainingCount;
}

String? _visitProgressLabelForOrder(WorkflowOrder order) {
  if (order.isServiceOrder) {
    return null;
  }
  final plannedCount = _plannedVisitCountForOrder(order);
  if (plannedCount <= 0) {
    return null;
  }
  final completedCount = _completedVisitCountForOrder(order);
  return '$completedCount/$plannedCount';
}

ThemeData _buildTheme({required Color seed, required Brightness brightness}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  ).copyWith(surfaceTint: Colors.transparent);
  final isDark = brightness == Brightness.dark;

  final backgroundColor = isDark
      ? const Color(0xFF18191B)
      : const Color(0xFFF7F7F5);
  final surfaceColor = isDark ? const Color(0xFF202225) : Colors.white;
  final surfaceVariantColor = isDark
      ? const Color(0xFF26282B)
      : const Color(0xFFF5F5F3);
  final borderColor = isDark
      ? const Color(0xFF2F3134)
      : const Color(0xFFE8E8E5);
  final primaryTextColor = isDark
      ? const Color(0xFFF2F2F0)
      : const Color(0xFF1A1A1A);
  final secondaryTextColor = isDark
      ? const Color(0xFFA3A39E)
      : const Color(0xFF6B6B68);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: surfaceColor,
    dialogTheme: DialogThemeData(backgroundColor: surfaceColor),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: primaryTextColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
    ),
    dividerTheme: DividerThemeData(color: borderColor, space: 1, thickness: 1),
    textTheme: GoogleFonts.interTextTheme(
      (isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
    ).apply(bodyColor: primaryTextColor, displayColor: primaryTextColor),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariantColor,
      hintStyle: TextStyle(color: secondaryTextColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryTextColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: surfaceVariantColor,
        foregroundColor: primaryTextColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? surfaceVariantColor : null,
      contentTextStyle: TextStyle(color: isDark ? primaryTextColor : null),
    ),
  );
}

const Set<WorkflowStage> _workAndCatalogStages = {
  WorkflowStage.estimating,
  WorkflowStage.finance,
  WorkflowStage.relationship,
  WorkflowStage.engineering,
  WorkflowStage.assembly,
  WorkflowStage.installation,
};

const Set<WorkflowStage> _standaloneWorkspaceStages = {
  WorkflowStage.warehouse,
  WorkflowStage.stock,
};

enum _StageOrdersView { list, kanban }

class ErpDashboardPage extends StatefulWidget {
  const ErpDashboardPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ErpDashboardPage> createState() => _ErpDashboardPageState();
}

class _ErpDashboardPageState extends State<ErpDashboardPage> {
  static const _platformLogStorageKey = 'erp_danf_platform_logs';
  final FirebaseWorkflowRepository _repository = FirebaseWorkflowRepository();
  final SoftwareUpdateService _softwareUpdateService = SoftwareUpdateService();
  List<WorkflowOrder> _orders = List.of(mockOrders);
  List<EmployeeWorkspaceProfile> _workspaceProfiles = workspaceProfiles
      .map((profile) => profile.copyWith())
      .toList(growable: true);
  List<_PlatformLogEntry> _platformLogs = const [];
  StreamSubscription<List<WorkflowOrder>>? _ordersSubscription;
  StreamSubscription<List<EmployeeWorkspaceProfile>>? _profilesSubscription;
  final TextEditingController _customerSearchController =
      TextEditingController();
  String _selectedViewKey = 'workspace';
  int _customerRegistrationSubtab =
      0; // Added definition for _customerRegistrationSubtab
  String? _selectedOrderCode;
  String? _selectedManagedUserEmail;
  final Map<WorkflowStage, int> _stageWorkspaceSubtabs = {
    WorkflowStage.estimating: 0,
    WorkflowStage.finance: 0,
    WorkflowStage.relationship: 0,
    WorkflowStage.engineering: 0,
    WorkflowStage.assembly: 0,
    WorkflowStage.installation: 0,
  };
  String _customerSearchQuery = '';
  bool _ordersLoaded = false;
  bool _profilesLoaded = false;
  String? _busyMessage;
  Object? _syncError;
  Object? _softwareUpdateError;
  bool _isCheckingSoftwareUpdate = false;
  SoftwareUpdateManifest? _availableSoftwareUpdate;
  bool _didCheckLocalDriveBackend = false;
  _DriveSyncStatus _driveSyncStatus = _DriveSyncStatus.checking;
  final Map<WorkflowStage, _StageOrdersView> _stageOrdersViews = {
    for (final stage in workspaceStages) stage: _StageOrdersView.kanban,
  };
  DateTime _selectedInstallationCalendarDate = DateUtils.dateOnly(
    DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlatformLogs());
    _startFirebaseSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshDriveSyncStatus());
      unawaited(_checkForSoftwareUpdate(showNoUpdateMessage: false));
    });
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _profilesSubscription?.cancel();
    _customerSearchController.dispose();
    _repository.dispose();
    _softwareUpdateService.dispose();
    super.dispose();
  }

  void _setStateSafely(VoidCallback fn) {
    if (!mounted) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(fn);
    });
  }

  Future<void> _startFirebaseSync() async {
    try {
      await _repository.ensureWorkspaceProfiles(workspaceProfiles);
    } catch (error) {
      _setStateSafely(() {
        _syncError = error;
        _profilesLoaded = true;
      });
    }

    _ordersSubscription = _repository.watchOrders().listen((orders) {
      _setStateSafely(() {
        _orders = orders;
        _ordersLoaded = true;
        _syncError = null;
        if (_selectedOrderCode != null &&
            !_orders.any((order) => order.code == _selectedOrderCode)) {
          _selectedOrderCode = null;
        }
      });
    }, onError: _handleSyncError);

    _profilesSubscription = _repository.watchWorkspaceProfiles().listen((
      profiles,
    ) {
      _setStateSafely(() {
        _workspaceProfiles = profiles.isEmpty
            ? workspaceProfiles.map((profile) => profile.copyWith()).toList()
            : profiles;
        _profilesLoaded = true;
        _syncError = null;
        if (_selectedManagedUserEmail != null &&
            !_workspaceProfiles.any(
              (profile) => profile.email == _selectedManagedUserEmail,
            )) {
          _selectedManagedUserEmail = null;
        }
      });
    }, onError: _handleSyncError);
  }

  Future<void> _refreshDriveSyncStatus() async {
    if (!_repository.isDriveUploadConfigured) {
      if (mounted) {
        setState(() {
          _driveSyncStatus = _DriveSyncStatus.notConfigured;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _driveSyncStatus = _DriveSyncStatus.checking;
      });
    }

    if (!_repository.isUsingLocalDriveUpload) {
      final availabilityError = await _repository
          .checkDriveUploadAvailability();
      if (!mounted) {
        return;
      }

      setState(() {
        _driveSyncStatus = availabilityError == null
            ? _DriveSyncStatus.synced
            : _isDriveConfigurationMissingError(availabilityError)
            ? _DriveSyncStatus.notConfigured
            : _DriveSyncStatus.offline;
      });
      return;
    }

    if (_didCheckLocalDriveBackend) {
      final availabilityError = await _repository
          .checkDriveUploadAvailability();
      if (!mounted) {
        return;
      }

      setState(() {
        _driveSyncStatus = availabilityError == null
            ? _DriveSyncStatus.synced
            : _isDriveConfigurationMissingError(availabilityError)
            ? _DriveSyncStatus.notConfigured
            : _DriveSyncStatus.offline;
      });
      return;
    }

    _didCheckLocalDriveBackend = true;
    final result = await _repository.ensureLocalDriveBackendRunning();
    if (!mounted) {
      return;
    }

    setState(() {
      _driveSyncStatus = result.isAvailable
          ? _DriveSyncStatus.synced
          : _isDriveConfigurationMissingError(result.errorMessage)
          ? _DriveSyncStatus.notConfigured
          : _DriveSyncStatus.offline;
    });

    if (result.isAvailable && result.didLaunch) {
      _showAppMessage('Servidor local do Drive iniciado automaticamente.');
      return;
    }

    if (!result.isAvailable &&
        !_isDriveConfigurationMissingError(result.errorMessage)) {
      _showAppMessage(
        'Servidor local do Drive indisponível. Detalhe: ${result.errorMessage}',
        isError: true,
      );
    }
  }

  Future<void> _checkForSoftwareUpdate({
    required bool showNoUpdateMessage,
  }) async {
    if (!_softwareUpdateService.isConfigured) {
      if (showNoUpdateMessage) {
        _showAppMessage(
          'Atualizacao automatica nao configurada neste executavel.',
          isError: true,
        );
      }
      return;
    }

    if (_isCheckingSoftwareUpdate) {
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingSoftwareUpdate = true;
        _softwareUpdateError = null;
      });
    }

    try {
      final result = await _softwareUpdateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableSoftwareUpdate = result.hasUpdate ? result.manifest : null;
      });

      if (!result.hasUpdate && showNoUpdateMessage) {
        _showAppMessage('Voce ja esta usando a versao mais recente.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _softwareUpdateError = error;
      });

      if (showNoUpdateMessage) {
        _showAppMessage(
          'Nao foi possivel verificar atualizacoes: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSoftwareUpdate = false;
        });
      }
    }
  }

  Future<void> _installAvailableSoftwareUpdate() async {
    final manifest = _availableSoftwareUpdate;
    if (manifest == null) {
      return;
    }

    final shouldInstall = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atualizar ERP DANF?'),
        content: Text(
          'A versao ${manifest.version} sera baixada e instalada. '
          'O app vai fechar e abrir novamente no final.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Depois'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
    if (shouldInstall != true) {
      return;
    }

    await _runBusyTask(
      () async {
        final packageFile = await _softwareUpdateService.downloadUpdatePackage(
          manifest,
          onProgress: (received, total) {
            if (!mounted || total == null || total <= 0) {
              return;
            }

            final percentage = ((received / total) * 100).clamp(0, 100).round();
            setState(() {
              _busyMessage = 'Baixando atualizacao... $percentage%';
            });
          },
        );
        if (mounted) {
          setState(() {
            _busyMessage = 'Aplicando atualizacao...';
          });
        }
        await _softwareUpdateService.installDownloadedPackage(packageFile);
      },
      busyMessage: 'Baixando atualizacao...',
      errorPrefix: 'Nao foi possivel atualizar o ERP DANF',
    );
  }

  bool _isDriveConfigurationMissingError(String? errorMessage) {
    final normalized = errorMessage?.toLowerCase() ?? '';
    return normalized.contains('oauth-client.json') ||
        normalized.contains('oauth client desktop') ||
        normalized.contains('drive não configurado') ||
        normalized.contains('drive nao configurado');
  }

  Future<void> _loadPlatformLogs() async {
    final preferences = await SharedPreferences.getInstance();
    final storedEntries =
        preferences.getStringList(_platformLogStorageKey) ?? const [];
    final loadedEntries = <_PlatformLogEntry>[];

    for (final rawEntry in storedEntries) {
      try {
        final decoded = jsonDecode(rawEntry);
        if (decoded is Map<String, dynamic>) {
          final entry = _PlatformLogEntry.fromMap(decoded);
          if (_shouldDisplayPlatformLogEntry(entry)) {
            loadedEntries.add(entry);
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _platformLogs = loadedEntries;
    });

    await _persistPlatformLogs();
  }

  Future<void> _persistPlatformLogs() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _platformLogStorageKey,
      _platformLogs.map((entry) => jsonEncode(entry.toMap())).toList(),
    );
  }

  Future<void> _appendPlatformLog({
    required String action,
    required String area,
    String? details,
  }) async {
    final actor = _currentWorkspaceProfile.name.trim().isNotEmpty
        ? _currentWorkspaceProfile.name.trim()
        : (_currentUserEmail ?? 'Sistema');
    final entry = _PlatformLogEntry(
      actor: actor,
      action: action,
      area: area,
      details: details,
      createdAt: DateTime.now(),
    );

    if (!_shouldDisplayPlatformLogEntry(entry)) {
      return;
    }

    if (mounted) {
      setState(() {
        _platformLogs = [
          entry,
          ..._platformLogs,
        ].take(200).toList(growable: false);
      });
    } else {
      _platformLogs = [
        entry,
        ..._platformLogs,
      ].take(200).toList(growable: false);
    }

    await _persistPlatformLogs();
  }

  Future<void> _clearPlatformLogs() async {
    if (mounted) {
      setState(() {
        _platformLogs = const [];
      });
    } else {
      _platformLogs = const [];
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_platformLogStorageKey);
  }

  bool _shouldDisplayPlatformLogEntry(_PlatformLogEntry entry) {
    return entry.area != 'Navegação' && entry.area != 'Sessão';
  }

  List<EmployeeWorkspaceProfile> _resolveMentionedProfiles(String message) {
    final matches = RegExp(r'(?:^|\\s)@([A-Za-z0-9._-]+)')
        .allMatches(message)
        .map((match) => (match.group(1) ?? '').trim().toLowerCase())
        .where((login) => login.isNotEmpty)
        .toSet();
    if (matches.isEmpty) {
      return const <EmployeeWorkspaceProfile>[];
    }

    return _workspaceProfiles
        .where(
          (profile) => matches.contains(profile.login.trim().toLowerCase()),
        )
        .toList(growable: false);
  }

  int _unreadMentionCountForOrder(WorkflowOrder order) {
    final email = _currentUserEmail;
    if (email == null || email.isEmpty) {
      return 0;
    }

    return order.conversationMessages.where((message) {
      return message.mentionedUserEmails.contains(email) &&
          !message.readByUserEmails.contains(email) &&
          message.authorEmail != email;
    }).length;
  }

  List<_OrderConversationNotification> get _conversationNotifications {
    final email = _currentUserEmail;
    if (email == null || email.isEmpty) {
      return const <_OrderConversationNotification>[];
    }

    final notifications = <_OrderConversationNotification>[];
    for (final order in _orders) {
      for (final message in order.conversationMessages) {
        if (!message.mentionedUserEmails.contains(email) ||
            message.readByUserEmails.contains(email) ||
            message.authorEmail == email) {
          continue;
        }
        notifications.add(
          _OrderConversationNotification(
            orderCode: order.code,
            orderLabel: _displayOrderCode(order, _orders),
            workName: order.workName,
            stage: order.currentStage,
            authorName: message.authorName,
            preview: message.message,
            createdAt: message.createdAt,
          ),
        );
      }
    }

    notifications.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
    return notifications;
  }

  Future<void> _markConversationMentionsAsRead(String orderCode) async {
    final email = _currentUserEmail;
    if (email == null || email.isEmpty) {
      return;
    }

    final selected = _findOrderByCode(orderCode);
    if (selected == null) {
      return;
    }

    var changed = false;
    final updatedMessages = selected.conversationMessages
        .map((message) {
          if (!message.mentionedUserEmails.contains(email) ||
              message.readByUserEmails.contains(email)) {
            return message;
          }

          changed = true;
          return message.copyWith(
            readByUserEmails: {
              ...message.readByUserEmails,
              email,
            }.toList(growable: false),
          );
        })
        .toList(growable: false);

    if (!changed) {
      return;
    }

    final savedOrder = await _repository.saveOrder(
      selected.copyWith(conversationMessages: updatedMessages),
    );
    _mergeOrderLocally(savedOrder);
    _setStateSafely(() {});
  }

  Future<bool> _sendConversationMessage(
    String orderCode,
    String messageText,
  ) async {
    final selected = _findOrderByCode(orderCode);
    if (selected == null) {
      return false;
    }

    final normalizedMessage = messageText.trim();
    if (normalizedMessage.isEmpty) {
      return false;
    }

    final authorProfile = _currentWorkspaceProfile;
    final authorEmail = (_currentUserEmail ?? authorProfile.email)
        .trim()
        .toLowerCase();
    final mentionedProfiles = _resolveMentionedProfiles(normalizedMessage);
    final mentionedEmails = mentionedProfiles
        .map((profile) => profile.email.trim().toLowerCase())
        .where((email) => email.isNotEmpty && email != authorEmail)
        .toSet()
        .toList(growable: false);
    final newMessage = OrderConversationMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      authorEmail: authorEmail,
      authorName: authorProfile.name.trim().isEmpty
          ? (authorProfile.login.trim().isEmpty
                ? 'Colaborador'
                : authorProfile.login)
          : authorProfile.name.trim(),
      message: normalizedMessage,
      createdAt: DateTime.now(),
      mentionedUserEmails: mentionedEmails,
      readByUserEmails: authorEmail.isEmpty ? const [] : [authorEmail],
    );
    final updatedOrder = selected.copyWith(
      conversationMessages: [...selected.conversationMessages, newMessage],
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Enviando mensagem...',
      errorPrefix: 'Não foi possível enviar a mensagem',
    );
    if (savedOrder == null) {
      return false;
    }

    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Comentou no card do cliente',
        area: savedOrder.currentStage.title,
        details: '${_displayOrderCode(savedOrder)} • ${savedOrder.workName}',
      ),
    );
    return true;
  }

  Future<void> _openOrderDetailsScreen(
    WorkflowOrder order, {
    bool openConversationOnLoad = false,
  }) async {
    final orderStage = order.currentStage;
    setState(() {
      _selectedViewKey = 'stage:${orderStage.name}';
      _selectedOrderCode = order.code;
      if (_usesWorkAndCatalogSubtabs(orderStage)) {
        _stageWorkspaceSubtabs[orderStage] = 0;
      }
    });

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _OrderDetailsScreen(
          stage: orderStage,
          orderCode: order.code,
          showEngineeringChecklist: orderStage == WorkflowStage.engineering,
          showFlowActions: _currentWorkspaceProfile.allowedStages.contains(
            orderStage,
          ),
          resolveOrderByCode: _findOrderByCode,
          getAllOrders: () =>
              List<WorkflowOrder>.from(_orders, growable: false),
          currentProfile: _currentWorkspaceProfile,
          workspaceProfiles: _workspaceProfiles,
          unreadMentionCount: _unreadMentionCountForOrder(order),
          openConversationOnLoad: openConversationOnLoad,
          onMarkConversationRead: _markConversationMentionsAsRead,
          onSendConversationMessage: _sendConversationMessage,
          onAdvanceOrder: () => _moveSelectedOrder(1),
          onReturnOrder: () => _moveSelectedOrder(-1),
          onSendToEngineering: () =>
              _routeSelectedOrderToStage(WorkflowStage.engineering),
          onSendToAssembly: () =>
              _routeSelectedOrderToStage(WorkflowStage.assembly),
          onSendToInstallation: () =>
              _routeSelectedOrderToStage(WorkflowStage.installation),
          onAttachMaterials: _attachMaterialsToSelectedOrder,
          onSetEstimatingWasEstimate: _setEstimatingWasEstimateForSelectedOrder,
          onAttachElectricalProject: _attachElectricalProjectToSelectedOrder,
          onAttachPanelLayout: _attachPanelLayoutToSelectedOrder,
          onAttachPushButtonTable: _attachPushButtonTableToSelectedOrder,
          onAttachEngineeringData: _attachEngineeringDataToSelectedOrder,
          onAttachConsolidatedProposal:
              _attachConsolidatedProposalToSelectedOrder,
          onAttachContract: _attachContractToSelectedOrder,
          onAttachServiceOrderPdf: _attachServiceOrderPdfToSelectedOrder,
          onToggleFinanceClientApproval:
              _toggleFinanceClientApprovalForSelectedOrder,
          onScheduleInstallation: _scheduleInstallationForSelectedOrder,
          onToggleInstallationExecutionItem: _toggleInstallationExecutionItem,
          onOpenAssemblyPreparationChecklist:
              _openAssemblyChecklistForSelectedOrder,
          onScheduleEngineeringActivity: _scheduleEngineeringActivity,
          onUpdateEngineeringChecklistStatus: _updateEngineeringChecklistStatus,
          onUpdateFinanceContractStatus: _updateFinanceContractStatus,
          onUpdateRelationshipKanbanStatus: _updateRelationshipKanbanStatus,
          onEditOrder:
              (!_currentWorkspaceProfile.isAdministrator &&
                      !_currentWorkspaceProfile.allowedStages.contains(
                        WorkflowStage.customerRegistration,
                      )) ||
                  order.isServiceOrder
              ? null
              : () =>
                    _openCustomerRegistrationForm(_findOrderByCode(order.code)),
          onDeleteOrder: _currentWorkspaceProfile.isAdministrator
              ? _deleteSelectedOrder
              : null,
        ),
      ),
    );
  }

  void _handleSyncError(Object error) {
    _setStateSafely(() {
      _syncError = error;
      _ordersLoaded = true;
      _profilesLoaded = true;
    });
  }

  String? get _currentUserEmail =>
      WorkspaceSession.instance.currentProfileId?.trim().toLowerCase();

  EmployeeWorkspaceProfile? get _matchedWorkspaceProfile {
    final email = _currentUserEmail;
    if (email == null || email.isEmpty) {
      return null;
    }

    for (final profile in _workspaceProfiles) {
      if (profile.email.toLowerCase() == email) {
        return profile;
      }
    }

    return null;
  }

  bool get _currentUserHasWorkspaceAccess => _matchedWorkspaceProfile != null;

  bool get _hasFirestorePermissionError {
    final errorText = _syncError?.toString().toLowerCase() ?? '';
    return errorText.contains('permission-denied');
  }

  List<_FlowNavItem> get _visibleTabs {
    final profile = _currentWorkspaceProfile;
    return [
      const _FlowNavItem(
        routeKey: 'workspace',
        label: 'Área de trabalho',
        icon: Icons.workspaces_outline,
        color: Color(0xFF12372A),
      ),
      ...(profile.isAdministrator ? workspaceStages : profile.allowedStages)
          .map(
            (stage) => _FlowNavItem(
              routeKey: 'stage:${stage.name}',
              label: stage.title,
              icon: stage.icon,
              color: stage.color,
              stage: stage,
              badgeCount: stage == WorkflowStage.relationship
                  ? _mergeableCandidates.length
                  : 0,
            ),
          ),
      if (profile.isAdministrator)
        const _FlowNavItem(
          routeKey: 'admin',
          label: 'Administração',
          icon: Icons.admin_panel_settings_outlined,
          color: Color(0xFF0F172A),
        ),
      if (profile.isAdministrator)
        const _FlowNavItem(
          routeKey: 'log',
          label: 'Log',
          icon: Icons.receipt_long_outlined,
          color: Color(0xFF475569),
        ),
    ];
  }

  WorkflowStage? get _selectedStage {
    if (!_selectedViewKey.startsWith('stage:')) {
      return null;
    }

    final stageName = _selectedViewKey.replaceFirst('stage:', '');
    return WorkflowStage.values.byName(stageName);
  }

  bool _usesWorkAndCatalogSubtabs(WorkflowStage stage) {
    return _workAndCatalogStages.contains(stage);
  }

  bool _isStandaloneWorkspaceStage(WorkflowStage stage) {
    return _standaloneWorkspaceStages.contains(stage);
  }

  int _stageWorkspaceSubtabIndex(WorkflowStage stage) {
    return _stageWorkspaceSubtabs[stage] ?? 0;
  }

  List<WorkflowOrder> get _filteredOrders {
    final stage = _selectedStage;
    if (stage == null) {
      return _orders;
    }

    if (stage == WorkflowStage.customerRegistration) {
      return _orders
          .where((order) => order.currentStage == stage)
          .toList(growable: false);
    }

    if (_usesWorkAndCatalogSubtabs(stage) &&
        _stageWorkspaceSubtabIndex(stage) == 0) {
      return _orders
          .where((order) => order.currentStage == stage)
          .toList(growable: false);
    }

    if (_isStandaloneWorkspaceStage(stage)) {
      return const <WorkflowOrder>[];
    }

    return _orders;
  }

  List<WorkflowOrder> get _selectedOrderPool {
    final stage = _selectedStage;
    if (stage != null &&
        _usesWorkAndCatalogSubtabs(stage) &&
        _stageWorkspaceSubtabIndex(stage) == 1) {
      return _orders
          .where((order) => _matchesCustomerSearch(order))
          .toList(growable: false);
    }

    return _filteredOrders;
  }

  EmployeeWorkspaceProfile get _currentWorkspaceProfile {
    final matchedProfile = _matchedWorkspaceProfile;
    if (matchedProfile != null) {
      return matchedProfile;
    }

    return const EmployeeWorkspaceProfile(
      email: '',
      login: '',
      name: 'Conta sem acesso',
      cellPhone: '',
      role: 'Aguardando liberação no Firebase',
      isAdministrator: false,
      allowedStages: [],
      accent: Color(0xFF12372A),
      accessCodeHash: '',
    );
  }

  List<WorkspaceTask> get _currentWorkspaceTasks {
    final profile = _currentWorkspaceProfile;
    final email = _currentUserEmail;

    return workspaceTasks
        .where((task) {
          final taskAssignedToUser =
              email != null && task.assigneeEmail.toLowerCase() == email;
          final taskWithinAllowedStages = profile.allowedStages.contains(
            task.stage,
          );

          return taskWithinAllowedStages &&
              (taskAssignedToUser ||
                  profile.email.isEmpty ||
                  profile.isAdministrator);
        })
        .toList(growable: false);
  }

  EmployeeWorkspaceProfile? get _selectedManagedProfile {
    if (_workspaceProfiles.isEmpty) {
      return null;
    }

    if (_selectedManagedUserEmail != null) {
      final matched = _workspaceProfiles.where(
        (profile) => profile.email == _selectedManagedUserEmail,
      );
      if (matched.isNotEmpty) {
        return matched.first;
      }
    }

    return _workspaceProfiles.first;
  }

  WorkflowOrder? get _selectedOrder {
    final orders = _selectedOrderPool;
    if (orders.isEmpty) {
      return null;
    }

    if (_selectedOrderCode == null) {
      return null;
    }

    final matched = orders.where((order) => order.code == _selectedOrderCode);
    if (matched.isNotEmpty) {
      return matched.first;
    }

    return null;
  }

  WorkflowOrder? _findOrderByCode(String code) {
    final matched = _orders.where((order) => order.code == code);
    if (matched.isEmpty) {
      return null;
    }

    return matched.first;
  }

  void _selectTab(int index) {
    final tabs = _visibleTabs;
    if (index < 0 || index >= tabs.length) {
      return;
    }

    final selectedTab = tabs[index];
    if (_selectedViewKey == selectedTab.routeKey) {
      return;
    }

    setState(() {
      _selectedViewKey = selectedTab.routeKey;
      _selectedOrderCode = null;
      if (_selectedViewKey !=
          'stage:${WorkflowStage.customerRegistration.name}') {
        _customerRegistrationSubtab = 0;
      }
      for (final stage in _workAndCatalogStages) {
        if (_selectedViewKey != 'stage:${stage.name}') {
          _stageWorkspaceSubtabs[stage] = 0;
        }
      }
    });
  }

  void _selectCustomerRegistrationSubtab(int index) {
    setState(() {
      _customerRegistrationSubtab = index;
      _selectedOrderCode = null;
    });
  }

  void _selectStageWorkspaceSubtab(WorkflowStage stage, int index) {
    setState(() {
      _stageWorkspaceSubtabs[stage] = index;
      _selectedOrderCode = null;
    });
  }

  void _selectOrder(WorkflowOrder order) {
    setState(() {
      _selectedOrderCode = order.code;
    });
  }

  void _selectStageOrdersView(WorkflowStage stage, _StageOrdersView view) {
    if (_stageOrdersViews[stage] == view) {
      return;
    }

    setState(() {
      _stageOrdersViews[stage] = view;
    });
  }

  void _selectInstallationCalendarDate(DateTime date) {
    setState(() {
      _selectedInstallationCalendarDate = DateUtils.dateOnly(date);
    });
  }

  void _selectManagedUser(String email) {
    setState(() {
      _selectedManagedUserEmail = email;
    });
  }

  List<_ServiceOrderClientOption> get _serviceOrderClientOptions {
    final latestByClientId = <String, WorkflowOrder>{};

    for (final order in _orders) {
      if (order.client.id.trim().isEmpty) {
        continue;
      }

      if (latestByClientId.containsKey(order.client.id)) {
        continue;
      }

      latestByClientId[order.client.id] = order;
    }

    final options = latestByClientId.values
        .map(
          (order) => _ServiceOrderClientOption(
            client: order.client,
            address: order.address,
            referenceWorkName: order.workName,
          ),
        )
        .toList(growable: true);

    options.sort(
      (left, right) => left.client.name.toLowerCase().compareTo(
        right.client.name.toLowerCase(),
      ),
    );
    return options;
  }

  Future<void> _openCreateManagedUserDialog() async {
    final draft = await showDialog<_WorkspaceUserDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _WorkspaceUserDialog(),
    );

    if (draft == null) {
      return;
    }

    final normalizedLogin = draft.login.trim().toLowerCase();
    if (_workspaceProfiles.any(
      (profile) =>
          profile.login.toLowerCase() == normalizedLogin ||
          profile.email.toLowerCase() == normalizedLogin,
    )) {
      _showAppMessage(
        'Já existe um usuário com esse login interno.',
        isError: true,
      );
      return;
    }

    final allowedStages =
        draft.isAdministrator
              ? List<WorkflowStage>.from(workspaceStages)
              : List<WorkflowStage>.from(draft.allowedStages)
          ..sort(
            (left, right) => workspaceStages
                .indexOf(left)
                .compareTo(workspaceStages.indexOf(right)),
          );

    final profile = EmployeeWorkspaceProfile(
      email: normalizedLogin,
      login: normalizedLogin,
      name: draft.name.trim(),
      cellPhone: draft.cellPhone.trim(),
      role: draft.role.trim(),
      isAdministrator: draft.isAdministrator,
      allowedStages: allowedStages,
      accent: _nextWorkspaceProfileAccent(),
      accessCodeHash: hashWorkspaceAccessCode(draft.accessCode),
      photoFileName: draft.photoFileName,
      photoFilePath: draft.photoFilePath,
    );

    setState(() {
      _workspaceProfiles = [..._workspaceProfiles, profile];
      _selectedManagedUserEmail = profile.email;
    });

    final savedProfile = await _runBusyTask(
      () async {
        return _repository.saveWorkspaceProfile(profile);
      },
      busyMessage: 'Criando usuário...',
      successMessage: 'Usuário criado com sucesso.',
      errorPrefix: 'Não foi possível criar o usuário',
    );

    if (savedProfile == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _workspaceProfiles = _workspaceProfiles
            .where((item) => item.email != profile.email)
            .toList(growable: false);
        if (_selectedManagedUserEmail == profile.email) {
          _selectedManagedUserEmail = null;
        }
      });
      return;
    }

    setState(() {
      _workspaceProfiles = _workspaceProfiles
          .map((item) => item.email == savedProfile.email ? savedProfile : item)
          .toList(growable: false);
      _selectedManagedUserEmail = savedProfile.email;
    });
    unawaited(
      _appendPlatformLog(
        action: 'Criou usuário',
        area: 'Administração',
        details: '${savedProfile.name} (@${savedProfile.login})',
      ),
    );

    if (!_repository.isDriveUploadConfigured &&
        profile.photoFilePath != null &&
        profile.photoFilePath!.trim().isNotEmpty) {
      _showAppMessage(
        'Usuário criado, mas a foto ficou salva apenas neste computador. Configure o backend do Drive para hospedá-la centralmente.',
        isError: true,
      );
    }
  }

  Future<void> _openEditManagedUserDialog(
    EmployeeWorkspaceProfile profile,
  ) async {
    final draft = await showDialog<_WorkspaceUserDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WorkspaceUserDialog(initialProfile: profile),
    );

    if (draft == null) {
      return;
    }

    final updatedStages =
        draft.isAdministrator
              ? List<WorkflowStage>.from(workspaceStages)
              : List<WorkflowStage>.from(draft.allowedStages)
          ..sort(
            (left, right) => workspaceStages
                .indexOf(left)
                .compareTo(workspaceStages.indexOf(right)),
          );

    final updatedProfile = profile.copyWith(
      name: draft.name.trim(),
      cellPhone: draft.cellPhone.trim(),
      role: draft.role.trim(),
      isAdministrator: draft.isAdministrator,
      allowedStages: updatedStages,
      accessCodeHash: draft.accessCode.trim().isEmpty
          ? profile.accessCodeHash
          : hashWorkspaceAccessCode(draft.accessCode),
      photoFileName: draft.photoFileName,
      photoFilePath: draft.photoFilePath,
    );

    setState(() {
      _workspaceProfiles = _workspaceProfiles
          .map(
            (item) =>
                item.email == updatedProfile.email ? updatedProfile : item,
          )
          .toList(growable: false);
      _selectedManagedUserEmail = updatedProfile.email;
    });

    final savedProfile = await _runBusyTask(
      () => _repository.saveWorkspaceProfile(updatedProfile),
      busyMessage: 'Salvando usuário...',
      successMessage: 'Usuário atualizado com sucesso.',
      errorPrefix: 'Não foi possível salvar o usuário',
    );

    if (savedProfile == null) {
      setState(() {
        _workspaceProfiles = _workspaceProfiles
            .map((item) => item.email == profile.email ? profile : item)
            .toList(growable: false);
      });
      return;
    }

    setState(() {
      _workspaceProfiles = _workspaceProfiles
          .map((item) => item.email == savedProfile.email ? savedProfile : item)
          .toList(growable: false);
    });
    unawaited(
      _appendPlatformLog(
        action: 'Atualizou usuário',
        area: 'Administração',
        details: '${savedProfile.name} (@${savedProfile.login})',
      ),
    );

    if (!_repository.isDriveUploadConfigured &&
        draft.photoFilePath != null &&
        draft.photoFilePath!.trim().isNotEmpty &&
        !_isRemoteFileLocation(draft.photoFilePath)) {
      _showAppMessage(
        'Usuário atualizado, mas a foto ficou salva apenas neste computador. Configure o backend do Drive para hospedá-la centralmente.',
        isError: true,
      );
    }
  }

  Color _nextWorkspaceProfileAccent() {
    const palette = <Color>[
      Color(0xFF2563EB),
      Color(0xFF4F46E5),
      Color(0xFF15803D),
      Color(0xFFB45309),
      Color(0xFFC2410C),
      Color(0xFF7C3AED),
      Color(0xFF0F766E),
      Color(0xFFBE185D),
    ];

    return palette[_workspaceProfiles.length % palette.length];
  }

  Future<void> _deleteManagedUser(EmployeeWorkspaceProfile profile) async {
    if (!_currentWorkspaceProfile.isAdministrator) {
      _showAppMessage(
        'Apenas a conta administradora pode excluir usuários.',
        isError: true,
      );
      return;
    }

    if (profile.email == _currentWorkspaceProfile.email) {
      _showAppMessage(
        'A conta administradora logada não pode excluir a si mesma.',
        isError: true,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir usuário'),
            content: Text(
              'Deseja excluir o usuário "${profile.name}" (@${profile.login})? Esta ação remove o acesso ao sistema.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final deleted = await _runBusyTask(
      () async {
        await _repository.deleteWorkspaceProfile(profile.email);
        return true;
      },
      busyMessage: 'Excluindo usuário...',
      successMessage: 'Usuário removido com sucesso.',
      errorPrefix: 'Não foi possível excluir o usuário',
    );

    if (deleted == null) {
      return;
    }

    setState(() {
      _workspaceProfiles = _workspaceProfiles
          .where((item) => item.email != profile.email)
          .toList(growable: false);
      if (_selectedManagedUserEmail == profile.email) {
        _selectedManagedUserEmail = _workspaceProfiles.isEmpty
            ? null
            : _workspaceProfiles.first.email;
      }
    });
    unawaited(
      _appendPlatformLog(
        action: 'Excluiu usuário',
        area: 'Administração',
        details: '${profile.name} (@${profile.login})',
      ),
    );
  }

  Future<void> _toggleManagedUserStage(
    String email,
    WorkflowStage stage,
  ) async {
    final profileIndex = _workspaceProfiles.indexWhere(
      (profile) => profile.email == email,
    );
    if (profileIndex == -1) {
      return;
    }

    final profile = _workspaceProfiles[profileIndex];
    final updatedStages = List<WorkflowStage>.from(profile.allowedStages);
    if (updatedStages.contains(stage)) {
      if (updatedStages.length == 1) {
        return;
      }
      updatedStages.remove(stage);
    } else {
      updatedStages.add(stage);
    }

    updatedStages.sort(
      (left, right) => workspaceStages
          .indexOf(left)
          .compareTo(workspaceStages.indexOf(right)),
    );

    setState(() {
      _workspaceProfiles[profileIndex] = profile.copyWith(
        allowedStages: updatedStages,
      );
    });

    final saved = await _runBusyTask(
      () async {
        await _repository.updateAllowedStages(email, updatedStages);
        return true;
      },
      busyMessage: 'Salvando permissões...',
      successMessage: 'Permissões do usuário atualizadas.',
      errorPrefix: 'Não foi possível salvar as permissões',
    );
    if (saved == null) {
      return;
    }

    unawaited(
      _appendPlatformLog(
        action: 'Atualizou permissões de acesso',
        area: 'Administração',
        details:
            '${profile.name} agora tem ${updatedStages.length} quadro(s) liberado(s)',
      ),
    );
  }

  void _mergeOrderLocally(WorkflowOrder order) {
    final orderIndex = _orders.indexWhere((item) => item.code == order.code);
    setState(() {
      if (orderIndex == -1) {
        _orders = [order, ..._orders];
      } else {
        _orders[orderIndex] = order;
      }
      _selectedOrderCode = order.code;
    });
  }

  Future<void> _deleteSelectedOrder() async {
    if (!_currentWorkspaceProfile.isAdministrator) {
      _showAppMessage(
        'Apenas a conta administradora pode excluir clientes.',
        isError: true,
      );
      return;
    }

    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir cliente'),
            content: Text(
              'Deseja excluir o cliente "${selected.workName}" (${selected.code})? Esta ação é irreversível.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final deleted = await _runBusyTask(
      () async {
        await _repository.deleteOrder(selected.code);
        return true;
      },
      busyMessage: 'Excluindo cliente...',
      successMessage: '${selected.workName} removido com sucesso.',
      errorPrefix: 'Não foi possível excluir o cliente',
    );
    if (deleted == null) {
      return;
    }

    setState(() {
      _orders = _orders
          .where((order) => order.code != selected.code)
          .toList(growable: false);
      if (_selectedOrderCode == selected.code) {
        _selectedOrderCode = null;
      }
    });
    unawaited(
      _appendPlatformLog(
        action: 'Excluiu cadastro',
        area: 'Cadastro de Clientes',
        details: '${selected.code} • ${selected.workName}',
      ),
    );
  }

  void _showAppMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : null,
      ),
    );
  }

  Future<void> _showSingleRemainingVisitAlertIfNeeded(
    WorkflowOrder order,
  ) async {
    if (!mounted || order.isServiceOrder) {
      return;
    }

    if (_remainingVisitCountForOrder(order) != 1) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atenção às visitas'),
        content: const Text(
          'Só tem mais uma visita disponível para este pedido.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  bool _isRemoteFileLocation(String? location) {
    final normalized = location?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(normalized);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _orderHasLocalOnlyAttachments(WorkflowOrder order) {
    final attachmentLocations = <String?>[
      order.proposalFilePath,
      order.detailFilePath,
      order.materialFilePath,
      order.consolidatedProposalFilePath,
      order.contractFilePath,
      order.electricalProjectFilePath,
      order.engineeringDataFilePath,
    ];

    for (final location in attachmentLocations) {
      final normalized = location?.trim();
      if (normalized == null || normalized.isEmpty) {
        continue;
      }

      if (!_isRemoteFileLocation(normalized)) {
        return true;
      }
    }

    return false;
  }

  void _showDriveUploadConfigurationWarningIfNeeded(WorkflowOrder order) {
    if (_repository.isDriveUploadConfigured) {
      return;
    }

    if (!_orderHasLocalOnlyAttachments(order)) {
      return;
    }

    _showAppMessage(
      'Cadastro salvo, mas os anexos ficaram apenas neste computador. Configure COMPANY_DRIVE_UPLOAD_URL para enviar ao Drive.',
      isError: true,
    );
  }

  Future<bool> _promptDriveAuthenticationReconnect() async {
    if (!mounted) {
      return false;
    }

    final shouldReconnect =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Reconectar Google Drive'),
            content: const Text(
              'A autenticacao local do Google Drive expirou. O app pode abrir o login do Google Cloud CLI para reconectar agora.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reconectar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldReconnect) {
      return false;
    }
    if (!mounted) {
      return false;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: const [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Reconectando Google Drive...')),
              ],
            ),
          ),
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    try {
      final result = await _repository.reconnectLocalDriveAuthentication();
      if (!mounted) {
        return false;
      }

      if (!result.isSuccess) {
        _showAppMessage(
          result.errorMessage ??
              'Nao foi possivel reautenticar o Google Drive.',
          isError: true,
        );
        return false;
      }

      return true;
    } finally {
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }
  }

  Future<T?> _runBusyTask<T>(
    Future<T> Function() action, {
    required String busyMessage,
    String? successMessage,
    String errorPrefix = 'Não foi possível concluir a ação',
    bool allowDriveReconnectRetry = true,
  }) async {
    if (mounted) {
      setState(() {
        _busyMessage = busyMessage;
      });
    }

    try {
      final result = await action();
      if (successMessage != null) {
        _showAppMessage(successMessage);
      }
      return result;
    } on DriveAuthExpiredException {
      if (allowDriveReconnectRetry &&
          await _promptDriveAuthenticationReconnect()) {
        return _runBusyTask(
          action,
          busyMessage: busyMessage,
          successMessage: successMessage,
          errorPrefix: errorPrefix,
          allowDriveReconnectRetry: false,
        );
      }
      _showAppMessage(
        '$errorPrefix: A autenticacao local do Google Drive expirou.',
        isError: true,
      );
      return null;
    } catch (error) {
      _showAppMessage('$errorPrefix: $error', isError: true);
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _busyMessage = null;
        });
      }
    }
  }

  void _openOrderFromWorkspace(String orderCode) {
    final matchedOrder = _orders.where((order) => order.code == orderCode);
    if (matchedOrder.isEmpty) {
      return;
    }

    final order = matchedOrder.first;
    setState(() {
      _selectedViewKey = 'stage:${order.currentStage.name}';
      _selectedOrderCode = order.code;
      if (order.currentStage == WorkflowStage.customerRegistration) {
        _customerRegistrationSubtab = 0;
      }
      if (_usesWorkAndCatalogSubtabs(order.currentStage)) {
        _stageWorkspaceSubtabs[order.currentStage] = 0;
      }
    });
  }

  void _signOut() {
    WorkspaceSession.instance.signOut();
  }

  Widget _buildContentForTab(_FlowNavItem tab) {
    if (tab.routeKey == 'workspace') {
      return _WorkflowSection(
        profile: _currentWorkspaceProfile,
        tasks: _currentWorkspaceTasks,
        allOrders: _orders,
        onOpenTaskOrder: _openOrderFromWorkspace,
      );
    }

    if (tab.routeKey == 'log') {
      if (!_currentWorkspaceProfile.isAdministrator) {
        return _WorkflowSection(
          profile: _currentWorkspaceProfile,
          tasks: _currentWorkspaceTasks,
          allOrders: _orders,
          onOpenTaskOrder: _openOrderFromWorkspace,
        );
      }

      return _PlatformLogSection(
        entries: _platformLogs,
        onClearLogs: _clearPlatformLogs,
      );
    }

    if (tab.routeKey == 'admin') {
      return _AdminAccessSection(
        currentProfile: _currentWorkspaceProfile,
        profiles: _workspaceProfiles,
        selectedProfile: _selectedManagedProfile,
        onSelectProfile: _selectManagedUser,
        onCreateProfile: _openCreateManagedUserDialog,
        onEditProfile: _openEditManagedUserDialog,
        currentUserEmail: _currentWorkspaceProfile.email,
        onDeleteProfile: _deleteManagedUser,
        onToggleStage: _toggleManagedUserStage,
      );
    }

    final stage = tab.stage!;
    if (stage == WorkflowStage.stock) {
      return _StockWorkspaceSection(repository: _repository);
    }

    final selectedOrderMatchesStage =
        _selectedOrder != null && _selectedOrder!.currentStage == stage;
    return _StageWorkspaceSection(
      stage: stage,
      currentProfile: _currentWorkspaceProfile,
      canDeleteOrder: _currentWorkspaceProfile.isAdministrator,
      orders: _orders,
      selectedOrder: _selectedStage == stage ? _selectedOrder : null,
      onOrderSelected: _selectOrder,
      onOpenOrderDetails: _openOrderDetailsScreen,
      onOpenOrderConversation: (order) =>
          _openOrderDetailsScreen(order, openConversationOnLoad: true),
      onAdvanceOrder: () => _moveSelectedOrder(1),
      onReturnOrder: () => _moveSelectedOrder(-1),
      onSendToEngineering: () =>
          _routeSelectedOrderToStage(WorkflowStage.engineering),
      onSendToAssembly: () =>
          _routeSelectedOrderToStage(WorkflowStage.assembly),
      onSendToInstallation: () =>
          _routeSelectedOrderToStage(WorkflowStage.installation),
      onAttachMaterials: _attachMaterialsToSelectedOrder,
      onSetEstimatingWasEstimate: _setEstimatingWasEstimateForSelectedOrder,
      onAttachElectricalProject: _attachElectricalProjectToSelectedOrder,
      onAttachPanelLayout: _attachPanelLayoutToSelectedOrder,
      onAttachPushButtonTable: _attachPushButtonTableToSelectedOrder,
      onAttachEngineeringData: _attachEngineeringDataToSelectedOrder,
      onAttachConsolidatedProposal: _attachConsolidatedProposalToSelectedOrder,
      onAttachContract: _attachContractToSelectedOrder,
      onAttachServiceOrderPdf: _attachServiceOrderPdfToSelectedOrder,
      onToggleFinanceClientApproval:
          _toggleFinanceClientApprovalForSelectedOrder,
      onScheduleInstallation: _scheduleInstallationForSelectedOrder,
      onToggleInstallationExecutionItem: _toggleInstallationExecutionItem,
      onOpenAssemblyPreparationChecklist:
          _openAssemblyChecklistForSelectedOrder,
      onScheduleEngineeringActivity: _scheduleEngineeringActivity,
      onUpdateEngineeringChecklistStatus: _updateEngineeringChecklistStatus,
      onUpdateFinanceContractStatus: _updateFinanceContractStatus,
      onUpdateRelationshipKanbanStatus: _updateRelationshipKanbanStatus,
      onMoveAssemblyKanbanOrder: _moveAssemblyOrderToKanbanColumn,
      canAcceptAssemblyKanbanDrop: _canMoveAssemblyOrderToTarget,
      onMoveEngineeringKanbanOrder: _moveEngineeringOrderToKanbanColumn,
      canAcceptEngineeringKanbanDrop: _canMoveEngineeringOrderToTarget,
      onMoveFinanceKanbanOrder: _moveFinanceOrderToKanbanColumn,
      canAcceptFinanceKanbanDrop: _canMoveFinanceOrderToTarget,
      onMoveRelationshipKanbanOrder: _moveRelationshipOrderToKanbanColumn,
      canAcceptRelationshipKanbanDrop: _canMoveRelationshipOrderToTarget,
      onMoveInstallationKanbanOrder: _moveInstallationOrderToKanbanColumn,
      canAcceptInstallationKanbanDrop: _canMoveInstallationOrderToTarget,
      onCreateServiceOrder: stage == WorkflowStage.relationship
          ? _openServiceOrderForm
          : null,
      onCreateAdditionalProposal:
          stage == WorkflowStage.customerRegistration &&
              _customerRegistrationSubtab == 1 &&
              _availableAdditionalProposalBaseOrders().isNotEmpty
          ? _openAdditionalProposalSelectionFlow
          : null,
      onCreateOrder: stage == WorkflowStage.customerRegistration
          ? _openCustomerRegistrationForm
          : null,
      onEditOrder:
          stage == _selectedStage &&
              _selectedOrder != null &&
              selectedOrderMatchesStage &&
              !_selectedOrder!.isServiceOrder
          ? () => _openCustomerRegistrationForm(_selectedOrder)
          : null,
      onDeleteOrder:
          stage == _selectedStage &&
              _selectedOrder != null &&
              selectedOrderMatchesStage
          ? _deleteSelectedOrder
          : null,
      customerRegistrationSubtab: stage == WorkflowStage.customerRegistration
          ? _customerRegistrationSubtab
          : null,
      onCustomerRegistrationSubtabChanged:
          stage == WorkflowStage.customerRegistration
          ? _selectCustomerRegistrationSubtab
          : null,
      stageWorkspaceSubtab: _usesWorkAndCatalogSubtabs(stage)
          ? _stageWorkspaceSubtabIndex(stage)
          : null,
      onStageWorkspaceSubtabChanged: _usesWorkAndCatalogSubtabs(stage)
          ? (index) => _selectStageWorkspaceSubtab(stage, index)
          : null,
      selectedOrdersView: _stageOrdersViews[stage] ?? _StageOrdersView.list,
      onOrdersViewChanged: (view) => _selectStageOrdersView(stage, view),
      selectedInstallationCalendarDate: _selectedInstallationCalendarDate,
      onInstallationCalendarDateChanged: _selectInstallationCalendarDate,
      customerSearchQuery: _customerSearchQuery,
      customerSearchController: _customerSearchController,
      onCustomerSearchChanged: (value) => setState(() {
        _customerSearchQuery = value;
        _selectedOrderCode = null;
      }),
      onClearCustomerSearch: () => setState(() {
        _customerSearchController.clear();
        _customerSearchQuery = '';
        _selectedOrderCode = null;
      }),
      workspaceProfiles: _workspaceProfiles,
      mergeCandidates: stage == WorkflowStage.relationship
          ? _mergeableCandidates
          : const [],
      onMergeProposal: stage == WorkflowStage.relationship
          ? _mergeProposalWithPrimary
          : null,
      onUnmergeProposal: _unmergeProposalFromPrimary,
    );
  }

  Future<void> _openCustomerRegistrationForm([WorkflowOrder? order]) async {
    final draft = await showDialog<_CustomerRegistrationDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CustomerRegistrationDialog(
        initialDraft: order == null
            ? null
            : _CustomerRegistrationDraft(
                fullName: order.client.name,
                birthDate: order.client.birthDate,
                email: order.client.email,
                rg: order.client.rg,
                cpf: order.client.cpf,
                workName: order.workName,
                phone: order.client.phone,
                billingPostalCode: order.client.postalCode,
                billingStreet: order.client.street,
                billingNumber: order.client.number,
                billingNeighborhood: order.client.neighborhood,
                billingComplement: order.client.complement,
                billingCity: order.client.city,
                workPostalCode: order.workPostalCode,
                workStreet: order.workStreet,
                workNumber: order.workNumber,
                workNeighborhood: order.workNeighborhood,
                workComplement: order.workComplement,
                workCity: '',
                address: order.address,
                commercialProposalNumber: order.commercialProposalNumber,
                paymentType: order.paymentType,
                consolidatedValue: order.value == 0
                    ? ''
                    : order.value.toStringAsFixed(2),
                paymentMethod: order.paymentMethod,
                paymentObservation: order.paymentObservation,
                installmentValue: order.installmentValue,
                installmentCount: order.installmentCount,
                paymentDate: order.paymentDate,
                rtValue: order.rtValue,
                integratorValue: order.integratorValue,
                integratorName: order.integratorName,
                architectName: order.architectName,
                proposalServices: order.proposalServices,
                isDanfClient: order.isDanfClient,
                danfInstallerName: order.danfInstallerName,
                canHaveDanfPlate: order.canHaveDanfPlate,
                hasWhatsappGroup: order.hasWhatsappGroup,
                whatsappGroupMembers: order.whatsappGroupMembers,
                whatsappGroupObservation: order.whatsappGroupObservation,
                proposalFileName: order.proposalFileName,
                proposalFilePath: order.proposalFilePath,
                detailFileName: order.detailFileName,
                detailFilePath: order.detailFilePath,
              ),
        isEditing: order != null,
      ),
    );

    if (draft == null) {
      return;
    }

    final now = DateTime.now();
    final creatorLabel = _currentOrderOwnerLabel();
    if (order != null) {
      final updatedOrder = order.copyWith(
        client: order.client.copyWith(
          name: draft.fullName,
          birthDate: draft.birthDate,
          email: draft.email,
          rg: draft.rg,
          cpf: draft.cpf,
          city: draft.billingCity,
          postalCode: draft.billingPostalCode,
          street: draft.billingStreet,
          number: draft.billingNumber,
          neighborhood: draft.billingNeighborhood,
          complement: draft.billingComplement,
          phone: draft.phone,
        ),
        workName: draft.workName,
        address: draft.address,
        workPostalCode: draft.workPostalCode,
        workStreet: draft.workStreet,
        workNumber: draft.workNumber,
        workNeighborhood: draft.workNeighborhood,
        workComplement: draft.workComplement,
        value:
            double.tryParse(
              draft.consolidatedValue.replaceAll('.', '').replaceAll(',', '.'),
            ) ??
            0,
        commercialProposalNumber: draft.commercialProposalNumber,
        paymentType: draft.paymentType,
        paymentMethod: draft.paymentMethod,
        paymentObservation: draft.paymentObservation,
        installmentValue: draft.installmentValue,
        installmentCount: draft.installmentCount,
        paymentDate: draft.paymentDate,
        rtValue: draft.rtValue,
        integratorValue: draft.integratorValue,
        integratorName: draft.integratorName,
        architectName: draft.architectName,
        proposalServices: draft.proposalServices,
        isDanfClient: draft.isDanfClient,
        danfInstallerName: draft.danfInstallerName,
        canHaveDanfPlate: draft.canHaveDanfPlate,
        hasWhatsappGroup: draft.hasWhatsappGroup,
        whatsappGroupMembers: draft.whatsappGroupMembers,
        whatsappGroupObservation: draft.whatsappGroupObservation,
        proposalFileName: draft.proposalFileName,
        proposalFilePath: draft.proposalFilePath,
        detailFileName: draft.detailFileName,
        detailFilePath: draft.detailFilePath,
        history: Map<WorkflowStage, String>.from(
          order.history,
        )..[order.currentStage] = 'Cadastro editado em ${_formatDateTime(now)}',
      );

      final savedOrder = await _runBusyTask(
        () => _repository.saveOrder(updatedOrder),
        busyMessage: 'Salvando cadastro...',
        successMessage: '${updatedOrder.workName} atualizado.',
        errorPrefix: 'Não foi possível salvar o cadastro',
      );
      if (savedOrder == null) {
        return;
      }

      setState(() {
        _selectedOrderCode = savedOrder.code;
      });
      _mergeOrderLocally(savedOrder);
      _showDriveUploadConfigurationWarningIfNeeded(savedOrder);
      unawaited(
        _appendPlatformLog(
          action: 'Editou cadastro',
          area: 'Cadastro de Clientes',
          details: '${savedOrder.code} • ${savedOrder.workName}',
        ),
      );
      return;
    }

    final newClientId = _nextClientId();
    final newOrderCode = _primaryProposalCode(newClientId);
    final newOrder = WorkflowOrder(
      code: newOrderCode,
      client: ClientProfile(
        id: newClientId,
        name: draft.fullName,
        birthDate: draft.birthDate,
        email: draft.email,
        rg: draft.rg,
        cpf: draft.cpf,
        city: draft.billingCity,
        postalCode: draft.billingPostalCode,
        street: draft.billingStreet,
        number: draft.billingNumber,
        neighborhood: draft.billingNeighborhood,
        complement: draft.billingComplement,
        segment: 'Cadastro inicial',
        contact: 'A definir',
        phone: draft.phone,
        temperature: 'Novo',
      ),
      workName: draft.workName,
      address: draft.address,
      workPostalCode: draft.workPostalCode,
      workStreet: draft.workStreet,
      workNumber: draft.workNumber,
      workNeighborhood: draft.workNeighborhood,
      workComplement: draft.workComplement,
      proposalFileName: draft.proposalFileName,
      proposalFilePath: draft.proposalFilePath,
      detailFileName: draft.detailFileName,
      detailFilePath: draft.detailFilePath,
      materialFileName: '',
      materialFilePath: null,
      estimatingIncludedVisits: const [],
      estimatingMaterials: const [],
      consolidatedProposalFileName: '',
      consolidatedProposalFilePath: null,
      contractFileName: '',
      contractFilePath: null,
      electricalProjectFileName: '',
      electricalProjectFilePath: null,
      panelLayoutFileName: '',
      panelLayoutFilePath: null,
      pushButtonTableFileName: '',
      pushButtonTableFilePath: null,
      engineeringDataFileName: '',
      engineeringDataFilePath: null,
      engineeringChecklistStatuses: const {},
      engineeringActivitySchedules: const {},
      financeContractStatuses: const {},
      estimatingKanbanStatuses: const {},
      relationshipKanbanStatuses: const {},
      assemblyPreparationChecklist: const {},
      assemblyWorkflowStatus: AssemblyWorkflowStatus.waiting,
      assemblyAssignedEmployeeEmails: const [],
      currentStage: WorkflowStage.customerRegistration,
      owner: creatorLabel,
      stageOwners: {WorkflowStage.customerRegistration: creatorLabel},
      proposalGroupCode: newOrderCode,
      proposalVersion: 1,
      kind: WorkflowOrderKind.standard,
      serviceDescription: '',
      serviceOrderFileName: '',
      serviceOrderFilePath: null,
      financeClientApproved: false,
      serviceOrderFinanceStatus: ServiceOrderFinanceStatus.waitingApproval,
      installationWorkflowStatus: InstallationWorkflowStatus.waiting,
      installationScheduledAt: null,
      installationAssignedEmployeeEmails: const [],
      installationAssignedTeam: '',
      installationNotes: '',
      estimatingWasEstimate: '',
      installationVisitHistory: const [],
      value:
          double.tryParse(
            draft.consolidatedValue.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0,
      commercialProposalNumber: draft.commercialProposalNumber,
      paymentType: draft.paymentType,
      paymentMethod: draft.paymentMethod,
      paymentObservation: draft.paymentObservation,
      installmentValue: draft.installmentValue,
      installmentCount: draft.installmentCount,
      paymentDate: draft.paymentDate,
      rtValue: draft.rtValue,
      integratorValue: draft.integratorValue,
      integratorName: draft.integratorName,
      architectName: draft.architectName,
      proposalServices: draft.proposalServices,
      isDanfClient: draft.isDanfClient,
      danfInstallerName: draft.danfInstallerName,
      canHaveDanfPlate: draft.canHaveDanfPlate,
      hasWhatsappGroup: draft.hasWhatsappGroup,
      whatsappGroupMembers: draft.whatsappGroupMembers,
      whatsappGroupObservation: draft.whatsappGroupObservation,
      deadline: now.add(const Duration(days: 1)),
      progress: 1 / workflowStages.length,
      nextAction: WorkflowStage.customerRegistration.checklist.first,
      blocker: 'Aguardando conferência do cadastro e anexos.',
      tags: const ['Novo cadastro'],
      conversationMessages: const [],
      history: {
        WorkflowStage.customerRegistration:
            'Cadastro criado por $creatorLabel em ${_formatDateTime(now)}',
      },
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(newOrder),
      busyMessage: 'Criando cadastro...',
      successMessage: '${newOrder.workName} criado no cadastro do cliente.',
      errorPrefix: 'Não foi possível criar o cadastro',
    );
    if (savedOrder == null) {
      return;
    }

    setState(() {
      _selectedViewKey = 'stage:${WorkflowStage.customerRegistration.name}';
      _customerRegistrationSubtab = 0;
      _selectedOrderCode = savedOrder.code;
    });
    _mergeOrderLocally(savedOrder);
    _showDriveUploadConfigurationWarningIfNeeded(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Criou cadastro',
        area: 'Cadastro de Clientes',
        details: '${savedOrder.code} • ${savedOrder.workName}',
      ),
    );
  }

  Future<void> _openServiceOrderForm() async {
    final clientOptions = _serviceOrderClientOptions;
    if (clientOptions.isEmpty) {
      _showAppMessage(
        'Cadastre pelo menos um cliente antes de criar uma ordem de serviço.',
        isError: true,
      );
      return;
    }

    final draft = await showDialog<_ServiceOrderDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ServiceOrderDialog(clients: clientOptions),
    );

    if (draft == null) {
      return;
    }

    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final newOrderCode = _nextServiceOrderCode(draft.client.id);
    final draftOrder = WorkflowOrder(
      code: newOrderCode,
      client: draft.client,
      workName: draft.serviceTitle.trim(),
      address: draft.address.trim(),
      workPostalCode: '',
      workStreet: '',
      workNumber: '',
      workNeighborhood: '',
      workComplement: '',
      proposalFileName: '',
      proposalFilePath: null,
      detailFileName: '',
      detailFilePath: null,
      materialFileName: '',
      materialFilePath: null,
      estimatingIncludedVisits: const [],
      estimatingMaterials: const [],
      consolidatedProposalFileName: '',
      consolidatedProposalFilePath: null,
      contractFileName: '',
      contractFilePath: null,
      electricalProjectFileName: '',
      electricalProjectFilePath: null,
      panelLayoutFileName: '',
      panelLayoutFilePath: null,
      pushButtonTableFileName: '',
      pushButtonTableFilePath: null,
      engineeringDataFileName: '',
      engineeringDataFilePath: null,
      engineeringChecklistStatuses: const {},
      engineeringActivitySchedules: const {},
      financeContractStatuses: const {},
      estimatingKanbanStatuses: const {},
      relationshipKanbanStatuses: const {},
      assemblyPreparationChecklist: const {},
      assemblyWorkflowStatus: AssemblyWorkflowStatus.waiting,
      assemblyAssignedEmployeeEmails: const [],
      currentStage: WorkflowStage.estimating,
      owner: actorLabel,
      stageOwners: {
        WorkflowStage.relationship: actorLabel,
        WorkflowStage.estimating: actorLabel,
      },
      proposalGroupCode: newOrderCode,
      proposalVersion: 1,
      kind: WorkflowOrderKind.serviceOrder,
      serviceDescription: draft.serviceDescription.trim(),
      serviceOrderFileName: '',
      serviceOrderFilePath: null,
      financeClientApproved: false,
      serviceOrderFinanceStatus: ServiceOrderFinanceStatus.waitingApproval,
      installationWorkflowStatus: InstallationWorkflowStatus.waiting,
      installationScheduledAt: null,
      installationAssignedEmployeeEmails: const [],
      installationAssignedTeam: '',
      installationNotes: '',
      estimatingWasEstimate: '',
      installationVisitHistory: const [],
      value: 0,
      commercialProposalNumber: '',
      paymentType: '',
      paymentMethod: '',
      paymentObservation: '',
      installmentValue: '',
      installmentCount: '',
      paymentDate: '',
      rtValue: '',
      integratorValue: '',
      integratorName: '',
      architectName: '',
      proposalServices: const [],
      isDanfClient: '',
      danfInstallerName: '',
      canHaveDanfPlate: '',
      hasWhatsappGroup: '',
      whatsappGroupMembers: const [],
      whatsappGroupObservation: '',
      deadline: now.add(const Duration(days: 2)),
      progress: 0,
      nextAction: 'Emitir PDF da ordem de serviço',
      blocker: 'Aguardando emissão da ordem de serviço pelo Orçamentista.',
      tags: const ['Ordem de serviço'],
      conversationMessages: const [],
      history: {
        WorkflowStage.relationship:
            'OS criada por $actorLabel em ${_formatDateTime(now)}',
        WorkflowStage.estimating:
            'Encaminhada ao Orçamentista em ${_formatDateTime(now)}',
      },
    );
    final newOrder = draftOrder.copyWith(
      progress: _effectiveOrderProgress(draftOrder),
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(newOrder),
      busyMessage: 'Criando ordem de serviço...',
      successMessage: 'Ordem de serviço criada e enviada ao Orçamentista.',
      errorPrefix: 'Não foi possível criar a ordem de serviço',
    );
    if (savedOrder == null) {
      return;
    }

    final canOpenEstimating = _currentWorkspaceProfile.allowedStages.contains(
      WorkflowStage.estimating,
    );
    setState(() {
      _selectedViewKey = canOpenEstimating
          ? 'stage:${WorkflowStage.estimating.name}'
          : 'stage:${WorkflowStage.relationship.name}';
      _stageWorkspaceSubtabs[WorkflowStage.estimating] = 0;
      _selectedOrderCode = savedOrder.code;
    });
    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Criou ordem de serviço',
        area: 'Relacionamento',
        details: '${savedOrder.code} • ${savedOrder.client.name}',
      ),
    );
  }

  Future<void> _scheduleInstallationForSelectedOrder() async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    final existingPlannedVisit = _plannedInstallationVisitForSchedule(
      selected,
      selected.installationScheduledAt,
    );

    final draft = await showDialog<_InstallationScheduleDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InstallationScheduleDialog(
        order: selected,
        initialDraft: _InstallationScheduleDraft(
          scheduledAt:
              selected.installationScheduledAt ??
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day + 1,
                8,
              ),
          assignedTeam: '',
          plannedItems: existingPlannedVisit?.plannedItems ?? const [],
          notes: existingPlannedVisit?.notes ?? selected.installationNotes,
        ),
      ),
    );

    if (draft == null) {
      return;
    }

    final hadSchedule = selected.installationScheduledAt != null;
    final now = DateTime.now();
    final nextVisitHistory = [
      ...selected.installationVisitHistory,
      if (hadSchedule)
        _installationReportEntry(
          order: selected,
          scheduledAt: selected.installationScheduledAt!,
          createdAt: now,
          report:
              'Reagendamento registrado para ${_formatDateTime(draft.scheduledAt)}.'
              '${draft.notes.trim().isEmpty ? '' : ' Observações: ${draft.notes.trim()}'}',
        ),
      InstallationVisitLog(
        scheduledAt: draft.scheduledAt,
        employeeEmails: const [],
        plannedItems: draft.plannedItems,
        completedItems: const [],
        serviceTime: '',
        notes: draft.notes.trim(),
        createdAt: now,
      ),
    ];
    final previewOrder = selected.copyWith(
      installationWorkflowStatus: InstallationWorkflowStatus.scheduled,
      installationScheduledAt: draft.scheduledAt,
    );
    final updatedOrder = selected.copyWith(
      installationWorkflowStatus: InstallationWorkflowStatus.scheduled,
      installationScheduledAt: draft.scheduledAt,
      installationAssignedEmployeeEmails: const [],
      installationAssignedTeam: '',
      installationNotes: selected.isServiceOrder ? '' : draft.notes.trim(),
      installationVisitHistory: nextVisitHistory,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: _defaultNextActionForStage(
        WorkflowStage.installation,
        previewOrder,
      ),
      blocker: _installationWorkflowBlocker(
        InstallationWorkflowStatus.scheduled,
      ),
      history: Map<WorkflowStage, String>.from(selected.history)
        ..[WorkflowStage.installation] =
            'Instalação agendada para ${_formatDateTime(draft.scheduledAt)}',
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Salvando agenda de instalação...',
      successMessage: 'Calendário de instalação atualizado.',
      errorPrefix: 'Não foi possível salvar a agenda de instalação',
    );
    if (savedOrder == null) {
      return;
    }

    setState(() {
      _selectedOrderCode = savedOrder.code;
      _selectedInstallationCalendarDate = DateUtils.dateOnly(draft.scheduledAt);
    });
    _mergeOrderLocally(savedOrder);
    await _showSingleRemainingVisitAlertIfNeeded(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: hadSchedule ? 'Reagendou instalação' : 'Agendou instalação',
        area: 'Instalação',
        details: '${savedOrder.code} • ${_formatDateTime(draft.scheduledAt)}',
      ),
    );
  }

  Future<List<String>?> _pickInstallationEmployees(WorkflowOrder order) async {
    final eligibleProfiles = _installationEligibleProfiles();
    if (eligibleProfiles.isEmpty) {
      _showAppMessage(
        'Nenhum colaborador está disponível para seleção.',
        isError: true,
      );
      return null;
    }

    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AssemblyTeamSelectionDialog(
        profiles: eligibleProfiles,
        initialSelectedEmails: order.installationAssignedEmployeeEmails,
        title: 'Equipe da instalação',
        subtitle: 'Selecione os funcionários que vão executar esta visita.',
        emptySelectionMessage:
            'Selecione pelo menos um funcionário da instalação.',
      ),
    );
  }

  Future<void> _startInstallationVisit() async {
    final selected = _selectedOrder;
    if (selected == null || selected.installationScheduledAt == null) {
      return;
    }

    final assignedEmployeeEmails = await _pickInstallationEmployees(selected);
    if (assignedEmployeeEmails == null || assignedEmployeeEmails.isEmpty) {
      return;
    }

    final plannedVisit = _plannedInstallationVisitForSchedule(
      selected,
      selected.installationScheduledAt,
    );
    if (plannedVisit == null || plannedVisit.plannedItems.isEmpty) {
      _showAppMessage(
        'Cadastre os trabalhos e a observação da instalação antes de iniciar a visita.',
        isError: true,
      );
      return;
    }

    final now = DateTime.now();
    final nextVisitHistory = List<InstallationVisitLog>.from(
      selected.installationVisitHistory,
    );
    final plannedVisitIndex = nextVisitHistory.lastIndexWhere(
      (visit) =>
          _isSameDateTime(
            visit.scheduledAt,
            selected.installationScheduledAt!,
          ) &&
          visit.plannedItems.isNotEmpty,
    );
    if (plannedVisitIndex == -1) {
      _showAppMessage(
        'Nao foi possivel localizar o planejamento desta visita.',
        isError: true,
      );
      return;
    }
    nextVisitHistory[plannedVisitIndex] = nextVisitHistory[plannedVisitIndex]
        .copyWith(employeeEmails: assignedEmployeeEmails, createdAt: now);
    final previewOrder = selected.copyWith(
      installationWorkflowStatus: InstallationWorkflowStatus.doing,
      installationAssignedEmployeeEmails: assignedEmployeeEmails,
      installationVisitHistory: nextVisitHistory,
    );
    final updatedOrder = selected.copyWith(
      installationWorkflowStatus: InstallationWorkflowStatus.doing,
      installationAssignedEmployeeEmails: assignedEmployeeEmails,
      installationAssignedTeam: _profileNamesForEmails(assignedEmployeeEmails),
      installationVisitHistory: nextVisitHistory,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: _defaultNextActionForStage(
        WorkflowStage.installation,
        previewOrder,
      ),
      blocker: _installationWorkflowBlocker(InstallationWorkflowStatus.doing),
      history: Map<WorkflowStage, String>.from(selected.history)
        ..[WorkflowStage.installation] =
            'Visita iniciada em ${_formatDateTime(selected.installationScheduledAt!)}',
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Iniciando instalação...',
      successMessage: 'Instalação em andamento.',
      errorPrefix: 'Não foi possível iniciar a instalação',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Iniciou visita de instalação',
        area: 'Instalação',
        details:
            '${_displayOrderCode(savedOrder)} • ${_formatDateTime(selected.installationScheduledAt!)}',
      ),
    );
  }

  String _profileNamesForEmails(List<String> emails) {
    final normalizedEmails = emails
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toList(growable: false);
    final names = <String>[];
    for (final email in normalizedEmails) {
      final profile = _workspaceProfiles.where(
        (profile) => profile.email.trim().toLowerCase() == email,
      );
      if (profile.isEmpty) {
        names.add(email);
        continue;
      }
      final matched = profile.first;
      names.add(matched.name.trim().isEmpty ? matched.login : matched.name);
    }
    return names.join(', ');
  }

  InstallationVisitLog _installationReportEntry({
    required WorkflowOrder order,
    required DateTime scheduledAt,
    required DateTime createdAt,
    required String report,
  }) {
    return InstallationVisitLog(
      scheduledAt: scheduledAt,
      employeeEmails: order.installationAssignedEmployeeEmails,
      plannedItems: const [],
      completedItems: const [],
      serviceTime: '',
      notes: report,
      createdAt: createdAt,
    );
  }

  InstallationVisitLog? _plannedInstallationVisitForSchedule(
    WorkflowOrder order,
    DateTime? scheduledAt,
  ) {
    if (scheduledAt == null) {
      return null;
    }

    for (
      var index = order.installationVisitHistory.length - 1;
      index >= 0;
      index--
    ) {
      final visit = order.installationVisitHistory[index];
      if (_isSameDateTime(visit.scheduledAt, scheduledAt) &&
          visit.plannedItems.isNotEmpty) {
        return visit;
      }
    }
    return null;
  }

  int _activeInstallationVisitIndex(WorkflowOrder order) {
    for (
      var index = order.installationVisitHistory.length - 1;
      index >= 0;
      index--
    ) {
      final visit = order.installationVisitHistory[index];
      if (visit.plannedItems.isNotEmpty && visit.employeeEmails.isNotEmpty) {
        return index;
      }
    }
    return -1;
  }

  bool _isSameDateTime(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day &&
        left.hour == right.hour &&
        left.minute == right.minute;
  }

  Future<({String serviceTime, String conclusionObservation})?>
  _promptServiceOrderCompletionData({
    required String initialServiceTime,
    required String initialConclusionObservation,
  }) async {
    final serviceTimeController = TextEditingController(
      text: initialServiceTime,
    );
    final observationController = TextEditingController(
      text: initialConclusionObservation,
    );
    final result =
        await showDialog<({String serviceTime, String conclusionObservation})>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Conclusão da OS'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: serviceTimeController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Tempo de serviço',
                      hintText: 'Ex.: 2h 30min',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: observationController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observação conclusão OS',
                      hintText:
                          'Informe o resultado da instalação para retorno ao Orçamentista.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop((
                  serviceTime: serviceTimeController.text.trim(),
                  conclusionObservation: observationController.text.trim(),
                )),
                child: const Text('Salvar'),
              ),
            ],
          ),
        );
    serviceTimeController.dispose();
    observationController.dispose();
    return result;
  }

  Future<void> _completeInstallation({
    WorkflowOrder? order,
    bool force = false,
  }) async {
    final selected = order ?? _selectedOrder;
    if (selected == null) {
      return;
    }

    final activeVisitIndex = _activeInstallationVisitIndex(selected);
    if (activeVisitIndex == -1 && !force) {
      _showAppMessage(
        'Registre os trabalhos executados antes de concluir a instalação.',
        isError: true,
      );
      return;
    }

    final activeVisit = activeVisitIndex == -1
        ? null
        : selected.installationVisitHistory[activeVisitIndex];
    final pendingItems = activeVisit == null
        ? const <String>[]
        : activeVisit.plannedItems
              .where((item) => !activeVisit.completedItems.contains(item))
              .toList(growable: false);
    if (pendingItems.isNotEmpty && !force) {
      _showAppMessage(
        'Marque todos os trabalhos executados ou agende retorno para concluir depois.',
        isError: true,
      );
      return;
    }

    var serviceTime = activeVisit?.serviceTime.trim() ?? '';
    var completionObservation = selected.isServiceOrder
        ? ''
        : selected.installationNotes.trim();
    if (selected.isServiceOrder) {
      final completionData = await _promptServiceOrderCompletionData(
        initialServiceTime: serviceTime,
        initialConclusionObservation: completionObservation,
      );
      if (completionData == null) {
        return;
      }
      if (completionData.serviceTime.trim().isEmpty) {
        _showAppMessage(
          'Informe o tempo de serviço para concluir a ordem de serviço.',
          isError: true,
        );
        return;
      }
      if (completionData.conclusionObservation.trim().isEmpty) {
        _showAppMessage(
          'Informe a observação conclusão OS para concluir a ordem de serviço.',
          isError: true,
        );
        return;
      }
      serviceTime = completionData.serviceTime.trim();
      completionObservation = completionData.conclusionObservation.trim();
    }

    final now = DateTime.now();
    final updatedVisits = List<InstallationVisitLog>.from(
      selected.installationVisitHistory,
    );
    if (activeVisit != null) {
      updatedVisits[activeVisitIndex] = activeVisit.copyWith(
        serviceTime: serviceTime,
        completedItems: pendingItems.isEmpty
            ? activeVisit.completedItems
            : activeVisit.plannedItems,
      );
    }
    final previewOrder = selected.copyWith(
      installationWorkflowStatus: InstallationWorkflowStatus.done,
      installationVisitHistory: updatedVisits,
    );
    final completionReport = _installationReportEntry(
      order: selected,
      scheduledAt: selected.installationScheduledAt ?? now,
      createdAt: now,
      report:
          'Conclusão registrada em ${_formatDateTime(now)}.'
          '${serviceTime.isEmpty ? '' : ' Tempo de serviço: $serviceTime.'}'
          '${completionObservation.isEmpty ? '' : ' Observação conclusão OS: $completionObservation'}',
    );
    final returnedToEstimatingOrder = selected.copyWith(
      currentStage: WorkflowStage.estimating,
      installationWorkflowStatus: InstallationWorkflowStatus.done,
      installationVisitHistory: [...updatedVisits, completionReport],
    );
    final updatedOrder = selected.isServiceOrder
        ? selected.copyWith(
            currentStage: WorkflowStage.estimating,
            installationWorkflowStatus: InstallationWorkflowStatus.done,
            installationNotes: completionObservation,
            installationVisitHistory: [...updatedVisits, completionReport],
            progress: _effectiveOrderProgress(returnedToEstimatingOrder),
            nextAction: 'OS Realizada',
            blocker: 'Sem bloqueio. Ordem de serviço realizada na Instalação.',
            history: Map<WorkflowStage, String>.from(selected.history)
              ..[WorkflowStage.installation] =
                  'Instalação concluída em ${_formatDateTime(now)}'
              ..[WorkflowStage.estimating] =
                  'OS realizada recebida da Instalação em ${_formatDateTime(now)}',
          )
        : selected.copyWith(
            installationWorkflowStatus: InstallationWorkflowStatus.done,
            installationVisitHistory: [...updatedVisits, completionReport],
            progress: _effectiveOrderProgress(previewOrder),
            nextAction: _defaultNextActionForStage(
              WorkflowStage.installation,
              previewOrder,
            ),
            blocker: _installationWorkflowBlocker(
              InstallationWorkflowStatus.done,
            ),
            history: Map<WorkflowStage, String>.from(selected.history)
              ..[WorkflowStage.installation] =
                  'Instalação concluída em ${_formatDateTime(now)}',
          );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Concluindo instalação...',
      successMessage: selected.isServiceOrder
          ? 'Instalação concluída e OS enviada ao Orçamentista.'
          : 'Instalação concluída.',
      errorPrefix: 'Não foi possível concluir a instalação',
    );
    if (savedOrder == null) {
      return;
    }

    if (selected.isServiceOrder) {
      setState(() {
        _selectedViewKey = 'stage:${WorkflowStage.estimating.name}';
        _stageWorkspaceSubtabs[WorkflowStage.estimating] = 0;
        _selectedOrderCode = savedOrder.code;
      });
    }
    _mergeOrderLocally(savedOrder);
  }

  Future<void> _toggleInstallationExecutionItem(
    int visitIndex,
    String item,
  ) async {
    final selected = _selectedOrder;
    if (selected == null || selected.installationVisitHistory.isEmpty) {
      return;
    }

    final visits = List<InstallationVisitLog>.from(
      selected.installationVisitHistory,
    );
    if (visitIndex < 0 || visitIndex >= visits.length) {
      return;
    }
    final visit = visits[visitIndex];
    final completedItems = visit.completedItems.toSet();
    if (completedItems.contains(item)) {
      completedItems.remove(item);
    } else {
      completedItems.add(item);
    }
    visits[visitIndex] = visit.copyWith(
      completedItems: completedItems.toList(growable: false),
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(
        selected.copyWith(installationVisitHistory: visits),
      ),
      busyMessage: 'Atualizando execução da instalação...',
      errorPrefix: 'Não foi possível atualizar a execução',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
  }

  Future<void> _handleInstallationInProgressAdvance() async {
    final action = await showDialog<_InstallationProgressAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instalação em andamento'),
        content: const Text(
          'Concluir a instalação ou agendar retorno para outro dia?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(_InstallationProgressAction.scheduleReturn),
            child: const Text('Agendar retorno'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_InstallationProgressAction.complete),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );

    if (action == _InstallationProgressAction.complete) {
      await _completeInstallation();
      return;
    }

    if (action == _InstallationProgressAction.scheduleReturn) {
      await _scheduleInstallationForSelectedOrder();
    }
  }

  Future<void> _scheduleEngineeringActivity(String taskKey) async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    final task = _engineeringChecklistTaskByKey(taskKey);
    final existingSchedule = selected.engineeringActivitySchedules[taskKey];
    final scheduled = await _pickEngineeringActivitySchedule(selected, taskKey);
    if (scheduled == null || task == null) {
      return;
    }

    final updatedSchedules = Map<String, EngineeringTaskSchedule>.from(
      selected.engineeringActivitySchedules,
    )..[taskKey] = scheduled;
    final updatedStatuses = Map<String, EngineeringChecklistStatus>.from(
      selected.engineeringChecklistStatuses,
    );
    updatedStatuses[taskKey] = _normalizeEngineeringChecklistStatus(
      updatedStatuses[taskKey] ?? EngineeringChecklistStatus.notStarted,
    );

    final historyMessage =
        '${task.label} agendada para ${_formatDateTime(scheduled.scheduledAt)}';
    final updatedOrder = selected.copyWith(
      engineeringActivitySchedules: updatedSchedules,
      engineeringChecklistStatuses: updatedStatuses,
      nextAction: historyMessage,
      blocker: 'Aguardando execução de atividade agendada pela Engenharia.',
      history: Map<WorkflowStage, String>.from(selected.history)
        ..[WorkflowStage.engineering] = historyMessage,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Salvando agenda da engenharia...',
      successMessage: 'Atividade da engenharia agendada.',
      errorPrefix: 'Não foi possível salvar a agenda da engenharia',
    );
    if (savedOrder == null) {
      return;
    }

    setState(() {
      _selectedOrderCode = savedOrder.code;
    });
    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: existingSchedule == null
            ? 'Agendou atividade da engenharia'
            : 'Reagendou atividade da engenharia',
        area: 'Engenharia',
        details:
            '${_displayOrderCode(savedOrder)} • ${task.label} • ${_formatDateTime(scheduled.scheduledAt)}',
      ),
    );
  }

  Future<EngineeringTaskSchedule?> _pickEngineeringActivitySchedule(
    WorkflowOrder order,
    String taskKey,
  ) async {
    final task = _engineeringChecklistTaskByKey(taskKey);
    if (task == null || !task.supportsScheduling) {
      _showAppMessage(
        'Essa atividade da engenharia não aceita agendamento.',
        isError: true,
      );
      return null;
    }

    final existingSchedule = order.engineeringActivitySchedules[taskKey];
    final draft = await showDialog<_EngineeringActivityScheduleDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EngineeringActivityScheduleDialog(
        order: order,
        task: task,
        initialDraft: _EngineeringActivityScheduleDraft(
          scheduledAt:
              existingSchedule?.scheduledAt ??
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day + 1,
                8,
              ),
          notes: existingSchedule?.notes ?? '',
        ),
      ),
    );

    if (draft == null) {
      return null;
    }

    return EngineeringTaskSchedule(
      scheduledAt: draft.scheduledAt,
      notes: draft.notes.trim(),
    );
  }

  String _defaultNextActionForStage(WorkflowStage stage, WorkflowOrder order) {
    if (order.isServiceOrder) {
      return switch (stage) {
        WorkflowStage.estimating => 'Emitir PDF da ordem de serviço',
        WorkflowStage.finance => _serviceOrderFinanceNextAction(order),
        WorkflowStage.relationship =>
          'Definir destino final da ordem de serviço',
        WorkflowStage.engineering =>
          _engineeringFlowSnapshot(order).currentTask?.label ??
              'Liberar ordem para montagem',
        WorkflowStage.assembly => switch (order.assemblyWorkflowStatus) {
          AssemblyWorkflowStatus.waiting =>
            _isAssemblyPreparationChecklistComplete(order)
                ? 'Liberar para montagem'
                : 'Dar baixa no checklist de preparação',
          AssemblyWorkflowStatus.released => 'Liberado para montagem',
          AssemblyWorkflowStatus.doing => 'Executar montagem',
          AssemblyWorkflowStatus.panelTesting => 'Realizar teste de painel',
          AssemblyWorkflowStatus.done =>
            'Painel concluído. Liberar para instalação',
        },
        WorkflowStage.installation => _installationNextAction(order),
        _ => stage.checklist.isEmpty ? stage.title : stage.checklist.first,
      };
    }

    if (stage == WorkflowStage.engineering) {
      return _engineeringFlowSnapshot(order).currentTask?.label ??
          'Liberar ordem para montagem';
    }

    if (stage == WorkflowStage.finance) {
      return _financeContractFlowSnapshot(order).currentTask?.label ??
          'Fluxo de contrato concluído';
    }

    if (stage == WorkflowStage.estimating && !order.isServiceOrder) {
      return _estimatingKanbanFlowSnapshot(order).currentTask?.label ??
          'Orçamento concluído';
    }

    if (stage == WorkflowStage.relationship) {
      return _relationshipKanbanFlowSnapshot(order).currentTask?.label ??
          'Relacionamento concluído';
    }

    if (stage == WorkflowStage.assembly) {
      return switch (order.assemblyWorkflowStatus) {
        AssemblyWorkflowStatus.waiting =>
          _isAssemblyPreparationChecklistComplete(order)
              ? 'Liberar para montagem'
              : 'Dar baixa no checklist de preparação',
        AssemblyWorkflowStatus.released => 'Liberado para montagem',
        AssemblyWorkflowStatus.doing => 'Executar montagem',
        AssemblyWorkflowStatus.panelTesting => 'Realizar teste de painel',
        AssemblyWorkflowStatus.done =>
          'Painel concluído. Liberar para instalação',
      };
    }

    if (stage == WorkflowStage.installation) {
      return _installationNextAction(order);
    }

    return stage.checklist.isEmpty ? stage.title : stage.checklist.first;
  }

  String _serviceOrderFinanceNextAction(WorkflowOrder order) {
    if (!order.financeClientApproved ||
        order.serviceOrderFinanceStatus ==
            ServiceOrderFinanceStatus.waitingApproval) {
      return 'Confirmar aprovação do cliente';
    }
    return switch (order.serviceOrderFinanceStatus) {
      ServiceOrderFinanceStatus.waitingApproval =>
        'Confirmar aprovação do cliente',
      ServiceOrderFinanceStatus.approved =>
        'Aguardar OS realizada do Orçamentista',
      ServiceOrderFinanceStatus.concluded => 'Registrar pagamento da OS',
      ServiceOrderFinanceStatus.paid => 'OS paga',
    };
  }

  String _serviceOrderFinanceBlocker(WorkflowOrder order) {
    if (!order.financeClientApproved ||
        order.serviceOrderFinanceStatus ==
            ServiceOrderFinanceStatus.waitingApproval) {
      return 'Aguardando confirmação do cliente no Financeiro.';
    }
    return switch (order.serviceOrderFinanceStatus) {
      ServiceOrderFinanceStatus.waitingApproval =>
        'Aguardando confirmação do cliente no Financeiro.',
      ServiceOrderFinanceStatus.approved =>
        'Cliente aprovado. Aguardando retorno da OS realizada pelo Orçamentista.',
      ServiceOrderFinanceStatus.concluded =>
        'OS concluída no Orçamentista. Aguardando baixa do pagamento.',
      ServiceOrderFinanceStatus.paid => 'Pagamento da OS registrado.',
    };
  }

  String _assemblyWorkflowBlocker(
    WorkflowOrder order,
    AssemblyWorkflowStatus status,
  ) {
    return switch (status) {
      AssemblyWorkflowStatus.waiting =>
        _isAssemblyPreparationChecklistComplete(order)
            ? 'Checklist concluído. Pedido pronto para ser liberado à montagem.'
            : 'Checklist de preparação inicial pendente antes de liberar para Montagem.',
      AssemblyWorkflowStatus.released =>
        'Liberado para Montagem. Aguardando início da execução.',
      AssemblyWorkflowStatus.doing => 'Montagem em andamento.',
      AssemblyWorkflowStatus.panelTesting =>
        'Painel em teste. Validar funcionamento antes de concluir.',
      AssemblyWorkflowStatus.done =>
        'Painel concluído. Pronto para Instalação.',
    };
  }

  String _installationWorkflowBlocker(InstallationWorkflowStatus status) {
    return switch (status) {
      InstallationWorkflowStatus.waiting =>
        'Aguardando liberação da agenda de instalação.',
      InstallationWorkflowStatus.scheduled =>
        'Instalação agendada. Aguardando definição da equipe.',
      InstallationWorkflowStatus.doing => 'Instalação em andamento em campo.',
      InstallationWorkflowStatus.done => 'Instalação concluída.',
    };
  }

  String _financeContractWorkflowBlocker(WorkflowOrder order) {
    final flowSnapshot = _financeContractFlowSnapshot(order);
    return flowSnapshot.isComplete
        ? 'Sem bloqueio. Fluxo de contrato concluído no Financeiro.'
        : 'Kanban do contrato em ${flowSnapshot.currentTask!.label}.';
  }

  String _estimatingKanbanWorkflowBlocker(WorkflowOrder order) {
    final flowSnapshot = _estimatingKanbanFlowSnapshot(order);
    return flowSnapshot.isComplete
        ? 'Sem bloqueio. Fluxo do Orçamentista concluído.'
        : 'Kanban do Orçamentista em ${flowSnapshot.currentTask!.label}.';
  }

  String _relationshipKanbanWorkflowBlocker(WorkflowOrder order) {
    final flowSnapshot = _relationshipKanbanFlowSnapshot(order);
    return flowSnapshot.isComplete
        ? 'Sem bloqueio. Fluxo de Relacionamento concluído.'
        : 'Kanban do relacionamento em ${flowSnapshot.currentTask!.label}.';
  }

  String _installationNextAction(WorkflowOrder order) {
    return switch (order.installationWorkflowStatus) {
      InstallationWorkflowStatus.waiting => 'Agendar instalação',
      InstallationWorkflowStatus.scheduled => 'Selecionar equipe da instalação',
      InstallationWorkflowStatus.doing => 'Concluir ou agendar retorno',
      InstallationWorkflowStatus.done => 'Instalação concluída',
    };
  }

  List<EmployeeWorkspaceProfile> _assemblyEligibleProfiles() {
    final profiles = _workspaceProfiles
        .where((profile) => profile.email.trim().isNotEmpty)
        .toList(growable: false);
    profiles.sort((left, right) {
      final leftName = left.name.trim().isEmpty ? left.login : left.name;
      final rightName = right.name.trim().isEmpty ? right.login : right.name;
      return leftName.toLowerCase().compareTo(rightName.toLowerCase());
    });
    return profiles;
  }

  List<EmployeeWorkspaceProfile> _installationEligibleProfiles() {
    final profiles = _workspaceProfiles
        .where(
          (profile) =>
              profile.email.trim().isNotEmpty &&
              (profile.isAdministrator ||
                  profile.allowedStages.contains(WorkflowStage.installation)),
        )
        .toList(growable: false);
    profiles.sort((left, right) {
      final leftName = left.name.trim().isEmpty ? left.login : left.name;
      final rightName = right.name.trim().isEmpty ? right.login : right.name;
      return leftName.toLowerCase().compareTo(rightName.toLowerCase());
    });
    return profiles;
  }

  Future<void> _updateAssemblyWorkflowStatus(
    AssemblyWorkflowStatus status, {
    WorkflowOrder? order,
    List<String>? assignedEmployeeEmails,
  }) async {
    final sourceOrder = order ?? _selectedOrder;
    if (sourceOrder == null) {
      return;
    }

    final now = DateTime.now();
    final nextAssignedEmployeeEmails =
        status == AssemblyWorkflowStatus.released ||
            status == AssemblyWorkflowStatus.waiting
        ? const <String>[]
        : assignedEmployeeEmails ??
              List<String>.from(sourceOrder.assemblyAssignedEmployeeEmails);
    final previewOrder = sourceOrder.copyWith(
      assemblyWorkflowStatus: status,
      assemblyAssignedEmployeeEmails: nextAssignedEmployeeEmails,
    );
    final updatedOrder = sourceOrder.copyWith(
      assemblyWorkflowStatus: status,
      assemblyAssignedEmployeeEmails: nextAssignedEmployeeEmails,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: _defaultNextActionForStage(
        WorkflowStage.assembly,
        previewOrder,
      ),
      blocker: _assemblyWorkflowBlocker(previewOrder, status),
      history: Map<WorkflowStage, String>.from(sourceOrder.history)
        ..[WorkflowStage.assembly] =
            'Montagem marcada como ${status.title.toLowerCase()} em ${_formatDateTime(now)}',
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Atualizando status da montagem...',
      successMessage: 'Status da montagem atualizado.',
      errorPrefix: 'Não foi possível atualizar a montagem',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Atualizou status da montagem',
        area: 'Montagem',
        details:
            '${_displayOrderCode(savedOrder)} • ${savedOrder.assemblyWorkflowStatus.title}',
      ),
    );
  }

  Future<bool> _reviewAssemblyPreparationChecklist({
    WorkflowOrder? order,
    required bool requireCompletion,
  }) async {
    return _reviewAssemblyChecklist(
      order: order,
      sections: const [assemblyPreparationChecklistSection],
      requireCompletion: requireCompletion,
      dialogTitle: 'Checklist da montagem',
      busyMessage: 'Salvando checklist da montagem...',
      successMessage: requireCompletion
          ? 'Checklist da preparação concluído.'
          : 'Checklist da preparação atualizado.',
    );
  }

  Future<bool> _reviewAssemblyExecutionChecklist({
    WorkflowOrder? order,
    required bool requireCompletion,
  }) async {
    return _reviewAssemblyChecklist(
      order: order,
      sections: assemblyExecutionChecklistSections,
      requireCompletion: requireCompletion,
      dialogTitle: 'Checklist de execução da montagem',
      busyMessage: 'Salvando execução da montagem...',
      successMessage: requireCompletion
          ? 'Checklist da execução concluído.'
          : 'Checklist da execução atualizado.',
    );
  }

  Future<bool> _reviewAssemblyChecklist({
    WorkflowOrder? order,
    required List<AssemblyChecklistSection> sections,
    required bool requireCompletion,
    required String dialogTitle,
    required String busyMessage,
    required String successMessage,
  }) async {
    final sourceOrder = order ?? _selectedOrder;
    if (sourceOrder == null) {
      return false;
    }

    final sectionItems = sections.expand((section) => section.items).toSet();
    final checklist = await showDialog<Map<String, bool>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AssemblyChecklistDialog(
        order: sourceOrder,
        title: dialogTitle,
        sections: sections,
        initialChecklist: {
          for (final item in sectionItems)
            item: sourceOrder.assemblyPreparationChecklist[item] == true,
        },
        requireCompletion: requireCompletion,
      ),
    );
    if (checklist == null) {
      return false;
    }

    final normalizedChecklist = {
      ...sourceOrder.assemblyPreparationChecklist,
      for (final item in sectionItems) item: checklist[item] == true,
    };
    final previewOrder = sourceOrder.copyWith(
      assemblyPreparationChecklist: normalizedChecklist,
    );
    final updatedOrder = sourceOrder.copyWith(
      assemblyPreparationChecklist: normalizedChecklist,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: sourceOrder.currentStage == WorkflowStage.assembly
          ? _defaultNextActionForStage(WorkflowStage.assembly, previewOrder)
          : sourceOrder.nextAction,
      blocker: sourceOrder.currentStage == WorkflowStage.assembly
          ? _assemblyWorkflowBlocker(
              previewOrder,
              previewOrder.assemblyWorkflowStatus,
            )
          : sourceOrder.blocker,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: busyMessage,
      successMessage: successMessage,
      errorPrefix: 'Não foi possível salvar o checklist da montagem',
    );
    if (savedOrder == null) {
      return false;
    }

    _mergeOrderLocally(savedOrder);
    return requireCompletion
        ? sectionItems.every(
            (item) => savedOrder.assemblyPreparationChecklist[item] == true,
          )
        : true;
  }

  Future<void> _openAssemblyChecklistForSelectedOrder() async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    if (selected.assemblyWorkflowStatus == AssemblyWorkflowStatus.doing ||
        selected.assemblyWorkflowStatus ==
            AssemblyWorkflowStatus.panelTesting ||
        selected.assemblyWorkflowStatus == AssemblyWorkflowStatus.done) {
      await _reviewAssemblyExecutionChecklist(requireCompletion: false);
      return;
    }

    await _reviewAssemblyPreparationChecklist(requireCompletion: false);
  }

  Future<List<String>?> _pickAssemblyEmployees(WorkflowOrder order) async {
    final eligibleProfiles = _assemblyEligibleProfiles();
    if (eligibleProfiles.isEmpty) {
      _showAppMessage(
        'Nenhum colaborador com permissão de Montagem está disponível para seleção.',
        isError: true,
      );
      return null;
    }

    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AssemblyTeamSelectionDialog(
        profiles: eligibleProfiles,
        initialSelectedEmails: order.assemblyAssignedEmployeeEmails,
      ),
    );
  }

  Future<void> _completeAssemblyAndAdvanceToInstallation() async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final targetStage = WorkflowStage.installation;
    final updatedHistory = Map<WorkflowStage, String>.from(selected.history)
      ..[WorkflowStage.assembly] = 'Concluído em ${_formatDateTime(now)}'
      ..[targetStage] = 'Recebido da Montagem em ${_formatDateTime(now)}';
    final nextAssemblyStatus = AssemblyWorkflowStatus.done;
    final previewOrder = selected.copyWith(
      currentStage: targetStage,
      assemblyWorkflowStatus: nextAssemblyStatus,
      installationWorkflowStatus: InstallationWorkflowStatus.waiting,
      installationScheduledAt: null,
      clearInstallationScheduledAt: true,
      installationAssignedEmployeeEmails: const [],
    );

    final updatedOrder = selected.copyWith(
      currentStage: targetStage,
      assemblyWorkflowStatus: nextAssemblyStatus,
      installationWorkflowStatus: InstallationWorkflowStatus.waiting,
      installationScheduledAt: null,
      clearInstallationScheduledAt: true,
      installationAssignedEmployeeEmails: const [],
      installationAssignedTeam: '',
      owner: actorLabel,
      stageOwners: _updatedStageOwnersForAction(
        selected,
        WorkflowStage.assembly,
        actorLabel,
      ),
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: _defaultNextActionForStage(targetStage, previewOrder),
      blocker: _installationWorkflowBlocker(InstallationWorkflowStatus.waiting),
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Concluindo montagem e enviando para instalação...',
      successMessage: 'Montagem concluída e pedido enviado para instalação.',
      errorPrefix: 'Não foi possível concluir a montagem',
    );
    if (savedOrder == null) {
      return;
    }

    setState(() {
      _selectedViewKey = 'stage:${savedOrder.currentStage.name}';
      _selectedOrderCode = savedOrder.code;
    });
    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Concluiu montagem e enviou para Instalação',
        area: 'Instalação',
        details: '${_displayOrderCode(savedOrder)} • ${savedOrder.workName}',
      ),
    );
  }

  WorkflowOrder _resolvePrimaryProposal(WorkflowOrder order) {
    final proposalGroupCode = order.proposalGroupCode.trim();
    if (proposalGroupCode.isEmpty) {
      return order;
    }

    final groupedOrders = _orders
        .where((item) => item.proposalGroupCode == proposalGroupCode)
        .toList(growable: false);
    if (groupedOrders.isEmpty) {
      return order;
    }

    groupedOrders.sort((left, right) {
      final versionCompare = left.proposalVersion.compareTo(
        right.proposalVersion,
      );
      if (versionCompare != 0) {
        return versionCompare;
      }
      return _extractOrderNumber(
        left.code,
      ).compareTo(_extractOrderNumber(right.code));
    });
    return groupedOrders.first;
  }

  List<WorkflowOrder> _availableAdditionalProposalBaseOrders() {
    final primaryOrdersByGroup = <String, WorkflowOrder>{};
    for (final order in _orders) {
      if (order.isServiceOrder) {
        continue;
      }

      final primaryOrder = _resolvePrimaryProposal(order);
      final proposalGroupCode = primaryOrder.proposalGroupCode.trim().isEmpty
          ? primaryOrder.code
          : primaryOrder.proposalGroupCode.trim();
      primaryOrdersByGroup[proposalGroupCode] = primaryOrder;
    }

    final availableOrders = primaryOrdersByGroup.values.toList(growable: false);
    availableOrders.sort((left, right) {
      final clientIdCompare = left.client.id.compareTo(right.client.id);
      if (clientIdCompare != 0) {
        return clientIdCompare;
      }

      final clientNameCompare = left.client.name.toLowerCase().compareTo(
        right.client.name.toLowerCase(),
      );
      if (clientNameCompare != 0) {
        return clientNameCompare;
      }

      return left.workName.toLowerCase().compareTo(
        right.workName.toLowerCase(),
      );
    });
    return availableOrders;
  }

  Future<void> _openAdditionalProposalSelectionFlow() async {
    final availableOrders = _availableAdditionalProposalBaseOrders();
    if (availableOrders.isEmpty) {
      _showAppMessage(
        'Nenhum cliente com proposta comercial disponível para gerar nova proposta.',
        isError: true,
      );
      return;
    }

    WorkflowOrder? selectedOrder;
    if (availableOrders.length == 1) {
      selectedOrder = availableOrders.first;
    } else {
      selectedOrder = await showDialog<WorkflowOrder>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _AdditionalProposalClientPickerDialog(baseOrders: availableOrders),
      );
    }

    if (selectedOrder == null) {
      return;
    }

    await _openAdditionalProposalForm(selectedOrder);
  }

  Future<void> _openAdditionalProposalForm(WorkflowOrder sourceOrder) async {
    if (sourceOrder.isServiceOrder) {
      _showAppMessage(
        'Nova proposta vinculada está disponível apenas para propostas comerciais.',
        isError: true,
      );
      return;
    }

    final primaryOrder = _resolvePrimaryProposal(sourceOrder);
    final proposalGroupCode = primaryOrder.proposalGroupCode.trim().isEmpty
        ? primaryOrder.code
        : primaryOrder.proposalGroupCode;
    final nextProposalVersion =
        _orders
            .where((order) => order.proposalGroupCode == proposalGroupCode)
            .fold<int>(0, (highest, order) {
              return order.proposalVersion > highest
                  ? order.proposalVersion
                  : highest;
            }) +
        1;

    final draft = await showDialog<_AdditionalProposalDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AdditionalProposalDialog(
        baseOrder: primaryOrder,
        proposalVersion: nextProposalVersion,
      ),
    );

    if (draft == null) {
      return;
    }

    final now = DateTime.now();
    final creatorLabel = _currentOrderOwnerLabel();
    final newOrderCode = _proposalCodeForClient(
      primaryOrder.client.id,
      proposalVersion: nextProposalVersion,
    );
    final newOrder = WorkflowOrder(
      code: newOrderCode,
      client: primaryOrder.client,
      workName: draft.workName.trim(),
      address: draft.address.trim(),
      workPostalCode: primaryOrder.workPostalCode,
      workStreet: primaryOrder.workStreet,
      workNumber: primaryOrder.workNumber,
      workNeighborhood: primaryOrder.workNeighborhood,
      workComplement: primaryOrder.workComplement,
      proposalFileName: draft.proposalFileName.trim(),
      proposalFilePath: draft.proposalFilePath,
      detailFileName: primaryOrder.detailFileName,
      detailFilePath: primaryOrder.detailFilePath,
      materialFileName: '',
      materialFilePath: null,
      estimatingIncludedVisits: List<EstimatingIncludedVisitEntry>.from(
        primaryOrder.estimatingIncludedVisits,
      ),
      estimatingMaterials: List<EstimatingMaterialEntry>.from(
        primaryOrder.estimatingMaterials,
      ),
      consolidatedProposalFileName: '',
      consolidatedProposalFilePath: null,
      contractFileName: '',
      contractFilePath: null,
      electricalProjectFileName: '',
      electricalProjectFilePath: null,
      panelLayoutFileName: '',
      panelLayoutFilePath: null,
      pushButtonTableFileName: '',
      pushButtonTableFilePath: null,
      engineeringDataFileName: '',
      engineeringDataFilePath: null,
      engineeringChecklistStatuses: const {},
      engineeringActivitySchedules: const {},
      financeContractStatuses: const {},
      estimatingKanbanStatuses: const {},
      relationshipKanbanStatuses: const {},
      assemblyPreparationChecklist: const {},
      assemblyWorkflowStatus: AssemblyWorkflowStatus.waiting,
      assemblyAssignedEmployeeEmails: const [],
      currentStage: WorkflowStage.customerRegistration,
      owner: creatorLabel,
      stageOwners: {WorkflowStage.customerRegistration: creatorLabel},
      proposalGroupCode: proposalGroupCode,
      proposalVersion: nextProposalVersion,
      kind: WorkflowOrderKind.standard,
      serviceDescription: '',
      serviceOrderFileName: '',
      serviceOrderFilePath: null,
      financeClientApproved: false,
      serviceOrderFinanceStatus: ServiceOrderFinanceStatus.waitingApproval,
      installationWorkflowStatus: InstallationWorkflowStatus.waiting,
      installationScheduledAt: null,
      installationAssignedEmployeeEmails: const [],
      installationAssignedTeam: '',
      installationNotes: '',
      estimatingWasEstimate: '',
      installationVisitHistory: const [],
      value: draft.consolidatedValue.trim().isEmpty
          ? primaryOrder.value
          : double.tryParse(
                  draft.consolidatedValue
                      .replaceAll('.', '')
                      .replaceAll(',', '.'),
                ) ??
                primaryOrder.value,
      commercialProposalNumber: draft.commercialProposalNumber.trim().isEmpty
          ? primaryOrder.commercialProposalNumber
          : draft.commercialProposalNumber.trim(),
      paymentType: draft.paymentType,
      paymentMethod: draft.paymentMethod,
      paymentObservation: draft.paymentObservation,
      installmentValue: draft.installmentValue,
      installmentCount: draft.installmentCount,
      paymentDate: draft.paymentDate,
      rtValue: draft.rtValue,
      integratorValue: draft.integratorValue,
      integratorName: draft.integratorName,
      architectName: draft.architectName,
      proposalServices: draft.proposalServices,
      isDanfClient: draft.isDanfClient,
      danfInstallerName: draft.danfInstallerName,
      canHaveDanfPlate: draft.canHaveDanfPlate,
      hasWhatsappGroup: draft.hasWhatsappGroup,
      whatsappGroupMembers: draft.whatsappGroupMembers,
      whatsappGroupObservation: draft.whatsappGroupObservation,
      deadline: now.add(const Duration(days: 1)),
      progress: 1 / workflowStages.length,
      nextAction: WorkflowStage.customerRegistration.checklist.first,
      blocker:
          'Nova proposta vinculada criada para o cliente principal. Aguardando conferência do cadastro.',
      tags: ['Proposta $nextProposalVersion', 'Cliente existente'],
      conversationMessages: const [],
      history: {
        WorkflowStage.customerRegistration:
            'Proposta $nextProposalVersion criada por $creatorLabel em ${_formatDateTime(now)}',
      },
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(newOrder),
      busyMessage: 'Criando nova proposta...',
      successMessage:
          'Proposta $nextProposalVersion criada e vinculada ao card principal.',
      errorPrefix: 'Não foi possível criar a nova proposta',
    );
    if (savedOrder == null) {
      return;
    }

    setState(() {
      _selectedViewKey = 'stage:${WorkflowStage.customerRegistration.name}';
      _customerRegistrationSubtab = 0;
      _selectedOrderCode = savedOrder.code;
    });
    _mergeOrderLocally(savedOrder);
    _showDriveUploadConfigurationWarningIfNeeded(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Criou nova proposta vinculada',
        area: 'Cadastro de Clientes',
        details: '${savedOrder.code} • Proposta ${savedOrder.proposalVersion}',
      ),
    );
  }

  Future<void> _moveSelectedOrder(int direction) async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    if (direction > 0 && selected.currentStage == WorkflowStage.estimating) {
      if (selected.isServiceOrder &&
          selected.serviceOrderFileName.trim().isEmpty) {
        _showAppMessage(
          'Anexe o PDF da ordem de serviço no Orçamentista antes de avançar a etapa.',
          isError: true,
        );
        return;
      }

      if (!selected.isServiceOrder && !_hasEstimatingWorksheetData(selected)) {
        _showAppMessage(
          'Preencha a lista de visitas, materiais e o campo de estimativa no Orçamentista antes de avançar a etapa.',
          isError: true,
        );
        return;
      }
    }

    if (direction > 0 &&
        selected.currentStage == WorkflowStage.finance &&
        selected.isServiceOrder &&
        !selected.financeClientApproved) {
      _showAppMessage(
        'O Financeiro precisa confirmar a aprovação do cliente antes de avançar a OS.',
        isError: true,
      );
      return;
    }

    if (selected.isServiceOrder &&
        direction > 0 &&
        selected.currentStage == WorkflowStage.estimating &&
        selected.financeClientApproved &&
        selected.installationWorkflowStatus ==
            InstallationWorkflowStatus.done) {
      final now = DateTime.now();
      final actorLabel = _currentOrderOwnerLabel();
      final previewOrder = selected.copyWith(
        currentStage: WorkflowStage.finance,
        serviceOrderFinanceStatus: ServiceOrderFinanceStatus.concluded,
      );
      final updatedOrder = selected.copyWith(
        currentStage: WorkflowStage.finance,
        serviceOrderFinanceStatus: ServiceOrderFinanceStatus.concluded,
        owner: actorLabel,
        stageOwners: _updatedStageOwnersForAction(
          selected,
          WorkflowStage.estimating,
          actorLabel,
        ),
        progress: _effectiveOrderProgress(previewOrder),
        nextAction: _serviceOrderFinanceNextAction(previewOrder),
        blocker: _serviceOrderFinanceBlocker(previewOrder),
        history: Map<WorkflowStage, String>.from(selected.history)
          ..[WorkflowStage.estimating] =
              'OS concluída enviada ao Financeiro em ${_formatDateTime(now)}'
          ..[WorkflowStage.finance] =
              'OS concluída recebida do Orçamentista em ${_formatDateTime(now)}',
      );
      final savedOrder = await _runBusyTask(
        () => _repository.saveOrder(updatedOrder),
        busyMessage: 'Enviando OS concluída ao Financeiro...',
        successMessage: 'OS concluída enviada ao Financeiro.',
        errorPrefix: 'Não foi possível enviar a OS concluída ao Financeiro',
      );
      if (savedOrder == null) {
        return;
      }
      _mergeOrderLocally(savedOrder);
      setState(() {
        _selectedViewKey = 'stage:${WorkflowStage.finance.name}';
        _stageWorkspaceSubtabs[WorkflowStage.finance] = 0;
        _selectedOrderCode = savedOrder.code;
      });
      return;
    }

    if (selected.isServiceOrder &&
        selected.currentStage == WorkflowStage.finance &&
        selected.financeClientApproved) {
      if (direction > 0 &&
          selected.serviceOrderFinanceStatus ==
              ServiceOrderFinanceStatus.concluded) {
        final now = DateTime.now();
        final previewOrder = selected.copyWith(
          serviceOrderFinanceStatus: ServiceOrderFinanceStatus.paid,
        );
        final updatedOrder = selected.copyWith(
          serviceOrderFinanceStatus: ServiceOrderFinanceStatus.paid,
          progress: _effectiveOrderProgress(previewOrder),
          nextAction: _serviceOrderFinanceNextAction(previewOrder),
          blocker: _serviceOrderFinanceBlocker(previewOrder),
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.finance] =
                'Pagamento da OS registrado em ${_formatDateTime(now)}',
        );
        final savedOrder = await _runBusyTask(
          () => _repository.saveOrder(updatedOrder),
          busyMessage: 'Registrando pagamento da OS...',
          successMessage: 'OS marcada como paga.',
          errorPrefix: 'Não foi possível registrar o pagamento da OS',
        );
        if (savedOrder != null) {
          _mergeOrderLocally(savedOrder);
        }
        return;
      }

      if (direction < 0 &&
          selected.serviceOrderFinanceStatus ==
              ServiceOrderFinanceStatus.paid) {
        final now = DateTime.now();
        final previewOrder = selected.copyWith(
          serviceOrderFinanceStatus: ServiceOrderFinanceStatus.concluded,
        );
        final updatedOrder = selected.copyWith(
          serviceOrderFinanceStatus: ServiceOrderFinanceStatus.concluded,
          progress: _effectiveOrderProgress(previewOrder),
          nextAction: _serviceOrderFinanceNextAction(previewOrder),
          blocker: _serviceOrderFinanceBlocker(previewOrder),
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.finance] =
                'Pagamento da OS reaberto em ${_formatDateTime(now)}',
        );
        final savedOrder = await _runBusyTask(
          () => _repository.saveOrder(updatedOrder),
          busyMessage: 'Reabrindo pagamento da OS...',
          successMessage: 'OS retornada para concluída.',
          errorPrefix: 'Não foi possível reabrir o pagamento da OS',
        );
        if (savedOrder != null) {
          _mergeOrderLocally(savedOrder);
        }
        return;
      }

      if (direction < 0 &&
          selected.serviceOrderFinanceStatus ==
              ServiceOrderFinanceStatus.concluded) {
        final now = DateTime.now();
        final actorLabel = _currentOrderOwnerLabel();
        final previewOrder = selected.copyWith(
          currentStage: WorkflowStage.estimating,
          serviceOrderFinanceStatus: ServiceOrderFinanceStatus.approved,
        );
        final updatedOrder = selected.copyWith(
          currentStage: WorkflowStage.estimating,
          serviceOrderFinanceStatus: ServiceOrderFinanceStatus.approved,
          owner: actorLabel,
          stageOwners: _updatedStageOwnersForAction(
            selected,
            WorkflowStage.finance,
            actorLabel,
          ),
          progress: _effectiveOrderProgress(previewOrder),
          nextAction: 'OS Realizada',
          blocker: 'OS retornada ao Orçamentista para ajuste final.',
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.finance] =
                'OS concluída reaberta em ${_formatDateTime(now)}'
            ..[WorkflowStage.estimating] =
                'OS realizada reaberta no Orçamentista em ${_formatDateTime(now)}',
        );
        final savedOrder = await _runBusyTask(
          () => _repository.saveOrder(updatedOrder),
          busyMessage: 'Retornando OS ao Orçamentista...',
          successMessage: 'OS retornada ao Orçamentista.',
          errorPrefix: 'Não foi possível retornar a OS ao Orçamentista',
        );
        if (savedOrder == null) {
          return;
        }
        _mergeOrderLocally(savedOrder);
        setState(() {
          _selectedViewKey = 'stage:${WorkflowStage.estimating.name}';
          _stageWorkspaceSubtabs[WorkflowStage.estimating] = 0;
          _selectedOrderCode = savedOrder.code;
        });
        return;
      }
    }

    if (direction > 0 && selected.currentStage == WorkflowStage.engineering) {
      final flowSnapshot = _engineeringFlowSnapshot(selected);
      if (!flowSnapshot.isComplete && flowSnapshot.currentTask != null) {
        await _updateEngineeringChecklistStatus(
          flowSnapshot.currentTask!.key,
          EngineeringChecklistStatus.done,
        );
        return;
      }
    }

    if (selected.currentStage == WorkflowStage.assembly) {
      if (direction > 0) {
        if (selected.assemblyWorkflowStatus == AssemblyWorkflowStatus.waiting) {
          final checklistCompleted = await _reviewAssemblyPreparationChecklist(
            requireCompletion: true,
          );
          if (!checklistCompleted) {
            _showAppMessage(
              'Conclua o checklist da montagem antes de liberar o pedido.',
              isError: true,
            );
            return;
          }
          await _updateAssemblyWorkflowStatus(AssemblyWorkflowStatus.released);
          return;
        }
        if (selected.assemblyWorkflowStatus ==
            AssemblyWorkflowStatus.released) {
          final assignedEmployeeEmails = await _pickAssemblyEmployees(selected);
          if (assignedEmployeeEmails == null ||
              assignedEmployeeEmails.isEmpty) {
            return;
          }
          await _updateAssemblyWorkflowStatus(
            AssemblyWorkflowStatus.doing,
            assignedEmployeeEmails: assignedEmployeeEmails,
          );
          return;
        }
        if (selected.assemblyWorkflowStatus == AssemblyWorkflowStatus.doing) {
          final checklistCompleted = await _reviewAssemblyExecutionChecklist(
            requireCompletion: true,
          );
          if (!checklistCompleted) {
            _showAppMessage(
              'Conclua o checklist de execução antes de finalizar a montagem.',
              isError: true,
            );
            return;
          }
          await _updateAssemblyWorkflowStatus(
            AssemblyWorkflowStatus.panelTesting,
          );
          return;
        }
        if (selected.assemblyWorkflowStatus ==
            AssemblyWorkflowStatus.panelTesting) {
          await _updateAssemblyWorkflowStatus(AssemblyWorkflowStatus.done);
          return;
        }
        if (selected.assemblyWorkflowStatus == AssemblyWorkflowStatus.done) {
          await _completeAssemblyAndAdvanceToInstallation();
          return;
        }
      } else {
        if (selected.assemblyWorkflowStatus == AssemblyWorkflowStatus.done) {
          await _updateAssemblyWorkflowStatus(
            AssemblyWorkflowStatus.panelTesting,
          );
          return;
        }
        if (selected.assemblyWorkflowStatus ==
            AssemblyWorkflowStatus.panelTesting) {
          await _updateAssemblyWorkflowStatus(AssemblyWorkflowStatus.doing);
          return;
        }
        if (selected.assemblyWorkflowStatus == AssemblyWorkflowStatus.doing) {
          await _updateAssemblyWorkflowStatus(AssemblyWorkflowStatus.released);
          return;
        }
        if (selected.assemblyWorkflowStatus ==
            AssemblyWorkflowStatus.released) {
          await _updateAssemblyWorkflowStatus(AssemblyWorkflowStatus.waiting);
          return;
        }
      }
    }

    if (selected.currentStage == WorkflowStage.installation) {
      if (direction > 0) {
        if (selected.installationWorkflowStatus ==
            InstallationWorkflowStatus.waiting) {
          await _scheduleInstallationForSelectedOrder();
          return;
        }
        if (selected.installationWorkflowStatus ==
            InstallationWorkflowStatus.scheduled) {
          await _startInstallationVisit();
          return;
        }
        if (selected.installationWorkflowStatus ==
            InstallationWorkflowStatus.doing) {
          await _handleInstallationInProgressAdvance();
          return;
        }
      } else {
        if (selected.installationWorkflowStatus ==
            InstallationWorkflowStatus.doing) {
          await _scheduleInstallationForSelectedOrder();
          return;
        }
        if (selected.installationWorkflowStatus ==
            InstallationWorkflowStatus.scheduled) {
          final updatedOrder = selected.copyWith(
            installationWorkflowStatus: InstallationWorkflowStatus.waiting,
            clearInstallationScheduledAt: true,
            installationAssignedEmployeeEmails: const [],
            installationAssignedTeam: '',
            progress: _effectiveOrderProgress(
              selected.copyWith(
                installationWorkflowStatus: InstallationWorkflowStatus.waiting,
                clearInstallationScheduledAt: true,
                installationAssignedEmployeeEmails: const [],
                installationAssignedTeam: '',
              ),
            ),
            nextAction: 'Agendar instalação',
            blocker: _installationWorkflowBlocker(
              InstallationWorkflowStatus.waiting,
            ),
          );
          final savedOrder = await _runBusyTask(
            () => _repository.saveOrder(updatedOrder),
            busyMessage: 'Retornando instalação...',
            errorPrefix: 'Não foi possível retornar a instalação',
          );
          if (savedOrder != null) {
            _mergeOrderLocally(savedOrder);
          }
          return;
        }
      }
    }

    final currentIndex = workflowStages.indexOf(selected.currentStage);
    final nextIndex = (currentIndex + direction).clamp(
      0,
      workflowStages.length - 1,
    );
    if (nextIndex == currentIndex) {
      return;
    }

    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final updatedHistory = Map<WorkflowStage, String>.from(selected.history)
      ..[selected.currentStage] = 'Concluído em ${_formatDateTime(now)}';
    if (direction > 0) {
      updatedHistory[workflowStages[nextIndex]] =
          'Em andamento desde ${_formatDateTime(now)}';
    } else {
      updatedHistory[workflowStages[nextIndex]] =
          'Reaberto em ${_formatDateTime(now)}';
    }
    final nextStage = workflowStages[nextIndex];
    final nextAssemblyStatus = nextStage == WorkflowStage.assembly
        ? AssemblyWorkflowStatus.waiting
        : selected.assemblyWorkflowStatus;
    final nextAssemblyAssignedEmployeeEmails =
        nextStage == WorkflowStage.assembly
        ? const <String>[]
        : selected.assemblyAssignedEmployeeEmails;
    final nextInstallationStatus = nextStage == WorkflowStage.installation
        ? InstallationWorkflowStatus.waiting
        : selected.installationWorkflowStatus;
    final nextInstallationScheduledAt = nextStage == WorkflowStage.installation
        ? null
        : selected.installationScheduledAt;
    final nextInstallationAssignedEmployeeEmails =
        nextStage == WorkflowStage.installation
        ? const <String>[]
        : selected.installationAssignedEmployeeEmails;
    final previewOrder = selected.copyWith(
      currentStage: nextStage,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: nextAssemblyAssignedEmployeeEmails,
      installationWorkflowStatus: nextInstallationStatus,
      installationScheduledAt: nextInstallationScheduledAt,
      clearInstallationScheduledAt: nextStage == WorkflowStage.installation,
      installationAssignedEmployeeEmails:
          nextInstallationAssignedEmployeeEmails,
    );

    final updatedOrder = selected.copyWith(
      currentStage: nextStage,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: nextAssemblyAssignedEmployeeEmails,
      installationWorkflowStatus: nextInstallationStatus,
      installationScheduledAt: nextInstallationScheduledAt,
      clearInstallationScheduledAt: nextStage == WorkflowStage.installation,
      installationAssignedEmployeeEmails:
          nextInstallationAssignedEmployeeEmails,
      installationAssignedTeam: nextStage == WorkflowStage.installation
          ? ''
          : selected.installationAssignedTeam,
      owner: actorLabel,
      stageOwners: _updatedStageOwnersForAction(
        selected,
        selected.currentStage,
        actorLabel,
      ),
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: _defaultNextActionForStage(nextStage, previewOrder),
      blocker: nextStage == WorkflowStage.assembly
          ? _assemblyWorkflowBlocker(
              previewOrder,
              AssemblyWorkflowStatus.waiting,
            )
          : nextStage == WorkflowStage.estimating &&
                !previewOrder.isServiceOrder
          ? _estimatingKanbanWorkflowBlocker(previewOrder)
          : nextStage == WorkflowStage.relationship
          ? _relationshipKanbanWorkflowBlocker(previewOrder)
          : nextStage == WorkflowStage.finance
          ? _financeContractWorkflowBlocker(previewOrder)
          : nextStage == WorkflowStage.installation
          ? _installationWorkflowBlocker(InstallationWorkflowStatus.waiting)
          : nextIndex > currentIndex
          ? 'Sem bloqueio. Fluxo avançado manualmente.'
          : 'Etapa anterior reaberta para ajuste.',
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: direction > 0 ? 'Avançando etapa...' : 'Retornando etapa...',
      errorPrefix: 'Não foi possível atualizar a etapa',
    );
    if (savedOrder == null) {
      return;
    }

    setState(() {
      _selectedViewKey = 'stage:${savedOrder.currentStage.name}';
      _selectedOrderCode = savedOrder.code;
    });
    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: direction > 0
            ? 'Avançou etapa do pedido'
            : 'Retornou etapa do pedido',
        area: savedOrder.currentStage.title,
        details: '${savedOrder.code} • ${savedOrder.workName}',
      ),
    );

  }

  List<WorkflowOrder> get _mergeableCandidates {
    final relationshipIndex = workflowStages.indexOf(
      WorkflowStage.relationship,
    );
    return _orders.where((order) {
      if (order.proposalVersion <= 1) return false;
      if (_isSubProposal(order)) return false;
      final stageIndex = workflowStages.indexOf(order.currentStage);
      if (stageIndex < relationshipIndex) return false;
      final primary = _resolvePrimaryProposal(order);
      if (primary.code == order.code) return false;
      return workflowStages.indexOf(primary.currentStage) >= relationshipIndex;
    }).toList(growable: false);
  }

  Future<void> _mergeProposalWithPrimary(WorkflowOrder secondary) async {
    final primary = _resolvePrimaryProposal(secondary);
    final mergedOrder = secondary.copyWith(
      tags: [...secondary.tags, _subProposalMergeTag],
    );
    final saved = await _runBusyTask(
      () => _repository.saveOrder(mergedOrder),
      busyMessage: 'Juntando propostas...',
      errorPrefix: 'Não foi possível juntar as propostas',
    );
    if (saved == null) return;
    _mergeOrderLocally(saved);
    setState(() {
      _selectedViewKey = 'stage:${primary.currentStage.name}';
      _selectedOrderCode = primary.code;
    });
  }

  Future<void> _unmergeProposalFromPrimary(WorkflowOrder secondary) async {
    final updatedOrder = secondary.copyWith(
      tags: secondary.tags.where((t) => t != _subProposalMergeTag).toList(),
    );
    final saved = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Desfazendo junção...',
      errorPrefix: 'Não foi possível desfazer a junção',
    );
    if (saved == null) return;
    _mergeOrderLocally(saved);
  }

  Future<void> _routeSelectedOrderToStage(WorkflowStage targetStage) async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    if (selected.currentStage == WorkflowStage.relationship &&
        !selected.isServiceOrder &&
        !_relationshipKanbanFlowSnapshot(selected).isComplete) {
      _showAppMessage(
        'Conclua o kanban do Relacionamento antes de encaminhar o pedido.',
        isError: true,
      );
      return;
    }

    final currentIndex = workflowStages.indexOf(selected.currentStage);
    final targetIndex = workflowStages.indexOf(targetStage);
    if (targetIndex == currentIndex) {
      return;
    }

    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final updatedHistory = Map<WorkflowStage, String>.from(selected.history)
      ..[selected.currentStage] = 'Concluído em ${_formatDateTime(now)}'
      ..[targetStage] =
          'Encaminhado por Relacionamento em ${_formatDateTime(now)}';
    final nextAssemblyStatus = targetStage == WorkflowStage.assembly
        ? AssemblyWorkflowStatus.waiting
        : selected.assemblyWorkflowStatus;
    final nextAssemblyAssignedEmployeeEmails =
        targetStage == WorkflowStage.assembly
        ? const <String>[]
        : selected.assemblyAssignedEmployeeEmails;
    final nextInstallationStatus = targetStage == WorkflowStage.installation
        ? InstallationWorkflowStatus.waiting
        : selected.installationWorkflowStatus;
    final nextInstallationScheduledAt =
        targetStage == WorkflowStage.installation
        ? null
        : selected.installationScheduledAt;
    final nextInstallationAssignedEmployeeEmails =
        targetStage == WorkflowStage.installation
        ? const <String>[]
        : selected.installationAssignedEmployeeEmails;
    final previewOrder = selected.copyWith(
      currentStage: targetStage,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: nextAssemblyAssignedEmployeeEmails,
      installationWorkflowStatus: nextInstallationStatus,
      installationScheduledAt: nextInstallationScheduledAt,
      clearInstallationScheduledAt: targetStage == WorkflowStage.installation,
      installationAssignedEmployeeEmails:
          nextInstallationAssignedEmployeeEmails,
    );

    final updatedOrder = selected.copyWith(
      currentStage: targetStage,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: nextAssemblyAssignedEmployeeEmails,
      installationWorkflowStatus: nextInstallationStatus,
      installationScheduledAt: nextInstallationScheduledAt,
      clearInstallationScheduledAt: targetStage == WorkflowStage.installation,
      installationAssignedEmployeeEmails:
          nextInstallationAssignedEmployeeEmails,
      installationAssignedTeam: targetStage == WorkflowStage.installation
          ? ''
          : selected.installationAssignedTeam,
      owner: actorLabel,
      stageOwners: _updatedStageOwnersForAction(
        selected,
        selected.currentStage,
        actorLabel,
      ),
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: _defaultNextActionForStage(targetStage, previewOrder),
      blocker: targetStage == WorkflowStage.assembly
          ? _assemblyWorkflowBlocker(
              previewOrder,
              AssemblyWorkflowStatus.waiting,
            )
          : targetStage == WorkflowStage.estimating &&
                !previewOrder.isServiceOrder
          ? _estimatingKanbanWorkflowBlocker(previewOrder)
          : targetStage == WorkflowStage.relationship
          ? _relationshipKanbanWorkflowBlocker(previewOrder)
          : targetStage == WorkflowStage.finance
          ? _financeContractWorkflowBlocker(previewOrder)
          : targetStage == WorkflowStage.installation
          ? _installationWorkflowBlocker(InstallationWorkflowStatus.waiting)
          : 'Encaminhado para ${targetStage.title.toLowerCase()}.',
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Encaminhando pedido...',
      errorPrefix: 'Não foi possível encaminhar o pedido',
    );
    if (savedOrder == null) {
      return;
    }

    setState(() {
      _selectedViewKey = 'stage:${savedOrder.currentStage.name}';
      _selectedOrderCode = savedOrder.code;
    });
    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Encaminhou pedido para ${targetStage.title}',
        area: targetStage.title,
        details: '${savedOrder.code} • ${savedOrder.workName}',
      ),
    );
  }

  Future<void> _attachMaterialsToSelectedOrder() async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    final draft = await showDialog<_EstimatingWorksheetDraft>(
      context: context,
      builder: (context) => _EstimatingWorksheetDialog(order: selected),
    );
    if (draft == null) {
      return;
    }

    final now = DateTime.now();
    final updatedEstimatingStatuses = <String, EngineeringChecklistStatus>{
      'waiting': EngineeringChecklistStatus.done,
      'doing':
          _hasEstimatingWorksheetData(
            selected.copyWith(
              estimatingIncludedVisits: draft.includedVisits,
              estimatingMaterials: draft.materials,
            ),
          )
          ? EngineeringChecklistStatus.done
          : EngineeringChecklistStatus.notStarted,
    };
    final updatedOrder = selected.copyWith(
      estimatingIncludedVisits: draft.includedVisits,
      estimatingMaterials: draft.materials,
      estimatingKanbanStatuses: updatedEstimatingStatuses,
      history: Map<WorkflowStage, String>.from(selected.history)
        ..[WorkflowStage.estimating] =
            'Levantamento do Orçamentista atualizado em ${_formatDateTime(now)}',
      nextAction:
          _estimatingKanbanFlowSnapshotFromStatuses(
            updatedEstimatingStatuses,
          ).currentTask?.label ??
          'Orçamento concluído',
      blocker:
          _estimatingKanbanFlowSnapshotFromStatuses(
            updatedEstimatingStatuses,
          ).isComplete
          ? 'Sem bloqueio. Fluxo do Orçamentista concluído.'
          : 'Kanban do Orçamentista em ${_estimatingKanbanFlowSnapshotFromStatuses(updatedEstimatingStatuses).currentTask!.label}.',
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Salvando levantamento do Orçamentista...',
      successMessage: 'Levantamento do Orçamentista salvo.',
      errorPrefix: 'Não foi possível salvar o levantamento do Orçamentista',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Atualizou levantamento do Orçamentista',
        area: 'Orçamentista',
        details:
            '${savedOrder.code} • ${savedOrder.estimatingMaterials.length} materiais',
      ),
    );
  }

  Future<void> _setEstimatingWasEstimateForSelectedOrder() async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    String? value = selected.estimatingWasEstimate.trim().isEmpty
        ? null
        : selected.estimatingWasEstimate.trim();
    final chosenValue = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Foi estimativa?'),
          content: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: const InputDecoration(
              labelText: 'Estimativa',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Sim', child: Text('Sim')),
              DropdownMenuItem(value: 'Não', child: Text('Não')),
            ],
            onChanged: (newValue) {
              setModalState(() {
                value = newValue;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: value == null
                  ? null
                  : () => Navigator.of(context).pop(value),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (chosenValue == null) {
      return;
    }

    final now = DateTime.now();
    final updatedOrder = selected.copyWith(
      estimatingWasEstimate: chosenValue,
      history: Map<WorkflowStage, String>.from(selected.history)
        ..[WorkflowStage.estimating] =
            'Estimativa definida como $chosenValue em ${_formatDateTime(now)}',
    );
    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Salvando estimativa...',
      successMessage: 'Estimativa atualizada.',
      errorPrefix: 'Não foi possível salvar a estimativa',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
  }

  Future<void> _attachConsolidatedProposalToSelectedOrder() async {
    await _attachFileToSelectedOrder(
      logAction: 'Anexou proposta consolidada',
      logArea: 'Financeiro',
      onUpdate: (selected, file) {
        final now = DateTime.now();
        return selected.copyWith(
          consolidatedProposalFileName: file.name,
          consolidatedProposalFilePath: file.path,
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.finance] =
                'Proposta consolidada anexada em ${_formatDateTime(now)}',
        );
      },
    );
  }

  Future<void> _attachElectricalProjectToSelectedOrder() async {
    await _attachFileToSelectedOrder(
      allowedExtensions: const ['pdf', 'dwg', 'dxf', 'zip'],
      successMessage: 'Projeto elétrico salvo no Firebase.',
      busyMessage: 'Enviando projeto elétrico...',
      errorPrefix: 'Não foi possível salvar o projeto elétrico',
      logAction: 'Anexou projeto elétrico',
      logArea: 'Engenharia',
      onUpdate: (selected, file) {
        final now = DateTime.now();
        return selected.copyWith(
          electricalProjectFileName: file.name,
          electricalProjectFilePath: file.path,
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.engineering] =
                'Projeto elétrico anexado em ${_formatDateTime(now)}',
        );
      },
    );
  }

  Future<void> _attachPanelLayoutToSelectedOrder() async {
    await _attachFileToSelectedOrder(
      allowedExtensions: const [
        'pdf',
        'dwg',
        'dxf',
        'png',
        'jpg',
        'jpeg',
        'zip',
      ],
      successMessage: 'Layout do painel salvo no Firebase.',
      busyMessage: 'Enviando layout do painel...',
      errorPrefix: 'Não foi possível salvar o layout do painel',
      logAction: 'Anexou layout do painel',
      logArea: 'Engenharia',
      onUpdate: (selected, file) {
        final now = DateTime.now();
        return selected.copyWith(
          panelLayoutFileName: file.name,
          panelLayoutFilePath: file.path,
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.engineering] =
                'Layout do painel anexado em ${_formatDateTime(now)}',
        );
      },
    );
  }

  Future<void> _attachPushButtonTableToSelectedOrder() async {
    await _attachFileToSelectedOrder(
      allowedExtensions: const [
        'pdf',
        'xls',
        'xlsx',
        'csv',
        'png',
        'jpg',
        'jpeg',
        'zip',
      ],
      successMessage: 'Tabela de pulsadores salva no Firebase.',
      busyMessage: 'Enviando tabela de pulsadores...',
      errorPrefix: 'Não foi possível salvar a tabela de pulsadores',
      logAction: 'Anexou tabela de pulsadores',
      logArea: 'Engenharia',
      onUpdate: (selected, file) {
        final now = DateTime.now();
        return selected.copyWith(
          pushButtonTableFileName: file.name,
          pushButtonTableFilePath: file.path,
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.engineering] =
                'Tabela de pulsadores anexada em ${_formatDateTime(now)}',
        );
      },
    );
  }

  Future<void> _attachEngineeringDataToSelectedOrder() async {
    await _attachFileToSelectedOrder(
      allowedExtensions: const ['pdf', 'xls', 'xlsx', 'csv', 'zip'],
      successMessage: 'Arquivo de dados salvo no Firebase.',
      busyMessage: 'Enviando arquivo de dados...',
      errorPrefix: 'Não foi possível salvar o arquivo de dados',
      logAction: 'Anexou arquivo de dados',
      logArea: 'Engenharia',
      onUpdate: (selected, file) {
        final now = DateTime.now();
        return selected.copyWith(
          engineeringDataFileName: file.name,
          engineeringDataFilePath: file.path,
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.engineering] =
                'Arquivo de dados anexado em ${_formatDateTime(now)}',
        );
      },
    );
  }

  Future<void> _updateEngineeringChecklistStatus(
    String taskKey,
    EngineeringChecklistStatus status,
  ) async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    final updatedStatuses = Map<String, EngineeringChecklistStatus>.from(
      selected.engineeringChecklistStatuses,
    );
    final taskIndex = engineeringChecklistTasks.indexWhere(
      (task) => task.key == taskKey,
    );
    if (taskIndex == -1) {
      return;
    }
    final task = engineeringChecklistTasks[taskIndex];
    final updatedSchedules = Map<String, EngineeringTaskSchedule>.from(
      selected.engineeringActivitySchedules,
    );
    if (status == EngineeringChecklistStatus.done) {
      updatedStatuses[taskKey] = EngineeringChecklistStatus.done;
    } else {
      for (
        var index = taskIndex;
        index < engineeringChecklistTasks.length;
        index++
      ) {
        updatedStatuses[engineeringChecklistTasks[index].key] =
            EngineeringChecklistStatus.notStarted;
      }
    }
    final flowSnapshot = _engineeringFlowSnapshotFromStatuses(updatedStatuses);
    EngineeringTaskSchedule? scheduledTarget;
    if (status == EngineeringChecklistStatus.done &&
        !flowSnapshot.isComplete &&
        flowSnapshot.currentTask != null &&
        flowSnapshot.currentTask!.supportsScheduling) {
      scheduledTarget = await _pickEngineeringActivitySchedule(
        selected,
        flowSnapshot.currentTask!.key,
      );
      if (scheduledTarget == null) {
        return;
      }
      updatedSchedules[flowSnapshot.currentTask!.key] = scheduledTarget;
    }
    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final historyMessage = status == EngineeringChecklistStatus.done
        ? flowSnapshot.isComplete
              ? 'Kanban da engenharia concluído em ${_formatDateTime(now)}'
              : scheduledTarget != null
              ? '${flowSnapshot.currentTask!.label} agendada para ${_formatDateTime(scheduledTarget.scheduledAt)}'
              : '${task.label} concluída. Próxima etapa: ${flowSnapshot.currentTask!.label}'
        : '${task.label} reaberta em ${_formatDateTime(now)}';
    final nextStage = flowSnapshot.isComplete
        ? WorkflowStage.assembly
        : selected.currentStage;
    final nextAssemblyStatus = flowSnapshot.isComplete
        ? AssemblyWorkflowStatus.waiting
        : selected.assemblyWorkflowStatus;
    final previewOrder = selected.copyWith(
      currentStage: nextStage,
      engineeringChecklistStatuses: updatedStatuses,
      engineeringActivitySchedules: updatedSchedules,
      engineeringDependsOnClient: false,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: flowSnapshot.isComplete
          ? const <String>[]
          : selected.assemblyAssignedEmployeeEmails,
    );
    final updatedHistory = Map<WorkflowStage, String>.from(selected.history)
      ..[WorkflowStage.engineering] = historyMessage;
    if (flowSnapshot.isComplete) {
      updatedHistory[WorkflowStage.assembly] =
          'Recebido da Engenharia em ${_formatDateTime(now)}';
    }
    final updatedOrder = selected.copyWith(
      currentStage: nextStage,
      engineeringChecklistStatuses: updatedStatuses,
      engineeringActivitySchedules: updatedSchedules,
      engineeringDependsOnClient: false,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: flowSnapshot.isComplete
          ? const <String>[]
          : selected.assemblyAssignedEmployeeEmails,
      owner: flowSnapshot.isComplete ? actorLabel : selected.owner,
      stageOwners: flowSnapshot.isComplete
          ? _updatedStageOwnersForAction(
              selected,
              WorkflowStage.engineering,
              actorLabel,
            )
          : selected.stageOwners,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: flowSnapshot.isComplete
          ? _defaultNextActionForStage(WorkflowStage.assembly, previewOrder)
          : (flowSnapshot.currentTask?.label ?? 'Liberar ordem para montagem'),
      blocker: flowSnapshot.isComplete
          ? _assemblyWorkflowBlocker(
              previewOrder,
              AssemblyWorkflowStatus.waiting,
            )
          : 'Kanban da engenharia em ${flowSnapshot.currentTask!.label}.',
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Atualizando status da engenharia...',
      successMessage: 'Status da engenharia atualizado.',
      errorPrefix: 'Não foi possível atualizar o status da engenharia',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    if (flowSnapshot.isComplete) {
      setState(() {
        _selectedViewKey = 'stage:${WorkflowStage.assembly.name}';
        _stageWorkspaceSubtabs[WorkflowStage.assembly] = 0;
        _selectedOrderCode = savedOrder.code;
      });
    }
    unawaited(
      _appendPlatformLog(
        action: status == EngineeringChecklistStatus.done
            ? 'Avançou kanban da engenharia'
            : 'Reabriu etapa da engenharia',
        area: 'Engenharia',
        details:
            '${_displayOrderCode(savedOrder)} • ${task.label}${status == EngineeringChecklistStatus.done ? ' concluída' : ' reaberta'}',
      ),
    );
  }

  bool _canMoveEngineeringOrderToTarget(
    WorkflowOrder order,
    String? targetTaskKey,
  ) {
    if (order.currentStage != WorkflowStage.engineering) {
      return false;
    }

    // "Depende do Cliente" não segue o fluxo: aceita pedidos vindos de
    // qualquer etapa e pode ser devolvido para qualquer etapa do fluxo.
    if (order.engineeringDependsOnClient) {
      if (targetTaskKey == null ||
          targetTaskKey == engineeringDependsOnClientTask.key) {
        return false;
      }
      return engineeringChecklistTasks.any((task) => task.key == targetTaskKey);
    }

    if (targetTaskKey == engineeringDependsOnClientTask.key) {
      return _engineeringFlowSnapshot(order).currentTask != null;
    }

    final snapshot = _engineeringFlowSnapshot(order);
    final currentTask = snapshot.currentTask;
    if (currentTask == null) {
      return false;
    }

    final currentIndex = engineeringChecklistTasks.indexWhere(
      (task) => task.key == currentTask.key,
    );
    if (currentIndex == -1) {
      return false;
    }

    if (targetTaskKey == null) {
      return currentIndex == engineeringChecklistTasks.length - 1;
    }

    final targetIndex = engineeringChecklistTasks.indexWhere(
      (task) => task.key == targetTaskKey,
    );
    if (targetIndex == -1) {
      return false;
    }

    return targetIndex == currentIndex + 1;
  }

  Future<void> _moveEngineeringOrderToKanbanColumn(
    WorkflowOrder order,
    String? targetTaskKey,
  ) async {
    if (!_canMoveEngineeringOrderToTarget(order, targetTaskKey)) {
      return;
    }

    if (targetTaskKey == engineeringDependsOnClientTask.key) {
      final now = DateTime.now();
      final historyMessage =
          'Marcado como ${engineeringDependsOnClientTask.label} em ${_formatDateTime(now)}';
      final updatedOrder = order.copyWith(
        engineeringDependsOnClient: true,
        nextAction: engineeringDependsOnClientTask.label,
        blocker: 'Depende de retorno do cliente para avançar na Engenharia.',
        history: Map<WorkflowStage, String>.from(order.history)
          ..[WorkflowStage.engineering] = historyMessage,
      );

      final savedOrder = await _runBusyTask(
        () => _repository.saveOrder(updatedOrder),
        busyMessage: 'Movendo card da engenharia...',
        successMessage: 'Kanban da engenharia atualizado.',
        errorPrefix: 'Não foi possível mover o card da engenharia',
      );
      if (savedOrder == null) {
        return;
      }

      _mergeOrderLocally(savedOrder);
      if (_selectedOrderCode == savedOrder.code) {
        setState(() {
          _selectedOrderCode = savedOrder.code;
        });
      }
      unawaited(
        _appendPlatformLog(
          action: 'Moveu card no kanban da engenharia',
          area: 'Engenharia',
          details:
              '${_displayOrderCode(savedOrder)} • ${engineeringDependsOnClientTask.label}',
        ),
      );
      return;
    }

    final updatedStatuses = <String, EngineeringChecklistStatus>{};
    final updatedSchedules = Map<String, EngineeringTaskSchedule>.from(
      order.engineeringActivitySchedules,
    );
    final targetIndex = targetTaskKey == null
        ? engineeringChecklistTasks.length
        : engineeringChecklistTasks.indexWhere(
            (task) => task.key == targetTaskKey,
          );
    for (var index = 0; index < engineeringChecklistTasks.length; index++) {
      updatedStatuses[engineeringChecklistTasks[index].key] =
          index < targetIndex
          ? EngineeringChecklistStatus.done
          : EngineeringChecklistStatus.notStarted;
    }

    final targetTask = targetTaskKey == null
        ? null
        : _engineeringChecklistTaskByKey(targetTaskKey);
    EngineeringTaskSchedule? scheduledTarget;
    if (targetTask != null && targetTask.supportsScheduling) {
      scheduledTarget = await _pickEngineeringActivitySchedule(
        order,
        targetTask.key,
      );
      if (scheduledTarget == null) {
        return;
      }
      updatedSchedules[targetTask.key] = scheduledTarget;
    }

    final flowSnapshot = _engineeringFlowSnapshotFromStatuses(updatedStatuses);
    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final historyMessage = flowSnapshot.isComplete
        ? 'Kanban da engenharia concluído em ${_formatDateTime(now)}'
        : scheduledTarget != null
        ? '${flowSnapshot.currentTask!.label} agendada para ${_formatDateTime(scheduledTarget.scheduledAt)}'
        : 'Kanban da engenharia movido para ${flowSnapshot.currentTask!.label} em ${_formatDateTime(now)}';
    final nextStage = flowSnapshot.isComplete
        ? WorkflowStage.assembly
        : order.currentStage;
    final nextAssemblyStatus = flowSnapshot.isComplete
        ? AssemblyWorkflowStatus.waiting
        : order.assemblyWorkflowStatus;
    final previewOrder = order.copyWith(
      currentStage: nextStage,
      engineeringChecklistStatuses: updatedStatuses,
      engineeringDependsOnClient: false,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: flowSnapshot.isComplete
          ? const <String>[]
          : order.assemblyAssignedEmployeeEmails,
    );
    final updatedHistory = Map<WorkflowStage, String>.from(order.history)
      ..[WorkflowStage.engineering] = historyMessage;
    if (flowSnapshot.isComplete) {
      updatedHistory[WorkflowStage.assembly] =
          'Recebido da Engenharia em ${_formatDateTime(now)}';
    }
    final updatedOrder = order.copyWith(
      currentStage: nextStage,
      engineeringChecklistStatuses: updatedStatuses,
      engineeringActivitySchedules: updatedSchedules,
      engineeringDependsOnClient: false,
      assemblyWorkflowStatus: nextAssemblyStatus,
      assemblyAssignedEmployeeEmails: flowSnapshot.isComplete
          ? const <String>[]
          : order.assemblyAssignedEmployeeEmails,
      owner: flowSnapshot.isComplete ? actorLabel : order.owner,
      stageOwners: flowSnapshot.isComplete
          ? _updatedStageOwnersForAction(
              order,
              WorkflowStage.engineering,
              actorLabel,
            )
          : order.stageOwners,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: flowSnapshot.isComplete
          ? _defaultNextActionForStage(WorkflowStage.assembly, previewOrder)
          : scheduledTarget != null
          ? historyMessage
          : (flowSnapshot.currentTask?.label ?? 'Liberar ordem para montagem'),
      blocker: flowSnapshot.isComplete
          ? _assemblyWorkflowBlocker(
              previewOrder,
              AssemblyWorkflowStatus.waiting,
            )
          : scheduledTarget != null
          ? 'Aguardando execução de atividade agendada pela Engenharia.'
          : 'Kanban da engenharia em ${flowSnapshot.currentTask!.label}.',
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Movendo card da engenharia...',
      successMessage: 'Kanban da engenharia atualizado.',
      errorPrefix: 'Não foi possível mover o card da engenharia',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    if (_selectedOrderCode == savedOrder.code && flowSnapshot.isComplete) {
      setState(() {
        _selectedViewKey = 'stage:${WorkflowStage.assembly.name}';
        _stageWorkspaceSubtabs[WorkflowStage.assembly] = 0;
        _selectedOrderCode = savedOrder.code;
      });
    } else if (_selectedOrderCode == savedOrder.code) {
      setState(() {
        _selectedOrderCode = savedOrder.code;
      });
    }
    unawaited(
      _appendPlatformLog(
        action: 'Moveu card no kanban da engenharia',
        area: 'Engenharia',
        details:
            '${_displayOrderCode(savedOrder)} • ${flowSnapshot.currentTask?.label ?? 'Concluído'}',
      ),
    );
  }

  bool _canMoveAssemblyOrderToTarget(
    WorkflowOrder order,
    AssemblyWorkflowStatus targetStatus,
  ) {
    if (order.currentStage != WorkflowStage.assembly) {
      return false;
    }

    final workflow = AssemblyWorkflowStatus.values;
    final currentIndex = workflow.indexOf(order.assemblyWorkflowStatus);
    final targetIndex = workflow.indexOf(targetStatus);
    if (currentIndex == -1 || targetIndex == -1) {
      return false;
    }

    return targetIndex == currentIndex + 1;
  }

  Future<void> _moveAssemblyOrderToKanbanColumn(
    WorkflowOrder order,
    AssemblyWorkflowStatus targetStatus,
  ) async {
    if (!_canMoveAssemblyOrderToTarget(order, targetStatus)) {
      return;
    }

    if (targetStatus == AssemblyWorkflowStatus.released) {
      final checklistCompleted = await _reviewAssemblyPreparationChecklist(
        order: order,
        requireCompletion: true,
      );
      if (!checklistCompleted) {
        _showAppMessage(
          'Conclua o checklist da montagem antes de liberar o pedido.',
          isError: true,
        );
        return;
      }
      await _updateAssemblyWorkflowStatus(
        AssemblyWorkflowStatus.released,
        order: order,
      );
      return;
    }

    if (targetStatus == AssemblyWorkflowStatus.doing) {
      final assignedEmployeeEmails = await _pickAssemblyEmployees(order);
      if (assignedEmployeeEmails == null || assignedEmployeeEmails.isEmpty) {
        return;
      }
      await _updateAssemblyWorkflowStatus(
        AssemblyWorkflowStatus.doing,
        order: order,
        assignedEmployeeEmails: assignedEmployeeEmails,
      );
      return;
    }

    if (targetStatus == AssemblyWorkflowStatus.panelTesting) {
      final checklistCompleted = await _reviewAssemblyExecutionChecklist(
        order: order,
        requireCompletion: true,
      );
      if (!checklistCompleted) {
        _showAppMessage(
          'Conclua o checklist de execução antes de enviar para teste.',
          isError: true,
        );
        return;
      }
      await _updateAssemblyWorkflowStatus(
        AssemblyWorkflowStatus.panelTesting,
        order: order,
      );
      return;
    }

    if (targetStatus == AssemblyWorkflowStatus.done) {
      await _updateAssemblyWorkflowStatus(
        AssemblyWorkflowStatus.done,
        order: order,
      );
    }
  }

  bool _canMoveInstallationOrderToTarget(
    WorkflowOrder order,
    InstallationWorkflowStatus targetStatus,
  ) {
    if (order.currentStage != WorkflowStage.installation) {
      return false;
    }

    return targetStatus == InstallationWorkflowStatus.done &&
        order.installationWorkflowStatus != InstallationWorkflowStatus.done;
  }

  Future<void> _moveInstallationOrderToKanbanColumn(
    WorkflowOrder order,
    InstallationWorkflowStatus targetStatus,
  ) async {
    if (!_canMoveInstallationOrderToTarget(order, targetStatus)) {
      return;
    }

    if (targetStatus == InstallationWorkflowStatus.done) {
      await _completeInstallation(order: order, force: true);
    }
  }

  Future<void> _attachContractToSelectedOrder() async {
    await _attachFileToSelectedOrder(
      logAction: 'Anexou contrato',
      logArea: 'Financeiro',
      onUpdate: (selected, file) {
        final now = DateTime.now();
        final updatedStatuses =
            Map<String, EngineeringChecklistStatus>.from(
                selected.financeContractStatuses,
              )
              ..['waiting'] = EngineeringChecklistStatus.done
              ..['generate_contract'] = EngineeringChecklistStatus.done;
        final flowSnapshot = _financeContractFlowSnapshotFromStatuses(
          updatedStatuses,
        );
        return selected.copyWith(
          contractFileName: file.name,
          contractFilePath: file.path,
          financeContractStatuses: updatedStatuses,
          progress: _effectiveOrderProgress(
            selected.copyWith(financeContractStatuses: updatedStatuses),
          ),
          nextAction:
              flowSnapshot.currentTask?.label ?? 'Contrato pronto para seguir',
          blocker: flowSnapshot.isComplete
              ? 'Sem bloqueio. Fluxo de contrato concluído no Financeiro.'
              : 'Kanban do contrato em ${flowSnapshot.currentTask!.label}.',
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.finance] =
                'Contrato anexado em ${_formatDateTime(now)}',
        );
      },
    );
  }

  Future<void> _attachServiceOrderPdfToSelectedOrder() async {
    await _attachFileToSelectedOrder(
      allowedExtensions: const ['pdf'],
      busyMessage: 'Enviando PDF da ordem de serviço...',
      successMessage: 'PDF da ordem de serviço salvo no Firebase.',
      errorPrefix: 'Não foi possível salvar o PDF da ordem de serviço',
      logAction: 'Anexou PDF da ordem de serviço',
      logArea: 'Orçamentista',
      onUpdate: (selected, file) {
        final now = DateTime.now();
        return selected.copyWith(
          serviceOrderFileName: file.name,
          serviceOrderFilePath: file.path,
          nextAction: 'Aguardar aprovação do cliente no Financeiro',
          history: Map<WorkflowStage, String>.from(selected.history)
            ..[WorkflowStage.estimating] =
                'PDF da ordem de serviço anexado em ${_formatDateTime(now)}',
        );
      },
    );
  }

  Future<void> _toggleFinanceClientApprovalForSelectedOrder() async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    final approved = !selected.financeClientApproved;
    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final targetStage = approved
        ? WorkflowStage.relationship
        : selected.currentStage;
    final actorEmail = (_currentUserEmail ?? _currentWorkspaceProfile.email)
        .trim()
        .toLowerCase();
    final relationshipMentionEmails = approved
        ? _workspaceProfiles
              .where(
                (profile) =>
                    profile.allowedStages.contains(WorkflowStage.relationship),
              )
              .map((profile) => profile.email.trim().toLowerCase())
              .where((email) => email.isNotEmpty && email != actorEmail)
              .toSet()
              .toList(growable: false)
        : const <String>[];
    final approvalNotification = approved
        ? OrderConversationMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            authorEmail: actorEmail,
            authorName: actorLabel.isEmpty ? 'Sistema' : actorLabel,
            message: 'Ordem de serviço aprovada.',
            createdAt: now,
            mentionedUserEmails: relationshipMentionEmails,
            readByUserEmails: actorEmail.isEmpty ? const [] : [actorEmail],
          )
        : null;
    final updatedHistory = Map<WorkflowStage, String>.from(selected.history)
      ..[WorkflowStage.finance] = approved
          ? 'Cliente aprovado no Financeiro em ${_formatDateTime(now)}'
          : 'Aprovação do cliente removida em ${_formatDateTime(now)}';
    if (approved) {
      updatedHistory[WorkflowStage.relationship] =
          'Retornou do Financeiro em ${_formatDateTime(now)}';
    }
    final updatedOrder = selected.copyWith(
      currentStage: targetStage,
      financeClientApproved: approved,
      serviceOrderFinanceStatus: approved
          ? ServiceOrderFinanceStatus.approved
          : ServiceOrderFinanceStatus.waitingApproval,
      nextAction: approved
          ? 'Retornar ao Relacionamento para encaminhamento'
          : 'Aguardar aprovação do cliente',
      blocker: approved
          ? _serviceOrderFinanceBlocker(
              selected.copyWith(
                financeClientApproved: true,
                serviceOrderFinanceStatus: ServiceOrderFinanceStatus.approved,
              ),
            )
          : 'Aguardando confirmação do cliente no Financeiro.',
      owner: approved ? actorLabel : selected.owner,
      stageOwners: approved
          ? _updatedStageOwnersForAction(
              selected,
              WorkflowStage.finance,
              actorLabel,
            )
          : selected.stageOwners,
      progress: _effectiveOrderProgress(
        selected.copyWith(
          currentStage: targetStage,
          financeClientApproved: approved,
        ),
      ),
      conversationMessages: approvalNotification == null
          ? selected.conversationMessages
          : [...selected.conversationMessages, approvalNotification],
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: approved
          ? 'Confirmando aprovação do cliente...'
          : 'Removendo aprovação do cliente...',
      successMessage: approved
          ? 'Aprovação do cliente registrada.'
          : 'Aprovação do cliente removida.',
      errorPrefix: 'Não foi possível atualizar a aprovação do cliente',
    );
    if (savedOrder == null) {
      return;
    }

    if (approved) {
      setState(() {
        _selectedViewKey = 'stage:${WorkflowStage.relationship.name}';
      });
    }
    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: approved
            ? 'Confirmou aprovação da OS'
            : 'Removeu aprovação da OS',
        area: 'Financeiro',
        details: '${savedOrder.code} • ${savedOrder.client.name}',
      ),
    );
  }

  Future<void> _updateFinanceContractStatus(
    String taskKey,
    EngineeringChecklistStatus status,
  ) async {
    final selected = _selectedOrder;
    if (selected == null || selected.currentStage != WorkflowStage.finance) {
      return;
    }

    final updatedStatuses = Map<String, EngineeringChecklistStatus>.from(
      selected.financeContractStatuses,
    );
    final taskIndex = financeContractTasks.indexWhere(
      (task) => task.key == taskKey,
    );
    if (taskIndex == -1) {
      return;
    }

    final task = financeContractTasks[taskIndex];
    if (status == EngineeringChecklistStatus.done) {
      updatedStatuses[taskKey] = EngineeringChecklistStatus.done;
    } else {
      for (
        var index = taskIndex;
        index < financeContractTasks.length;
        index++
      ) {
        updatedStatuses[financeContractTasks[index].key] =
            EngineeringChecklistStatus.notStarted;
      }
    }

    final flowSnapshot = _financeContractFlowSnapshotFromStatuses(
      updatedStatuses,
    );
    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final historyMessage = status == EngineeringChecklistStatus.done
        ? flowSnapshot.isComplete
              ? 'Kanban do contrato concluído em ${_formatDateTime(now)}'
              : '${task.label} concluída. Próxima etapa: ${flowSnapshot.currentTask!.label}'
        : '${task.label} reaberta em ${_formatDateTime(now)}';
    final nextStage = flowSnapshot.isComplete
        ? WorkflowStage.relationship
        : selected.currentStage;
    final previewOrder = selected.copyWith(
      currentStage: nextStage,
      financeContractStatuses: updatedStatuses,
    );
    final updatedHistory = Map<WorkflowStage, String>.from(selected.history)
      ..[WorkflowStage.finance] = historyMessage;
    if (flowSnapshot.isComplete) {
      updatedHistory[WorkflowStage.relationship] =
          'Recebido do Financeiro em ${_formatDateTime(now)}';
    }
    final updatedOrder = selected.copyWith(
      currentStage: nextStage,
      financeContractStatuses: updatedStatuses,
      owner: flowSnapshot.isComplete ? actorLabel : selected.owner,
      stageOwners: flowSnapshot.isComplete
          ? _updatedStageOwnersForAction(
              selected,
              WorkflowStage.finance,
              actorLabel,
            )
          : selected.stageOwners,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: flowSnapshot.isComplete
          ? _defaultNextActionForStage(WorkflowStage.relationship, previewOrder)
          : (flowSnapshot.currentTask?.label ?? 'Fluxo de contrato concluído'),
      blocker: flowSnapshot.isComplete
          ? _relationshipKanbanWorkflowBlocker(previewOrder)
          : 'Kanban do contrato em ${flowSnapshot.currentTask!.label}.',
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Atualizando kanban do contrato...',
      successMessage: 'Kanban do contrato atualizado.',
      errorPrefix: 'Não foi possível atualizar o kanban do contrato',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    if (flowSnapshot.isComplete) {
      setState(() {
        _selectedViewKey = 'stage:${WorkflowStage.relationship.name}';
        _stageWorkspaceSubtabs[WorkflowStage.relationship] = 0;
        _selectedOrderCode = savedOrder.code;
      });
    }
    unawaited(
      _appendPlatformLog(
        action: status == EngineeringChecklistStatus.done
            ? 'Avançou kanban do contrato'
            : 'Reabriu etapa do contrato',
        area: 'Financeiro',
        details:
            '${_displayOrderCode(savedOrder)} • ${task.label}${status == EngineeringChecklistStatus.done ? ' concluída' : ' reaberta'}',
      ),
    );
  }

  Future<void> _updateRelationshipKanbanStatus(
    String taskKey,
    EngineeringChecklistStatus status,
  ) async {
    final selected = _selectedOrder;
    if (selected == null ||
        selected.currentStage != WorkflowStage.relationship) {
      return;
    }

    final updatedStatuses = Map<String, EngineeringChecklistStatus>.from(
      selected.relationshipKanbanStatuses,
    );
    final taskIndex = relationshipKanbanTasks.indexWhere(
      (task) => task.key == taskKey,
    );
    if (taskIndex == -1) {
      return;
    }

    final task = relationshipKanbanTasks[taskIndex];
    if (status == EngineeringChecklistStatus.done) {
      updatedStatuses[taskKey] = EngineeringChecklistStatus.done;
    } else {
      for (
        var index = taskIndex;
        index < relationshipKanbanTasks.length;
        index++
      ) {
        updatedStatuses[relationshipKanbanTasks[index].key] =
            EngineeringChecklistStatus.notStarted;
      }
    }

    final flowSnapshot = _relationshipKanbanFlowSnapshotFromStatuses(
      updatedStatuses,
    );
    final now = DateTime.now();
    final historyMessage = status == EngineeringChecklistStatus.done
        ? flowSnapshot.isComplete
              ? 'Kanban do relacionamento concluído em ${_formatDateTime(now)}'
              : '${task.label} concluída. Próxima etapa: ${flowSnapshot.currentTask!.label}'
        : '${task.label} reaberta em ${_formatDateTime(now)}';
    final updatedOrder = selected.copyWith(
      relationshipKanbanStatuses: updatedStatuses,
      progress: _effectiveOrderProgress(
        selected.copyWith(relationshipKanbanStatuses: updatedStatuses),
      ),
      nextAction: flowSnapshot.currentTask?.label ?? 'Relacionamento concluído',
      blocker: flowSnapshot.isComplete
          ? 'Sem bloqueio. Fluxo de Relacionamento concluído.'
          : 'Kanban do relacionamento em ${flowSnapshot.currentTask!.label}.',
      history: Map<WorkflowStage, String>.from(selected.history)
        ..[WorkflowStage.relationship] = historyMessage,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Atualizando kanban do relacionamento...',
      successMessage: 'Kanban do relacionamento atualizado.',
      errorPrefix: 'Não foi possível atualizar o kanban do relacionamento',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: status == EngineeringChecklistStatus.done
            ? 'Avançou kanban do relacionamento'
            : 'Reabriu etapa do relacionamento',
        area: 'Relacionamento',
        details:
            '${_displayOrderCode(savedOrder)} • ${task.label}${status == EngineeringChecklistStatus.done ? ' concluída' : ' reaberta'}',
      ),
    );
  }

  bool _canMoveFinanceOrderToTarget(
    WorkflowOrder order,
    String? targetTaskKey,
  ) {
    if (order.currentStage != WorkflowStage.finance || order.isServiceOrder) {
      return false;
    }

    final snapshot = _financeContractFlowSnapshot(order);
    final currentTask = snapshot.currentTask;
    if (currentTask == null) {
      return false;
    }

    final currentIndex = financeContractTasks.indexWhere(
      (task) => task.key == currentTask.key,
    );
    if (currentIndex == -1) {
      return false;
    }

    if (targetTaskKey == null) {
      return currentIndex == financeContractTasks.length - 1;
    }

    final targetIndex = financeContractTasks.indexWhere(
      (task) => task.key == targetTaskKey,
    );
    if (targetIndex == -1) {
      return false;
    }

    return targetIndex == currentIndex + 1;
  }

  Future<void> _moveFinanceOrderToKanbanColumn(
    WorkflowOrder order,
    String? targetTaskKey,
  ) async {
    if (!_canMoveFinanceOrderToTarget(order, targetTaskKey)) {
      return;
    }

    final updatedStatuses = <String, EngineeringChecklistStatus>{};
    final targetIndex = targetTaskKey == null
        ? financeContractTasks.length
        : financeContractTasks.indexWhere((task) => task.key == targetTaskKey);
    for (var index = 0; index < financeContractTasks.length; index++) {
      updatedStatuses[financeContractTasks[index].key] = index < targetIndex
          ? EngineeringChecklistStatus.done
          : EngineeringChecklistStatus.notStarted;
    }

    final flowSnapshot = _financeContractFlowSnapshotFromStatuses(
      updatedStatuses,
    );
    final now = DateTime.now();
    final actorLabel = _currentOrderOwnerLabel();
    final historyMessage = flowSnapshot.isComplete
        ? 'Kanban do contrato concluído em ${_formatDateTime(now)}'
        : 'Kanban do contrato movido para ${flowSnapshot.currentTask!.label} em ${_formatDateTime(now)}';
    final nextStage = flowSnapshot.isComplete
        ? WorkflowStage.relationship
        : order.currentStage;
    final previewOrder = order.copyWith(
      currentStage: nextStage,
      financeContractStatuses: updatedStatuses,
    );
    final updatedHistory = Map<WorkflowStage, String>.from(order.history)
      ..[WorkflowStage.finance] = historyMessage;
    if (flowSnapshot.isComplete) {
      updatedHistory[WorkflowStage.relationship] =
          'Recebido do Financeiro em ${_formatDateTime(now)}';
    }
    final updatedOrder = order.copyWith(
      currentStage: nextStage,
      financeContractStatuses: updatedStatuses,
      owner: flowSnapshot.isComplete ? actorLabel : order.owner,
      stageOwners: flowSnapshot.isComplete
          ? _updatedStageOwnersForAction(
              order,
              WorkflowStage.finance,
              actorLabel,
            )
          : order.stageOwners,
      progress: _effectiveOrderProgress(previewOrder),
      nextAction: flowSnapshot.isComplete
          ? _defaultNextActionForStage(WorkflowStage.relationship, previewOrder)
          : (flowSnapshot.currentTask?.label ?? 'Fluxo de contrato concluído'),
      blocker: flowSnapshot.isComplete
          ? _relationshipKanbanWorkflowBlocker(previewOrder)
          : 'Kanban do contrato em ${flowSnapshot.currentTask!.label}.',
      history: updatedHistory,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Movendo card do Financeiro...',
      successMessage: 'Kanban do Financeiro atualizado.',
      errorPrefix: 'Não foi possível mover o card do Financeiro',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    if (_selectedOrderCode == savedOrder.code && flowSnapshot.isComplete) {
      setState(() {
        _selectedViewKey = 'stage:${WorkflowStage.relationship.name}';
        _stageWorkspaceSubtabs[WorkflowStage.relationship] = 0;
        _selectedOrderCode = savedOrder.code;
      });
    }
    unawaited(
      _appendPlatformLog(
        action: 'Moveu card no kanban do Financeiro',
        area: 'Financeiro',
        details:
            '${_displayOrderCode(savedOrder)} • ${flowSnapshot.currentTask?.label ?? 'Concluído'}',
      ),
    );
  }

  bool _canMoveRelationshipOrderToTarget(
    WorkflowOrder order,
    String targetTaskKey,
  ) {
    if (order.currentStage != WorkflowStage.relationship ||
        order.isServiceOrder) {
      return false;
    }

    final snapshot = _relationshipKanbanFlowSnapshot(order);
    final currentTask = snapshot.currentTask;
    if (currentTask == null) {
      return false;
    }

    final currentIndex = relationshipKanbanTasks.indexWhere(
      (task) => task.key == currentTask.key,
    );
    final targetIndex = relationshipKanbanTasks.indexWhere(
      (task) => task.key == targetTaskKey,
    );
    if (currentIndex == -1 || targetIndex == -1) {
      return false;
    }

    return targetIndex == currentIndex + 1;
  }

  Future<void> _moveRelationshipOrderToKanbanColumn(
    WorkflowOrder order,
    String targetTaskKey,
  ) async {
    if (!_canMoveRelationshipOrderToTarget(order, targetTaskKey)) {
      return;
    }

    final updatedStatuses = <String, EngineeringChecklistStatus>{};
    final targetIndex = relationshipKanbanTasks.indexWhere(
      (task) => task.key == targetTaskKey,
    );
    for (var index = 0; index < relationshipKanbanTasks.length; index++) {
      updatedStatuses[relationshipKanbanTasks[index].key] = index < targetIndex
          ? EngineeringChecklistStatus.done
          : EngineeringChecklistStatus.notStarted;
    }

    final flowSnapshot = _relationshipKanbanFlowSnapshotFromStatuses(
      updatedStatuses,
    );
    final now = DateTime.now();
    final historyMessage =
        'Kanban do relacionamento movido para ${flowSnapshot.currentTask!.label} em ${_formatDateTime(now)}';
    final updatedOrder = order.copyWith(
      relationshipKanbanStatuses: updatedStatuses,
      progress: _effectiveOrderProgress(
        order.copyWith(relationshipKanbanStatuses: updatedStatuses),
      ),
      nextAction: flowSnapshot.currentTask?.label ?? 'Relacionamento concluído',
      blocker: flowSnapshot.isComplete
          ? 'Sem bloqueio. Fluxo de Relacionamento concluído.'
          : 'Kanban do relacionamento em ${flowSnapshot.currentTask!.label}.',
      history: Map<WorkflowStage, String>.from(order.history)
        ..[WorkflowStage.relationship] = historyMessage,
    );

    final savedOrder = await _runBusyTask(
      () => _repository.saveOrder(updatedOrder),
      busyMessage: 'Movendo card do Relacionamento...',
      successMessage: 'Kanban do Relacionamento atualizado.',
      errorPrefix: 'Não foi possível mover o card do Relacionamento',
    );
    if (savedOrder == null) {
      return;
    }

    _mergeOrderLocally(savedOrder);
    unawaited(
      _appendPlatformLog(
        action: 'Moveu card no kanban do Relacionamento',
        area: 'Relacionamento',
        details:
            '${_displayOrderCode(savedOrder)} • ${flowSnapshot.currentTask?.label ?? 'Concluído'}',
      ),
    );
  }

  Future<void> _attachFileToSelectedOrder({
    List<String> allowedExtensions = const ['pdf', 'xls', 'xlsx'],
    String busyMessage = 'Enviando anexo...',
    String successMessage = 'Anexo salvo no Firebase.',
    String errorPrefix = 'Não foi possível salvar o anexo',
    String? logAction,
    String? logArea,
    required WorkflowOrder Function(WorkflowOrder selected, PlatformFile file)
    onUpdate,
  }) async {
    final selected = _selectedOrder;
    if (selected == null) {
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final updatedOrder = onUpdate(selected, result.files.single);
      final savedOrder = await _runBusyTask(
        () => _repository.saveOrder(updatedOrder),
        busyMessage: busyMessage,
        successMessage: successMessage,
        errorPrefix: errorPrefix,
      );
      if (savedOrder == null) {
        return;
      }

      _mergeOrderLocally(savedOrder);
      _showDriveUploadConfigurationWarningIfNeeded(savedOrder);
      if (logAction != null && logArea != null) {
        unawaited(
          _appendPlatformLog(
            action: logAction,
            area: logArea,
            details: '${savedOrder.code} • ${result.files.single.name}',
          ),
        );
      }
    } on MissingPluginException {
      _showWorkflowFilePickerUnavailableMessage();
    } catch (error) {
      final message = error.toString();
      if (message.contains('LateInitializationError') ||
          message.contains('LateError') ||
          error is UnimplementedError) {
        _showWorkflowFilePickerUnavailableMessage();
        return;
      }

      rethrow;
    }
  }

  void _showWorkflowFilePickerUnavailableMessage() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Seletor de arquivo indisponível neste ambiente. Faça um restart completo do app para carregar o plugin.',
        ),
      ),
    );
  }

  String _nextClientId() {
    var maxCode = 1000;

    for (final order in _orders) {
      final parsed = int.tryParse(order.client.id);
      if (parsed != null && parsed > maxCode) {
        maxCode = parsed;
      }
    }

    return '${maxCode + 1}';
  }

  String _primaryProposalCode(String clientId) {
    return 'OP-$clientId';
  }

  String _proposalCodeForClient(
    String clientId, {
    required int proposalVersion,
  }) {
    final baseCode = _primaryProposalCode(clientId);
    if (proposalVersion <= 1) {
      return baseCode;
    }

    return '$baseCode-P$proposalVersion';
  }

  String _nextServiceOrderCode(String clientId) {
    final baseCode = _primaryProposalCode(clientId);
    final serviceOrderPattern = RegExp(
      '^${RegExp.escape(baseCode)}-OS(\\d+)\$',
    );
    var highestSuffix = 0;

    for (final order in _orders) {
      if (order.client.id != clientId || !order.isServiceOrder) {
        continue;
      }

      if (highestSuffix == 0) {
        highestSuffix = 1;
      }

      final match = serviceOrderPattern.firstMatch(order.code.trim());
      final parsedSuffix = int.tryParse(match?.group(1) ?? '');
      if (parsedSuffix != null && parsedSuffix > highestSuffix) {
        highestSuffix = parsedSuffix;
      }
    }

    return '$baseCode-OS${highestSuffix + 1}';
  }

  bool _matchesCustomerSearch(WorkflowOrder order) {
    final query = _customerSearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    return order.client.id.toLowerCase().contains(query) ||
        order.client.name.toLowerCase().contains(query) ||
        order.workName.toLowerCase().contains(query) ||
        order.client.phone.toLowerCase().contains(query) ||
        order.client.postalCode.toLowerCase().contains(query) ||
        order.client.street.toLowerCase().contains(query) ||
        order.client.neighborhood.toLowerCase().contains(query) ||
        order.address.toLowerCase().contains(query);
  }

  String _currentOrderOwnerLabel() {
    final profile = _currentWorkspaceProfile;
    final name = profile.name.trim();
    final login = profile.login.trim();

    if (name.isEmpty && login.isEmpty) {
      return 'Cadastro';
    }

    if (name.isEmpty) {
      return login;
    }

    if (login.isEmpty) {
      return name;
    }

    return '$name (@$login)';
  }

  Map<WorkflowStage, String> _updatedStageOwnersForAction(
    WorkflowOrder order,
    WorkflowStage stage,
    String actorLabel,
  ) {
    final updatedOwners = order.resolvedStageOwners();
    final normalizedActorLabel = actorLabel.trim();

    if (normalizedActorLabel.isNotEmpty) {
      updatedOwners[stage] = normalizedActorLabel;
    }

    return updatedOwners;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !_ordersLoaded || !_profilesLoaded;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactLayout = screenWidth < 760;
    final sidebarWidth = screenWidth < 900 ? 94.0 : 104.0;

    if (!isLoading &&
        (_hasFirestorePermissionError || !_currentUserHasWorkspaceAccess)) {
      return _FirebaseAccessDeniedScreen(
        email: _currentUserEmail,
        syncError: _syncError?.toString(),
        knownProfiles: _workspaceProfiles,
        onSignOut: _signOut,
      );
    }

    final tabs = _visibleTabs;
    final selectedIndex = tabs.indexWhere(
      (tab) => tab.routeKey == _selectedViewKey,
    );
    final activeTab = selectedIndex == -1 ? tabs.first : tabs[selectedIndex];
    final content = isLoading
        ? const Center(child: CircularProgressIndicator())
        : KeyedSubtree(
            key: ValueKey(activeTab.routeKey),
            child: _buildContentForTab(activeTab),
          );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _ShellBackdrop()),
          SafeArea(
            child: isCompactLayout
                ? Column(
                    children: [
                      if (_availableSoftwareUpdate != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: _SoftwareUpdateBanner(
                            manifest: _availableSoftwareUpdate!,
                            currentVersion: erpDanfAppVersion,
                            isChecking: _isCheckingSoftwareUpdate,
                            error: _softwareUpdateError?.toString(),
                            onInstall: _installAvailableSoftwareUpdate,
                            onCheckAgain: () => _checkForSoftwareUpdate(
                              showNoUpdateMessage: true,
                            ),
                            onDismiss: () {
                              setState(() {
                                _availableSoftwareUpdate = null;
                              });
                            },
                          ),
                        ),
                      if (_syncError != null)
                        _SyncErrorBanner(error: _syncError.toString()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _FlowTopNavbar(
                          items: tabs,
                          selectedIndex: selectedIndex == -1
                              ? 0
                              : selectedIndex,
                          onSelected: _selectTab,
                          themeMode: widget.themeMode,
                          onThemeModeChanged: widget.onThemeModeChanged,
                          profile: _currentWorkspaceProfile,
                          notificationCount: _conversationNotifications.length,
                          notifications: _conversationNotifications,
                          isCheckingSoftwareUpdate: _isCheckingSoftwareUpdate,
                          onCheckSoftwareUpdate: () => _checkForSoftwareUpdate(
                            showNoUpdateMessage: true,
                          ),
                          onOpenNotification: (notification) {
                            final order = _findOrderByCode(
                              notification.orderCode,
                            );
                            if (order == null) {
                              return;
                            }
                            unawaited(
                              _openOrderDetailsScreen(
                                order,
                                openConversationOnLoad: true,
                              ),
                            );
                          },
                          onSignOut: _signOut,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: content,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: sidebarWidth,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 10, 20),
                          child: _FlowNavbar(
                            items: tabs,
                            selectedIndex: selectedIndex == -1
                                ? 0
                                : selectedIndex,
                            onSelected: _selectTab,
                            themeMode: widget.themeMode,
                            onThemeModeChanged: widget.onThemeModeChanged,
                            notificationCount:
                                _conversationNotifications.length,
                            notifications: _conversationNotifications,
                            isCheckingSoftwareUpdate: _isCheckingSoftwareUpdate,
                            onCheckSoftwareUpdate: () =>
                                _checkForSoftwareUpdate(
                                  showNoUpdateMessage: true,
                                ),
                            onOpenNotification: (notification) {
                              final order = _findOrderByCode(
                                notification.orderCode,
                              );
                              if (order == null) {
                                return;
                              }
                              unawaited(
                                _openOrderDetailsScreen(
                                  order,
                                  openConversationOnLoad: true,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 18, 22, 20),
                          child: Column(
                            children: [
                              _DesktopShellHeader(
                                title: activeTab.label,
                                profile: _currentWorkspaceProfile,
                                onSignOut: _signOut,
                                notificationCount:
                                    _conversationNotifications.length,
                                notifications: _conversationNotifications,
                                driveSyncStatus: _driveSyncStatus,
                                isCheckingSoftwareUpdate:
                                    _isCheckingSoftwareUpdate,
                                onCheckSoftwareUpdate: () =>
                                    _checkForSoftwareUpdate(
                                      showNoUpdateMessage: true,
                                    ),
                                onOpenNotification: (notification) {
                                  final order = _findOrderByCode(
                                    notification.orderCode,
                                  );
                                  if (order == null) {
                                    return;
                                  }
                                  unawaited(
                                    _openOrderDetailsScreen(
                                      order,
                                      openConversationOnLoad: true,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              if (_availableSoftwareUpdate != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _SoftwareUpdateBanner(
                                    manifest: _availableSoftwareUpdate!,
                                    currentVersion: erpDanfAppVersion,
                                    isChecking: _isCheckingSoftwareUpdate,
                                    error: _softwareUpdateError?.toString(),
                                    onInstall: _installAvailableSoftwareUpdate,
                                    onCheckAgain: () => _checkForSoftwareUpdate(
                                      showNoUpdateMessage: true,
                                    ),
                                    onDismiss: () {
                                      setState(() {
                                        _availableSoftwareUpdate = null;
                                      });
                                    },
                                  ),
                                ),
                              if (_syncError != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _SyncErrorBanner(
                                    error: _syncError.toString(),
                                  ),
                                ),
                              Expanded(child: content),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_busyMessage != null)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x660F172A),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _busyMessage!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? const Color(0xFF18191B) : const Color(0xFFF7F7F5),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? const Color(0xFF26282B).withValues(alpha: 0.34)
                    : const Color(0xFFF5F5F3),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? const Color(0xFF26282B).withValues(alpha: 0.42)
                    : const Color(0xFFF5F5F3),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: 180,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? const Color(0xFF26282B).withValues(alpha: 0.34)
                    : const Color(0xFFF5F5F3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopShellHeader extends StatelessWidget {
  const _DesktopShellHeader({
    required this.title,
    required this.profile,
    required this.onSignOut,
    required this.notificationCount,
    required this.notifications,
    required this.driveSyncStatus,
    required this.isCheckingSoftwareUpdate,
    required this.onCheckSoftwareUpdate,
    required this.onOpenNotification,
  });

  final String title;
  final EmployeeWorkspaceProfile profile;
  final VoidCallback onSignOut;
  final int notificationCount;
  final List<_OrderConversationNotification> notifications;
  final _DriveSyncStatus driveSyncStatus;
  final bool isCheckingSoftwareUpdate;
  final VoidCallback onCheckSoftwareUpdate;
  final ValueChanged<_OrderConversationNotification> onOpenNotification;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode
                        ? const Color(0xFFF2F2F0)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Painel operacional com busca rápida e acesso direto às áreas.',
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFFA3A39E)
                        : const Color(0xFF6B6B68),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                const _SoftwareVersionLabel(),
              ],
            ),
          ),
          const SizedBox(width: 18),
          const SizedBox(width: 14),
          const _HeaderDateBadge(),
          const SizedBox(width: 10),
          _DriveSyncIndicator(status: driveSyncStatus),
          const SizedBox(width: 10),
          _SoftwareUpdateCheckButton(
            isChecking: isCheckingSoftwareUpdate,
            onPressed: onCheckSoftwareUpdate,
          ),
          const SizedBox(width: 10),
          _ConversationNotificationsButton(
            notifications: notifications,
            notificationCount: notificationCount,
            onOpenNotification: onOpenNotification,
          ),
          const SizedBox(width: 10),
          _ShellProfileMenuButton(
            profile: profile,
            onSignOut: onSignOut,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

class _HeaderDateBadge extends StatefulWidget {
  const _HeaderDateBadge();

  @override
  State<_HeaderDateBadge> createState() => _HeaderDateBadgeState();
}

class _HeaderDateBadgeState extends State<_HeaderDateBadge> {
  int _secretTapCount = 0;
  DateTime? _lastSecretTapAt;

  void _handleTap() {
    final now = DateTime.now();
    if (_lastSecretTapAt == null ||
        now.difference(_lastSecretTapAt!) > const Duration(seconds: 2)) {
      _secretTapCount = 0;
    }
    _lastSecretTapAt = now;
    _secretTapCount++;
    if (_secretTapCount >= 10) {
      _secretTapCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const _SecretBlankScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF202225)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF26282B)
                : const Color(0xFFE8E8E5),
          ),
        ),
        child: Text(
          _formatDate(DateTime.now()),
          style: TextStyle(
            color: isDarkMode
                ? const Color(0xFFF2F2F0)
                : const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SoftwareVersionLabel extends StatelessWidget {
  const _SoftwareVersionLabel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDarkMode
        ? const Color(0xFFF2F2F0)
        : const Color(0xFF1A1A1A);
    final backgroundColor = isDarkMode
        ? const Color(0xFF26282B)
        : const Color(0xFFF5F5F3);
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE0E0DD);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        child: Text(
          'Versao $erpDanfAppVersion',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foregroundColor,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DriveSyncIndicator extends StatelessWidget {
  const _DriveSyncIndicator({required this.status});

  final _DriveSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = switch (status) {
      _DriveSyncStatus.synced => const Color(0xFF16A34A),
      _DriveSyncStatus.checking => const Color(0xFF2563EB),
      _DriveSyncStatus.offline => const Color(0xFFDC2626),
      _DriveSyncStatus.notConfigured => const Color(0xFFF59E0B),
    };
    final icon = switch (status) {
      _DriveSyncStatus.synced => Icons.cloud_done_outlined,
      _DriveSyncStatus.checking => Icons.sync_rounded,
      _DriveSyncStatus.offline => Icons.cloud_off_outlined,
      _DriveSyncStatus.notConfigured => Icons.cloud_queue_outlined,
    };
    final label = switch (status) {
      _DriveSyncStatus.synced => 'Drive sincronizado',
      _DriveSyncStatus.checking => 'Verificando Drive',
      _DriveSyncStatus.offline => 'Drive offline',
      _DriveSyncStatus.notConfigured => 'Drive não configurado',
    };

    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode
              ? color.withValues(alpha: 0.14)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? const Color(0xFFF2F2F0) : color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftwareUpdateCheckButton extends StatelessWidget {
  const _SoftwareUpdateCheckButton({
    required this.isChecking,
    required this.onPressed,
    this.compact = false,
  });

  final bool isChecking;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = isDarkMode
        ? const Color(0xFF93C5FD)
        : const Color(0xFF2563EB);

    return Tooltip(
      message: 'Verificar atualizacao',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isChecking ? null : onPressed,
        child: Container(
          width: compact ? 44 : 46,
          height: compact ? 44 : 46,
          decoration: BoxDecoration(
            color: isDarkMode
                ? color.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDarkMode
                  ? color.withValues(alpha: 0.28)
                  : const Color(0xFFE8E8E5),
            ),
          ),
          child: Center(
            child: isChecking
                ? SizedBox(
                    width: compact ? 17 : 18,
                    height: compact ? 17 : 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(Icons.system_update_alt_rounded, color: color),
          ),
        ),
      ),
    );
  }
}

class _OrderConversationNotification {
  const _OrderConversationNotification({
    required this.orderCode,
    required this.orderLabel,
    required this.workName,
    required this.stage,
    required this.authorName,
    required this.preview,
    required this.createdAt,
  });

  final String orderCode;
  final String orderLabel;
  final String workName;
  final WorkflowStage stage;
  final String authorName;
  final String preview;
  final DateTime createdAt;
}

class _ConversationNotificationsButton extends StatelessWidget {
  const _ConversationNotificationsButton({
    required this.notifications,
    required this.notificationCount,
    required this.onOpenNotification,
    this.compact = false,
  });

  final List<_OrderConversationNotification> notifications;
  final int notificationCount;
  final ValueChanged<_OrderConversationNotification> onOpenNotification;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final countLabel = notificationCount > 9 ? '9+' : '$notificationCount';

    return PopupMenuButton<_OrderConversationNotification>(
      tooltip: 'Mensagens',
      onSelected: onOpenNotification,
      itemBuilder: (context) {
        if (notifications.isEmpty) {
          return const [
            PopupMenuItem<_OrderConversationNotification>(
              enabled: false,
              child: Text('Nenhuma menção pendente.'),
            ),
          ];
        }

        return notifications
            .take(8)
            .map((notification) {
              return PopupMenuItem<_OrderConversationNotification>(
                value: notification,
                child: SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${notification.orderLabel} • ${notification.workName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${notification.authorName} mencionou você em ${notification.stage.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B6B68),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: compact ? 44 : 46,
            height: compact ? 44 : 46,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF202225)
                  : Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF26282B)
                    : const Color(0xFFE8E8E5),
              ),
            ),
            child: Icon(
              notificationCount > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_rounded,
            ),
          ),
          if (notificationCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  countLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShellProfileMenuButton extends StatelessWidget {
  const _ShellProfileMenuButton({
    required this.profile,
    required this.onSignOut,
    this.expanded = false,
  });

  final EmployeeWorkspaceProfile profile;
  final VoidCallback onSignOut;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final imageProvider = _resolveProfileImageProvider(profile.photoFilePath);
    final initials = profile.name.trim().isEmpty
        ? '?'
        : profile.name.trim().substring(0, 1).toUpperCase();

    return PopupMenuButton<String>(
      tooltip: 'Perfil',
      onSelected: (value) {
        if (value == 'signout') {
          onSignOut();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_outlined),
              SizedBox(width: 10),
              Text('Deslogar'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 10 : 8,
          vertical: expanded ? 8 : 8,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF202225)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF26282B)
                : const Color(0xFFE8E8E5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: profile.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: imageProvider != null
                  ? Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: profile.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: profile.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFF2F2F0)
                          : const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    profile.role,
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFA3A39E)
                          : const Color(0xFF6B6B68),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more_rounded,
                color: isDarkMode
                    ? const Color(0xFFA3A39E)
                    : const Color(0xFF6B6B68),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        'Falha ao sincronizar com o Firebase: $error',
        style: const TextStyle(
          color: Color(0xFF991B1B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SoftwareUpdateBanner extends StatelessWidget {
  const _SoftwareUpdateBanner({
    required this.manifest,
    required this.currentVersion,
    required this.isChecking,
    required this.onInstall,
    required this.onCheckAgain,
    required this.onDismiss,
    this.error,
  });

  final SoftwareUpdateManifest manifest;
  final String currentVersion;
  final bool isChecking;
  final String? error;
  final VoidCallback onInstall;
  final VoidCallback onCheckAgain;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDarkMode
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1D4ED8);
    final borderColor = isDarkMode
        ? const Color(0xFF2B4A67)
        : const Color(0xFFBFDBFE);
    final surfaceColor = isDarkMode
        ? const Color(0xFF132436)
        : const Color(0xFFEFF6FF);
    final titleColor = isDarkMode
        ? const Color(0xFFEAF2FF)
        : const Color(0xFF172554);
    final helperColor = isDarkMode
        ? const Color(0xFFC7D6EA)
        : const Color(0xFF1E3A8A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.system_update_alt_rounded, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nova versao disponivel',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instalada: $currentVersion  |  Disponivel: ${manifest.version}',
                  style: TextStyle(
                    color: helperColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (manifest.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    manifest.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: helperColor,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              IconButton(
                tooltip: 'Verificar novamente',
                onPressed: isChecking ? null : onCheckAgain,
                icon: isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              FilledButton.icon(
                onPressed: onInstall,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Atualizar'),
              ),
              IconButton(
                tooltip: 'Ocultar aviso',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FirebaseAccessDeniedScreen extends StatelessWidget {
  const _FirebaseAccessDeniedScreen({
    required this.email,
    required this.syncError,
    required this.knownProfiles,
    required this.onSignOut,
  });

  final String? email;
  final String? syncError;
  final List<EmployeeWorkspaceProfile> knownProfiles;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final allowedEmails =
        knownProfiles
            .map((profile) => profile.login)
            .toSet()
            .toList(growable: false)
          ..sort();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? const [Color(0xFF18191B), Color(0xFF202225)]
                : const [Color(0xFFF5F5F3), Color(0xFFF5F5F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF202225) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFFECACA)),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? const Color(0x66030B09)
                            : const Color(0x141E293B),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFB91C1C),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Acesso ao Firestore bloqueado',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode
                              ? const Color(0xFFF2F2F0)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        email == null || email!.isEmpty
                            ? 'Nenhum usuário interno foi encontrado na sessão autenticada.'
                            : 'O usuário interno atual é "$email". Essa sessão não conseguiu ler ou gravar os dados do projeto Firebase.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isDarkMode
                              ? const Color(0xFFA3A39E)
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          syncError ??
                              'O Firebase retornou uma negação de permissão para esta sessão.',
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Usuários liberados neste ambiente:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? const Color(0xFFF2F2F0)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allowedEmails
                            .map(
                              (value) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F3),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFE8E8E5),
                                  ),
                                ),
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? const Color(0xFFF2F2F0)
                                        : const Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Se este usuário deveria ter acesso, ajuste as regras do Firestore ou libere o perfil correspondente no projeto.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDarkMode
                              ? const Color(0xFFA3A39E)
                              : const Color(0xFF6B6B68),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sair desta conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection({
    required this.profile,
    required this.tasks,
    required this.allOrders,
    required this.onOpenTaskOrder,
  });

  final EmployeeWorkspaceProfile profile;
  final List<WorkspaceTask> tasks;
  final List<WorkflowOrder> allOrders;
  final ValueChanged<String> onOpenTaskOrder;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 900;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (profile.isAdministrator)
          _AdminSectorCompletionPanel(orders: allOrders)
        else
          _AllowedStageWorkspacePanel(
            profile: profile,
            allOrders: allOrders,
            onOpenTaskOrder: onOpenTaskOrder,
          ),
        const SizedBox(height: 22),
        if (tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: _panelDecoration(context),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: profile.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.inbox_outlined, color: profile.accent),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Nenhuma tarefa pessoal disponível para este usuário no momento.',
                    style: TextStyle(fontSize: 15, height: 1.35),
                  ),
                ),
              ],
            ),
          )
        else
          _PersonalKanbanBoard(
            tasks: tasks,
            isWide: isWide,
            onOpenTaskOrder: onOpenTaskOrder,
          ),
      ],
    );
  }
}

class _AllowedStageWorkspacePanel extends StatelessWidget {
  const _AllowedStageWorkspacePanel({
    required this.profile,
    required this.allOrders,
    required this.onOpenTaskOrder,
  });

  final EmployeeWorkspaceProfile profile;
  final List<WorkflowOrder> allOrders;
  final ValueChanged<String> onOpenTaskOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quadros permitidos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'A sua área mostra somente os quadros e tarefas liberados para o seu perfil.',
                      style: TextStyle(color: Color(0xFF6B6B68), height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _WorkspaceMetaChip(
                icon: Icons.dashboard_customize_outlined,
                label: '${profile.allowedStages.length} quadros',
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 1180
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: profile.allowedStages
                    .map(
                      (stage) => SizedBox(
                        width: cardWidth,
                        child: _StageFilterChip(
                          title: stage.title,
                          subtitle: stage.subtitle,
                          selected: true,
                          color: stage.color,
                          icon: stage.icon,
                          metadata: stage.sla,
                          onTap: () {
                            final stageOrders = allOrders.where(
                              (order) => order.currentStage == stage,
                            );
                            if (stageOrders.isNotEmpty) {
                              onOpenTaskOrder(stageOrders.first.code);
                            }
                          },
                          counter: allOrders
                              .where((item) => item.currentStage == stage)
                              .length,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _SectorCompletionViewMode { list, chart }

class _AdminSectorCompletionPanel extends StatefulWidget {
  const _AdminSectorCompletionPanel({required this.orders});

  final List<WorkflowOrder> orders;

  @override
  State<_AdminSectorCompletionPanel> createState() =>
      _AdminSectorCompletionPanelState();
}

class _AdminSectorCompletionPanelState
    extends State<_AdminSectorCompletionPanel> {
  _SectorCompletionViewMode _viewMode = _SectorCompletionViewMode.list;
  DateTimeRange? _customRange;
  final GlobalKey _dateFilterButtonKey = GlobalKey();

  Future<void> _showDateFilterPopup() async {
    final buttonBox =
        _dateFilterButtonKey.currentContext!.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        buttonBox.localToGlobal(
          Offset(0, buttonBox.size.height + 8),
          ancestor: overlayBox,
        ),
        buttonBox.localToGlobal(
          buttonBox.size.bottomRight(Offset.zero),
          ancestor: overlayBox,
        ),
      ),
      Offset.zero & overlayBox.size,
    );

    final result = await showMenu<DateTimeRange>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxWidth: 340),
      items: [
        _PopupMenuContent<DateTimeRange>(
          child: _DateFilterPopupContent(initialRange: _customRange),
        ),
      ],
    );

    if (result != null && mounted) {
      setState(() {
        _customRange = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    final now = DateTime.now();
    final customRange = _customRange;
    final allTimeStart = DateTime(2000);
    final periods = [
      _CompletionPeriod(
        title: 'Em Andamento',
        subtitle: 'Pedidos ativos por setor',
        start: allTimeStart,
        end: now,
        focus: _CompletionPeriodFocus.inProgress,
      ),
      _CompletionPeriod(
        title: 'Concluído',
        subtitle: customRange != null
            ? '${_formatDate(customRange.start)} a ${_formatDate(customRange.end)}'
            : 'Todos os períodos',
        start: customRange != null
            ? DateUtils.dateOnly(customRange.start)
            : allTimeStart,
        end: customRange != null
            ? DateUtils.dateOnly(customRange.end).add(
                const Duration(
                  hours: 23,
                  minutes: 59,
                  seconds: 59,
                  milliseconds: 999,
                ),
              )
            : now,
        focus: _CompletionPeriodFocus.completed,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conclusões por setor',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Acompanhe quantos pedidos estão em andamento e quantos foram concluídos em cada setor. Use o filtro de período para consultar conclusões em uma data específica.',
                      style: TextStyle(color: Color(0xFF6B6B68), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_SectorCompletionViewMode>(
                segments: const [
                  ButtonSegment(
                    value: _SectorCompletionViewMode.list,
                    icon: Icon(Icons.view_agenda_outlined),
                    label: Text('Lista'),
                  ),
                  ButtonSegment(
                    value: _SectorCompletionViewMode.chart,
                    icon: Icon(Icons.bar_chart_rounded),
                    label: Text('Gráfico'),
                  ),
                ],
                selected: {_viewMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() {
                    _viewMode = selection.first;
                  });
                },
              ),
              OutlinedButton.icon(
                key: _dateFilterButtonKey,
                onPressed: _showDateFilterPopup,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  customRange == null
                      ? 'Filtrar por período'
                      : '${_formatDate(customRange.start)} - ${_formatDate(customRange.end)}',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              if (customRange != null)
                IconButton(
                  tooltip: 'Remover filtro de período',
                  onPressed: () => setState(() => _customRange = null),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: const Color(0xFFB91C1C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: periods
                    .map(
                      (period) => SizedBox(
                        width: cardWidth,
                        child: _SectorCompletionChart(
                          period: period,
                          entries: _completionEntriesForPeriod(
                            orders: orders,
                            period: period,
                          ),
                          viewMode: _viewMode,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PopupMenuContent<T> extends PopupMenuEntry<T> {
  const _PopupMenuContent({required this.child});

  final Widget child;

  @override
  double get height => 0;

  @override
  bool represents(T? value) => false;

  @override
  State<_PopupMenuContent<T>> createState() => _PopupMenuContentState<T>();
}

class _PopupMenuContentState<T> extends State<_PopupMenuContent<T>> {
  @override
  Widget build(BuildContext context) => widget.child;
}

class _DateFilterPopupContent extends StatefulWidget {
  const _DateFilterPopupContent({this.initialRange});

  final DateTimeRange? initialRange;

  @override
  State<_DateFilterPopupContent> createState() =>
      _DateFilterPopupContentState();
}

class _DateFilterPopupContentState extends State<_DateFilterPopupContent> {
  late DateTime _start;
  late DateTime _end;
  bool _editingStart = true;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    final range = widget.initialRange;
    _start = range != null
        ? DateUtils.dateOnly(range.start)
        : today.subtract(const Duration(days: 6));
    _end = range != null ? DateUtils.dateOnly(range.end) : today;
  }

  void _applyRange(DateTimeRange range) {
    Navigator.pop(context, range);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final today = DateUtils.dateOnly(DateTime.now());
    final labelColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);

    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Período rápido',
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Hoje'),
                  onPressed: () =>
                      _applyRange(DateTimeRange(start: today, end: today)),
                ),
                ActionChip(
                  label: const Text('Últimos 7 dias'),
                  onPressed: () => _applyRange(
                    DateTimeRange(
                      start: today.subtract(const Duration(days: 6)),
                      end: today,
                    ),
                  ),
                ),
                ActionChip(
                  label: const Text('Este mês'),
                  onPressed: () => _applyRange(
                    DateTimeRange(
                      start: DateTime(today.year, today.month),
                      end: today,
                    ),
                  ),
                ),
                ActionChip(
                  label: const Text('Este ano'),
                  onPressed: () => _applyRange(
                    DateTimeRange(start: DateTime(today.year), end: today),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDarkMode
                  ? const Color(0xFF3E4044)
                  : const Color(0xFFE8E8E5),
            ),
            const SizedBox(height: 16),
            Text(
              'Período personalizado',
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateFilterFieldButton(
                    label: 'De',
                    date: _start,
                    selected: _editingStart,
                    onTap: () => setState(() => _editingStart = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateFilterFieldButton(
                    label: 'Até',
                    date: _end,
                    selected: !_editingStart,
                    onTap: () => setState(() => _editingStart = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: CalendarDatePicker(
                key: ValueKey(_editingStart),
                initialDate: _editingStart ? _start : _end,
                firstDate: DateTime(today.year - 5),
                lastDate: today,
                onDateChanged: (date) {
                  setState(() {
                    if (_editingStart) {
                      _start = date;
                      if (_end.isBefore(_start)) {
                        _end = _start;
                      }
                    } else {
                      _end = date;
                      if (_start.isAfter(_end)) {
                        _start = _end;
                      }
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      _applyRange(DateTimeRange(start: _start, end: _end)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterFieldButton extends StatelessWidget {
  const _DateFilterFieldButton({
    required this.label,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? const Color(0xFF0F766E)
        : isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);
    final labelColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final valueColor = isDarkMode
        ? const Color(0xFFF2F2F0)
        : const Color(0xFF1A1A1A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(date),
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CompletionPeriodFocus { inProgress, completed }

class _CompletionPeriod {
  const _CompletionPeriod({
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    this.focus = _CompletionPeriodFocus.completed,
  });

  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime end;
  final _CompletionPeriodFocus focus;
}

class _SectorCompletionEntry {
  const _SectorCompletionEntry({
    required this.stage,
    required this.count,
    required this.inProgressCount,
  });

  final WorkflowStage stage;
  final int count;
  final int inProgressCount;
}

class _SectorCompletionChart extends StatelessWidget {
  const _SectorCompletionChart({
    required this.period,
    required this.entries,
    required this.viewMode,
  });

  final _CompletionPeriod period;
  final List<_SectorCompletionEntry> entries;
  final _SectorCompletionViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.count);
    final totalInProgress = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.inProgressCount,
    );
    final maxCount = entries.fold<int>(0, (max, entry) {
      final val = period.focus == _CompletionPeriodFocus.inProgress
          ? entry.inProgressCount
          : entry.count;
      return val > max ? val : max;
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF26282B) : const Color(0xFFF5F5F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2F3134) : const Color(0xFFE8E8E5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      period.subtitle,
                      style: TextStyle(
                        color: isDarkMode
                            ? const Color(0xFFA3A39E)
                            : const Color(0xFF6B6B68),
                      ),
                    ),
                  ],
                ),
              ),
                      _StatusBadge(
                label: period.focus == _CompletionPeriodFocus.inProgress
                    ? 'Em andamento: $totalInProgress'
                    : 'Concluído: $total',
                color: period.focus == _CompletionPeriodFocus.inProgress
                    ? const Color(0xFFF97316)
                    : const Color(0xFF16A34A),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (viewMode == _SectorCompletionViewMode.chart)
            _SectorCompletionBarChart(entries: entries, focus: period.focus)
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SectorCompletionBar(
                  entry: entry,
                  maxCount: maxCount,
                  focus: period.focus,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectorCompletionBar extends StatelessWidget {
  const _SectorCompletionBar({
    required this.entry,
    required this.maxCount,
    required this.focus,
  });

  final _SectorCompletionEntry entry;
  final int maxCount;
  final _CompletionPeriodFocus focus;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isInProgress = focus == _CompletionPeriodFocus.inProgress;
    final displayCount = isInProgress ? entry.inProgressCount : entry.count;
    final value = maxCount == 0 ? 0.0 : displayCount / maxCount;
    final focusColor = isInProgress
        ? const Color(0xFFF97316)
        : const Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(entry.stage.icon, size: 16, color: isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF111827)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.stage.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _StatusBadge(
          label: isInProgress
              ? 'Em andamento: ${entry.inProgressCount}'
              : 'Concluído: ${entry.count}',
          color: focusColor,
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: isDarkMode
                ? const Color(0xFF2F3134)
                : const Color(0xFFE8E8E5),
            valueColor: AlwaysStoppedAnimation(focusColor),
          ),
        ),
      ],
    );
  }
}

class _SectorCompletionBarChart extends StatelessWidget {
  const _SectorCompletionBarChart({
    required this.entries,
    required this.focus,
  });

  final List<_SectorCompletionEntry> entries;
  final _CompletionPeriodFocus focus;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final axisTextColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final gridColor = isDarkMode
        ? const Color(0xFF2F3134)
        : const Color(0xFFE8E8E5);
    final isInProgress = focus == _CompletionPeriodFocus.inProgress;
    final focusColor = isInProgress
        ? const Color(0xFFF97316)
        : const Color(0xFF16A34A);

    final rawMax = entries.fold<int>(
      1,
      (max, entry) {
        final val = isInProgress ? entry.inProgressCount : entry.count;
        return val > max ? val : max;
      },
    );
    final maxY = (((rawMax / 4).ceil()) * 4).toDouble();
    final interval = maxY / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => isDarkMode
                      ? const Color(0xFF12372A)
                      : const Color(0xFF0F172A),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final entry = entries[group.x];
                    final label = isInProgress ? 'Em andamento' : 'Concluído';
                    return BarTooltipItem(
                      '${entry.stage.title}\n$label: ${rod.toY.round()}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      final stage = entries[index].stage;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(stage.icon, size: 18, color: isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF111827)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(color: axisTextColor, fontSize: 11),
                    ),
                  ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: gridColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(entries.length, (index) {
                final entry = entries[index];
                final barValue = isInProgress
                    ? entry.inProgressCount.toDouble()
                    : entry.count.toDouble();
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: barValue,
                      color: focusColor,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _ChartLegendItem(
              color: focusColor,
              label: isInProgress ? 'Em andamento' : 'Concluído no período',
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

List<_SectorCompletionEntry> _completionEntriesForPeriod({
  required List<WorkflowOrder> orders,
  required _CompletionPeriod period,
}) {
  return workflowStages
      .map(
        (stage) => _SectorCompletionEntry(
          stage: stage,
          count: orders
              .where(
                (order) => _wasStageCompletedInPeriod(
                  order: order,
                  stage: stage,
                  period: period,
                ),
              )
              .length,
          inProgressCount: orders
              .where((order) => order.currentStage == stage)
              .length,
        ),
      )
      .toList(growable: false);
}

bool _wasStageCompletedInPeriod({
  required WorkflowOrder order,
  required WorkflowStage stage,
  required _CompletionPeriod period,
}) {
  final completedAt = _stageCompletionDate(order, stage);
  if (completedAt == null) {
    return false;
  }

  return !completedAt.isBefore(period.start) &&
      !completedAt.isAfter(period.end);
}

DateTime? _stageCompletionDate(WorkflowOrder order, WorkflowStage stage) {
  final historyText = order.history[stage]?.trim();
  if (historyText == null || historyText.isEmpty) {
    return null;
  }

  final stageIndex = workflowStages.indexOf(stage);
  final currentStageIndex = workflowStages.indexOf(order.currentStage);
  final normalizedHistory = historyText.toLowerCase();
  final isCompleted =
      normalizedHistory.contains('conclu') ||
      currentStageIndex > stageIndex ||
      (stage == WorkflowStage.installation &&
          order.installationWorkflowStatus == InstallationWorkflowStatus.done);

  if (!isCompleted) {
    return null;
  }

  return _parseHistoryDateTime(historyText);
}

DateTime? _parseHistoryDateTime(String text) {
  final match = RegExp(
    r'(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2})',
  ).firstMatch(text);
  if (match == null) {
    return null;
  }

  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  final hour = int.tryParse(match.group(4) ?? '');
  final minute = int.tryParse(match.group(5) ?? '');
  if (day == null ||
      month == null ||
      year == null ||
      hour == null ||
      minute == null) {
    return null;
  }

  return DateTime(year, month, day, hour, minute);
}

class _WorkspaceUserDraft {
  const _WorkspaceUserDraft({
    required this.name,
    required this.login,
    required this.cellPhone,
    required this.role,
    required this.accessCode,
    required this.isAdministrator,
    required this.allowedStages,
    required this.photoFileName,
    required this.photoFilePath,
  });

  final String name;
  final String login;
  final String cellPhone;
  final String role;
  final String accessCode;
  final bool isAdministrator;
  final List<WorkflowStage> allowedStages;
  final String photoFileName;
  final String? photoFilePath;
}

class _WorkspaceUserDialog extends StatefulWidget {
  const _WorkspaceUserDialog({this.initialProfile});

  final EmployeeWorkspaceProfile? initialProfile;

  @override
  State<_WorkspaceUserDialog> createState() => _WorkspaceUserDialogState();
}

class _WorkspaceUserDialogState extends State<_WorkspaceUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _loginController = TextEditingController();
  final _cellPhoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final Set<WorkflowStage> _selectedStages = {
    WorkflowStage.customerRegistration,
  };

  bool _isAdministrator = false;
  bool _obscureAccessCode = true;
  String _photoFileName = '';
  String? _photoFilePath;

  bool get _isEditing => widget.initialProfile != null;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile == null) {
      return;
    }

    _nameController.text = profile.name;
    _loginController.text = profile.login;
    _cellPhoneController.text = profile.cellPhone;
    _roleController.text = profile.role;
    _isAdministrator = profile.isAdministrator;
    _selectedStages
      ..clear()
      ..addAll(profile.allowedStages);
    _photoFileName = profile.photoFileName;
    _photoFilePath = profile.photoFilePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _loginController.dispose();
    _cellPhoneController.dispose();
    _roleController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  void _toggleStage(WorkflowStage stage) {
    setState(() {
      if (_selectedStages.contains(stage)) {
        if (_selectedStages.length > 1) {
          _selectedStages.remove(stage);
        }
      } else {
        _selectedStages.add(stage);
      }
    });
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: false,
    );

    if (result == null) {
      return;
    }

    final file = result.files.single;
    if (file.path == null || file.path!.trim().isEmpty) {
      return;
    }

    setState(() {
      _photoFileName = file.name;
      _photoFilePath = file.path;
    });
  }

  String? _validateFullName(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Informe o nome.';
    }

    final parts = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return 'Informe nome e sobrenome.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar usuário' : 'Novo usuário interno'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogField(
                  controller: _nameController,
                  label: 'Nome do usuário',
                  validator: _validateFullName,
                ),
                const SizedBox(height: 14),
                _DialogField(
                  controller: _loginController,
                  label: 'Login interno',
                  enabled: !_isEditing,
                  validator: (value) {
                    final login = (value ?? '').trim().toLowerCase();
                    if (login.isEmpty) {
                      return 'Informe o login.';
                    }
                    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(login)) {
                      return 'Use apenas letras minúsculas, números, ponto, hífen ou underline.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _DialogField(
                  controller: _cellPhoneController,
                  label: 'Celular',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final normalized = (value ?? '').trim();
                    if (normalized.isEmpty) {
                      return 'Informe o celular.';
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
                      return 'Digite apenas números.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _DialogField(
                  controller: _roleController,
                  label: 'Função',
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Informe a função.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _accessCodeController,
                  obscureText: _obscureAccessCode,
                  decoration: InputDecoration(
                    labelText: _isEditing
                        ? 'Novo código de acesso'
                        : 'Código de acesso',
                    hintText: _isEditing
                        ? 'Deixe em branco para manter o atual'
                        : null,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureAccessCode = !_obscureAccessCode;
                        });
                      },
                      icon: Icon(
                        _obscureAccessCode
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final normalized = (value ?? '').trim();
                    if (_isEditing && normalized.isEmpty) {
                      return null;
                    }
                    if (normalized.length < 4) {
                      return 'Use pelo menos 4 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _panelDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _WorkspaceProfileAvatarPreview(
                            name: _nameController.text,
                            photoFilePath: _photoFilePath,
                            size: 62,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Foto do usuário',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _photoFileName.isEmpty
                                      ? 'Opcional. Você pode carregar uma foto para exibir no sistema.'
                                      : _photoFileName,
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B68),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.photo_camera_back_outlined),
                            label: Text(
                              _photoFilePath == null
                                  ? 'Adicionar foto'
                                  : 'Trocar foto',
                            ),
                          ),
                          if (_photoFilePath != null)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _photoFileName = '';
                                  _photoFilePath = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover foto'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  value: _isAdministrator,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Conta administradora'),
                  subtitle: const Text(
                    'Administradores recebem visão completa do fluxo e acesso ao painel de gestão.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _isAdministrator = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Quadros liberados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isAdministrator
                      ? 'Como esta conta é administradora, todos os quadros serão liberados automaticamente.'
                      : 'Selecione os quadros que este usuário poderá acessar.',
                  style: const TextStyle(color: Color(0xFF6B6B68), height: 1.4),
                ),
                const SizedBox(height: 14),
                if (_isAdministrator)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: workspaceStages
                        .map(
                          (stage) => _StatusBadge(
                            label: stage.title,
                            color: stage.color,
                          ),
                        )
                        .toList(growable: false),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: workspaceStages
                        .map(
                          (stage) => FilterChip(
                            selected: _selectedStages.contains(stage),
                            onSelected: (_) => _toggleStage(stage),
                            label: Text(stage.title),
                            avatar: Icon(
                              stage.icon,
                              size: 18,
                              color: stage.color,
                            ),
                            selectedColor: stage.color.withValues(alpha: 0.14),
                            checkmarkColor: stage.color,
                            side: BorderSide(
                              color: _selectedStages.contains(stage)
                                  ? stage.color
                                  : const Color(0xFFE0E0DD),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            if (!_isAdministrator && _selectedStages.isEmpty) {
              return;
            }

            Navigator.of(context).pop(
              _WorkspaceUserDraft(
                name: _nameController.text.trim(),
                login: _loginController.text.trim().toLowerCase(),
                cellPhone: _cellPhoneController.text.trim(),
                role: _roleController.text.trim(),
                accessCode: _accessCodeController.text.trim(),
                isAdministrator: _isAdministrator,
                allowedStages: _selectedStages.toList(growable: false),
                photoFileName: _photoFileName,
                photoFilePath: _photoFilePath,
              ),
            );
          },
          child: Text(_isEditing ? 'Salvar alterações' : 'Criar usuário'),
        ),
      ],
    );
  }
}

class _WorkspaceProfileAvatarPreview extends StatelessWidget {
  const _WorkspaceProfileAvatarPreview({
    required this.name,
    required this.photoFilePath,
    required this.size,
  });

  final String name;
  final String? photoFilePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveProfileImageProvider(photoFilePath);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF12372A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: imageProvider != null
          ? Image(
              image: imageProvider,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallback(),
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    final text = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF12372A),
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdminAccessSection extends StatelessWidget {
  const _AdminAccessSection({
    required this.currentProfile,
    required this.profiles,
    required this.selectedProfile,
    required this.onSelectProfile,
    required this.onCreateProfile,
    required this.onEditProfile,
    required this.currentUserEmail,
    required this.onDeleteProfile,
    required this.onToggleStage,
  });

  final EmployeeWorkspaceProfile currentProfile;
  final List<EmployeeWorkspaceProfile> profiles;
  final EmployeeWorkspaceProfile? selectedProfile;
  final ValueChanged<String> onSelectProfile;
  final Future<void> Function() onCreateProfile;
  final Future<void> Function(EmployeeWorkspaceProfile profile) onEditProfile;
  final String currentUserEmail;
  final Future<void> Function(EmployeeWorkspaceProfile profile) onDeleteProfile;
  final Future<void> Function(String email, WorkflowStage stage) onToggleStage;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    final managedProfile = selectedProfile;
    final administratorCount = profiles
        .where((profile) => profile.isAdministrator)
        .length;
    final operationalCount = profiles.length - administratorCount;
    final totalGrantedStages = profiles.fold<int>(
      0,
      (total, profile) => total + profile.allowedStages.length,
    );
    final fullyReleasedCount = profiles
        .where(
          (profile) => profile.allowedStages.length == workspaceStages.length,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B1220), Color(0xFF12372A), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3306120F),
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSideCard = constraints.maxWidth >= 840;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSideCard)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _AdminHeroContent(
                            currentProfile: currentProfile,
                            profiles: profiles,
                            selectedProfile: managedProfile,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 4,
                          child: _AdminHeroHighlightCard(
                            selectedProfile: managedProfile,
                            fullyReleasedCount: fullyReleasedCount,
                            operationalCount: operationalCount,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _AdminHeroContent(
                      currentProfile: currentProfile,
                      profiles: profiles,
                      selectedProfile: managedProfile,
                    ),
                    const SizedBox(height: 18),
                    _AdminHeroHighlightCard(
                      selectedProfile: managedProfile,
                      fullyReleasedCount: fullyReleasedCount,
                      operationalCount: operationalCount,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _AdminSummaryPill(
                        label: 'Usuários gerenciados',
                        value: profiles.length.toString(),
                        icon: Icons.groups_2_outlined,
                      ),
                      _AdminSummaryPill(
                        label: 'Administradores',
                        value: administratorCount.toString(),
                        icon: Icons.admin_panel_settings_outlined,
                      ),
                      _AdminSummaryPill(
                        label: 'Liberações ativas',
                        value: totalGrantedStages.toString(),
                        icon: Icons.visibility_outlined,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _AdminUserListPanel(
                  profiles: profiles,
                  selectedEmail: managedProfile?.email,
                  onSelectProfile: onSelectProfile,
                  onCreateProfile: onCreateProfile,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: _AdminPermissionsPanel(
                  profile: managedProfile,
                  canDeleteProfile:
                      managedProfile != null &&
                      managedProfile.email != currentUserEmail,
                  onEditProfile: onEditProfile,
                  onDeleteProfile: onDeleteProfile,
                  onToggleStage: onToggleStage,
                ),
              ),
            ],
          )
        else ...[
          _AdminUserListPanel(
            profiles: profiles,
            selectedEmail: managedProfile?.email,
            onSelectProfile: onSelectProfile,
            onCreateProfile: onCreateProfile,
          ),
          const SizedBox(height: 18),
          _AdminPermissionsPanel(
            profile: managedProfile,
            canDeleteProfile:
                managedProfile != null &&
                managedProfile.email != currentUserEmail,
            onEditProfile: onEditProfile,
            onDeleteProfile: onDeleteProfile,
            onToggleStage: onToggleStage,
          ),
        ],
      ],
    );
  }
}

class _AdminHeroContent extends StatelessWidget {
  const _AdminHeroContent({
    required this.currentProfile,
    required this.profiles,
    required this.selectedProfile,
  });

  final EmployeeWorkspaceProfile currentProfile;
  final List<EmployeeWorkspaceProfile> profiles;
  final EmployeeWorkspaceProfile? selectedProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _AdminProfileAvatar(profile: currentProfile, large: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Text(
                      'Administração de usuários',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    currentProfile.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Organize o acesso de cada colaborador por setor e publique a liberação em tempo real no Firebase.',
          style: TextStyle(
            color: Color(0xFFE8E8E5),
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatusBadge(
              label: '${profiles.length} perfis conectados',
              color: Colors.white,
            ),
            _StatusBadge(
              label: selectedProfile == null
                  ? 'Selecione um usuário para editar'
                  : 'Editando ${selectedProfile!.name}',
              color: const Color(0xFF93C5FD),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminHeroHighlightCard extends StatelessWidget {
  const _AdminHeroHighlightCard({
    required this.selectedProfile,
    required this.fullyReleasedCount,
    required this.operationalCount,
  });

  final EmployeeWorkspaceProfile? selectedProfile;
  final int fullyReleasedCount;
  final int operationalCount;

  @override
  Widget build(BuildContext context) {
    final profile = selectedProfile;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on_outlined, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Painel instantâneo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            profile == null
                ? 'As permissões de visualização são publicadas assim que você altera os setores.'
                : '${profile.name} está com ${profile.allowedStages.length} de ${workspaceStages.length} setores liberados.',
            style: const TextStyle(color: Color(0xFFE8E8E5), height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AdminHighlightMetric(
                  label: 'Perfis completos',
                  value: fullyReleasedCount.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminHighlightMetric(
                  label: 'Operacionais',
                  value: operationalCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminHighlightMetric extends StatelessWidget {
  const _AdminHighlightMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFFE8E8E5))),
        ],
      ),
    );
  }
}

class _AdminUserListPanel extends StatelessWidget {
  const _AdminUserListPanel({
    required this.profiles,
    required this.selectedEmail,
    required this.onSelectProfile,
    required this.onCreateProfile,
  });

  final List<EmployeeWorkspaceProfile> profiles;
  final String? selectedEmail;
  final ValueChanged<String> onSelectProfile;
  final Future<void> Function() onCreateProfile;

  @override
  Widget build(BuildContext context) {
    final sortedProfiles = [...profiles]
      ..sort((left, right) {
        final adminPriority =
            (right.isAdministrator ? 1 : 0) - (left.isAdministrator ? 1 : 0);
        if (adminPriority != 0) {
          return adminPriority;
        }

        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    final selectedProfile = profiles
        .where((profile) => profile.email == selectedEmail)
        .firstOrNull;
    final administrators = profiles
        .where((profile) => profile.isAdministrator)
        .length;
    final operators = profiles.length - administrators;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipe e acessos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Selecione um perfil para revisar o escopo liberado por setor.',
                      style: TextStyle(color: Color(0xFF6B6B68)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCreateProfile,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Novo usuário'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _AdminCompactInfoCard(
                  label: 'Administradores',
                  value: administrators.toString(),
                  accent: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminCompactInfoCard(
                  label: 'Operacionais',
                  value: operators.toString(),
                  accent: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (selectedProfile != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    selectedProfile.accent.withValues(alpha: 0.16),
                    selectedProfile.accent.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selectedProfile.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  _AdminProfileAvatar(profile: selectedProfile, large: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedProfile.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (selectedProfile.cellPhone.trim().isNotEmpty)
                          Text(
                            selectedProfile.cellPhone,
                            style: const TextStyle(color: Color(0xFF6B6B68)),
                          ),
                        if (selectedProfile.cellPhone.trim().isNotEmpty)
                          const SizedBox(height: 4),
                        Text(
                          '${selectedProfile.allowedStages.length} setores liberados no momento',
                          style: const TextStyle(color: Color(0xFF6B6B68)),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value:
                                selectedProfile.allowedStages.length /
                                workspaceStages.length,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.55,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              selectedProfile.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (selectedProfile != null) const SizedBox(height: 16),
          ...sortedProfiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onSelectProfile(profile.email),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: selectedEmail == profile.email
                        ? LinearGradient(
                            colors: [
                              profile.accent.withValues(alpha: 0.14),
                              profile.accent.withValues(alpha: 0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: selectedEmail == profile.email
                        ? null
                        : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1C1D20)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selectedEmail == profile.email
                          ? profile.accent
                          : const Color(0xFFE8E8E5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _AdminProfileAvatar(profile: profile),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${profile.login}',
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B68),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedEmail == profile.email)
                            Icon(
                              Icons.check_circle_rounded,
                              color: profile.accent,
                            )
                          else
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value:
                              profile.allowedStages.length /
                              workspaceStages.length,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF26282B)
                              : const Color(0xFFE8E8E5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            profile.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusBadge(
                            label: profile.isAdministrator
                                ? 'Administrador'
                                : 'Usuário',
                            color: profile.isAdministrator
                                ? const Color(0xFF0F172A)
                                : profile.accent,
                          ),
                          _StatusBadge(
                            label:
                                '${profile.allowedStages.length}/${workspaceStages.length} setores',
                            color: profile.accent,
                          ),
                          _StatusBadge(
                            label: profile.role,
                            color: const Color(0xFF475569),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPermissionsPanel extends StatelessWidget {
  const _AdminPermissionsPanel({
    required this.profile,
    required this.canDeleteProfile,
    required this.onEditProfile,
    required this.onDeleteProfile,
    required this.onToggleStage,
  });

  final EmployeeWorkspaceProfile? profile;
  final bool canDeleteProfile;
  final Future<void> Function(EmployeeWorkspaceProfile profile) onEditProfile;
  final Future<void> Function(EmployeeWorkspaceProfile profile) onDeleteProfile;
  final Future<void> Function(String email, WorkflowStage stage) onToggleStage;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _panelDecoration(context),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissões por setor',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'Selecione um usuário para editar as permissões e publicar a liberação imediatamente no Firebase.',
              style: TextStyle(color: Color(0xFF6B6B68), height: 1.45),
            ),
          ],
        ),
      );
    }

    final managedProfile = profile!;
    final releasedStageCount = managedProfile.isAdministrator
        ? workspaceStages.length
        : managedProfile.allowedStages.length;
    final blockedStageCount = workspaceStages.length - releasedStageCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminProfileAvatar(profile: managedProfile, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      managedProfile.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      managedProfile.cellPhone.trim().isEmpty
                          ? '${managedProfile.role}  •  @${managedProfile.login}'
                          : '${managedProfile.role}  •  ${managedProfile.cellPhone}  •  @${managedProfile.login}',
                      style: const TextStyle(color: Color(0xFF6B6B68)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusBadge(
                          label: managedProfile.isAdministrator
                              ? 'Conta administradora'
                              : 'Perfil operacional',
                          color: managedProfile.isAdministrator
                              ? const Color(0xFF0F172A)
                              : managedProfile.accent,
                        ),
                        _StatusBadge(
                          label: '@${managedProfile.login}',
                          color: const Color(0xFF475569),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () async {
                  await onEditProfile(managedProfile);
                },
                tooltip: 'Editar usuário',
                icon: const Icon(Icons.edit_outlined),
              ),
              const SizedBox(width: 8),
              if (canDeleteProfile)
                IconButton.filledTonal(
                  onPressed: () async {
                    await onDeleteProfile(managedProfile);
                  },
                  tooltip: 'Excluir usuário',
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1D20)
                  : const Color(0xFFF5F5F3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3E4044)
                    : const Color(0xFFE8E8E5),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF0F766E)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A conta administradora centraliza a gestão do sistema. Nesta tela você define apenas o que cada usuário pode visualizar e a alteração entra em vigor imediatamente.',
                    style: TextStyle(color: Color(0xFF6B6B68), height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              final cardWidth = isCompact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 28) / 3;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _AdminStatCard(
                      label: 'Setores liberados',
                      value: releasedStageCount.toString(),
                      accent: managedProfile.accent,
                      icon: Icons.visibility_outlined,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _AdminStatCard(
                      label: 'Setores bloqueados',
                      value: blockedStageCount.toString(),
                      accent: const Color(0xFFB45309),
                      icon: Icons.visibility_off_outlined,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _AdminStatCard(
                      label: 'Perfil',
                      value: managedProfile.isAdministrator ? 'ADM' : 'USER',
                      accent: const Color(0xFF0F766E),
                      icon: Icons.badge_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'Setores e quadros visíveis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ative ou desative cada setor para publicar a liberação imediatamente no Firebase.',
            style: TextStyle(color: Color(0xFF6B6B68)),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useGrid = constraints.maxWidth >= 860;
              final cardWidth = useGrid
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: workspaceStages
                    .map(
                      (stage) => SizedBox(
                        width: cardWidth,
                        child: _AdminStagePermissionCard(
                          stage: stage,
                          selected: managedProfile.allowedStages.contains(
                            stage,
                          ),
                          onToggle: () async {
                            await onToggleStage(managedProfile.email, stage);
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminSummaryPill extends StatelessWidget {
  const _AdminSummaryPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminProfileAvatar extends StatelessWidget {
  const _AdminProfileAvatar({required this.profile, this.large = false});

  final EmployeeWorkspaceProfile profile;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 54.0 : 42.0;
    final text = profile.name.trim().isEmpty
        ? '?'
        : profile.name.trim().substring(0, 1).toUpperCase();
    final imageProvider = _resolveProfileImageProvider(profile.photoFilePath);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: profile.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(large ? 18 : 14),
        border: Border.all(color: profile.accent.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageProvider != null
          ? Image(
              image: imageProvider,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallback(text),
            )
          : _buildFallback(text),
    );
  }

  Widget _buildFallback(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: profile.accent,
          fontSize: large ? 22 : 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6B6B68), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _AdminStagePermissionCard extends StatelessWidget {
  const _AdminStagePermissionCard({
    required this.stage,
    required this.selected,
    required this.onToggle,
  });

  final WorkflowStage stage;
  final bool selected;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? stage.color.withValues(alpha: 0.35)
        : isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE0E0DD);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: selected
            ? stage.color.withValues(alpha: 0.10)
            : isDarkMode
            ? const Color(0xFF1C1D20)
            : const Color(0xFFF5F5F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: stage.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(stage.icon, color: stage.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stage.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusBadge(
                          label: selected ? 'Liberado' : 'Bloqueado',
                          color: selected
                              ? stage.color
                              : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stage.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B6B68),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? stage.color.withValues(alpha: 0.24)
                    : isDarkMode
                    ? const Color(0xFF3E4044)
                    : const Color(0xFFE8E8E5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected
                            ? 'Visualização liberada'
                            : 'Visualização bloqueada',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected
                            ? 'Este setor já está disponível para o usuário.'
                            : 'Ative para publicar a liberação imediatamente.',
                        style: const TextStyle(
                          color: Color(0xFF6B6B68),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: selected,
                  activeThumbColor: stage.color,
                  activeTrackColor: stage.color.withValues(alpha: 0.35),
                  onChanged: (_) async {
                    await onToggle();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCompactInfoCard extends StatelessWidget {
  const _AdminCompactInfoCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF6B6B68))),
        ],
      ),
    );
  }
}

class _StockItem {
  const _StockItem({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.location,
    required this.unit,
    required this.quantity,
    required this.minimumQuantity,
    required this.supplier,
    required this.notes,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String category;
  final String location;
  final String unit;
  final double quantity;
  final double minimumQuantity;
  final String supplier;
  final String notes;
  final DateTime updatedAt;

  bool get isLowStock => quantity <= minimumQuantity;
  double get stockValue => quantity;

  _StockItem copyWith({
    String? code,
    String? name,
    String? category,
    String? location,
    String? unit,
    double? quantity,
    double? minimumQuantity,
    String? supplier,
    String? notes,
    DateTime? updatedAt,
  }) {
    return _StockItem(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'category': category,
      'location': location,
      'unit': unit,
      'quantity': quantity,
      'minimumQuantity': minimumQuantity,
      'supplier': supplier,
      'notes': notes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory _StockItem.fromMap(Map<String, dynamic> map) {
    return _StockItem(
      id: (map['id'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      unit: (map['unit'] ?? 'un').toString(),
      quantity: _readStockDouble(map['quantity']),
      minimumQuantity: _readStockDouble(map['minimumQuantity']),
      supplier: (map['supplier'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      updatedAt:
          DateTime.tryParse((map['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

double _readStockDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

String _formatStockNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

class _StockWorkspaceSection extends StatefulWidget {
  const _StockWorkspaceSection({required this.repository});

  final FirebaseWorkflowRepository repository;

  @override
  State<_StockWorkspaceSection> createState() => _StockWorkspaceSectionState();
}

class _StockWorkspaceSectionState extends State<_StockWorkspaceSection> {
  final TextEditingController _searchController = TextEditingController();
  List<_StockItem> _items = const [];
  bool _showOnlyLowStock = false;
  bool _loaded = false;
  StreamSubscription<List<Map<String, dynamic>>>? _itemsSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _itemsSubscription = widget.repository.watchStockItems().listen((raw) {
      if (!mounted) {
        return;
      }
      final items = raw
          .map(_StockItem.fromMap)
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
      setState(() {
        _items = items;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _upsertItem(_StockItem item) async {
    await widget.repository.saveStockItem(item.toMap());
  }

  Future<void> _deleteItem(_StockItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover item'),
        content: Text('Remover "${item.name}" do estoque?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await widget.repository.deleteStockItem(item.id);
  }

  Future<void> _openItemDialog({_StockItem? item}) async {
    final categories =
        _items
            .map((entry) => entry.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
    final draft = await Navigator.of(context).push<_StockItem>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            _StockItemPage(initialItem: item, categories: categories),
      ),
    );
    if (draft == null) {
      return;
    }
    await _upsertItem(draft);
  }

  Future<void> _openMovementDialog(_StockItem item) async {
    final updatedItem = await showDialog<_StockItem>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StockMovementDialog(item: item),
    );
    if (updatedItem == null) {
      return;
    }
    await _upsertItem(updatedItem);
  }

  List<_StockItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    return _items
        .where((item) {
          if (_showOnlyLowStock && !item.isLowStock) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return item.code.toLowerCase().contains(query) ||
              item.name.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query) ||
              item.location.toLowerCase().contains(query) ||
              item.supplier.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final totalQuantity = _items.fold<double>(
      0,
      (total, item) => total + item.quantity,
    );
    final lowStockCount = _items.where((item) => item.isLowStock).length;
    final categoryCount = _items
        .map((item) => item.category.trim().toLowerCase())
        .where((category) => category.isNotEmpty)
        .toSet()
        .length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _CustomerRegistrationUtilityCard(
          icon: WorkflowStage.stock.icon,
          accent: WorkflowStage.stock.color,
          title: 'Estoque',
          description:
              'Cadastre itens, acompanhe saldos, defina mínimos e registre entradas ou saídas.',
          headerTrailing: FilledButton.icon(
            onPressed: () => _openItemDialog(),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Novo item'),
          ),
          child: null,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final useFourColumns = constraints.maxWidth >= 920;
            final cardWidth = useFourColumns
                ? (constraints.maxWidth - 36) / 4
                : constraints.maxWidth >= 620
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Itens cadastrados',
                    value: _items.length.toString(),
                    icon: Icons.inventory_2_outlined,
                    accent: WorkflowStage.stock.color,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Saldo total',
                    value: _formatStockNumber(totalQuantity),
                    icon: Icons.functions_outlined,
                    accent: const Color(0xFF2563EB),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Baixo estoque',
                    value: lowStockCount.toString(),
                    icon: Icons.warning_amber_outlined,
                    accent: const Color(0xFFB45309),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Categorias',
                    value: categoryCount.toString(),
                    icon: Icons.category_outlined,
                    accent: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _CustomerRegistrationUtilityCard(
          icon: Icons.manage_search_outlined,
          accent: WorkflowStage.stock.color,
          title: 'Consulta',
          description:
              'Busque por código, produto, categoria, local ou fornecedor.',
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Pesquisar no estoque',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: _showOnlyLowStock,
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar apenas baixo estoque'),
                onChanged: (value) {
                  setState(() => _showOnlyLowStock = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (!_loaded)
          const Center(child: CircularProgressIndicator())
        else if (filteredItems.isEmpty)
          _CustomerRegistrationUtilityCard(
            icon: Icons.inventory_outlined,
            accent: WorkflowStage.stock.color,
            title: 'Nenhum item encontrado',
            description: _items.isEmpty
                ? 'Cadastre o primeiro item para começar o controle de estoque.'
                : 'Ajuste a busca ou os filtros para visualizar outros itens.',
            child: _items.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => _openItemDialog(),
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Cadastrar item'),
                    ),
                  )
                : null,
          )
        else
          _StockItemsList(
            items: filteredItems,
            onEdit: (item) => _openItemDialog(item: item),
            onMove: _openMovementDialog,
            onDelete: _deleteItem,
          ),
      ],
    );
  }
}

class _StockItemsList extends StatelessWidget {
  const _StockItemsList({
    required this.items,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
  });

  final List<_StockItem> items;
  final ValueChanged<_StockItem> onEdit;
  final ValueChanged<_StockItem> onMove;
  final ValueChanged<_StockItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 860
              ? 860.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    color: WorkflowStage.stock.color.withValues(alpha: 0.06),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('Item')),
                        Expanded(flex: 2, child: Text('Categoria')),
                        Expanded(flex: 2, child: Text('Local')),
                        SizedBox(width: 92, child: Text('Saldo')),
                        SizedBox(width: 92, child: Text('Mínimo')),
                        SizedBox(width: 132, child: Text('Ações')),
                      ],
                    ),
                  ),
                  for (var index = 0; index < items.length; index++) ...[
                    _StockItemListRow(
                      item: items[index],
                      onEdit: () => onEdit(items[index]),
                      onMove: () => onMove(items[index]),
                      onDelete: () => onDelete(items[index]),
                    ),
                    if (index < items.length - 1)
                      const Divider(height: 1, color: Color(0xFFE8E8E5)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StockItemListRow extends StatelessWidget {
  const _StockItemListRow({
    required this.item,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
  });

  final _StockItem item;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = item.isLowStock
        ? const Color(0xFFB45309)
        : WorkflowStage.stock.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            item.code.isEmpty ? 'Sem código' : item.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  '${_formatStockNumber(item.quantity)} ${item.unit}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  '${_formatStockNumber(item.minimumQuantity)} ${item.unit}',
                ),
              ),
              SizedBox(
                width: 132,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onMove,
                      tooltip: 'Movimentar',
                      icon: const Icon(Icons.sync_alt_outlined),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'Remover',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockItemPage extends StatefulWidget {
  const _StockItemPage({this.initialItem, required this.categories});

  final _StockItem? initialItem;
  final List<String> categories;

  @override
  State<_StockItemPage> createState() => _StockItemPageState();
}

class _StockItemPageState extends State<_StockItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _locationController;
  late final TextEditingController _quantityController;
  late final TextEditingController _minimumController;
  late final TextEditingController _supplierController;
  late final TextEditingController _notesController;
  late String _selectedUnit;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _codeController = TextEditingController(text: item?.code ?? '');
    _nameController = TextEditingController(text: item?.name ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _locationController = TextEditingController(text: item?.location ?? '');
    _selectedUnit = switch ((item?.unit ?? 'Un').trim().toLowerCase()) {
      'cx' => 'Cx',
      _ => 'Un',
    };
    _quantityController = TextEditingController(
      text: item == null ? '0' : _formatStockNumber(item.quantity),
    );
    _minimumController = TextEditingController(
      text: item == null ? '0' : _formatStockNumber(item.minimumQuantity),
    );
    _supplierController = TextEditingController(text: item?.supplier ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    _minimumController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Campo obrigatório.' : null;
  }

  String? _number(String? value) {
    if (double.tryParse((value ?? '').trim().replaceAll(',', '.')) == null) {
      return 'Informe um número válido.';
    }
    return null;
  }

  double _parse(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    Navigator.of(context).pop(
      _StockItem(
        id: widget.initialItem?.id ?? now.microsecondsSinceEpoch.toString(),
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        location: _locationController.text.trim(),
        unit: _selectedUnit,
        quantity: _parse(_quantityController.text),
        minimumQuantity: _parse(_minimumController.text),
        supplier: _supplierController.text.trim(),
        notes: _notesController.text.trim(),
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialItem == null ? 'Novo item' : 'Editar item';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CustomerRegistrationUtilityCard(
                      icon: Icons.inventory_2_outlined,
                      accent: WorkflowStage.stock.color,
                      title: title,
                      description:
                          'Informe os dados do produto, saldo atual e parâmetros de controle.',
                      child: null,
                    ),
                    const SizedBox(height: 18),
                    _DialogField(
                      controller: _nameController,
                      label: 'Produto',
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    _DialogField(
                      controller: _codeController,
                      label: 'Código',
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useColumns = constraints.maxWidth >= 620;
                        final fieldWidth = useColumns
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: _StockCategoryField(
                                controller: _categoryController,
                                categories: widget.categories,
                                validator: _required,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _DialogField(
                                controller: _locationController,
                                label: 'Local',
                                validator: _required,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useColumns = constraints.maxWidth >= 720;
                        final fieldWidth = useColumns
                            ? (constraints.maxWidth - 24) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: _DialogField(
                                controller: _quantityController,
                                label: 'Quantidade',
                                keyboardType: TextInputType.number,
                                validator: _number,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _DialogField(
                                controller: _minimumController,
                                label: 'Mínimo',
                                keyboardType: TextInputType.number,
                                validator: _number,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Unidade',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Un',
                                    child: Text('Un'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Cx',
                                    child: Text('Cx'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() => _selectedUnit = value);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _DialogField(
                      controller: _supplierController,
                      label: 'Fornecedor',
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 12),
                    _DialogField(
                      controller: _notesController,
                      label: 'Observações',
                      validator: (_) => null,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Salvar item'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockCategoryField extends StatefulWidget {
  const _StockCategoryField({
    required this.controller,
    required this.categories,
    required this.validator,
  });

  final TextEditingController controller;
  final List<String> categories;
  final String? Function(String?) validator;

  @override
  State<_StockCategoryField> createState() => _StockCategoryFieldState();
}

class _StockCategoryFieldState extends State<_StockCategoryField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return widget.categories;
        }
        return widget.categories.where(
          (category) => category.toLowerCase().contains(query),
        );
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                hintText: 'Selecione ou crie uma categoria',
              ),
              validator: widget.validator,
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionList.length,
                itemBuilder: (context, index) {
                  final option = optionList[index];
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StockMovementDialog extends StatefulWidget {
  const _StockMovementDialog({required this.item});

  final _StockItem item;

  @override
  State<_StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<_StockMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isEntry = true;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final quantity =
        double.tryParse(_quantityController.text.trim().replaceAll(',', '.')) ??
        0;
    final nextQuantity = _isEntry
        ? widget.item.quantity + quantity
        : widget.item.quantity - quantity;
    Navigator.of(context).pop(
      widget.item.copyWith(
        quantity: nextQuantity < 0 ? 0 : nextQuantity,
        notes: _notesController.text.trim().isEmpty
            ? widget.item.notes
            : _notesController.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Movimentar ${widget.item.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.add),
                    label: Text('Entrada'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.remove),
                    label: Text('Saída'),
                  ),
                ],
                selected: {_isEntry},
                onSelectionChanged: (value) {
                  setState(() => _isEntry = value.first);
                },
              ),
              const SizedBox(height: 14),
              _DialogField(
                controller: _quantityController,
                label: 'Quantidade',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final quantity = double.tryParse(
                    (value ?? '').trim().replaceAll(',', '.'),
                  );
                  if (quantity == null || quantity <= 0) {
                    return 'Informe uma quantidade maior que zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _DialogField(
                controller: _notesController,
                label: 'Observação',
                validator: (_) => null,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}

class _StageWorkspaceSection extends StatelessWidget {
  const _StageWorkspaceSection({
    required this.stage,
    required this.currentProfile,
    required this.canDeleteOrder,
    required this.orders,
    required this.selectedOrder,
    required this.onOrderSelected,
    required this.onOpenOrderDetails,
    required this.onOpenOrderConversation,
    required this.onAdvanceOrder,
    required this.onReturnOrder,
    required this.onSendToEngineering,
    required this.onSendToAssembly,
    required this.onSendToInstallation,
    this.onAttachMaterials,
    this.onSetEstimatingWasEstimate,
    this.onAttachElectricalProject,
    this.onAttachPanelLayout,
    this.onAttachPushButtonTable,
    this.onAttachEngineeringData,
    this.onAttachConsolidatedProposal,
    this.onAttachContract,
    this.onAttachServiceOrderPdf,
    this.onToggleFinanceClientApproval,
    this.onScheduleInstallation,
    this.onToggleInstallationExecutionItem,
    this.onOpenAssemblyPreparationChecklist,
    this.onScheduleEngineeringActivity,
    this.onUpdateEngineeringChecklistStatus,
    this.onUpdateFinanceContractStatus,
    this.onUpdateRelationshipKanbanStatus,
    this.onMoveAssemblyKanbanOrder,
    this.canAcceptAssemblyKanbanDrop,
    this.onMoveEngineeringKanbanOrder,
    this.canAcceptEngineeringKanbanDrop,
    this.onMoveFinanceKanbanOrder,
    this.canAcceptFinanceKanbanDrop,
    this.onMoveRelationshipKanbanOrder,
    this.canAcceptRelationshipKanbanDrop,
    this.onMoveInstallationKanbanOrder,
    this.canAcceptInstallationKanbanDrop,
    this.onCreateServiceOrder,
    this.onCreateAdditionalProposal,
    this.onCreateOrder,
    this.onEditOrder,
    this.onDeleteOrder,
    this.customerRegistrationSubtab,
    this.onCustomerRegistrationSubtabChanged,
    this.stageWorkspaceSubtab,
    this.onStageWorkspaceSubtabChanged,
    required this.selectedOrdersView,
    required this.onOrdersViewChanged,
    required this.selectedInstallationCalendarDate,
    this.onInstallationCalendarDateChanged,
    this.customerSearchQuery = '',
    this.customerSearchController,
    this.onCustomerSearchChanged,
    this.onClearCustomerSearch,
    required this.workspaceProfiles,
    this.mergeCandidates = const [],
    this.onMergeProposal,
    this.onUnmergeProposal,
  });

  final WorkflowStage stage;
  final EmployeeWorkspaceProfile currentProfile;
  final bool canDeleteOrder;
  final List<WorkflowOrder> orders;
  final WorkflowOrder? selectedOrder;
  final ValueChanged<WorkflowOrder> onOrderSelected;
  final Future<void> Function(WorkflowOrder order) onOpenOrderDetails;
  final Future<void> Function(WorkflowOrder order) onOpenOrderConversation;
  final Future<void> Function() onAdvanceOrder;
  final Future<void> Function() onReturnOrder;
  final Future<void> Function() onSendToEngineering;
  final Future<void> Function() onSendToAssembly;
  final Future<void> Function() onSendToInstallation;
  final Future<void> Function()? onAttachMaterials;
  final Future<void> Function()? onSetEstimatingWasEstimate;
  final Future<void> Function()? onAttachElectricalProject;
  final Future<void> Function()? onAttachPanelLayout;
  final Future<void> Function()? onAttachPushButtonTable;
  final Future<void> Function()? onAttachEngineeringData;
  final Future<void> Function()? onAttachConsolidatedProposal;
  final Future<void> Function()? onAttachContract;
  final Future<void> Function()? onAttachServiceOrderPdf;
  final Future<void> Function()? onToggleFinanceClientApproval;
  final Future<void> Function()? onScheduleInstallation;
  final Future<void> Function(int visitIndex, String item)?
  onToggleInstallationExecutionItem;
  final Future<void> Function()? onOpenAssemblyPreparationChecklist;
  final Future<void> Function(String taskKey)? onScheduleEngineeringActivity;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateEngineeringChecklistStatus;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateFinanceContractStatus;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateRelationshipKanbanStatus;
  final Future<void> Function(
    WorkflowOrder order,
    AssemblyWorkflowStatus target,
  )?
  onMoveAssemblyKanbanOrder;
  final bool Function(WorkflowOrder order, AssemblyWorkflowStatus target)?
  canAcceptAssemblyKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String? targetTaskKey)?
  onMoveEngineeringKanbanOrder;
  final bool Function(WorkflowOrder order, String? targetTaskKey)?
  canAcceptEngineeringKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String? targetTaskKey)?
  onMoveFinanceKanbanOrder;
  final bool Function(WorkflowOrder order, String? targetTaskKey)?
  canAcceptFinanceKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String targetTaskKey)?
  onMoveRelationshipKanbanOrder;
  final bool Function(WorkflowOrder order, String targetTaskKey)?
  canAcceptRelationshipKanbanDrop;
  final Future<void> Function(
    WorkflowOrder order,
    InstallationWorkflowStatus target,
  )?
  onMoveInstallationKanbanOrder;
  final bool Function(WorkflowOrder order, InstallationWorkflowStatus target)?
  canAcceptInstallationKanbanDrop;
  final Future<void> Function()? onCreateServiceOrder;
  final Future<void> Function()? onCreateAdditionalProposal;
  final Future<void> Function()? onCreateOrder;
  final Future<void> Function()? onEditOrder;
  final Future<void> Function()? onDeleteOrder;
  final int? customerRegistrationSubtab;
  final ValueChanged<int>? onCustomerRegistrationSubtabChanged;
  final int? stageWorkspaceSubtab;
  final ValueChanged<int>? onStageWorkspaceSubtabChanged;
  final _StageOrdersView selectedOrdersView;
  final ValueChanged<_StageOrdersView> onOrdersViewChanged;
  final DateTime selectedInstallationCalendarDate;
  final ValueChanged<DateTime>? onInstallationCalendarDateChanged;
  final String customerSearchQuery;
  final TextEditingController? customerSearchController;
  final ValueChanged<String>? onCustomerSearchChanged;
  final VoidCallback? onClearCustomerSearch;
  final List<EmployeeWorkspaceProfile> workspaceProfiles;
  final List<WorkflowOrder> mergeCandidates;
  final Future<void> Function(WorkflowOrder secondary)? onMergeProposal;
  final Future<void> Function(WorkflowOrder secondary)? onUnmergeProposal;

  @override
  Widget build(BuildContext context) {
    final isMedium = MediaQuery.sizeOf(context).width >= 680;
    final registrationStage = WorkflowStage.customerRegistration;
    final isStandaloneWorkspaceStage = _standaloneWorkspaceStages.contains(
      stage,
    );
    final hasWorkAndCatalogSubtabs =
        !isStandaloneWorkspaceStage &&
        _workAndCatalogStages.contains(stage) &&
        stageWorkspaceSubtab != null &&
        onStageWorkspaceSubtabChanged != null;
    final isCustomerRegistration =
        stage == WorkflowStage.customerRegistration &&
        customerRegistrationSubtab != null &&
        onCustomerRegistrationSubtabChanged != null;
    final showingSharedCatalog =
        !isStandaloneWorkspaceStage &&
        !isCustomerRegistration &&
        !hasWorkAndCatalogSubtabs;
    final showingRegistrationInProgress =
        isCustomerRegistration && customerRegistrationSubtab == 0;
    final showingRegisteredClients =
        isCustomerRegistration && customerRegistrationSubtab == 1;
    final hasCalendarTab =
        stage == WorkflowStage.installation ||
        stage == WorkflowStage.engineering;
    final registeredCatalogTabIndex = hasCalendarTab ? 2 : 1;
    final showingWorkQueue =
        isStandaloneWorkspaceStage ||
        (hasWorkAndCatalogSubtabs && stageWorkspaceSubtab == 0);
    final showingInstallationCalendar =
        stage == WorkflowStage.installation &&
        hasWorkAndCatalogSubtabs &&
        stageWorkspaceSubtab == 1;
    final showingEngineeringCalendar =
        stage == WorkflowStage.engineering &&
        hasWorkAndCatalogSubtabs &&
        stageWorkspaceSubtab == 1;
    final showingStageRegisteredClients =
        hasWorkAndCatalogSubtabs &&
        stageWorkspaceSubtab == registeredCatalogTabIndex;
    final showingRegisteredCatalog =
        showingSharedCatalog ||
        showingRegisteredClients ||
        showingStageRegisteredClients;
    final registeredCatalogAccentStage = showingRegisteredCatalog
        ? registrationStage
        : stage;
    final kanbanSearchQuery = customerSearchQuery.trim().toLowerCase();
    bool matchesKanbanSearch(WorkflowOrder item) {
      if (kanbanSearchQuery.isEmpty) {
        return true;
      }

      return item.client.id.toLowerCase().contains(kanbanSearchQuery) ||
          item.client.name.toLowerCase().contains(kanbanSearchQuery) ||
          item.workName.toLowerCase().contains(kanbanSearchQuery) ||
          item.client.phone.toLowerCase().contains(kanbanSearchQuery) ||
          item.client.postalCode.toLowerCase().contains(kanbanSearchQuery) ||
          item.client.street.toLowerCase().contains(kanbanSearchQuery) ||
          item.client.neighborhood.toLowerCase().contains(kanbanSearchQuery) ||
          item.address.toLowerCase().contains(kanbanSearchQuery);
    }

    final visibleOrders = showingRegisteredCatalog
        ? orders
              .where((item) {
                if (item.currentStage == WorkflowStage.customerRegistration) {
                  return false;
                }

                final query = customerSearchQuery.trim().toLowerCase();
                if (query.isEmpty) {
                  return true;
                }

                return item.client.id.toLowerCase().contains(query) ||
                    item.client.name.toLowerCase().contains(query) ||
                    item.workName.toLowerCase().contains(query) ||
                    item.client.phone.toLowerCase().contains(query) ||
                    item.address.toLowerCase().contains(query);
              })
              .toList(growable: false)
        : showingInstallationCalendar
        ? orders
              .where((item) => item.currentStage == stage)
              .toList(growable: false)
        : showingEngineeringCalendar
        ? orders
              .where((item) => item.currentStage == stage)
              .toList(growable: false)
        : showingWorkQueue
        ? orders
              .where(
                (item) =>
                    item.currentStage == stage &&
                    matchesKanbanSearch(item) &&
                    !_isSubProposal(item),
              )
              .toList(growable: false)
        : isCustomerRegistration
        ? orders
              .where(
                (item) =>
                    item.currentStage == WorkflowStage.customerRegistration &&
                    matchesKanbanSearch(item),
              )
              .toList(growable: false)
        : orders;
    final currentProfileOwnerLabel = _workspaceProfileOwnerLabel(
      currentProfile,
    );
    final stageIndex = workflowStages.indexOf(stage);
    final currentKanbanOrders =
        showingRegistrationInProgress || showingWorkQueue
        ? visibleOrders
        : const <WorkflowOrder>[];
    final completedOrdersSource = showingRegisteredCatalog
        ? visibleOrders
        : orders
              .where((o) => matchesKanbanSearch(o) && !_isSubProposal(o))
              .toList(growable: false);
    final completedOrdersForStage = completedOrdersSource
        .where((order) {
          final orderStageIndex = workflowStages.indexOf(order.currentStage);
          return orderStageIndex > stageIndex &&
              order.ownerForStage(stage).trim().isNotEmpty;
        })
        .toList(growable: false);
    final completedOrdersByOwner = <String, List<WorkflowOrder>>{};
    for (final order in completedOrdersForStage) {
      final owner = order.ownerForStage(stage).trim();
      final ownerKey = owner.isEmpty ? 'Sem responsável' : owner;
      completedOrdersByOwner
          .putIfAbsent(ownerKey, () => <WorkflowOrder>[])
          .add(order);
    }
    final completedOwnerEntries = completedOrdersByOwner.entries.toList(
      growable: false,
    );
    final visibleCompletedOwnerEntries =
        currentProfile.isAdministrator || currentProfileOwnerLabel.isEmpty
        ? completedOwnerEntries
        : completedOwnerEntries
              .where((entry) => entry.key == currentProfileOwnerLabel)
              .toList(growable: false);
    final estimatingCompletedHistoryOrders = <WorkflowOrder>[];
    final financeCompletedHistoryOrders = <WorkflowOrder>[];
    final engineeringCompletedHistoryOrders = <WorkflowOrder>[];
    final assemblyCompletedHistoryOrders = <WorkflowOrder>[];
    final relationshipCompletedHistoryOrders = <WorkflowOrder>[];
    final financeApprovedServiceOrdersHistory = <WorkflowOrder>[];
    final relationshipServiceOrderSource = orders
        .where((order) => order.isServiceOrder && matchesKanbanSearch(order))
        .toList(growable: false);
    final installationServiceOrderSource = orders
        .where(
          (order) =>
              order.isServiceOrder &&
              matchesKanbanSearch(order) &&
              workflowStages.indexOf(order.currentStage) >=
                  workflowStages.indexOf(WorkflowStage.installation),
        )
        .toList(growable: false);
    if (stage == WorkflowStage.estimating) {
      final seenCodes = <String>{};
      for (final entry in visibleCompletedOwnerEntries) {
        for (final order in entry.value) {
          if (seenCodes.add(order.code)) {
            estimatingCompletedHistoryOrders.add(order);
          }
        }
      }
    }
    if (stage == WorkflowStage.assembly) {
      final seenCodes = <String>{};
      for (final order in currentKanbanOrders) {
        if (order.assemblyWorkflowStatus != AssemblyWorkflowStatus.done) {
          continue;
        }
        if (seenCodes.add(order.code)) {
          assemblyCompletedHistoryOrders.add(order);
        }
      }
      for (final entry in visibleCompletedOwnerEntries) {
        for (final order in entry.value) {
          if (seenCodes.add(order.code)) {
            assemblyCompletedHistoryOrders.add(order);
          }
        }
      }
    }
    if (stage == WorkflowStage.relationship) {
      final seenCodes = <String>{};
      for (final entry in visibleCompletedOwnerEntries) {
        for (final order in entry.value) {
          if (seenCodes.add(order.code)) {
            relationshipCompletedHistoryOrders.add(order);
          }
        }
      }
    }
    if (stage == WorkflowStage.engineering) {
      final seenCodes = <String>{};
      for (final entry in visibleCompletedOwnerEntries) {
        for (final order in entry.value) {
          if (!_engineeringFlowSnapshot(order).isComplete) {
            continue;
          }
          if (seenCodes.add(order.code)) {
            engineeringCompletedHistoryOrders.add(order);
          }
        }
      }
    }
    if (stage == WorkflowStage.finance) {
      final seenCodes = <String>{};
      for (final entry in visibleCompletedOwnerEntries) {
        for (final order in entry.value) {
          if (order.isServiceOrder ||
              !_financeContractFlowSnapshot(order).isComplete) {
            continue;
          }
          if (seenCodes.add(order.code)) {
            financeCompletedHistoryOrders.add(order);
          }
        }
      }
      for (final order in currentKanbanOrders) {
        if (!order.isServiceOrder || !order.financeClientApproved) {
          continue;
        }
        if (seenCodes.add(order.code)) {
          financeApprovedServiceOrdersHistory.add(order);
        }
      }
      for (final entry in visibleCompletedOwnerEntries) {
        for (final order in entry.value) {
          if (!order.isServiceOrder || !order.financeClientApproved) {
            continue;
          }
          if (seenCodes.add(order.code)) {
            financeApprovedServiceOrdersHistory.add(order);
          }
        }
      }
    }
    final financeServiceOrderKanbanColumns =
        stage == WorkflowStage.finance && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            _OrdersKanbanColumnData(
              title: 'Aguardando aprovação',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.isServiceOrder && (!order.financeClientApproved || order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.waitingApproval)).length} ordens de serviço',
              accent: const Color(0xFFB45309),
              icon: Icons.hourglass_bottom_rounded,
              emptyMessage:
                  'Nenhuma ordem de serviço aguardando aprovação no Financeiro.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.isServiceOrder &&
                        (!order.financeClientApproved ||
                            order.serviceOrderFinanceStatus ==
                                ServiceOrderFinanceStatus.waitingApproval),
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'Aprovadas',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.isServiceOrder && order.financeClientApproved && order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.approved).length} ordens de serviço',
              accent: const Color(0xFF15803D),
              icon: Icons.task_alt_rounded,
              emptyMessage: 'Nenhuma ordem de serviço aprovada no Financeiro.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.isServiceOrder &&
                        order.financeClientApproved &&
                        order.serviceOrderFinanceStatus ==
                            ServiceOrderFinanceStatus.approved,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'OS Concluída',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.isServiceOrder && order.financeClientApproved && order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.concluded).length} ordens de serviço',
              accent: const Color(0xFF2563EB),
              icon: Icons.assignment_turned_in_outlined,
              emptyMessage: 'Nenhuma ordem de serviço concluída no Financeiro.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.isServiceOrder &&
                        order.financeClientApproved &&
                        order.serviceOrderFinanceStatus ==
                            ServiceOrderFinanceStatus.concluded,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'OS Paga',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.isServiceOrder && order.financeClientApproved && order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.paid).length} ordens de serviço',
              accent: const Color(0xFF0F766E),
              icon: Icons.paid_outlined,
              emptyMessage: 'Nenhuma ordem de serviço paga no Financeiro.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.isServiceOrder &&
                        order.financeClientApproved &&
                        order.serviceOrderFinanceStatus ==
                            ServiceOrderFinanceStatus.paid,
                  )
                  .toList(growable: false),
            ),
          ]
        : const <_OrdersKanbanColumnData>[];
    final estimatingServiceOrderKanbanColumns =
        stage == WorkflowStage.estimating && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            _OrdersKanbanColumnData(
              title: 'Aguardando',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => !order.financeClientApproved && workflowStages.indexOf(order.currentStage) <= workflowStages.indexOf(WorkflowStage.finance)).length} ordens de serviço',
              accent: const Color(0xFFB45309),
              icon: Icons.assignment_outlined,
              emptyMessage:
                  'Nenhuma ordem de serviço criada aguardando aprovação.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        !order.financeClientApproved &&
                        workflowStages.indexOf(order.currentStage) <=
                            workflowStages.indexOf(WorkflowStage.finance),
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'Enviado ao Financeiro',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.currentStage == WorkflowStage.finance && order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.waitingApproval).length} ordens de serviço',
              accent: const Color(0xFF2563EB),
              icon: Icons.forward_to_inbox_outlined,
              emptyMessage: 'Nenhuma ordem de serviço enviada ao Financeiro.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.currentStage == WorkflowStage.finance &&
                        order.serviceOrderFinanceStatus ==
                            ServiceOrderFinanceStatus.waitingApproval,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'OS Realizada',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.financeClientApproved && order.currentStage == WorkflowStage.estimating && order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.approved).length} ordens de serviço',
              accent: const Color(0xFF15803D),
              icon: Icons.verified_outlined,
              emptyMessage:
                  'Nenhuma ordem de serviço em retorno da Instalação.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.financeClientApproved &&
                        order.currentStage == WorkflowStage.estimating &&
                        order.serviceOrderFinanceStatus ==
                            ServiceOrderFinanceStatus.approved,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'Concluido',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.financeClientApproved && (order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.concluded || order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.paid)).length} ordens de serviço',
              accent: const Color(0xFF2563EB),
              icon: Icons.task_alt_rounded,
              emptyMessage:
                  'Nenhuma ordem de serviço concluída no Orçamentista.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.financeClientApproved &&
                        (order.serviceOrderFinanceStatus ==
                                ServiceOrderFinanceStatus.concluded ||
                            order.serviceOrderFinanceStatus ==
                                ServiceOrderFinanceStatus.paid),
                  )
                  .toList(growable: false),
            ),
          ]
        : const <_OrdersKanbanColumnData>[];
    final relationshipServiceOrderKanbanColumns =
        stage == WorkflowStage.relationship && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            _OrdersKanbanColumnData(
              title: 'Solicitada OS',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => !order.financeClientApproved && workflowStages.indexOf(order.currentStage) <= workflowStages.indexOf(WorkflowStage.finance)).length} ordens de serviço',
              accent: const Color(0xFFB45309),
              icon: Icons.assignment_outlined,
              emptyMessage: 'Nenhuma OS criada aguardando aprovação.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        !order.financeClientApproved &&
                        workflowStages.indexOf(order.currentStage) <=
                            workflowStages.indexOf(WorkflowStage.finance),
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'OS Aprovadas',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.financeClientApproved && order.currentStage == WorkflowStage.relationship).length} ordens de serviço',
              accent: const Color(0xFF15803D),
              icon: Icons.verified_outlined,
              emptyMessage: 'Nenhuma OS aprovada no Relacionamento.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.financeClientApproved &&
                        order.currentStage == WorkflowStage.relationship,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'OS Concluídas',
              subtitle:
                  '${relationshipServiceOrderSource.where((order) => order.financeClientApproved && (workflowStages.indexOf(order.currentStage) > workflowStages.indexOf(WorkflowStage.relationship) || order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.concluded || order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.paid)).length} ordens de serviço',
              accent: const Color(0xFF2563EB),
              icon: Icons.task_alt_rounded,
              emptyMessage: 'Nenhuma OS concluída no Relacionamento.',
              orders: relationshipServiceOrderSource
                  .where(
                    (order) =>
                        order.financeClientApproved &&
                        (workflowStages.indexOf(order.currentStage) >
                                workflowStages.indexOf(
                                  WorkflowStage.relationship,
                                ) ||
                            order.serviceOrderFinanceStatus ==
                                ServiceOrderFinanceStatus.concluded ||
                            order.serviceOrderFinanceStatus ==
                                ServiceOrderFinanceStatus.paid),
                  )
                  .toList(growable: false),
            ),
          ]
        : const <_OrdersKanbanColumnData>[];
    final installationServiceOrderKanbanColumns =
        stage == WorkflowStage.installation && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            for (final status in InstallationWorkflowStatus.values)
              _OrdersKanbanColumnData(
                title: status.title,
                subtitle:
                    '${installationServiceOrderSource.where((order) => order.installationWorkflowStatus == status).length} ${status.title.toLowerCase()}',
                accent: status.color,
                icon: switch (status) {
                  InstallationWorkflowStatus.waiting =>
                    Icons.hourglass_bottom_rounded,
                  InstallationWorkflowStatus.scheduled =>
                    Icons.event_available_outlined,
                  InstallationWorkflowStatus.doing =>
                    Icons.home_repair_service_outlined,
                  InstallationWorkflowStatus.done => Icons.task_alt_rounded,
                },
                emptyMessage:
                    'Nenhuma ordem de serviço com instalação ${status.title.toLowerCase()}.',
                installationTargetStatus:
                    status == InstallationWorkflowStatus.done ? status : null,
                orders: installationServiceOrderSource
                    .where(
                      (order) => order.installationWorkflowStatus == status,
                    )
                    .toList(growable: false),
              ),
          ]
        : const <_OrdersKanbanColumnData>[];
    final kanbanColumns = stage == WorkflowStage.warehouse && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            for (final item in WorkflowStage.warehouse.checklist)
              _OrdersKanbanColumnData(
                title: item,
                subtitle: '0 produtos',
                accent: stage.color,
                icon: switch (item) {
                  'Pedir Produto' => Icons.add_shopping_cart_outlined,
                  'Consultar com fornecedor' => Icons.storefront_outlined,
                  'Aguardando aprovação do financeiro' =>
                    Icons.account_balance_wallet_outlined,
                  'Comprado' => Icons.shopping_bag_outlined,
                  _ => Icons.task_alt_rounded,
                },
                emptyMessage: 'Nenhum produto nesta etapa.',
                orders: const <WorkflowOrder>[],
              ),
          ]
        : stage == WorkflowStage.assembly && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            _OrdersKanbanColumnData(
              title: 'Aguardando',
              subtitle:
                  '${currentKanbanOrders.where((order) => order.assemblyWorkflowStatus == AssemblyWorkflowStatus.waiting).length} aguardando',
              accent: AssemblyWorkflowStatus.waiting.color,
              icon: Icons.hourglass_bottom_rounded,
              emptyMessage: 'Nenhum pedido aguardando início na montagem.',
              assemblyTargetStatus: AssemblyWorkflowStatus.waiting,
              orders: currentKanbanOrders
                  .where(
                    (order) =>
                        order.assemblyWorkflowStatus ==
                        AssemblyWorkflowStatus.waiting,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'Liberado para Montagem',
              subtitle:
                  '${currentKanbanOrders.where((order) => order.assemblyWorkflowStatus == AssemblyWorkflowStatus.released).length} liberados',
              accent: AssemblyWorkflowStatus.released.color,
              icon: Icons.move_to_inbox_outlined,
              emptyMessage: 'Nenhum pedido liberado para a montagem.',
              assemblyTargetStatus: AssemblyWorkflowStatus.released,
              orders: currentKanbanOrders
                  .where(
                    (order) =>
                        order.assemblyWorkflowStatus ==
                        AssemblyWorkflowStatus.released,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'Em andamento',
              subtitle:
                  '${currentKanbanOrders.where((order) => order.assemblyWorkflowStatus == AssemblyWorkflowStatus.doing).length} em andamento',
              accent: AssemblyWorkflowStatus.doing.color,
              icon: Icons.precision_manufacturing_outlined,
              emptyMessage: 'Nenhum pedido em produção na montagem.',
              assemblyTargetStatus: AssemblyWorkflowStatus.doing,
              orders: currentKanbanOrders
                  .where(
                    (order) =>
                        order.assemblyWorkflowStatus ==
                        AssemblyWorkflowStatus.doing,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'Teste de painel',
              subtitle:
                  '${currentKanbanOrders.where((order) => order.assemblyWorkflowStatus == AssemblyWorkflowStatus.panelTesting).length} em teste',
              accent: AssemblyWorkflowStatus.panelTesting.color,
              icon: Icons.science_outlined,
              emptyMessage: 'Nenhum painel em teste.',
              assemblyTargetStatus: AssemblyWorkflowStatus.panelTesting,
              orders: currentKanbanOrders
                  .where(
                    (order) =>
                        order.assemblyWorkflowStatus ==
                        AssemblyWorkflowStatus.panelTesting,
                  )
                  .toList(growable: false),
            ),
            _OrdersKanbanColumnData(
              title: 'Concluído',
              subtitle: '${assemblyCompletedHistoryOrders.length} no histórico',
              accent: AssemblyWorkflowStatus.done.color,
              icon: Icons.task_alt_rounded,
              emptyMessage: 'Nenhuma conclusão registrada na montagem.',
              assemblyTargetStatus: AssemblyWorkflowStatus.done,
              orders: assemblyCompletedHistoryOrders,
            ),
          ]
        : stage == WorkflowStage.installation && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            for (final status in InstallationWorkflowStatus.values)
              _OrdersKanbanColumnData(
                title: status.title,
                subtitle:
                    '${currentKanbanOrders.where((order) => !order.isServiceOrder && order.installationWorkflowStatus == status).length} ${status.title.toLowerCase()}',
                accent: status.color,
                icon: switch (status) {
                  InstallationWorkflowStatus.waiting =>
                    Icons.hourglass_bottom_rounded,
                  InstallationWorkflowStatus.scheduled =>
                    Icons.event_available_outlined,
                  InstallationWorkflowStatus.doing =>
                    Icons.home_repair_service_outlined,
                  InstallationWorkflowStatus.done => Icons.task_alt_rounded,
                },
                emptyMessage:
                    'Nenhum pedido com instalação ${status.title.toLowerCase()}.',
                installationTargetStatus:
                    status == InstallationWorkflowStatus.done ? status : null,
                orders: currentKanbanOrders
                    .where(
                      (order) =>
                          !order.isServiceOrder &&
                          order.installationWorkflowStatus == status,
                    )
                    .toList(growable: false),
              ),
          ]
        : stage == WorkflowStage.estimating && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            for (final task in estimatingKanbanTasks)
              _OrdersKanbanColumnData(
                title: task.label,
                subtitle:
                    '${currentKanbanOrders.where((order) => !order.isServiceOrder && _estimatingKanbanFlowSnapshot(order).currentTask?.key == task.key).length} clientes',
                accent: task.key == 'waiting'
                    ? const Color(0xFFB45309)
                    : WorkflowStage.estimating.color,
                icon: switch (task.key) {
                  'waiting' => Icons.hourglass_bottom_rounded,
                  'doing' => Icons.play_circle_outline_rounded,
                  _ => Icons.task_alt_outlined,
                },
                emptyMessage:
                    'Nenhum cliente aguardando ${task.label.toLowerCase()}.',
                orders: currentKanbanOrders
                    .where(
                      (order) =>
                          !order.isServiceOrder &&
                          _estimatingKanbanFlowSnapshot(
                                order,
                              ).currentTask?.key ==
                              task.key,
                    )
                    .toList(growable: false),
              ),
            _OrdersKanbanColumnData(
              title: 'Concluido',
              subtitle:
                  '${estimatingCompletedHistoryOrders.length + currentKanbanOrders.where((order) => !order.isServiceOrder && _estimatingKanbanFlowSnapshot(order).isComplete).length} no histórico',
              accent: const Color(0xFF15803D),
              icon: Icons.task_alt_rounded,
              emptyMessage: 'Nenhum cliente concluído no Orçamentista.',
              orders: [
                ...currentKanbanOrders.where(
                  (order) =>
                      !order.isServiceOrder &&
                      _estimatingKanbanFlowSnapshot(order).isComplete,
                ),
                ...estimatingCompletedHistoryOrders,
              ],
            ),
          ]
        : stage == WorkflowStage.finance && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            for (final task in financeContractTasks)
              _OrdersKanbanColumnData(
                title: task.label,
                subtitle:
                    '${currentKanbanOrders.where((order) => !order.isServiceOrder && _financeContractFlowSnapshot(order).currentTask?.key == task.key).length} clientes',
                accent: task.key == 'waiting'
                    ? const Color(0xFFB45309)
                    : WorkflowStage.finance.color,
                icon: switch (task.key) {
                  'waiting' => Icons.hourglass_bottom_rounded,
                  'generate_contract' => Icons.description_outlined,
                  'contract_sent' => Icons.send_outlined,
                  'signed_contract_received' =>
                    Icons.assignment_turned_in_outlined,
                  'registered_accounts_receivable' =>
                    Icons.account_balance_wallet_outlined,
                  _ => Icons.task_alt_outlined,
                },
                emptyMessage:
                    'Nenhum cliente aguardando ${task.label.toLowerCase()}.',
                financeTargetTaskKey: task.key,
                orders: currentKanbanOrders
                    .where(
                      (order) =>
                          !order.isServiceOrder &&
                          _financeContractFlowSnapshot(
                                order,
                              ).currentTask?.key ==
                              task.key,
                    )
                    .toList(growable: false),
              ),
            _OrdersKanbanColumnData(
              title: 'Concluído',
              subtitle:
                  '${financeCompletedHistoryOrders.length + currentKanbanOrders.where((order) => !order.isServiceOrder && _financeContractFlowSnapshot(order).isComplete).length} no histórico',
              accent: const Color(0xFF15803D),
              icon: Icons.task_alt_rounded,
              emptyMessage: 'Nenhum contrato concluído no Financeiro.',
              isFinanceCompletionTarget: true,
              orders: [
                ...currentKanbanOrders.where(
                  (order) =>
                      !order.isServiceOrder &&
                      _financeContractFlowSnapshot(order).isComplete,
                ),
                ...financeCompletedHistoryOrders,
              ],
            ),
          ]
        : stage == WorkflowStage.relationship && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            for (final task in relationshipKanbanTasks)
              _OrdersKanbanColumnData(
                title: task.label,
                subtitle:
                    '${currentKanbanOrders.where((order) => !order.isServiceOrder && _relationshipKanbanFlowSnapshot(order).currentTask?.key == task.key).length} clientes',
                accent: WorkflowStage.relationship.color,
                icon: switch (task.key) {
                  'in_progress' => Icons.play_circle_outline_rounded,
                  'create_omie_material_order' => Icons.inventory_2_outlined,
                  'update_worksheet' => Icons.table_chart_outlined,
                  'create_whatsapp_group' => Icons.groups_outlined,
                  _ => Icons.task_alt_outlined,
                },
                emptyMessage:
                    'Nenhum cliente aguardando ${task.label.toLowerCase()}.',
                relationshipTargetTaskKey: task.key,
                orders: currentKanbanOrders
                    .where(
                      (order) =>
                          !order.isServiceOrder &&
                          _relationshipKanbanFlowSnapshot(
                                order,
                              ).currentTask?.key ==
                              task.key,
                    )
                    .toList(growable: false),
              ),
            _OrdersKanbanColumnData(
              title: 'Concluido',
              subtitle:
                  '${relationshipCompletedHistoryOrders.length + currentKanbanOrders.where((order) => !order.isServiceOrder && _relationshipKanbanFlowSnapshot(order).isComplete).length} no histórico',
              accent: const Color(0xFF15803D),
              icon: Icons.task_alt_rounded,
              emptyMessage: 'Nenhum cliente concluído no Relacionamento.',
              orders: [
                ...currentKanbanOrders.where(
                  (order) =>
                      !order.isServiceOrder &&
                      _relationshipKanbanFlowSnapshot(order).isComplete,
                ),
                ...relationshipCompletedHistoryOrders,
              ],
            ),
          ]
        : stage == WorkflowStage.engineering && showingWorkQueue
        ? <_OrdersKanbanColumnData>[
            for (final task in engineeringChecklistTasks) ...[
              _OrdersKanbanColumnData(
                title: task.label,
                subtitle:
                    '${currentKanbanOrders.where((order) => !order.engineeringDependsOnClient && _engineeringFlowSnapshot(order).currentTask?.key == task.key).length} clientes',
                accent: _engineeringTaskAccent(task.key),
                icon: _engineeringTaskIcon(task.key),
                emptyMessage:
                    'Nenhum cliente aguardando ${task.label.toLowerCase()}.',
                engineeringTargetTaskKey: task.key,
                orders: currentKanbanOrders
                    .where(
                      (order) =>
                          !order.engineeringDependsOnClient &&
                          _engineeringFlowSnapshot(order).currentTask?.key ==
                              task.key,
                    )
                    .toList(growable: false),
              ),
              if (task.key == 'in_progress')
                _OrdersKanbanColumnData(
                  title: engineeringDependsOnClientTask.label,
                  subtitle:
                      '${currentKanbanOrders.where((order) => order.engineeringDependsOnClient).length} clientes',
                  accent: _engineeringTaskAccent(
                    engineeringDependsOnClientTask.key,
                  ),
                  icon: _engineeringTaskIcon(
                    engineeringDependsOnClientTask.key,
                  ),
                  emptyMessage: 'Nenhum cliente depende do cliente.',
                  engineeringTargetTaskKey: engineeringDependsOnClientTask.key,
                  orders: currentKanbanOrders
                      .where((order) => order.engineeringDependsOnClient)
                      .toList(growable: false),
                ),
            ],
            _OrdersKanbanColumnData(
              title: 'Concluído',
              subtitle:
                  '${engineeringCompletedHistoryOrders.length + currentKanbanOrders.where((order) => _engineeringFlowSnapshot(order).isComplete).length} no histórico',
              accent: const Color(0xFF10B981),
              icon: Icons.task_alt_rounded,
              emptyMessage: 'Nenhum cliente com a engenharia concluída.',
              isEngineeringCompletionTarget: true,
              orders: [
                ...currentKanbanOrders.where(
                  (order) => _engineeringFlowSnapshot(order).isComplete,
                ),
                ...engineeringCompletedHistoryOrders,
              ],
            ),
          ]
        : <_OrdersKanbanColumnData>[
            if (currentKanbanOrders.isNotEmpty || !showingRegisteredCatalog)
              _OrdersKanbanColumnData(
                title: stage.title,
                subtitle: '${currentKanbanOrders.length} em andamento',
                accent: stage.color,
                icon: stage.icon,
                emptyMessage: 'Nenhum pedido em andamento nesta etapa.',
                orders: currentKanbanOrders,
              ),
            ...visibleCompletedOwnerEntries.map(
              (entry) => _OrdersKanbanColumnData(
                title: currentProfile.isAdministrator
                    ? entry.key
                    : 'Concluídos',
                subtitle: currentProfile.isAdministrator
                    ? '${entry.value.length} concluídos'
                    : '${entry.value.length} concluídos por você',
                accent: stage.color,
                icon: Icons.task_alt_rounded,
                emptyMessage: 'Nenhum pedido concluído.',
                orders: entry.value,
              ),
            ),
          ];
    if (kanbanColumns.isEmpty) {
      kanbanColumns.add(
        _OrdersKanbanColumnData(
          title: 'Concluídos',
          subtitle: '0 concluídos',
          accent: stage.color,
          icon: Icons.task_alt_rounded,
          emptyMessage: 'Nenhum pedido concluído.',
          orders: const <WorkflowOrder>[],
        ),
      );
    }
    final topMetricCards = [
      _MetricCard(
        title: showingRegisteredCatalog
            ? 'Clientes cadastrados'
            : showingWorkQueue
            ? 'Trabalhos'
            : isCustomerRegistration
            ? 'Em andamento'
            : 'Pedidos na etapa',
        value: visibleOrders.length.toString(),
        icon: registeredCatalogAccentStage.icon,
        accent: registeredCatalogAccentStage.color,
      ),
      if (!isCustomerRegistration)
        _MetricCard(
          title: showingRegisteredCatalog
              ? 'No fluxo'
              : showingWorkQueue
              ? 'Em espera'
              : 'Com bloqueio',
          value: showingRegisteredCatalog
              ? visibleOrders.length.toString()
              : showingWorkQueue
              ? visibleOrders.length.toString()
              : visibleOrders
                    .where(
                      (item) => !item.blocker.startsWith('Nenhum bloqueio'),
                    )
                    .length
                    .toString(),
          icon: showingRegisteredCatalog
              ? Icons.sync_alt_outlined
              : showingWorkQueue
              ? Icons.pending_actions_outlined
              : Icons.report_problem_outlined,
          accent: showingWorkQueue
              ? stage.color
              : registeredCatalogAccentStage.color,
        ),
    ];
    void handleOrderTap(WorkflowOrder order) {
      unawaited(onOpenOrderDetails(order));
    }

    void handleOpenConversation(WorkflowOrder order) {
      unawaited(onOpenOrderConversation(order));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isCustomerRegistration) ...[
          _CustomerRegistrationSubtabs(
            selectedIndex: customerRegistrationSubtab!,
            onSelected: onCustomerRegistrationSubtabChanged!,
          ),
          const SizedBox(height: 16),
        ] else if (hasWorkAndCatalogSubtabs) ...[
          _StageWorkspaceSubtabs(
            selectedIndex: stageWorkspaceSubtab!,
            accentColor: stage.color,
            showCalendarTab: hasCalendarTab,
            onSelected: onStageWorkspaceSubtabChanged!,
          ),
          const SizedBox(height: 16),
        ] else if (showingSharedCatalog) ...[
          const _RegisteredClientsPreviewSubtabs(),
          const SizedBox(height: 16),
        ],
        if (stage == WorkflowStage.installation &&
            showingInstallationCalendar &&
            onInstallationCalendarDateChanged != null) ...[
          _InstallationCalendarBoard(
            orders: visibleOrders,
            selectedDate: selectedInstallationCalendarDate,
            selectedOrder: selectedOrder,
            onDateSelected: onInstallationCalendarDateChanged!,
            onOrderSelected: onOrderSelected,
            onScheduleSelectedOrder: onScheduleInstallation,
          ),
          const SizedBox(height: 20),
        ],
        if (stage == WorkflowStage.engineering &&
            showingEngineeringCalendar) ...[
          _EngineeringStageCalendarBoard(
            orders: visibleOrders,
            selectedOrder: selectedOrder,
            onOrderSelected: onOrderSelected,
          ),
          const SizedBox(height: 20),
        ],
        if (showingRegisteredCatalog ||
            showingRegistrationInProgress ||
            (showingWorkQueue && stage != WorkflowStage.warehouse)) ...[
          _CustomerRegistrationUtilityCard(
            icon: Icons.manage_search_outlined,
            accent: registeredCatalogAccentStage.color,
            title: 'Pesquisa de clientes',
            description: showingWorkQueue || showingRegistrationInProgress
                ? 'Encontre um cliente nos cards do kanban por ID, nome, obra, telefone ou endereço.'
                : 'Busque por ID do cliente, nome, obra, telefone ou endereço.',
            child: TextField(
              controller: customerSearchController,
              onChanged: onCustomerSearchChanged,
              decoration: InputDecoration(
                labelText: 'Pesquisar cliente',
                hintText: 'Ex.: 1001 ou nome do cliente',
                filled: true,
                fillColor: const Color(0xFFF5F5F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE0E0DD)),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: customerSearchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearCustomerSearch,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (stage == WorkflowStage.customerRegistration &&
            showingRegisteredCatalog) ...[
          _CustomerRegistrationUtilityCard(
            icon: Icons.post_add_outlined,
            accent: registrationStage.color,
            title: 'Nova proposta',
            description:
                'Abra a tela de nova proposta, escolha o cliente e gere uma proposta vinculada ao card principal.',
            headerTrailing: isMedium
                ? FilledButton.icon(
                    onPressed: onCreateAdditionalProposal == null
                        ? null
                        : () async {
                            await onCreateAdditionalProposal!();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: registrationStage.color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Nova proposta'),
                  )
                : null,
            child: isMedium
                ? null
                : FilledButton.icon(
                    onPressed: onCreateAdditionalProposal == null
                        ? null
                        : () async {
                            await onCreateAdditionalProposal!();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: registrationStage.color,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Nova proposta'),
                  ),
          ),
          const SizedBox(height: 20),
        ],
        if (showingRegistrationInProgress && onCreateOrder != null) ...[
          _CustomerRegistrationUtilityCard(
            icon: Icons.person_add_alt_1_outlined,
            accent: stage.color,
            title: 'Criar cadastro',
            description:
                'Cadastre a obra, telefone, endereço e os dados iniciais do cliente.',
            headerTrailing: isMedium
                ? FilledButton.icon(
                    onPressed: () async {
                      await onCreateOrder!();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: stage.color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Criar cadastro'),
                  )
                : null,
            child: isMedium
                ? null
                : FilledButton.icon(
                    onPressed: () async {
                      await onCreateOrder!();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: stage.color,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Criar cadastro'),
                  ),
          ),
          const SizedBox(height: 20),
        ],
        if (stage == WorkflowStage.relationship &&
            showingWorkQueue &&
            onCreateServiceOrder != null) ...[
          _CustomerRegistrationUtilityCard(
            icon: Icons.assignment_outlined,
            accent: stage.color,
            title: 'Criar ordem de serviço',
            description:
                'Selecione um cliente, descreva o serviço e envie a OS direto para o Orçamentista.',
            headerTrailing: isMedium
                ? FilledButton.icon(
                    onPressed: () async {
                      await onCreateServiceOrder!();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: stage.color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('Nova OS'),
                  )
                : null,
            child: isMedium
                ? null
                : FilledButton.icon(
                    onPressed: () async {
                      await onCreateServiceOrder!();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: stage.color,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('Nova OS'),
                  ),
          ),
          const SizedBox(height: 20),
        ],
        if (showingRegistrationInProgress ||
            showingRegisteredCatalog ||
            showingWorkQueue) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 760;
              final cardWidth = useTwoColumns
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: topMetricCards
                    .map((card) => SizedBox(width: cardWidth, child: card))
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 20),
          if (stage == WorkflowStage.finance && showingWorkQueue) ...[
            const Text(
              'Contratos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: kanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onMoveFinanceKanbanOrder: onMoveFinanceKanbanOrder,
              canAcceptFinanceKanbanDrop: canAcceptFinanceKanbanDrop,
              onUnmergeProposal: onUnmergeProposal,
            ),
            const SizedBox(height: 20),
            const Text(
              'Ordens de serviço',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: financeServiceOrderKanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onUnmergeProposal: onUnmergeProposal,
            ),
          ] else if (stage == WorkflowStage.installation &&
              showingWorkQueue) ...[
            const Text(
              'Pedidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: kanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onMoveInstallationKanbanOrder: onMoveInstallationKanbanOrder,
              canAcceptInstallationKanbanDrop: canAcceptInstallationKanbanDrop,
              onUnmergeProposal: onUnmergeProposal,
            ),
            const SizedBox(height: 20),
            const Text(
              'Ordens de serviço',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: installationServiceOrderKanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onMoveInstallationKanbanOrder: onMoveInstallationKanbanOrder,
              canAcceptInstallationKanbanDrop: canAcceptInstallationKanbanDrop,
              onUnmergeProposal: onUnmergeProposal,
            ),
          ] else if (stage == WorkflowStage.estimating && showingWorkQueue) ...[
            const Text(
              'Pedidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: kanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onUnmergeProposal: onUnmergeProposal,
            ),
            const SizedBox(height: 20),
            const Text(
              'Ordens de serviço',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: estimatingServiceOrderKanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onUnmergeProposal: onUnmergeProposal,
            ),
          ] else if (stage == WorkflowStage.relationship &&
              showingWorkQueue) ...[
            if (mergeCandidates.isNotEmpty) ...[
              _MergeCandidatesBanner(
                candidates: mergeCandidates,
                allOrders: orders,
                onMerge: onMergeProposal,
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Pedidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: kanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onMoveRelationshipKanbanOrder: onMoveRelationshipKanbanOrder,
              canAcceptRelationshipKanbanDrop: canAcceptRelationshipKanbanDrop,
              onUnmergeProposal: onUnmergeProposal,
            ),
            const SizedBox(height: 20),
            const Text(
              'Ordens de serviço',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _StageOrdersKanbanBoard(
              columns: relationshipServiceOrderKanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onUnmergeProposal: onUnmergeProposal,
            ),
          ] else
            _StageOrdersKanbanBoard(
              columns: kanbanColumns,
              allOrders: orders,
              selectedOrderCode: selectedOrder?.code,
              onOrderSelected: handleOrderTap,
              onOpenOrderConversation: handleOpenConversation,
              workspaceProfiles: workspaceProfiles,
              onMoveAssemblyKanbanOrder: stage == WorkflowStage.assembly
                  ? onMoveAssemblyKanbanOrder
                  : null,
              canAcceptAssemblyKanbanDrop: stage == WorkflowStage.assembly
                  ? canAcceptAssemblyKanbanDrop
                  : null,
              onMoveEngineeringKanbanOrder: stage == WorkflowStage.engineering
                  ? onMoveEngineeringKanbanOrder
                  : null,
              canAcceptEngineeringKanbanDrop: stage == WorkflowStage.engineering
                  ? canAcceptEngineeringKanbanDrop
                  : null,
              onMoveFinanceKanbanOrder: stage == WorkflowStage.finance
                  ? onMoveFinanceKanbanOrder
                  : null,
              canAcceptFinanceKanbanDrop: stage == WorkflowStage.finance
                  ? canAcceptFinanceKanbanDrop
                  : null,
              onMoveRelationshipKanbanOrder: stage == WorkflowStage.relationship
                  ? onMoveRelationshipKanbanOrder
                  : null,
              canAcceptRelationshipKanbanDrop:
                  stage == WorkflowStage.relationship
                  ? canAcceptRelationshipKanbanDrop
                  : null,
              onUnmergeProposal: onUnmergeProposal,
            ),
        ],
      ],
    );
  }
}

class _FlowNavbar extends StatelessWidget {
  const _FlowNavbar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.notificationCount,
    required this.notifications,
    required this.isCheckingSoftwareUpdate,
    required this.onCheckSoftwareUpdate,
    required this.onOpenNotification,
  });

  final List<_FlowNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final int notificationCount;
  final List<_OrderConversationNotification> notifications;
  final bool isCheckingSoftwareUpdate;
  final VoidCallback onCheckSoftwareUpdate;
  final ValueChanged<_OrderConversationNotification> onOpenNotification;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: _panelDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFFF2F2F0)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(18),
              boxShadow: isDarkMode
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x120F172A),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
            ),
            child: Icon(
              Icons.dashboard_customize_outlined,
              color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _FlowNavbarTab(
                  item: items[index],
                  selected: selectedIndex == index,
                  onTap: () => onSelected(index),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
            ),
          ),
          const SizedBox(height: 12),
          _ThemeModeSettingsButton(
            themeMode: themeMode,
            onThemeModeChanged: onThemeModeChanged,
            compact: true,
          ),
          const SizedBox(height: 8),
          _SoftwareUpdateCheckButton(
            isChecking: isCheckingSoftwareUpdate,
            onPressed: onCheckSoftwareUpdate,
            compact: true,
          ),
          const SizedBox(height: 8),
          _ConversationNotificationsButton(
            notifications: notifications,
            notificationCount: notificationCount,
            onOpenNotification: onOpenNotification,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _FlowTopNavbar extends StatelessWidget {
  const _FlowTopNavbar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.profile,
    required this.notificationCount,
    required this.notifications,
    required this.isCheckingSoftwareUpdate,
    required this.onCheckSoftwareUpdate,
    required this.onOpenNotification,
    this.onSignOut,
  });

  final List<_FlowNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final EmployeeWorkspaceProfile profile;
  final int notificationCount;
  final List<_OrderConversationNotification> notifications;
  final bool isCheckingSoftwareUpdate;
  final VoidCallback onCheckSoftwareUpdate;
  final ValueChanged<_OrderConversationNotification> onOpenNotification;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ERP DANF',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Painel integrado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B6B68)),
                    ),
                    SizedBox(height: 6),
                    _SoftwareVersionLabel(compact: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ThemeModeSettingsButton(
                themeMode: themeMode,
                onThemeModeChanged: onThemeModeChanged,
              ),
              const SizedBox(width: 8),
              _SoftwareUpdateCheckButton(
                isChecking: isCheckingSoftwareUpdate,
                onPressed: onCheckSoftwareUpdate,
                compact: true,
              ),
              const SizedBox(width: 8),
              _ConversationNotificationsButton(
                notifications: notifications,
                notificationCount: notificationCount,
                onOpenNotification: onOpenNotification,
                compact: true,
              ),
              if (onSignOut != null) ...[
                const SizedBox(width: 8),
                _ShellProfileMenuButton(
                  profile: profile,
                  onSignOut: onSignOut!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  _FlowTopNavbarTab(
                    item: items[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformLogSection extends StatelessWidget {
  const _PlatformLogSection({required this.entries, required this.onClearLogs});

  final List<_PlatformLogEntry> entries;
  final Future<void> Function() onClearLogs;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _panelDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log da plataforma',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Histórico das ações operacionais registradas neste app.',
                      style: TextStyle(color: Color(0xFF6B6B68), height: 1.35),
                    ),
                  ],
                ),
              ),
              if (entries.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onClearLogs,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Limpar'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: _panelDecoration(context),
            child: const Text(
              'Nenhuma ação registrada ainda.',
              style: TextStyle(fontSize: 15),
            ),
          )
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: _panelDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.action,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${entry.area} • ${entry.actor}',
                                style: const TextStyle(
                                  color: Color(0xFF6B6B68),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDateTime(entry.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (entry.details != null &&
                        entry.details!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        entry.details!,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FlowNavItem {
  const _FlowNavItem({
    required this.routeKey,
    required this.label,
    required this.icon,
    required this.color,
    this.stage,
    this.badgeCount = 0,
  });

  final String routeKey;
  final String label;
  final IconData icon;
  final Color color;
  final WorkflowStage? stage;
  final int badgeCount;
}

class _ThemeModeSettingsButton extends StatelessWidget {
  const _ThemeModeSettingsButton({
    required this.themeMode,
    required this.onThemeModeChanged,
    this.compact = false,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Configurações',
      onSelected: onThemeModeChanged,
      itemBuilder: (context) => [
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.light,
          child: Row(
            children: [
              Icon(
                Icons.light_mode_outlined,
                color: themeMode == ThemeMode.light
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Modo claro')),
              if (themeMode == ThemeMode.light)
                Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.dark,
          child: Row(
            children: [
              Icon(
                Icons.dark_mode_outlined,
                color: themeMode == ThemeMode.dark
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Modo escuro')),
              if (themeMode == ThemeMode.dark)
                Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ],
      child: Container(
        width: compact ? 48 : null,
        padding: EdgeInsets.all(compact ? 10 : 11),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF202225)
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF26282B)
                : const Color(0xFFE8E8E5),
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFF2F2F0)
              : const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _PlatformLogEntry {
  const _PlatformLogEntry({
    required this.actor,
    required this.action,
    required this.area,
    required this.createdAt,
    this.details,
  });

  final String actor;
  final String action;
  final String area;
  final DateTime createdAt;
  final String? details;

  Map<String, dynamic> toMap() {
    return {
      'actor': actor,
      'action': action,
      'area': area,
      'createdAt': createdAt.toIso8601String(),
      'details': details,
    };
  }

  factory _PlatformLogEntry.fromMap(Map<String, dynamic> map) {
    return _PlatformLogEntry(
      actor: map['actor']?.toString() ?? 'Sistema',
      action: map['action']?.toString() ?? 'Ação',
      area: map['area']?.toString() ?? 'Geral',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      details: map['details']?.toString(),
    );
  }
}

class _FlowNavbarTab extends StatelessWidget {
  const _FlowNavbarTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _FlowNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _resolveNavItemForegroundColor(
      context: context,
      itemColor: item.color,
      selected: selected,
    );
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? Colors.transparent
        : isDarkMode
        ? const Color(0xFF26282B)
        : const Color(0xFFE8E8E5);

    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 250),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: selected
                ? (isDarkMode
                      ? const Color(0xFFF2F2F0)
                      : const Color(0xFF1A1A1A))
                : (isDarkMode
                      ? const Color(0xFF202225)
                      : Colors.white.withValues(alpha: 0.92)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: selected && !isDarkMode
                ? const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: selected
                    ? (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white)
                    : foregroundColor,
              ),
              if (item.badgeCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB45309),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowTopNavbarTab extends StatelessWidget {
  const _FlowTopNavbarTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _FlowNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _resolveNavItemForegroundColor(
      context: context,
      itemColor: item.color,
      selected: selected,
    );
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? Colors.transparent
        : isDarkMode
        ? const Color(0xFF26282B)
        : const Color(0xFFE8E8E5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? (isDarkMode ? const Color(0xFFF2F2F0) : const Color(0xFF1A1A1A))
              : (isDarkMode
                    ? const Color(0xFF202225)
                    : Colors.white.withValues(alpha: 0.92)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: selected && !isDarkMode
              ? const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected
                      ? (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white)
                      : foregroundColor,
                ),
                if (item.badgeCount > 0)
                  Positioned(
                    top: -3,
                    right: -4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB45309),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                color: selected
                    ? (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white)
                    : isDarkMode
                    ? const Color(0xFFF2F2F0)
                    : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (item.badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${item.badgeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _resolveNavItemForegroundColor({
  required BuildContext context,
  required Color itemColor,
  required bool selected,
}) {
  if (selected) {
    return Colors.white;
  }

  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  if (!isDarkMode) {
    return itemColor;
  }

  return itemColor.computeLuminance() < 0.2
      ? const Color(0xFFF2F2F0)
      : itemColor;
}

class _OrderDetailsScreen extends StatefulWidget {
  const _OrderDetailsScreen({
    required this.stage,
    required this.orderCode,
    required this.showEngineeringChecklist,
    required this.showFlowActions,
    required this.resolveOrderByCode,
    required this.getAllOrders,
    required this.currentProfile,
    required this.workspaceProfiles,
    required this.unreadMentionCount,
    required this.onMarkConversationRead,
    required this.onSendConversationMessage,
    required this.onAdvanceOrder,
    required this.onReturnOrder,
    required this.onSendToEngineering,
    required this.onSendToAssembly,
    required this.onSendToInstallation,
    this.openConversationOnLoad = false,
    this.onAttachMaterials,
    this.onSetEstimatingWasEstimate,
    this.onAttachElectricalProject,
    this.onAttachPanelLayout,
    this.onAttachPushButtonTable,
    this.onAttachEngineeringData,
    this.onAttachConsolidatedProposal,
    this.onAttachContract,
    this.onAttachServiceOrderPdf,
    this.onToggleFinanceClientApproval,
    this.onScheduleInstallation,
    this.onToggleInstallationExecutionItem,
    this.onOpenAssemblyPreparationChecklist,
    this.onScheduleEngineeringActivity,
    this.onUpdateEngineeringChecklistStatus,
    this.onUpdateFinanceContractStatus,
    this.onUpdateRelationshipKanbanStatus,
    this.onEditOrder,
    this.onDeleteOrder,
  });

  final WorkflowStage stage;
  final String orderCode;
  final bool showEngineeringChecklist;
  final bool showFlowActions;
  final WorkflowOrder? Function(String code) resolveOrderByCode;
  final List<WorkflowOrder> Function() getAllOrders;
  final EmployeeWorkspaceProfile currentProfile;
  final List<EmployeeWorkspaceProfile> workspaceProfiles;
  final int unreadMentionCount;
  final Future<void> Function(String orderCode) onMarkConversationRead;
  final Future<bool> Function(String orderCode, String message)
  onSendConversationMessage;
  final Future<void> Function() onAdvanceOrder;
  final Future<void> Function() onReturnOrder;
  final Future<void> Function() onSendToEngineering;
  final Future<void> Function() onSendToAssembly;
  final Future<void> Function() onSendToInstallation;
  final bool openConversationOnLoad;
  final Future<void> Function()? onAttachMaterials;
  final Future<void> Function()? onSetEstimatingWasEstimate;
  final Future<void> Function()? onAttachElectricalProject;
  final Future<void> Function()? onAttachPanelLayout;
  final Future<void> Function()? onAttachPushButtonTable;
  final Future<void> Function()? onAttachEngineeringData;
  final Future<void> Function()? onAttachConsolidatedProposal;
  final Future<void> Function()? onAttachContract;
  final Future<void> Function()? onAttachServiceOrderPdf;
  final Future<void> Function()? onToggleFinanceClientApproval;
  final Future<void> Function()? onScheduleInstallation;
  final Future<void> Function(int visitIndex, String item)?
  onToggleInstallationExecutionItem;
  final Future<void> Function()? onOpenAssemblyPreparationChecklist;
  final Future<void> Function(String taskKey)? onScheduleEngineeringActivity;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateEngineeringChecklistStatus;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateFinanceContractStatus;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateRelationshipKanbanStatus;
  final Future<void> Function()? onEditOrder;
  final Future<void> Function()? onDeleteOrder;

  @override
  State<_OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<_OrderDetailsScreen> {
  late int _unreadConversationCount;

  WorkflowOrder? get _currentOrder =>
      widget.resolveOrderByCode(widget.orderCode);

  void _setStateSafely(VoidCallback fn) {
    if (!mounted) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(fn);
    });
  }

  @override
  void initState() {
    super.initState();
    _unreadConversationCount = widget.unreadMentionCount;
    if (widget.openConversationOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_openConversationDialog());
      });
    }
  }

  Future<void> _runAndRefresh(Future<void> Function()? action) async {
    if (action == null) {
      return;
    }

    await action();
    if (!mounted) {
      return;
    }
    _setStateSafely(() {});
  }

  Future<void> _openConversationDialog() async {
    final order = _currentOrder;
    if (order == null) {
      return;
    }

    await widget.onMarkConversationRead(order.code);
    if (!mounted) {
      return;
    }
    _setStateSafely(() {
      _unreadConversationCount = 0;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OrderConversationDialog(
        order: widget.resolveOrderByCode(order.code) ?? order,
        currentProfile: widget.currentProfile,
        profiles: widget.workspaceProfiles,
        onSendMessage: (message) =>
            widget.onSendConversationMessage(order.code, message),
      ),
    );

    if (!mounted) {
      return;
    }
    _setStateSafely(() {});
  }

  Future<void> _runStageTransition(Future<void> Function() action) async {
    await action();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;
    final allOrders = widget.getAllOrders();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF26282B)
        : const Color(0xFFF5F5F3);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order == null ? 'Pedido' : _displayOrderCode(order, allOrders),
            ),
            if (order != null)
              Text(
                order.workName,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: _OrderDetailsPanel(
                order: order,
                allOrders: allOrders,
                assemblyAssignedProfiles: order == null
                    ? []
                    : _assemblyAssignedProfilesForOrder(
                        order,
                        widget.workspaceProfiles,
                      ),
                workspaceProfiles: widget.workspaceProfiles,
                onAdvanceOrder: () =>
                    _runStageTransition(widget.onAdvanceOrder),
                onReturnOrder: () => _runStageTransition(widget.onReturnOrder),
                onSendToEngineering: () =>
                    _runStageTransition(widget.onSendToEngineering),
                onSendToAssembly: () =>
                    _runStageTransition(widget.onSendToAssembly),
                onSendToInstallation: () =>
                    _runStageTransition(widget.onSendToInstallation),
                onOpenConversation: _openConversationDialog,
                conversationCount: order?.conversationMessages.length ?? 0,
                unreadConversationCount: _unreadConversationCount,
                showEngineeringChecklist: widget.showEngineeringChecklist,
                onAttachMaterials: widget.onAttachMaterials == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachMaterials),
                onSetEstimatingWasEstimate:
                    widget.onSetEstimatingWasEstimate == null
                    ? null
                    : () => _runAndRefresh(widget.onSetEstimatingWasEstimate),
                onAttachElectricalProject:
                    widget.onAttachElectricalProject == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachElectricalProject),
                onAttachPanelLayout: widget.onAttachPanelLayout == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachPanelLayout),
                onAttachPushButtonTable: widget.onAttachPushButtonTable == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachPushButtonTable),
                onAttachEngineeringData: widget.onAttachEngineeringData == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachEngineeringData),
                onAttachConsolidatedProposal:
                    widget.onAttachConsolidatedProposal == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachConsolidatedProposal),
                onAttachContract: widget.onAttachContract == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachContract),
                onAttachServiceOrderPdf: widget.onAttachServiceOrderPdf == null
                    ? null
                    : () => _runAndRefresh(widget.onAttachServiceOrderPdf),
                onToggleFinanceClientApproval:
                    widget.onToggleFinanceClientApproval == null
                    ? null
                    : () =>
                          _runAndRefresh(widget.onToggleFinanceClientApproval),
                onScheduleInstallation: widget.onScheduleInstallation == null
                    ? null
                    : () => _runAndRefresh(widget.onScheduleInstallation),
                onToggleInstallationExecutionItem:
                    widget.onToggleInstallationExecutionItem == null
                    ? null
                    : (visitIndex, item) async {
                        await widget.onToggleInstallationExecutionItem!(
                          visitIndex,
                          item,
                        );
                        if (!mounted) {
                          return;
                        }
                        _setStateSafely(() {});
                      },
                onOpenAssemblyPreparationChecklist:
                    widget.onOpenAssemblyPreparationChecklist == null
                    ? null
                    : () => _runAndRefresh(
                        widget.onOpenAssemblyPreparationChecklist,
                      ),
                onScheduleEngineeringActivity:
                    widget.onScheduleEngineeringActivity == null
                    ? null
                    : (taskKey) async {
                        await widget.onScheduleEngineeringActivity!(taskKey);
                        if (!mounted) {
                          return;
                        }
                        _setStateSafely(() {});
                      },
                onUpdateEngineeringChecklistStatus:
                    widget.onUpdateEngineeringChecklistStatus == null
                    ? null
                    : (taskKey, status) async {
                        await widget.onUpdateEngineeringChecklistStatus!(
                          taskKey,
                          status,
                        );
                        if (!mounted) {
                          return;
                        }
                        _setStateSafely(() {});
                      },
                onUpdateFinanceContractStatus:
                    widget.onUpdateFinanceContractStatus == null
                    ? null
                    : (taskKey, status) async {
                        await widget.onUpdateFinanceContractStatus!(
                          taskKey,
                          status,
                        );
                        if (!mounted) {
                          return;
                        }
                        _setStateSafely(() {});
                      },
                onUpdateRelationshipKanbanStatus:
                    widget.onUpdateRelationshipKanbanStatus == null
                    ? null
                    : (taskKey, status) async {
                        await widget.onUpdateRelationshipKanbanStatus!(
                          taskKey,
                          status,
                        );
                        if (!mounted) {
                          return;
                        }
                        _setStateSafely(() {});
                      },
                onEditOrder: widget.onEditOrder == null
                    ? null
                    : () => _runAndRefresh(widget.onEditOrder),
                onDeleteOrder: widget.onDeleteOrder == null
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        await widget.onDeleteOrder!();
                        if (!mounted) {
                          return;
                        }
                        navigator.pop();
                      },
                showFlowActions:
                    widget.showFlowActions &&
                    order != null &&
                    order.currentStage == widget.stage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsPanel extends StatelessWidget {
  const _OrderDetailsPanel({
    required this.order,
    required this.allOrders,
    required this.assemblyAssignedProfiles,
    required this.workspaceProfiles,
    required this.onAdvanceOrder,
    required this.onReturnOrder,
    required this.onSendToEngineering,
    required this.onSendToAssembly,
    required this.onSendToInstallation,
    this.onOpenConversation,
    this.conversationCount = 0,
    this.unreadConversationCount = 0,
    this.showEngineeringChecklist = false,
    this.onAttachMaterials,
    this.onSetEstimatingWasEstimate,
    this.onAttachElectricalProject,
    this.onAttachPanelLayout,
    this.onAttachPushButtonTable,
    this.onAttachEngineeringData,
    this.onAttachConsolidatedProposal,
    this.onAttachContract,
    this.onAttachServiceOrderPdf,
    this.onToggleFinanceClientApproval,
    this.onScheduleInstallation,
    this.onToggleInstallationExecutionItem,
    this.onOpenAssemblyPreparationChecklist,
    this.onScheduleEngineeringActivity,
    this.onUpdateEngineeringChecklistStatus,
    this.onUpdateFinanceContractStatus,
    this.onUpdateRelationshipKanbanStatus,
    this.showFlowActions = true,
    this.onEditOrder,
    this.onDeleteOrder,
  });

  final WorkflowOrder? order;
  final List<WorkflowOrder> allOrders;
  final List<EmployeeWorkspaceProfile> assemblyAssignedProfiles;
  final List<EmployeeWorkspaceProfile> workspaceProfiles;
  final Future<void> Function() onAdvanceOrder;
  final Future<void> Function() onReturnOrder;
  final Future<void> Function() onSendToEngineering;
  final Future<void> Function() onSendToAssembly;
  final Future<void> Function() onSendToInstallation;
  final Future<void> Function()? onOpenConversation;
  final int conversationCount;
  final int unreadConversationCount;
  final bool showEngineeringChecklist;
  final Future<void> Function()? onAttachMaterials;
  final Future<void> Function()? onSetEstimatingWasEstimate;
  final Future<void> Function()? onAttachElectricalProject;
  final Future<void> Function()? onAttachPanelLayout;
  final Future<void> Function()? onAttachPushButtonTable;
  final Future<void> Function()? onAttachEngineeringData;
  final Future<void> Function()? onAttachConsolidatedProposal;
  final Future<void> Function()? onAttachContract;
  final Future<void> Function()? onAttachServiceOrderPdf;
  final Future<void> Function()? onToggleFinanceClientApproval;
  final Future<void> Function()? onScheduleInstallation;
  final Future<void> Function(int visitIndex, String item)?
  onToggleInstallationExecutionItem;
  final Future<void> Function()? onOpenAssemblyPreparationChecklist;
  final Future<void> Function(String taskKey)? onScheduleEngineeringActivity;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateEngineeringChecklistStatus;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateFinanceContractStatus;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onUpdateRelationshipKanbanStatus;
  final bool showFlowActions;
  final Future<void> Function()? onEditOrder;
  final Future<void> Function()? onDeleteOrder;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final subtleSurfaceColor = isDarkMode
        ? const Color(0xFF1C1D20)
        : const Color(0xFFF5F5F3);
    final subtleBorderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE0E0DD);
    final progressTrackColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);
    final showFullCustomerRegistrationData =
        order?.currentStage == WorkflowStage.customerRegistration;

    if (order == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(context),
        child: const Text('Selecione um pedido para ver os detalhes do fluxo.'),
      );
    }

    final stageIndex = workflowStages.indexOf(order!.currentStage);
    final isEstimatingStage = order!.currentStage == WorkflowStage.estimating;
    final isRelationshipStage =
        order!.currentStage == WorkflowStage.relationship;
    final isFinanceStage = order!.currentStage == WorkflowStage.finance;
    final isEngineeringStage = order!.currentStage == WorkflowStage.engineering;
    final isInstallationStage =
        order!.currentStage == WorkflowStage.installation;
    final isServiceOrder = order!.isServiceOrder;
    final hasMaterialsFile = _hasEstimatingWorksheetData(order!);
    final hasServiceOrderPdf = order!.serviceOrderFileName.trim().isNotEmpty;
    final hasElectricalProject = order!.electricalProjectFileName
        .trim()
        .isNotEmpty;
    final hasPanelLayout = order!.panelLayoutFileName.trim().isNotEmpty;
    final hasPushButtonTable = order!.pushButtonTableFileName.trim().isNotEmpty;
    final hasEngineeringData = order!.engineeringDataFileName.trim().isNotEmpty;
    final hasContractFile = order!.contractFileName.trim().isNotEmpty;
    // Use assemblyAssignedProfiles directly for avatars
    final relatedProposals = _proposalGroupOrders(allOrders, order!);
    final mergedSubProposals = relatedProposals
        .where((p) => p.code != order!.code && _isSubProposal(p))
        .toList(growable: false);
    final stageOwners = order!.resolvedStageOwners().entries.toList(
      growable: false,
    );
    final engineeringFlow = _engineeringFlowSnapshot(order!);
    final financeContractFlow = _financeContractFlowSnapshot(order!);
    final relationshipKanbanFlow = _relationshipKanbanFlowSnapshot(order!);
    final hasPassedFinance =
        stageIndex > workflowStages.indexOf(WorkflowStage.finance);
    final hasPassedRelationship =
        stageIndex > workflowStages.indexOf(WorkflowStage.relationship);
    final hasPassedEngineering =
        stageIndex > workflowStages.indexOf(WorkflowStage.engineering);
    final hasReachedAssembly =
        stageIndex >= workflowStages.indexOf(WorkflowStage.assembly);
    final showEngineeringFilesSection =
        isEngineeringStage ||
        order!.engineeringChecklistStatuses.isNotEmpty ||
        hasElectricalProject ||
        hasPanelLayout ||
        hasPushButtonTable ||
        hasEngineeringData;
    final showEngineeringFilesInStageFiles =
        hasPassedEngineering && showEngineeringFilesSection;
    final showEngineeringFilesInEngineering =
        showEngineeringFilesSection && !showEngineeringFilesInStageFiles;
    final showEngineeringSection =
        showEngineeringChecklist || showEngineeringFilesInEngineering;
    final canEditEngineeringSection = showFlowActions && isEngineeringStage;
    final showFinanceContractSection =
        !isServiceOrder &&
        !isEngineeringStage &&
        !isRelationshipStage &&
        !isInstallationStage &&
        (isFinanceStage ||
            hasPassedFinance ||
            hasContractFile ||
            order!.financeContractStatuses.isNotEmpty);
    final showRelationshipSection =
        !isServiceOrder &&
        !isEngineeringStage &&
        !isInstallationStage &&
        (isRelationshipStage ||
            hasPassedRelationship ||
            order!.relationshipKanbanStatuses.isNotEmpty);
    final showEditOrderAction = onEditOrder != null;
    final canSetEstimatingWasEstimate =
        showFlowActions &&
        isEstimatingStage &&
        onSetEstimatingWasEstimate != null;
    final assemblyChecklistSection = !hasReachedAssembly || isInstallationStage
        ? null
        : _CollapsibleDetailSection(
            title: 'Checklist da montagem',
            subtitle:
                'Preparação inicial obrigatória antes de liberar o pedido para a produção.',
            initiallyExpanded: order!.currentStage == WorkflowStage.assembly,
            child: _AssemblyPreparationChecklistCard(
              order: order!,
              canEdit:
                  showFlowActions &&
                  order!.currentStage == WorkflowStage.assembly &&
                  onOpenAssemblyPreparationChecklist != null,
              onOpenChecklist: onOpenAssemblyPreparationChecklist,
            ),
          );
    final canAdvance =
        (stageIndex != workflowStages.length - 1 ||
            (isInstallationStage &&
                order!.installationWorkflowStatus !=
                    InstallationWorkflowStatus.done)) &&
        (!isEstimatingStage ||
            (isServiceOrder ? hasServiceOrderPdf : hasMaterialsFile)) &&
        (!isFinanceStage ||
            (isServiceOrder
                ? (order!.financeClientApproved &&
                      order!.serviceOrderFinanceStatus !=
                          ServiceOrderFinanceStatus.paid)
                : financeContractFlow.isComplete));
    const headerActionSpacing = 6.0;
    const headerActionPanelPadding = 4.0;
    final headerActionMinWidth = isRelationshipStage ? 138.0 : 102.0;
    final compactOutlinedHeaderButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      iconSize: 15,
    );
    final compactFilledHeaderButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      iconSize: 15,
    );
    final headerActions = <Widget>[
      if (onOpenConversation != null)
        OutlinedButton.icon(
          onPressed: () async {
            await onOpenConversation!();
          },
          style: compactOutlinedHeaderButtonStyle,
          icon: unreadConversationCount > 0
              ? _HeaderCountBadgeIcon(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: unreadConversationCount,
                  color: const Color(0xFF2563EB),
                )
              : const Icon(Icons.chat_bubble_outline_rounded),
          label: Text(
            conversationCount > 0
                ? 'Conversa ($conversationCount)'
                : 'Conversa',
          ),
        ),
      if (showEditOrderAction)
        OutlinedButton.icon(
          onPressed: () async {
            await onEditOrder!();
          },
          style: compactOutlinedHeaderButtonStyle,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
      if (onDeleteOrder != null)
        OutlinedButton.icon(
          onPressed: () async {
            await onDeleteOrder!();
          },
          style: compactOutlinedHeaderButtonStyle.copyWith(
            foregroundColor: WidgetStatePropertyAll(const Color(0xFFB91C1C)),
            side: WidgetStatePropertyAll(
              const BorderSide(color: Color(0xFFFCA5A5)),
            ),
          ),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir'),
        ),
      if (showFlowActions)
        OutlinedButton.icon(
          onPressed: stageIndex == 0
              ? null
              : () async {
                  await onReturnOrder();
                },
          style: compactOutlinedHeaderButtonStyle,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Voltar'),
        ),
      if (showFlowActions && isRelationshipStage)
        FilledButton.icon(
          onPressed: isServiceOrder || relationshipKanbanFlow.isComplete
              ? () async {
                  await onSendToEngineering();
                }
              : null,
          style: compactFilledHeaderButtonStyle,
          icon: const Icon(Icons.architecture_outlined),
          label: const Text('Enviar para Engenharia'),
        ),
      if (showFlowActions && isRelationshipStage)
        FilledButton.icon(
          onPressed: isServiceOrder || relationshipKanbanFlow.isComplete
              ? () async {
                  await onSendToAssembly();
                }
              : null,
          style: compactFilledHeaderButtonStyle,
          icon: const Icon(Icons.precision_manufacturing_outlined),
          label: const Text('Enviar para Montagem'),
        ),
      if (showFlowActions && isRelationshipStage)
        FilledButton.icon(
          onPressed: isServiceOrder || relationshipKanbanFlow.isComplete
              ? () async {
                  await onSendToInstallation();
                }
              : null,
          style: compactFilledHeaderButtonStyle,
          icon: const Icon(Icons.home_repair_service_outlined),
          label: const Text('Enviar para Instalação'),
        ),
      if (showFlowActions && !isRelationshipStage)
        FilledButton.icon(
          onPressed: canAdvance
              ? () async {
                  await onAdvanceOrder();
                }
              : null,
          style: compactFilledHeaderButtonStyle,
          icon: const Icon(Icons.chevron_right),
          label: Text(
            isEngineeringStage
                ? (engineeringFlow.isComplete
                      ? 'Enviar para Montagem'
                      : 'Avançar kanban')
                : order!.currentStage == WorkflowStage.assembly
                ? switch (order!.assemblyWorkflowStatus) {
                    AssemblyWorkflowStatus.waiting =>
                      _isAssemblyPreparationChecklistComplete(order!)
                          ? 'Liberar para montagem'
                          : 'Baixar checklist',
                    AssemblyWorkflowStatus.released => 'Iniciar montagem',
                    AssemblyWorkflowStatus.doing => 'Enviar para teste',
                    AssemblyWorkflowStatus.panelTesting => 'Concluir painel',
                    AssemblyWorkflowStatus.done => 'Enviar para Instalação',
                  }
                : isInstallationStage
                ? switch (order!.installationWorkflowStatus) {
                    InstallationWorkflowStatus.waiting => 'Agendar instalação',
                    InstallationWorkflowStatus.scheduled => 'Iniciar visita',
                    InstallationWorkflowStatus.doing => 'Concluir/retorno',
                    InstallationWorkflowStatus.done => 'Concluído',
                  }
                : isFinanceStage && isServiceOrder
                ? switch (order!.serviceOrderFinanceStatus) {
                    ServiceOrderFinanceStatus.waitingApproval =>
                      'Aguardar aprovação',
                    ServiceOrderFinanceStatus.approved => 'Avançar',
                    ServiceOrderFinanceStatus.concluded => 'Marcar como paga',
                    ServiceOrderFinanceStatus.paid => 'Concluído',
                  }
                : 'Avançar',
          ),
        ),
    ];
    final uniformHeaderActions = <Widget>[
      for (var index = 0; index < headerActions.length; index++) ...[
        if (index > 0) const SizedBox(width: headerActionSpacing),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: headerActionMinWidth),
          child: SizedBox(height: 32, child: headerActions[index]),
        ),
      ],
    ];
    final relationshipHeaderActionGrid =
        isRelationshipStage && headerActions.isNotEmpty
        ? SizedBox(
            width: (headerActionMinWidth * 2) + headerActionSpacing,
            child: Wrap(
              spacing: headerActionSpacing,
              runSpacing: headerActionSpacing,
              children: [
                for (final action in headerActions)
                  SizedBox(
                    width: headerActionMinWidth,
                    height: 32,
                    child: action,
                  ),
              ],
            ),
          )
        : null;
    final showStandaloneEditAction =
        !showFlowActions && headerActions.length == 1 && showEditOrderAction;
    final headerActionPanel = headerActions.isEmpty
        ? null
        : showStandaloneEditAction
        ? SizedBox(width: 112, height: 32, child: headerActions.first)
        : Container(
            padding: const EdgeInsets.all(headerActionPanelPadding),
            decoration: BoxDecoration(
              color: subtleSurfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: subtleBorderColor),
            ),
            child: isRelationshipStage && relationshipHeaderActionGrid != null
                ? relationshipHeaderActionGrid
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: uniformHeaderActions,
                  ),
          );
    final headerActionGroupWidth = isRelationshipStage
        ? ((headerActionMinWidth * 2) +
              headerActionSpacing +
              (headerActionPanelPadding * 2))
        : headerActions.isEmpty
        ? 0.0
        : showStandaloneEditAction
        ? 120.0
        : (headerActions.length * headerActionMinWidth) +
              ((headerActions.length - 1) * headerActionSpacing) +
              (headerActionPanelPadding * 2);
    final inlineHeaderMinWidth =
        320 + (headerActions.isEmpty ? 0.0 : 16 + headerActionGroupWidth);
    final customerDataSection = _CollapsibleDetailSection(
      title: 'Dados do cliente',
      subtitle: showFullCustomerRegistrationData
          ? 'Consulta completa do cadastro, obra, comercial e etapa 2.'
          : 'Informações principais do cadastro e da obra.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = 14.0;
          final useTwoColumns = constraints.maxWidth >= 700;
          final itemWidth = useTwoColumns
              ? (constraints.maxWidth - spacing) / 2
              : constraints.maxWidth;
          final fullWidth = useTwoColumns ? constraints.maxWidth : itemWidth;

          Widget info(String label, String value, {bool emphasize = false}) {
            return SizedBox(
              width: itemWidth,
              child: _InfoRow(
                label: label,
                value: value.trim().isEmpty ? 'Não informado' : value,
                emphasizeValue: emphasize,
              ),
            );
          }

          Widget infoFull(
            String label,
            String value, {
            bool emphasize = false,
          }) {
            return SizedBox(
              width: fullWidth,
              child: _InfoRow(
                label: label,
                value: value.trim().isEmpty ? 'Não informado' : value,
                emphasizeValue: emphasize,
              ),
            );
          }

          final stage2ServicesSummary = order!.proposalServices.isEmpty
              ? 'Não informado'
              : order!.proposalServices
                    .map(
                      (service) =>
                          '${service.serviceName}: Consolidado ${service.consolidated.isEmpty ? "Não informado" : service.consolidated}, Projeto ${service.prepareInProject.isEmpty ? "Não informado" : service.prepareInProject}${service.observations.trim().isEmpty ? "" : " (${service.observations.trim()})"}',
                    )
                    .join('\n');
          final whatsappMembersSummary = order!.whatsappGroupMembers.isEmpty
              ? 'Não informado'
              : order!.whatsappGroupMembers
                    .map(
                      (member) =>
                          '${member.name} • ${member.phone} • ${member.role}',
                    )
                    .join('\n');

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              info('ID do cliente', order!.client.id, emphasize: true),
              info('Obra', order!.workName, emphasize: true),
              info('Cliente', order!.client.name, emphasize: true),
              info('Telefone', order!.client.phone),
              infoFull('Endereço', order!.address),
              if (order!.currentStage == WorkflowStage.estimating)
                info('Número da proposta', order!.commercialProposalNumber),
              if (showFullCustomerRegistrationData) ...[
                info('Data de nascimento', order!.client.birthDate),
                info('E-mail', order!.client.email),
                info('RG', order!.client.rg),
                info('CPF', order!.client.cpf),
                info('CEP cobrança', order!.client.postalCode),
                info('Rua cobrança', order!.client.street),
                info('Número cobrança', order!.client.number),
                info('Bairro cobrança', order!.client.neighborhood),
                info('Complemento cobrança', order!.client.complement),
                info('Cidade cobrança', order!.client.city),
                info('CEP obra', order!.workPostalCode),
                info('Rua obra', order!.workStreet),
                info('Número obra', order!.workNumber),
                info('Bairro obra', order!.workNeighborhood),
                info('Complemento obra', order!.workComplement),
                info('Número da proposta', order!.commercialProposalNumber),
                info(
                  'Valor consolidado',
                  order!.value == 0 ? '' : order!.value.toStringAsFixed(2),
                ),
                info('Pagamento', order!.paymentType),
                info('Forma de pagamento', order!.paymentMethod),
                info('Valor da parcela', order!.installmentValue),
                info('Qtde de parcelas', order!.installmentCount),
                infoFull('Observação comercial', order!.paymentObservation),
                info('Data do pagamento', order!.paymentDate),
                info('Valor RT', order!.rtValue),
                info('Nome do arquiteto', order!.architectName),
                info('Valor integrador', order!.integratorValue),
                info('Nome do integrador', order!.integratorName),
                info('Já é cliente DANF?', order!.isDanfClient),
                info('DANF faz a instalação?', order!.danfInstallerName),
                info('Pode ter placa DANF?', order!.canHaveDanfPlate),
                info('Tem grupo no WhatsApp?', order!.hasWhatsappGroup),
                infoFull('Serviços da etapa 2', stage2ServicesSummary),
                infoFull(
                  'Membros do grupo de WhatsApp',
                  whatsappMembersSummary,
                ),
                infoFull(
                  'Observação do grupo de WhatsApp',
                  order!.whatsappGroupObservation,
                ),
              ],
            ],
          );
        },
      ),
    );
    final serviceOrderSection = !isServiceOrder
        ? null
        : _CollapsibleDetailSection(
            title: 'Ordem de serviço',
            subtitle:
                'Resumo operacional da OS, emissão do PDF e aprovação do cliente.',
            initiallyExpanded: isFinanceStage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceOrderSummaryCard(
                  order: order!,
                  canEdit: showFlowActions,
                  onAttachServiceOrderPdf: onAttachServiceOrderPdf,
                  onToggleFinanceClientApproval: onToggleFinanceClientApproval,
                ),
                if (showFlowActions &&
                    isFinanceStage &&
                    !order!.financeClientApproved) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Confirme a aprovação do cliente no Financeiro antes de avançar a OS.',
                    style: TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ],
              ],
            ),
          );
    final financeContractSection = !showFinanceContractSection
        ? null
        : _CollapsibleDetailSection(
            title: 'Financeiro',
            subtitle:
                'Kanban interno de contrato para acompanhar emissão, envio, assinatura e contas a receber.',
            initiallyExpanded: isFinanceStage,
            child: _FinanceContractChecklistCard(
              order: order!,
              isEditable: showFlowActions && isFinanceStage,
              onAttachContract: onAttachContract,
              onStatusChanged: onUpdateFinanceContractStatus,
            ),
          );
    final relationshipSection = !showRelationshipSection
        ? null
        : _CollapsibleDetailSection(
            title: 'Relacionamento',
            subtitle:
                'Kanban interno para acompanhar aguardando, execução e conclusão antes do encaminhamento.',
            initiallyExpanded: isRelationshipStage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RelationshipChecklistCard(
                  order: order!,
                  isEditable: showFlowActions && isRelationshipStage,
                  onStatusChanged: onUpdateRelationshipKanbanStatus,
                ),
                if (showFlowActions &&
                    isRelationshipStage &&
                    !relationshipKanbanFlow.isComplete) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Conclua o kanban do Relacionamento antes de encaminhar o pedido.',
                    style: TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ],
              ],
            ),
          );
    final showEstimatingMetaSection =
        !isServiceOrder && (isEstimatingStage || isEngineeringStage);
    final estimatingMetaSection = !showEstimatingMetaSection
        ? null
        : _CollapsibleDetailSection(
            title: 'Estimativa',
            subtitle: isEstimatingStage
                ? 'Campo obrigatório do Orçamentista, compartilhado com a Engenharia.'
                : 'Informação compartilhada pelo Orçamentista para a Engenharia.',
            initiallyExpanded: isEstimatingStage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _InfoRow(
                      label: 'Foi estimativa?',
                      value: order!.estimatingWasEstimate.trim().isEmpty
                          ? 'Não informado'
                          : order!.estimatingWasEstimate,
                      emphasizeValue: order!.estimatingWasEstimate
                          .trim()
                          .isNotEmpty,
                    ),
                  ),
                  if (canSetEstimatingWasEstimate) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onSetEstimatingWasEstimate!();
                      },
                      icon: const Icon(Icons.rule_folder_outlined),
                      label: Text(
                        order!.estimatingWasEstimate.trim().isEmpty
                            ? 'Definir'
                            : 'Editar',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
    final showCommercialInfoSection =
        !showFullCustomerRegistrationData && isFinanceStage;
    final commercialInfoSection = !showCommercialInfoSection
        ? null
        : _CollapsibleDetailSection(
            title: 'Informações Comerciais',
            subtitle: 'Dados de pagamento, proposta e condições comerciais.',
            initiallyExpanded: isFinanceStage,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final spacing = 14.0;
                final useTwoColumns = constraints.maxWidth >= 700;
                final itemWidth = useTwoColumns
                    ? (constraints.maxWidth - spacing) / 2
                    : constraints.maxWidth;
                final fullWidth = useTwoColumns
                    ? constraints.maxWidth
                    : itemWidth;

                Widget infoRow(
                  String label,
                  String value, {
                  bool emphasize = false,
                  bool full = false,
                }) =>
                    SizedBox(
                      width: full ? fullWidth : itemWidth,
                      child: _InfoRow(
                        label: label,
                        value: value.trim().isEmpty ? 'Não informado' : value,
                        emphasizeValue: emphasize,
                      ),
                    );

                final rows = <Widget>[
                  infoRow('Data de nascimento', order!.client.birthDate),
                  infoRow('E-mail', order!.client.email),
                  infoRow('RG', order!.client.rg),
                  infoRow('CPF', order!.client.cpf),
                  infoRow('Telefone', order!.client.phone),
                  infoRow('CEP cobrança', order!.client.postalCode),
                  infoRow('Rua cobrança', order!.client.street),
                  infoRow('Número cobrança', order!.client.number),
                  infoRow('Bairro cobrança', order!.client.neighborhood),
                  infoRow('Complemento cobrança', order!.client.complement),
                  infoRow('Cidade cobrança', order!.client.city),
                  if (order!.commercialProposalNumber.trim().isNotEmpty)
                    infoRow('Nº da proposta', order!.commercialProposalNumber, emphasize: true),
                  infoRow('Tipo de pagamento', order!.paymentType),
                  infoRow('Forma de pagamento', order!.paymentMethod),
                  if (order!.installmentValue.trim().isNotEmpty)
                    infoRow('Valor da parcela', order!.installmentValue),
                  if (order!.installmentCount.trim().isNotEmpty)
                    infoRow('Qtde de parcelas', order!.installmentCount),
                  if (order!.paymentDate.trim().isNotEmpty)
                    infoRow('Data do pagamento', order!.paymentDate),
                  infoRow('Observação', order!.paymentObservation, full: true),
                  if (order!.rtValue.trim().isNotEmpty)
                    infoRow('Valor RT', order!.rtValue),
                  if (order!.integratorValue.trim().isNotEmpty)
                    infoRow('Valor integrador', order!.integratorValue),
                  if (order!.integratorName.trim().isNotEmpty)
                    infoRow('Integrador', order!.integratorName),
                  if (order!.architectName.trim().isNotEmpty)
                    infoRow('Arquiteto', order!.architectName),
                ];

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: rows,
                );
              },
            ),
          );
    final estimatingSection = isServiceOrder
        ? null
        : _CollapsibleDetailSection(
            title: 'Levantamento do Orçamentista',
            subtitle:
                'Quantidade de visitas inclusas e lista de materiais do orçamento.',
            initiallyExpanded: isEstimatingStage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mergedSubProposals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StatusBadge(
                      label: _proposalBadgeLabel(order!),
                      color: const Color(0xFF475569),
                    ),
                  ),
                _EstimatingWorksheetSummaryCard(
                  order: order!,
                  canEdit: showFlowActions && isEstimatingStage,
                  onEditWorksheet: onAttachMaterials,
                  showConsolidatedProjects: isEngineeringStage,
                ),
                ...mergedSubProposals.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StatusBadge(
                            label: _proposalBadgeLabel(p),
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                        _EstimatingWorksheetSummaryCard(
                          order: p,
                          canEdit: false,
                          onEditWorksheet: null,
                          showConsolidatedProjects: isEngineeringStage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
    final proposalExtensionsSection = relatedProposals.length <= 1
        ? null
        : _CollapsibleDetailSection(
            title: 'Propostas vinculadas',
            subtitle:
                'As propostas deste cliente ficam conectadas ao card principal.',
            initiallyExpanded: false,
            child: _ProposalExtensionsCard(
              currentOrder: order!,
              proposals: relatedProposals,
            ),
          );
    final engineeringSection = !showEngineeringSection
        ? null
        : _CollapsibleDetailSection(
            title: 'Engenharia',
            subtitle:
                'Checklist técnico, arquivos e agendamentos vinculados à obra.',
            initiallyExpanded: isEngineeringStage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showEngineeringChecklist)
                  _EngineeringChecklistCard(
                    order: order!,
                    isEditable: canEditEngineeringSection,
                    onScheduleActivity: onScheduleEngineeringActivity,
                    onStatusChanged: onUpdateEngineeringChecklistStatus,
                  ),
                if (showEngineeringFilesInEngineering) ...[
                  if (showEngineeringChecklist) const SizedBox(height: 12),
                  _FileInfoRow(
                    label: 'Projeto elétrico',
                    value: hasElectricalProject
                        ? order!.electricalProjectFileName
                        : 'Arquivo ainda não anexado',
                    filePath: order!.electricalProjectFilePath,
                    status: hasElectricalProject
                        ? _FileInfoStatus.available
                        : _FileInfoStatus.missing,
                  ),
                  _FileInfoRow(
                    label: 'Layout do painel',
                    value: hasPanelLayout
                        ? order!.panelLayoutFileName
                        : 'Arquivo ainda não anexado',
                    filePath: order!.panelLayoutFilePath,
                    status: hasPanelLayout
                        ? _FileInfoStatus.available
                        : _FileInfoStatus.missing,
                  ),
                  _FileInfoRow(
                    label: 'Tabela de pulsadores',
                    value: hasPushButtonTable
                        ? order!.pushButtonTableFileName
                        : 'Arquivo ainda não anexado',
                    filePath: order!.pushButtonTableFilePath,
                    status: hasPushButtonTable
                        ? _FileInfoStatus.available
                        : _FileInfoStatus.missing,
                  ),
                  _FileInfoRow(
                    label: 'Dados',
                    value: hasEngineeringData
                        ? order!.engineeringDataFileName
                        : 'Arquivo ainda não anexado',
                    filePath: order!.engineeringDataFilePath,
                    status: hasEngineeringData
                        ? _FileInfoStatus.available
                        : _FileInfoStatus.missing,
                  ),
                ],
                if (canEditEngineeringSection) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onAttachElectricalProject == null
                            ? null
                            : () async {
                                await onAttachElectricalProject!();
                              },
                        style: _attachmentReadyButtonStyle(
                          hasElectricalProject,
                        ),
                        icon: Icon(
                          hasElectricalProject
                              ? Icons.upload_file_outlined
                              : Icons.note_add_outlined,
                        ),
                        label: Text(
                          hasElectricalProject
                              ? 'Trocar projeto elétrico'
                              : 'Anexar projeto elétrico',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onAttachPanelLayout == null
                            ? null
                            : () async {
                                await onAttachPanelLayout!();
                              },
                        style: _attachmentReadyButtonStyle(hasPanelLayout),
                        icon: Icon(
                          hasPanelLayout
                              ? Icons.upload_file_outlined
                              : Icons.note_add_outlined,
                        ),
                        label: Text(
                          hasPanelLayout
                              ? 'Trocar layout do painel'
                              : 'Anexar layout do painel',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onAttachPushButtonTable == null
                            ? null
                            : () async {
                                await onAttachPushButtonTable!();
                              },
                        style: _attachmentReadyButtonStyle(hasPushButtonTable),
                        icon: Icon(
                          hasPushButtonTable
                              ? Icons.upload_file_outlined
                              : Icons.note_add_outlined,
                        ),
                        label: Text(
                          hasPushButtonTable
                              ? 'Trocar tabela de pulsadores'
                              : 'Anexar tabela de pulsadores',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onAttachEngineeringData == null
                            ? null
                            : () async {
                                await onAttachEngineeringData!();
                              },
                        style: _attachmentReadyButtonStyle(hasEngineeringData),
                        icon: Icon(
                          hasEngineeringData
                              ? Icons.upload_file_outlined
                              : Icons.note_add_outlined,
                        ),
                        label: Text(
                          hasEngineeringData
                              ? 'Trocar arquivo de dados'
                              : 'Anexar arquivo de dados',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
    final assemblyTeamSection =
        order!.currentStage == WorkflowStage.installation ||
            (order!.currentStage != WorkflowStage.assembly &&
                assemblyAssignedProfiles.isEmpty)
        ? null
        : _CollapsibleDetailSection(
            title: 'Equipe da montagem',
            subtitle: 'Funcionários selecionados para executar esta montagem.',
            initiallyExpanded: order!.currentStage == WorkflowStage.assembly,
            child: assemblyAssignedProfiles.isEmpty
                ? const Text(
                    'Nenhum funcionário definido',
                    style: TextStyle(fontSize: 14),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: assemblyAssignedProfiles
                        .map(
                          (profile) => Tooltip(
                            message: profile.name.trim().isEmpty
                                ? profile.login
                                : profile.name,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: profile.accent.withValues(
                                alpha: 0.15,
                              ),
                              backgroundImage: _resolveProfileImageProvider(
                                profile.photoFilePath,
                              ),
                              onBackgroundImageError: (_, _) {},
                              child:
                                  profile.photoFilePath == null ||
                                      profile.photoFilePath!.trim().isEmpty
                                  ? Text(
                                      profile.name.trim().isEmpty
                                          ? profile.login
                                                .trim()
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : profile.name
                                                .trim()
                                                .substring(0, 1)
                                                .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: profile.accent,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          );
    final installationSection = !isInstallationStage
        ? null
        : _CollapsibleDetailSection(
            title: 'Calendário de instalação',
            subtitle:
                'Defina a data da visita, equipe responsável e observações.',
            initiallyExpanded: true,
            child: _InstallationScheduleCard(
              order: order!,
              workspaceProfiles: workspaceProfiles,
              canEdit: showFlowActions,
              onScheduleInstallation: onScheduleInstallation,
              onToggleExecutionItem: onToggleInstallationExecutionItem,
            ),
          );
    final stageOwnersSection = stageOwners.isEmpty
        ? null
        : _CollapsibleDetailSection(
            title: 'Responsáveis por etapa',
            subtitle:
                'Veja de forma compacta quem passou por cada ponto do fluxo.',
            initiallyExpanded: false,
            child: _StageOwnersSection(owners: stageOwners, showHeader: false),
          );
    final serviceOrderFlowIndex = isServiceOrder
        ? _serviceOrderFlowStageIndex(order!)
        : -1;
    final flowSection = showFlowActions
        ? _CollapsibleDetailSection(
            title: 'Passagem do fluxo',
            subtitle: isServiceOrder
                ? 'Histórico das etapas da ordem de serviço até a baixa financeira.'
                : 'Histórico das etapas concluídas neste pedido.',
            initiallyExpanded: false,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: isServiceOrder
                  ? _serviceOrderFlowSteps
                        .asMap()
                        .entries
                        .map((entry) {
                          final stepIndex = entry.key;
                          final step = entry.value;
                          final isPast = stepIndex <= serviceOrderFlowIndex;
                          return Container(
                            width: 152,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isPast
                                  ? step.color.withValues(alpha: 0.12)
                                  : subtleSurfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPast ? step.color : subtleBorderColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(step.icon, color: step.color),
                                const SizedBox(height: 8),
                                Text(
                                  step.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _serviceOrderFlowHistory(order!, stepIndex),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(growable: false)
                  : workflowStages
                        .map((stage) {
                          final isPast =
                              workflowStages.indexOf(stage) <= stageIndex;
                          return Container(
                            width: 152,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isPast
                                  ? stage.color.withValues(alpha: 0.12)
                                  : subtleSurfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPast ? stage.color : subtleBorderColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(stage.icon, color: stage.color),
                                const SizedBox(height: 8),
                                Text(
                                  stage.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  order!.history[stage] ?? 'Aguardando etapa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(growable: false),
            ),
          )
        : null;

    final primaryBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderDetailsHero(
          order: order!,
          allOrders: allOrders,
          secondaryTextColor: secondaryTextColor,
          headerActionPanel: headerActionPanel,
          headerActions: headerActions,
          showStandaloneEditAction: showStandaloneEditAction,
          inlineHeaderMinWidth: inlineHeaderMinWidth,
          progressTrackColor: progressTrackColor,
        ),
        const SizedBox(height: 18),
        customerDataSection,
        if (relationshipSection != null) ...[
          const SizedBox(height: 12),
          relationshipSection,
        ],
        if (estimatingMetaSection != null) ...[
          const SizedBox(height: 12),
          estimatingMetaSection,
        ],
        if (financeContractSection != null) ...[
          const SizedBox(height: 12),
          financeContractSection,
        ],
        if (commercialInfoSection != null) ...[
          const SizedBox(height: 12),
          commercialInfoSection,
        ],
        if (estimatingSection != null) ...[
          const SizedBox(height: 12),
          estimatingSection,
        ],
        if (serviceOrderSection != null) ...[
          const SizedBox(height: 12),
          serviceOrderSection,
        ],
        if (proposalExtensionsSection != null) ...[
          const SizedBox(height: 12),
          proposalExtensionsSection,
        ],
        if (engineeringSection != null) ...[
          const SizedBox(height: 12),
          engineeringSection,
        ],
        if (assemblyChecklistSection != null) ...[
          const SizedBox(height: 12),
          assemblyChecklistSection,
        ],
        if (assemblyTeamSection != null) ...[
          const SizedBox(height: 12),
          assemblyTeamSection,
        ],
        if (installationSection != null) ...[
          const SizedBox(height: 12),
          installationSection,
        ],
        if (stageOwnersSection != null) ...[
          const SizedBox(height: 12),
          stageOwnersSection,
        ],
        if (flowSection != null) ...[const SizedBox(height: 12), flowSection],
      ],
    );

    if (mergedSubProposals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(context),
        child: primaryBody,
      );
    }

    final tabCount = 1 + mergedSubProposals.length;
    return DefaultTabController(
      length: tabCount,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProposalTabBar(
              primaryOrder: order!,
              secondaryOrders: mergedSubProposals,
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final tc = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: tc,
                  builder: (context, _) {
                    if (tc.index == 0) return primaryBody;
                    return _SecondaryProposalPanelContent(
                      order: mergedSubProposals[tc.index - 1],
                      isDarkMode: isDarkMode,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalTabBar extends StatelessWidget {
  const _ProposalTabBar({
    required this.primaryOrder,
    required this.secondaryOrders,
  });

  final WorkflowOrder primaryOrder;
  final List<WorkflowOrder> secondaryOrders;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final amber = const Color(0xFFB45309);
    final borderColor =
        isDarkMode ? const Color(0xFF3E4044) : const Color(0xFFE8E8E5);
    final surfaceColor =
        isDarkMode ? const Color(0xFF26282B) : Colors.white;
    final selectedBg = amber.withValues(alpha: isDarkMode ? 0.14 : 0.08);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF202225) : const Color(0xFFF5F5F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: selectedBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: amber.withValues(alpha: 0.35)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: amber,
        unselectedLabelColor:
            isDarkMode ? const Color(0xFFA3A39E) : const Color(0xFF6B6B68),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.looks_one_outlined, size: 14),
                const SizedBox(width: 5),
                Text(_proposalBadgeLabel(primaryOrder)),
              ],
            ),
          ),
          ...secondaryOrders.map(
            (p) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded, size: 13),
                  const SizedBox(width: 5),
                  Text(_proposalBadgeLabel(p)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryProposalPanelContent extends StatelessWidget {
  const _SecondaryProposalPanelContent({
    required this.order,
    required this.isDarkMode,
  });

  final WorkflowOrder order;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor =
        isDarkMode ? const Color(0xFFF2F2F0) : const Color(0xFF1A1A1A);
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFA3A39E) : const Color(0xFF6B6B68);
    final borderColor =
        isDarkMode ? const Color(0xFF3E4044) : const Color(0xFFE8E8E5);
    final surfaceColor =
        isDarkMode ? const Color(0xFF202225) : const Color(0xFFF5F5F3);
    final stageColor = order.currentStage.color;

    Widget infoRow(String label, String value, {bool emphasize = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ),
            Expanded(
              child: Text(
                value.trim().isEmpty ? '—' : value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      emphasize ? FontWeight.w700 : FontWeight.w400,
                  color: primaryTextColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasAddress = order.address.trim().isNotEmpty;
    final hasNextAction = order.nextAction.trim().isNotEmpty;
    final hasBlocker = order.blocker.trim().isNotEmpty;
    final visitPlanned = _plannedVisitCountForOrder(order);
    final hasWorksheet = order.estimatingIncludedVisits.isNotEmpty &&
        order.estimatingMaterials.isNotEmpty;
    final isAtFinanceOrBeyond = order.currentStage == WorkflowStage.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header badges
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(
              label: _proposalBadgeLabel(order),
              color: const Color(0xFF1D4ED8),
            ),
            _StatusBadge(
              label: order.currentStage.title,
              color: stageColor,
            ),
            const _StatusBadge(
              label: 'Sub-elemento',
              color: Color(0xFFB45309),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Main info container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.workName.trim().isEmpty ? '(sem nome de obra)' : order.workName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              if (hasAddress) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: secondaryTextColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.address,
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Next action + blocker
        if (hasNextAction || hasBlocker) ...[
          const SizedBox(height: 12),
          _CollapsibleDetailSection(
            title: 'Ação e bloqueios',
            subtitle: 'Próxima ação e impedimentos registrados nesta proposta.',
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNextAction)
                  infoRow('Próxima ação', order.nextAction),
                if (hasBlocker)
                  infoRow('Bloqueio', order.blocker),
              ],
            ),
          ),
        ],

        // Estimating worksheet
        if (hasWorksheet || visitPlanned > 0) ...[
          const SizedBox(height: 12),
          _CollapsibleDetailSection(
            title: 'Levantamento do Orçamentista',
            subtitle: 'Visitas inclusas e materiais desta proposta.',
            initiallyExpanded: true,
            child: _EstimatingWorksheetSummaryCard(
              order: order,
              canEdit: false,
              onEditWorksheet: null,
              showConsolidatedProjects:
                  order.currentStage == WorkflowStage.engineering,
            ),
          ),
        ],

        // Commercial info — shown only at the finance stage
        if (isAtFinanceOrBeyond) ...[
          const SizedBox(height: 12),
          _CollapsibleDetailSection(
            title: 'Informações Comerciais',
            subtitle: 'Dados financeiros e de pagamento desta proposta.',
            initiallyExpanded: true,
            child: Builder(
              builder: (context) {
                final rows = <Widget>[
                  if (order.commercialProposalNumber.trim().isNotEmpty)
                    infoRow('Nº da proposta', order.commercialProposalNumber, emphasize: true),
                  if (order.paymentType.trim().isNotEmpty)
                    infoRow('Tipo de pagamento', order.paymentType),
                  if (order.paymentMethod.trim().isNotEmpty)
                    infoRow('Forma de pagamento', order.paymentMethod),
                  if (order.installmentValue.trim().isNotEmpty)
                    infoRow('Valor da parcela', order.installmentValue),
                  if (order.installmentCount.trim().isNotEmpty)
                    infoRow('Qtde de parcelas', order.installmentCount),
                  if (order.paymentDate.trim().isNotEmpty)
                    infoRow('Data do pagamento', order.paymentDate),
                  if (order.paymentObservation.trim().isNotEmpty)
                    infoRow('Observação', order.paymentObservation),
                  if (order.rtValue.trim().isNotEmpty)
                    infoRow('Valor RT', order.rtValue),
                  if (order.integratorValue.trim().isNotEmpty)
                    infoRow('Valor integrador', order.integratorValue),
                  if (order.integratorName.trim().isNotEmpty)
                    infoRow('Integrador', order.integratorName),
                  if (order.architectName.trim().isNotEmpty)
                    infoRow('Arquiteto', order.architectName),
                ];
                if (rows.isEmpty) {
                  return Text(
                    'Nenhuma informação comercial preenchida ainda.',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows,
                );
              },
            ),
          ),
        ],

        // Identification
        const SizedBox(height: 12),
        _CollapsibleDetailSection(
          title: 'Identificação',
          subtitle: 'Código e versão desta proposta secundária.',
          initiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              infoRow('Código', order.code),
              infoRow('Versão', 'Proposta ${order.proposalVersion}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceOrderSummaryCard extends StatelessWidget {
  const _ServiceOrderSummaryCard({
    required this.order,
    required this.canEdit,
    this.onAttachServiceOrderPdf,
    this.onToggleFinanceClientApproval,
  });

  final WorkflowOrder order;
  final bool canEdit;
  final Future<void> Function()? onAttachServiceOrderPdf;
  final Future<void> Function()? onToggleFinanceClientApproval;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? const Color(0xFF2F3134)
        : const Color(0xFFE8E8E5);
    final surfaceColor = isDarkMode
        ? const Color(0xFF26282B)
        : const Color(0xFFF5F5F3);
    final secondaryTextColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final hasPdf = order.serviceOrderFileName.trim().isNotEmpty;
    final approvalColor = order.financeClientApproved
        ? const Color(0xFF15803D)
        : const Color(0xFFB45309);
    String? latestServiceTime() {
      for (
        var index = order.installationVisitHistory.length - 1;
        index >= 0;
        index--
      ) {
        final serviceTime = order.installationVisitHistory[index].serviceTime
            .trim();
        if (serviceTime.isNotEmpty) {
          return serviceTime;
        }
      }
      return null;
    }

    final serviceTime = order.isServiceOrder ? latestServiceTime() : null;
    final openingObservation = order.serviceDescription.trim();
    final completionObservation =
        order.installationWorkflowStatus == InstallationWorkflowStatus.done
        ? order.installationNotes.trim()
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isDarkMode ? 1.1 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.financeClientApproved) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF15803D).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF15803D).withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified_rounded, color: Color(0xFF15803D)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ordem de serviço aprovada',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const _StatusBadge(
                          label: 'Ordem de serviço',
                          color: Color(0xFF92400E),
                        ),
                        _StatusBadge(
                          label: order.financeClientApproved
                              ? 'Cliente aprovado'
                              : 'Aguardando aprovação',
                          color: order.financeClientApproved
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      order.serviceDescription.trim().isEmpty
                          ? 'Sem detalhes informados.'
                          : order.serviceDescription,
                      style: TextStyle(color: secondaryTextColor, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 720;
              final itemWidth = useTwoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _InfoRow(
                      label: 'Tipo',
                      value: order.kind.title,
                      emphasizeValue: true,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoRow(
                      label: 'Status financeiro',
                      value: order.financeClientApproved
                          ? 'Cliente aprovado'
                          : 'Aguardando aprovação do cliente',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoRow(
                      label: 'Próxima ação',
                      value: order.nextAction,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoRow(
                      label: 'Observação para abertura de OS',
                      value: openingObservation.isEmpty
                          ? 'Não informado'
                          : openingObservation,
                    ),
                  ),
                  if (order.isServiceOrder)
                    SizedBox(
                      width: itemWidth,
                      child: _InfoRow(
                        label: 'Tempo de serviço',
                        value: serviceTime ?? 'Não informado',
                      ),
                    ),
                  if (completionObservation.isNotEmpty)
                    SizedBox(
                      width: itemWidth,
                      child: _InfoRow(
                        label: 'Observação conclusão OS',
                        value: completionObservation,
                      ),
                    ),
                  SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: approvalColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: approvalColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirmação do Financeiro',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            order.financeClientApproved
                                ? 'Aprovado'
                                : 'Pendente',
                            style: TextStyle(
                              color: approvalColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (canEdit &&
                              order.currentStage == WorkflowStage.finance &&
                              onToggleFinanceClientApproval != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await onToggleFinanceClientApproval!();
                              },
                              icon: Icon(
                                order.financeClientApproved
                                    ? Icons.undo_outlined
                                    : Icons.check_circle_outline,
                              ),
                              label: Text(
                                order.financeClientApproved
                                    ? 'Remover aprovação'
                                    : 'Confirmar aprovação',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canEdit &&
                  order.currentStage == WorkflowStage.estimating &&
                  onAttachServiceOrderPdf != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await onAttachServiceOrderPdf!();
                  },
                  style: _attachmentReadyButtonStyle(hasPdf),
                  icon: Icon(
                    hasPdf
                        ? Icons.upload_file_outlined
                        : Icons.picture_as_pdf_outlined,
                  ),
                  label: Text(hasPdf ? 'Trocar PDF da OS' : 'Anexar PDF da OS'),
                ),
              if (canEdit &&
                  order.currentStage == WorkflowStage.finance &&
                  onToggleFinanceClientApproval != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await onToggleFinanceClientApproval!();
                  },
                  icon: Icon(
                    order.financeClientApproved
                        ? Icons.undo_outlined
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    order.financeClientApproved
                        ? 'Remover aprovação'
                        : 'Confirmar aprovação',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProposalExtensionsCard extends StatelessWidget {
  const _ProposalExtensionsCard({
    required this.currentOrder,
    required this.proposals,
  });

  final WorkflowOrder currentOrder;
  final List<WorkflowOrder> proposals;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);
    final surfaceColor = isDarkMode
        ? const Color(0xFF1C1D20)
        : const Color(0xFFF5F5F3);
    final secondaryTextColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...proposals.map(
            (proposal) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: proposal.code == currentOrder.code
                      ? proposal.currentStage.color.withValues(alpha: 0.05)
                      : isDarkMode
                      ? const Color(0xFF1C1D20)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: proposal.code == currentOrder.code
                        ? proposal.currentStage.color.withValues(alpha: 0.4)
                        : borderColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusBadge(
                          label: _proposalVersionTitle(proposal),
                          color: proposal.proposalVersion > 1
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF475569),
                        ),
                        _StatusBadge(
                          label: proposal.currentStage.title,
                          color: proposal.currentStage.color,
                        ),
                        if (proposal.code == currentOrder.code)
                          const _StatusBadge(
                            label: 'Selecionada',
                            color: Color(0xFF0F766E),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      proposal.workName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_displayOrderCode(proposal, proposals)} • ${proposal.client.name}',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
InstallationVisitLog? _plannedVisitForCurrentInstallationSchedule(
  WorkflowOrder order,
) {
  final scheduledAt = order.installationScheduledAt;
  if (scheduledAt == null) {
    return null;
  }

  for (
    var index = order.installationVisitHistory.length - 1;
    index >= 0;
    index--
  ) {
    final visit = order.installationVisitHistory[index];
    if (visit.plannedItems.isNotEmpty &&
        visit.scheduledAt.year == scheduledAt.year &&
        visit.scheduledAt.month == scheduledAt.month &&
        visit.scheduledAt.day == scheduledAt.day &&
        visit.scheduledAt.hour == scheduledAt.hour &&
        visit.scheduledAt.minute == scheduledAt.minute) {
      return visit;
    }
  }
  return null;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.allOrders,
    required this.selected,
    required this.onTap,
    required this.onOpenConversation,
    required this.workspaceProfiles,
    this.onMoveToCompleted,
    this.onUnmergeProposal,
  });

  final WorkflowOrder order;
  final List<WorkflowOrder> allOrders;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenConversation;
  final List<EmployeeWorkspaceProfile> workspaceProfiles;
  final Future<void> Function()? onMoveToCompleted;
  final Future<void> Function(WorkflowOrder secondary)? onUnmergeProposal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBackgroundColor = selected
        ? (isDarkMode ? const Color(0xFF26282B) : const Color(0xFFF5F5F3))
        : isDarkMode
        ? const Color(0xFF26282B)
        : Colors.white;
    final cardBorderColor = selected
        ? order.currentStage.color
        : isDarkMode
        ? const Color(0xFF6B6B68)
        : const Color(0xFFE8E8E5);
    final primaryTextColor = selected
        ? (isDarkMode ? const Color(0xFFF2F2F0) : const Color(0xFF1A1A1A))
        : isDarkMode
        ? const Color(0xFFF2F2F0)
        : const Color(0xFF1A1A1A);
    final secondaryTextColor = selected
        ? (isDarkMode ? const Color(0xFFA3A39E) : const Color(0xFF6B6B68))
        : isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final progressTrackColor = selected
        ? const Color(0xFFE8E8E5)
        : isDarkMode
        ? const Color(0xFF2F3134)
        : const Color(0xFFE8E8E5);
    final linkedProposals = _proposalExtensionsForPrimary(allOrders, order);
    final hasMergedProposals = linkedProposals.any(_isSubProposal);
    final proposalBadgeColor = linkedProposals.isNotEmpty
        ? const Color(0xFFB45309)
        : order.proposalVersion > 1
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF475569);
    final assemblyProfiles = _assemblyAssignedProfilesForOrder(
      order,
      workspaceProfiles,
    );
    final proposalSummary = linkedProposals.isNotEmpty
        ? '${linkedProposals.length + 1} propostas'
        : _proposalBadgeLabel(order);
    final displayCode = _displayOrderCode(order, allOrders);
    final effectiveProgress = _effectiveOrderProgress(order);
    final mergedLinked = linkedProposals.where(_isSubProposal).toList();
    final visitProgressLabel = order.isServiceOrder
        ? null
        : () {
            final allGroup = [order, ...mergedLinked];
            final planned = allGroup.fold<int>(
              0,
              (s, o) => s + _plannedVisitCountForOrder(o),
            );
            if (planned <= 0) return null;
            final completed = _completedVisitCountForOrder(order);
            return '$completed/$planned';
          }();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorderColor, width: selected ? 1.4 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayCode,
                        style: TextStyle(
                          color: order.currentStage.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.workName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (order.isServiceOrder)
                            const Text(
                              'OS',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasMergedProposals)
                                Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(
                                    Icons.merge_type_rounded,
                                    size: 12,
                                    color: proposalBadgeColor,
                                  ),
                                ),
                              Text(
                                proposalSummary,
                                style: TextStyle(
                                  color: proposalBadgeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: order.currentStage.title,
                  color: order.currentStage.color,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${order.client.name} • ${order.client.phone}',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Cliente ${order.client.id}',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            if (order.currentStage == WorkflowStage.estimating &&
                order.commercialProposalNumber.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Pedido nº ${order.commercialProposalNumber}',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (order.currentStage == WorkflowStage.engineering) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: WorkflowStage.engineering.color.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _engineeringFlowSnapshot(order).currentTask?.label ??
                      'Checklist concluído',
                  style: TextStyle(
                    color: WorkflowStage.engineering.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: effectiveProgress,
                minHeight: 6,
                backgroundColor: progressTrackColor,
                valueColor: AlwaysStoppedAnimation(order.currentStage.color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              order.nextAction,
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (visitProgressLabel != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Text(
                  visitProgressLabel,
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            if (assemblyProfiles.isNotEmpty &&
                order.currentStage != WorkflowStage.installation) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: assemblyProfiles
                    .map(
                      (profile) => Tooltip(
                        message: profile.name.trim().isEmpty
                            ? profile.login
                            : profile.name,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: profile.accent.withValues(
                            alpha: 0.15,
                          ),
                          backgroundImage: _resolveProfileImageProvider(
                            profile.photoFilePath,
                          ),
                          onBackgroundImageError: (_, _) {},
                          child:
                              profile.photoFilePath == null ||
                                  profile.photoFilePath!.trim().isEmpty
                              ? Text(
                                  profile.name.trim().isEmpty
                                      ? profile.login
                                            .trim()
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : profile.name
                                            .trim()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: profile.accent,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (linkedProposals.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MergedProposalsCardSection(
                primaryOrder: order,
                linkedProposals: linkedProposals,
                isDarkMode: isDarkMode,
                onUnmerge: onUnmergeProposal,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onOpenConversation,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    foregroundColor: order.currentStage.color,
                    backgroundColor: order.currentStage.color.withValues(
                      alpha: 0.08,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text(
                    order.conversationMessages.isEmpty
                        ? 'Conversa'
                        : 'Conversa (${order.conversationMessages.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onMoveToCompleted != null)
                  TextButton.icon(
                    onPressed: () => onMoveToCompleted!(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      foregroundColor: InstallationWorkflowStatus.done.color,
                      backgroundColor: InstallationWorkflowStatus.done.color
                          .withValues(alpha: 0.08),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text(
                      'Mover para Concluído',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MergeCandidatesBanner extends StatelessWidget {
  const _MergeCandidatesBanner({
    required this.candidates,
    required this.allOrders,
    required this.onMerge,
  });

  final List<WorkflowOrder> candidates;
  final List<WorkflowOrder> allOrders;
  final Future<void> Function(WorkflowOrder secondary)? onMerge;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final amber = const Color(0xFFB45309);
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: isDarkMode ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.merge_type_rounded, color: amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  candidates.length == 1
                      ? 'Uma proposta pode ser juntada ao card principal'
                      : '${candidates.length} propostas podem ser juntadas ao card principal',
                  style: TextStyle(
                    color: amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...candidates.map((secondary) {
            final primary = _proposalGroupOrders(allOrders, secondary)
                .firstWhere(
                  (o) => o.isPrimaryProposal,
                  orElse: () => secondary,
                );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF202225)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          secondary.client.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? const Color(0xFFF2F2F0)
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          children: [
                            _StatusBadge(
                              label: _proposalBadgeLabel(primary),
                              color: const Color(0xFF475569),
                            ),
                            Icon(
                              Icons.add_rounded,
                              size: 12,
                              color: isDarkMode
                                  ? const Color(0xFFA3A39E)
                                  : const Color(0xFF6B6B68),
                            ),
                            _StatusBadge(
                              label: _proposalBadgeLabel(secondary),
                              color: const Color(0xFF1D4ED8),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onMerge == null
                          ? null
                          : () => onMerge!(secondary),
                      style: FilledButton.styleFrom(
                        backgroundColor: amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.merge_type_rounded, size: 15),
                      label: const Text(
                        'Juntar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MergedProposalsCardSection extends StatelessWidget {
  const _MergedProposalsCardSection({
    required this.primaryOrder,
    required this.linkedProposals,
    required this.isDarkMode,
    this.onUnmerge,
  });

  final WorkflowOrder primaryOrder;
  final List<WorkflowOrder> linkedProposals;
  final bool isDarkMode;
  final Future<void> Function(WorkflowOrder secondary)? onUnmerge;

  @override
  Widget build(BuildContext context) {
    final stageColor = primaryOrder.currentStage.color;
    final hasMerged = linkedProposals.any(_isSubProposal);
    final accentColor = hasMerged
        ? const Color(0xFFB45309)
        : stageColor;
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);
    final primaryTextColor =
        isDarkMode ? const Color(0xFFF2F2F0) : const Color(0xFF1A1A1A);
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFA3A39E) : const Color(0xFF6B6B68);

    Widget proposalPill(WorkflowOrder p, {required bool isPrimary}) {
      final badgeColor = isPrimary
          ? const Color(0xFF475569)
          : const Color(0xFF1D4ED8);
      final isMerged = !isPrimary && _isSubProposal(p);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: p.currentStage.color.withValues(
            alpha: isDarkMode ? 0.12 : 0.07,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: p.currentStage.color.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMerged)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(
                  Icons.link_rounded,
                  size: 10,
                  color: badgeColor,
                ),
              ),
            Text(
              _proposalBadgeLabel(p),
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              p.currentStage.title,
              style: TextStyle(
                color: p.currentStage.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final allProposals = [primaryOrder, ...linkedProposals];
    final mergedProposals = linkedProposals.where(_isSubProposal).toList();
    final unmergedLinked =
        linkedProposals.where((p) => !_isSubProposal(p)).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDarkMode ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: isDarkMode ? 0.20 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasMerged ? Icons.merge_type_rounded : Icons.layers_outlined,
                size: 11,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  hasMerged
                      ? '${allProposals.length} propostas juntas'
                      : '${allProposals.length} propostas vinculadas',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (unmergedLinked.isNotEmpty)
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                proposalPill(primaryOrder, isPrimary: true),
                ...unmergedLinked.map((p) => proposalPill(p, isPrimary: false)),
              ],
            ),
          // Merged (sub-element) proposals — show expanded data
          ...mergedProposals.map((p) {
            final visitPlanned = _plannedVisitCountForOrder(p);
            final hasNextAction = p.nextAction.trim().isNotEmpty;
            final hasAddress = p.address.trim().isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF202225)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                size: 9,
                                color: Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _proposalBadgeLabel(p),
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.workName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onUnmerge != null)
                          Tooltip(
                            message: 'Desfazer junção',
                            child: InkWell(
                              onTap: () => onUnmerge!(p),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.link_off_rounded,
                                  size: 14,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (hasNextAction) ...[
                      const SizedBox(height: 5),
                      Text(
                        p.nextAction,
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (hasAddress) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              p.address,
                              style: TextStyle(
                                fontSize: 10,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (visitPlanned > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        '$visitPlanned visit${visitPlanned == 1 ? 'a' : 'as'} incl.',
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderCountBadgeIcon extends StatelessWidget {
  const _HeaderCountBadgeIcon({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -6,
          right: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

ButtonStyle _attachmentReadyButtonStyle(bool hasFile) {
  if (!hasFile) {
    return OutlinedButton.styleFrom();
  }

  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF15803D),
    backgroundColor: const Color(0xFFF0FDF4),
    side: const BorderSide(color: Color(0xFF86EFAC)),
  );
}

class _ConversationMentionMatch {
  const _ConversationMentionMatch({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

class _OrderConversationDialog extends StatefulWidget {
  const _OrderConversationDialog({
    required this.order,
    required this.currentProfile,
    required this.profiles,
    required this.onSendMessage,
  });

  final WorkflowOrder order;
  final EmployeeWorkspaceProfile currentProfile;
  final List<EmployeeWorkspaceProfile> profiles;
  final Future<bool> Function(String message) onSendMessage;

  @override
  State<_OrderConversationDialog> createState() =>
      _OrderConversationDialogState();
}

class _OrderConversationDialogState extends State<_OrderConversationDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<OrderConversationMessage> _messages;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages = List<OrderConversationMessage>.from(
      widget.order.conversationMessages,
    )..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(jump: true);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final target = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(target);
      return;
    }

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  _ConversationMentionMatch? _resolveActiveMention(TextEditingValue value) {
    final text = value.text;
    final selection = value.selection;
    final caretOffset = selection.baseOffset;
    if (caretOffset < 0 || caretOffset > text.length) {
      return null;
    }

    final prefix = text.substring(0, caretOffset);
    final match = RegExp(r'(?:^|\s)@([A-Za-z0-9._-]*)$').firstMatch(prefix);
    if (match == null) {
      return null;
    }

    final fullMatch = match.group(0) ?? '';
    final atOffset = fullMatch.lastIndexOf('@');
    if (atOffset == -1) {
      return null;
    }

    return _ConversationMentionMatch(
      start: match.start + atOffset,
      end: caretOffset,
      query: (match.group(1) ?? '').trim(),
    );
  }

  List<EmployeeWorkspaceProfile> _mentionSuggestionsFor(
    TextEditingValue value,
  ) {
    final mention = _resolveActiveMention(value);
    if (mention == null) {
      return const <EmployeeWorkspaceProfile>[];
    }

    final query = mention.query.toLowerCase();
    final currentEmail = widget.currentProfile.email.trim().toLowerCase();
    final suggestions = widget.profiles
        .where((profile) {
          final login = profile.login.trim().toLowerCase();
          final name = profile.name.trim().toLowerCase();
          final email = profile.email.trim().toLowerCase();
          if (login.isEmpty || email.isEmpty || email == currentEmail) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          return login.contains(query) || name.contains(query);
        })
        .toList(growable: false);

    suggestions.sort((left, right) {
      final leftLogin = left.login.trim().toLowerCase();
      final rightLogin = right.login.trim().toLowerCase();
      final leftStarts = query.isNotEmpty && leftLogin.startsWith(query);
      final rightStarts = query.isNotEmpty && rightLogin.startsWith(query);
      if (leftStarts != rightStarts) {
        return leftStarts ? -1 : 1;
      }
      return leftLogin.compareTo(rightLogin);
    });

    return suggestions.take(6).toList(growable: false);
  }

  void _insertMention(EmployeeWorkspaceProfile profile) {
    final mention = _resolveActiveMention(_messageController.value);
    if (mention == null) {
      return;
    }

    final text = _messageController.text;
    final replacement = '@${profile.login.trim()} ';
    final updatedText = text.replaceRange(
      mention.start,
      mention.end,
      replacement,
    );
    final caretOffset = mention.start + replacement.length;
    _messageController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
  }

  List<String> _resolveMentionedEmails(String message) {
    final mentionedLogins = RegExp(r'(?:^|\s)@([A-Za-z0-9._-]+)')
        .allMatches(message)
        .map((match) => (match.group(1) ?? '').trim().toLowerCase())
        .where((login) => login.isNotEmpty)
        .toSet();
    if (mentionedLogins.isEmpty) {
      return const <String>[];
    }

    final currentEmail = widget.currentProfile.email.trim().toLowerCase();
    return widget.profiles
        .where(
          (profile) =>
              mentionedLogins.contains(profile.login.trim().toLowerCase()),
        )
        .map((profile) => profile.email.trim().toLowerCase())
        .where((email) => email.isNotEmpty && email != currentEmail)
        .toSet()
        .toList(growable: false);
  }

  Future<void> _handleSend() async {
    if (_isSending) {
      return;
    }

    final normalizedMessage = _messageController.text.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final sent = await widget.onSendMessage(normalizedMessage);
    if (!mounted) {
      return;
    }

    if (!sent) {
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar a mensagem do card.'),
        ),
      );
      return;
    }

    final authorEmail = widget.currentProfile.email.trim().toLowerCase();
    setState(() {
      _messages = [
        ..._messages,
        OrderConversationMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          authorEmail: authorEmail,
          authorName: _workspaceProfileOwnerLabel(widget.currentProfile),
          message: normalizedMessage,
          createdAt: DateTime.now(),
          mentionedUserEmails: _resolveMentionedEmails(normalizedMessage),
          readByUserEmails: authorEmail.isEmpty ? const [] : [authorEmail],
        ),
      ];
      _messageController.clear();
      _isSending = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE0E0DD);
    final panelColor = isDarkMode ? const Color(0xFF202225) : Colors.white;
    final mutedTextColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conversa do cliente',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_displayOrderCode(widget.order)} • ${widget.order.workName}',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma mensagem neste card ainda.',
                            style: TextStyle(color: mutedTextColor),
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.separated(
                            controller: _scrollController,
                            itemCount: _messages.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isOwnMessage =
                                  message.authorEmail ==
                                  widget.currentProfile.email
                                      .trim()
                                      .toLowerCase();
                              return _ConversationMessageBubble(
                                message: message,
                                isOwnMessage: isOwnMessage,
                                profiles: widget.profiles,
                              );
                            },
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: 'Mensagem do card',
                  hintText: 'Use @login para mencionar outro colaborador.',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF1C1D20)
                      : const Color(0xFFF5F5F3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, _) {
                  final suggestions = _mentionSuggestionsFor(value);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      if (suggestions.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final profile in suggestions)
                              ActionChip(
                                avatar: CircleAvatar(
                                  backgroundColor: profile.accent.withValues(
                                    alpha: 0.16,
                                  ),
                                  child: Text(
                                    profile.login.trim().isEmpty
                                        ? '?'
                                        : profile.login
                                              .trim()
                                              .substring(0, 1)
                                              .toUpperCase(),
                                    style: TextStyle(
                                      color: profile.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                label: Text(
                                  '${profile.name.trim().isEmpty ? profile.login : profile.name} (@${profile.login})',
                                ),
                                onPressed: () => _insertMention(profile),
                              ),
                          ],
                        )
                      else
                        Text(
                          'As mensagens ficam salvas dentro deste card e podem ser respondidas depois.',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 12.5,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSending
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Fechar'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: _isSending ? null : _handleSend,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _isSending ? 'Enviando...' : 'Enviar mensagem',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationMessageBubble extends StatelessWidget {
  const _ConversationMessageBubble({
    required this.message,
    required this.isOwnMessage,
    required this.profiles,
  });

  final OrderConversationMessage message;
  final bool isOwnMessage;
  final List<EmployeeWorkspaceProfile> profiles;

  InlineSpan _buildMessageSpan(BuildContext context) {
    final baseColor = isOwnMessage
        ? const Color(0xFF10231D)
        : Theme.of(context).textTheme.bodyMedium?.color ??
              const Color(0xFF1A1A1A);
    final mentionColor = isOwnMessage
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF2563EB);
    final matches = RegExp(r'@([A-Za-z0-9._-]+)').allMatches(message.message);
    if (matches.isEmpty) {
      return TextSpan(
        text: message.message,
        style: TextStyle(color: baseColor, height: 1.45),
      );
    }

    final spans = <InlineSpan>[];
    var lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: message.message.substring(lastIndex, match.start),
            style: TextStyle(color: baseColor, height: 1.45),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: mentionColor,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < message.message.length) {
      spans.add(
        TextSpan(
          text: message.message.substring(lastIndex),
          style: TextStyle(color: baseColor, height: 1.45),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isOwnMessage
        ? const Color(0xFFEAF4EF)
        : isDarkMode
        ? const Color(0xFF26282B)
        : const Color(0xFFF5F5F3);
    final borderColor = isOwnMessage
        ? const Color(0xFFCFE3D6)
        : isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE0E0DD);
    final headerColor = isDarkMode
        ? const Color(0xFFF2F2F0)
        : const Color(0xFF1A1A1A);
    final metaColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final mentionedProfiles = profiles
        .where(
          (profile) => message.mentionedUserEmails.contains(
            profile.email.trim().toLowerCase(),
          ),
        )
        .toList(growable: false);

    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.authorName,
                      style: TextStyle(
                        color: headerColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _formatDateTime(message.createdAt),
                    style: TextStyle(
                      color: metaColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectionArea(child: RichText(text: _buildMessageSpan(context))),
              if (mentionedProfiles.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final profile in mentionedProfiles)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '@${profile.login}',
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StageFilterChip extends StatelessWidget {
  const _StageFilterChip({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
    required this.icon,
    this.metadata,
    this.counter,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData icon;
  final String? metadata;
  final int? counter;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode
        ? const Color(0xFFF2F2F0)
        : const Color(0xFF1A1A1A);
    final subtitleColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF202225)
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF3E4044)
                : const Color(0xFFE8E8E5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDarkMode ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (counter != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF26282B)
                          : const Color(0xFFF5F5F3),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDarkMode
                            ? const Color(0xFF3E4044)
                            : const Color(0xFFE8E8E5),
                      ),
                    ),
                    child: Text(
                      '$counter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: subtitleColor, height: 1.35),
            ),
            if (metadata != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDarkMode ? 0.10 : 0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  metadata!,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode
        ? const Color(0xFFF2F2F0)
        : const Color(0xFF1A1A1A);
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF26282B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF6B6B68) : const Color(0xFFE8E8E5),
          width: isDarkMode ? 1.1 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: accent.withValues(alpha: isDarkMode ? 0.9 : 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDarkMode ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrdersKanbanColumnData {
  const _OrdersKanbanColumnData({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.emptyMessage,
    required this.orders,
    this.assemblyTargetStatus,
    this.engineeringTargetTaskKey,
    this.isEngineeringCompletionTarget = false,
    this.financeTargetTaskKey,
    this.isFinanceCompletionTarget = false,
    this.relationshipTargetTaskKey,
    this.installationTargetStatus,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String emptyMessage;
  final List<WorkflowOrder> orders;
  final AssemblyWorkflowStatus? assemblyTargetStatus;
  final String? engineeringTargetTaskKey;
  final bool isEngineeringCompletionTarget;
  final String? financeTargetTaskKey;
  final bool isFinanceCompletionTarget;
  final String? relationshipTargetTaskKey;
  final InstallationWorkflowStatus? installationTargetStatus;
}

class _PersonalKanbanBoard extends StatelessWidget {
  const _PersonalKanbanBoard({
    required this.tasks,
    required this.isWide,
    required this.onOpenTaskOrder,
  });

  final List<WorkspaceTask> tasks;
  final bool isWide;
  final ValueChanged<String> onOpenTaskOrder;

  @override
  Widget build(BuildContext context) {
    final columnWidth = isWide ? 290.0 : 270.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: WorkspaceTaskStatus.values
            .map((status) {
              final statusTasks = tasks
                  .where((task) => task.status == status)
                  .toList(growable: false);

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: columnWidth,
                  child: _KanbanColumn(
                    status: status,
                    tasks: statusTasks,
                    onOpenTaskOrder: onOpenTaskOrder,
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _StageOrdersKanbanBoard extends StatefulWidget {
  const _StageOrdersKanbanBoard({
    required this.columns,
    required this.allOrders,
    required this.selectedOrderCode,
    required this.onOrderSelected,
    required this.onOpenOrderConversation,
    required this.workspaceProfiles,
    this.onMoveAssemblyKanbanOrder,
    this.canAcceptAssemblyKanbanDrop,
    this.onMoveEngineeringKanbanOrder,
    this.canAcceptEngineeringKanbanDrop,
    this.onMoveFinanceKanbanOrder,
    this.canAcceptFinanceKanbanDrop,
    this.onMoveRelationshipKanbanOrder,
    this.canAcceptRelationshipKanbanDrop,
    this.onMoveInstallationKanbanOrder,
    this.canAcceptInstallationKanbanDrop,
    this.onUnmergeProposal,
  });

  final List<_OrdersKanbanColumnData> columns;
  final List<WorkflowOrder> allOrders;
  final String? selectedOrderCode;
  final ValueChanged<WorkflowOrder> onOrderSelected;
  final ValueChanged<WorkflowOrder> onOpenOrderConversation;
  final List<EmployeeWorkspaceProfile> workspaceProfiles;
  final Future<void> Function(
    WorkflowOrder order,
    AssemblyWorkflowStatus target,
  )?
  onMoveAssemblyKanbanOrder;
  final bool Function(WorkflowOrder order, AssemblyWorkflowStatus target)?
  canAcceptAssemblyKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String? targetTaskKey)?
  onMoveEngineeringKanbanOrder;
  final bool Function(WorkflowOrder order, String? targetTaskKey)?
  canAcceptEngineeringKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String? targetTaskKey)?
  onMoveFinanceKanbanOrder;
  final bool Function(WorkflowOrder order, String? targetTaskKey)?
  canAcceptFinanceKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String targetTaskKey)?
  onMoveRelationshipKanbanOrder;
  final bool Function(WorkflowOrder order, String targetTaskKey)?
  canAcceptRelationshipKanbanDrop;
  final Future<void> Function(
    WorkflowOrder order,
    InstallationWorkflowStatus target,
  )?
  onMoveInstallationKanbanOrder;
  final bool Function(WorkflowOrder order, InstallationWorkflowStatus target)?
  canAcceptInstallationKanbanDrop;
  final Future<void> Function(WorkflowOrder secondary)? onUnmergeProposal;

  @override
  State<_StageOrdersKanbanBoard> createState() =>
      _StageOrdersKanbanBoardState();
}

class _StageOrdersKanbanBoardState extends State<_StageOrdersKanbanBoard> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleEngineeringCardDragUpdate(Offset globalPosition) {
    final viewportContext = _viewportKey.currentContext;
    if (viewportContext == null || !_scrollController.hasClients) {
      return;
    }

    final box = viewportContext.findRenderObject();
    if (box is! RenderBox) {
      return;
    }

    final local = box.globalToLocal(globalPosition);
    const edgeThreshold = 96.0;
    const maxStep = 24.0;
    double delta = 0;

    if (local.dx < edgeThreshold) {
      delta = -((edgeThreshold - local.dx) / edgeThreshold) * maxStep;
    } else if (local.dx > box.size.width - edgeThreshold) {
      delta =
          ((local.dx - (box.size.width - edgeThreshold)) / edgeThreshold) *
          maxStep;
    }

    if (delta == 0) {
      return;
    }

    final nextOffset = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (nextOffset != _scrollController.offset) {
      _scrollController.jumpTo(nextOffset);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) {
      return;
    }

    final delta = event.scrollDelta.dx;
    if (delta == 0) {
      return;
    }

    final nextOffset = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (nextOffset != _scrollController.offset) {
      _scrollController.jumpTo(nextOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: ScrollConfiguration(
        behavior: const _KanbanScrollBehavior(),
        child: SingleChildScrollView(
          key: _viewportKey,
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < widget.columns.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                SizedBox(
                  width: 300,
                  child: _StageOrdersKanbanColumn(
                    column: widget.columns[index],
                    allOrders: widget.allOrders,
                    selectedOrderCode: widget.selectedOrderCode,
                    onOrderSelected: widget.onOrderSelected,
                    onOpenOrderConversation: widget.onOpenOrderConversation,
                    workspaceProfiles: widget.workspaceProfiles,
                    onMoveAssemblyKanbanOrder: widget.onMoveAssemblyKanbanOrder,
                    canAcceptAssemblyKanbanDrop:
                        widget.canAcceptAssemblyKanbanDrop,
                    onMoveEngineeringKanbanOrder:
                        widget.onMoveEngineeringKanbanOrder,
                    canAcceptEngineeringKanbanDrop:
                        widget.canAcceptEngineeringKanbanDrop,
                    onMoveFinanceKanbanOrder: widget.onMoveFinanceKanbanOrder,
                    canAcceptFinanceKanbanDrop:
                        widget.canAcceptFinanceKanbanDrop,
                    onMoveRelationshipKanbanOrder:
                        widget.onMoveRelationshipKanbanOrder,
                    canAcceptRelationshipKanbanDrop:
                        widget.canAcceptRelationshipKanbanDrop,
                    onMoveInstallationKanbanOrder:
                        widget.onMoveInstallationKanbanOrder,
                    canAcceptInstallationKanbanDrop:
                        widget.canAcceptInstallationKanbanDrop,
                    onEngineeringCardDragUpdate:
                        _handleEngineeringCardDragUpdate,
                    onUnmergeProposal: widget.onUnmergeProposal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KanbanScrollBehavior extends MaterialScrollBehavior {
  const _KanbanScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}

class _StageOrdersKanbanColumn extends StatefulWidget {
  const _StageOrdersKanbanColumn({
    required this.column,
    required this.allOrders,
    required this.selectedOrderCode,
    required this.onOrderSelected,
    required this.onOpenOrderConversation,
    required this.workspaceProfiles,
    this.onMoveAssemblyKanbanOrder,
    this.canAcceptAssemblyKanbanDrop,
    this.onMoveEngineeringKanbanOrder,
    this.canAcceptEngineeringKanbanDrop,
    this.onMoveFinanceKanbanOrder,
    this.canAcceptFinanceKanbanDrop,
    this.onMoveRelationshipKanbanOrder,
    this.canAcceptRelationshipKanbanDrop,
    this.onMoveInstallationKanbanOrder,
    this.canAcceptInstallationKanbanDrop,
    this.onEngineeringCardDragUpdate,
    this.onUnmergeProposal,
  });

  final _OrdersKanbanColumnData column;
  final List<WorkflowOrder> allOrders;
  final String? selectedOrderCode;
  final ValueChanged<WorkflowOrder> onOrderSelected;
  final ValueChanged<WorkflowOrder> onOpenOrderConversation;
  final List<EmployeeWorkspaceProfile> workspaceProfiles;
  final Future<void> Function(
    WorkflowOrder order,
    AssemblyWorkflowStatus target,
  )?
  onMoveAssemblyKanbanOrder;
  final bool Function(WorkflowOrder order, AssemblyWorkflowStatus target)?
  canAcceptAssemblyKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String? targetTaskKey)?
  onMoveEngineeringKanbanOrder;
  final bool Function(WorkflowOrder order, String? targetTaskKey)?
  canAcceptEngineeringKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String? targetTaskKey)?
  onMoveFinanceKanbanOrder;
  final bool Function(WorkflowOrder order, String? targetTaskKey)?
  canAcceptFinanceKanbanDrop;
  final Future<void> Function(WorkflowOrder order, String targetTaskKey)?
  onMoveRelationshipKanbanOrder;
  final bool Function(WorkflowOrder order, String targetTaskKey)?
  canAcceptRelationshipKanbanDrop;
  final Future<void> Function(
    WorkflowOrder order,
    InstallationWorkflowStatus target,
  )?
  onMoveInstallationKanbanOrder;
  final bool Function(WorkflowOrder order, InstallationWorkflowStatus target)?
  canAcceptInstallationKanbanDrop;
  final ValueChanged<Offset>? onEngineeringCardDragUpdate;
  final Future<void> Function(WorkflowOrder secondary)? onUnmergeProposal;

  @override
  State<_StageOrdersKanbanColumn> createState() =>
      _StageOrdersKanbanColumnState();
}

class _StageOrdersKanbanColumnState extends State<_StageOrdersKanbanColumn> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final column = widget.column;
    final allOrders = widget.allOrders;
    final selectedOrderCode = widget.selectedOrderCode;
    final onOrderSelected = widget.onOrderSelected;
    final onOpenOrderConversation = widget.onOpenOrderConversation;
    final workspaceProfiles = widget.workspaceProfiles;
    final onEngineeringCardDragUpdate = widget.onEngineeringCardDragUpdate;
    final acceptsAssemblyDrop =
        widget.onMoveAssemblyKanbanOrder != null &&
        column.assemblyTargetStatus != null;
    final acceptsEngineeringDrop =
        widget.onMoveEngineeringKanbanOrder != null &&
        (column.engineeringTargetTaskKey != null ||
            column.isEngineeringCompletionTarget);
    final acceptsFinanceDrop =
        widget.onMoveFinanceKanbanOrder != null &&
        (column.financeTargetTaskKey != null ||
            column.isFinanceCompletionTarget);
    final acceptsRelationshipDrop =
        widget.onMoveRelationshipKanbanOrder != null &&
        column.relationshipTargetTaskKey != null;
    final acceptsInstallationDrop =
        widget.onMoveInstallationKanbanOrder != null &&
        column.installationTargetStatus != null;
    final acceptsDrop =
        acceptsAssemblyDrop ||
        acceptsEngineeringDrop ||
        acceptsFinanceDrop ||
        acceptsRelationshipDrop ||
        acceptsInstallationDrop;
    final hasExpandableCards = column.orders.length > 2;
    final visibleOrders = hasExpandableCards && !_isExpanded
        ? column.orders.take(2).toList(growable: false)
        : column.orders;

    return DragTarget<WorkflowOrder>(
      onWillAcceptWithDetails: acceptsDrop
          ? (details) {
              if (acceptsAssemblyDrop &&
                  details.data.currentStage == WorkflowStage.assembly) {
                return widget.canAcceptAssemblyKanbanDrop?.call(
                      details.data,
                      column.assemblyTargetStatus!,
                    ) ??
                    false;
              }
              if (acceptsEngineeringDrop &&
                  details.data.currentStage == WorkflowStage.engineering) {
                return widget.canAcceptEngineeringKanbanDrop?.call(
                      details.data,
                      column.isEngineeringCompletionTarget
                          ? null
                          : column.engineeringTargetTaskKey,
                    ) ??
                    false;
              }
              if (acceptsFinanceDrop &&
                  details.data.currentStage == WorkflowStage.finance) {
                return widget.canAcceptFinanceKanbanDrop?.call(
                      details.data,
                      column.isFinanceCompletionTarget
                          ? null
                          : column.financeTargetTaskKey,
                    ) ??
                    false;
              }
              if (acceptsRelationshipDrop &&
                  details.data.currentStage == WorkflowStage.relationship) {
                return widget.canAcceptRelationshipKanbanDrop?.call(
                      details.data,
                      column.relationshipTargetTaskKey!,
                    ) ??
                    false;
              }
              if (acceptsInstallationDrop &&
                  details.data.currentStage == WorkflowStage.installation) {
                return widget.canAcceptInstallationKanbanDrop?.call(
                      details.data,
                      column.installationTargetStatus!,
                    ) ??
                    false;
              }
              return false;
            }
          : null,
      onAcceptWithDetails: acceptsDrop
          ? (details) async {
              if (acceptsAssemblyDrop &&
                  details.data.currentStage == WorkflowStage.assembly) {
                await widget.onMoveAssemblyKanbanOrder!(
                  details.data,
                  column.assemblyTargetStatus!,
                );
                return;
              }
              if (acceptsEngineeringDrop &&
                  details.data.currentStage == WorkflowStage.engineering) {
                await widget.onMoveEngineeringKanbanOrder!(
                  details.data,
                  column.isEngineeringCompletionTarget
                      ? null
                      : column.engineeringTargetTaskKey,
                );
                return;
              }
              if (acceptsFinanceDrop &&
                  details.data.currentStage == WorkflowStage.finance) {
                await widget.onMoveFinanceKanbanOrder!(
                  details.data,
                  column.isFinanceCompletionTarget
                      ? null
                      : column.financeTargetTaskKey,
                );
                return;
              }
              if (acceptsRelationshipDrop &&
                  details.data.currentStage == WorkflowStage.relationship) {
                await widget.onMoveRelationshipKanbanOrder!(
                  details.data,
                  column.relationshipTargetTaskKey!,
                );
                return;
              }
              if (acceptsInstallationDrop &&
                  details.data.currentStage == WorkflowStage.installation) {
                await widget.onMoveInstallationKanbanOrder!(
                  details.data,
                  column.installationTargetStatus!,
                );
              }
            }
          : null,
      builder: (context, candidateData, rejectedData) {
        final isActiveTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(14),
          decoration: _panelDecoration(context).copyWith(
            border: Border.all(
              color: isActiveTarget
                  ? column.accent.withValues(alpha: 0.85)
                  : (isDarkMode
                        ? const Color(0xFF3E4044)
                        : const Color(0xFFE0E0DD)),
              width: isActiveTarget ? 2 : 1,
            ),
            color: isActiveTarget
                ? column.accent.withValues(alpha: isDarkMode ? 0.12 : 0.08)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: column.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(column.icon, color: column.accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          column.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          column.subtitle,
                          style: TextStyle(
                            color: isDarkMode
                                ? const Color(0xFFA3A39E)
                                : const Color(0xFF6B6B68),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? column.accent.withValues(alpha: 0.12)
                          : const Color(0xFFF5F5F3),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: column.accent.withValues(
                          alpha: isDarkMode ? 0.32 : 0.14,
                        ),
                      ),
                    ),
                    child: Text(
                      '${column.orders.length}',
                      style: TextStyle(
                        color: column.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (column.orders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: column.accent.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: column.accent.withValues(
                        alpha: isDarkMode ? 0.30 : 0.12,
                      ),
                    ),
                  ),
                  child: Text(
                    column.emptyMessage,
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFA3A39E)
                          : const Color(0xFF6B6B68),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                )
              else
                ...visibleOrders.map((order) {
                  final canMoveOrderToInstallationDone =
                      widget.onMoveInstallationKanbanOrder != null &&
                      (widget.canAcceptInstallationKanbanDrop?.call(
                            order,
                            InstallationWorkflowStatus.done,
                          ) ??
                          false);
                  final onMoveOrderToInstallationDone =
                      canMoveOrderToInstallationDone
                      ? () => widget.onMoveInstallationKanbanOrder!(
                          order,
                          InstallationWorkflowStatus.done,
                        )
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: acceptsDrop
                        ? LongPressDraggable<WorkflowOrder>(
                            data: order,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            onDragUpdate: (details) {
                              onEngineeringCardDragUpdate?.call(
                                details.globalPosition,
                              );
                            },
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 272,
                                child: Opacity(
                                  opacity: 0.92,
                                  child: _OrderCard(
                                    order: order,
                                    allOrders: allOrders,
                                    selected: false,
                                    onTap: () {},
                                    onOpenConversation: () {},
                                    workspaceProfiles: workspaceProfiles,
                                    onUnmergeProposal: widget.onUnmergeProposal,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _OrderCard(
                                order: order,
                                allOrders: allOrders,
                                selected: selectedOrderCode == order.code,
                                onTap: () => onOrderSelected(order),
                                onOpenConversation: () =>
                                    onOpenOrderConversation(order),
                                workspaceProfiles: workspaceProfiles,
                                onUnmergeProposal: widget.onUnmergeProposal,
                              ),
                            ),
                            child: _OrderCard(
                              order: order,
                              allOrders: allOrders,
                              selected: selectedOrderCode == order.code,
                              onTap: () => onOrderSelected(order),
                              onOpenConversation: () =>
                                  onOpenOrderConversation(order),
                              workspaceProfiles: workspaceProfiles,
                              onMoveToCompleted: onMoveOrderToInstallationDone,
                              onUnmergeProposal: widget.onUnmergeProposal,
                            ),
                          )
                        : _OrderCard(
                            order: order,
                            allOrders: allOrders,
                            selected: selectedOrderCode == order.code,
                            onTap: () => onOrderSelected(order),
                            onOpenConversation: () =>
                                onOpenOrderConversation(order),
                            workspaceProfiles: workspaceProfiles,
                            onMoveToCompleted: onMoveOrderToInstallationDone,
                            onUnmergeProposal: widget.onUnmergeProposal,
                          ),
                  );
                }),
              if (hasExpandableCards)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    icon: Icon(
                      _isExpanded
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                    ),
                    label: Text(
                      _isExpanded
                          ? 'Mostrar menos'
                          : 'Expandir mais ${column.orders.length - 2} cards',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.tasks,
    required this.onOpenTaskOrder,
  });

  final WorkspaceTaskStatus status;
  final List<WorkspaceTask> tasks;
  final ValueChanged<String> onOpenTaskOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.title,
                  style: TextStyle(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${tasks.length}',
                style: const TextStyle(
                  color: Color(0xFF6B6B68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Nenhuma tarefa neste quadro.',
                style: TextStyle(color: Color(0xFF6B6B68)),
              ),
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WorkspaceTaskCard(
                  task: task,
                  onTap: () => onOpenTaskOrder(task.orderCode),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceTaskCard extends StatelessWidget {
  const _WorkspaceTaskCard({required this.task, required this.onTap});

  final WorkspaceTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E8E5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusBadge(label: task.stage.title, color: task.stage.color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.summary,
              style: const TextStyle(color: Color(0xFF6B6B68), height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _WorkspaceMetaChip(
                  icon: Icons.inventory_2_outlined,
                  label: task.orderCode,
                ),
                _WorkspaceMetaChip(
                  icon: Icons.flag_outlined,
                  label: task.priorityLabel,
                ),
                _WorkspaceMetaChip(
                  icon: Icons.schedule_outlined,
                  label: task.dueLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMetaChip extends StatelessWidget {
  const _WorkspaceMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF202225)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF26282B) : const Color(0xFFE8E8E5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isDarkMode
                ? const Color(0xFFA3A39E)
                : const Color(0xFF6B6B68),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFF2F2F0)
                  : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StageOwnersSection extends StatelessWidget {
  const _StageOwnersSection({required this.owners, this.showHeader = true});

  final List<MapEntry<WorkflowStage, String>> owners;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final itemWidth = MediaQuery.sizeOf(context).width >= 900 ? 320.0 : 260.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF26282B).withValues(alpha: 0.56)
            : Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2F3134) : const Color(0xFFE8E8E5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              'Responsáveis por etapa',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFA3A39E)
                    : const Color(0xFF6B6B68),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: owners
                .map(
                  (entry) => SizedBox(
                    width: itemWidth,
                    child: _StageOwnerLine(
                      label: _stageOwnerSummaryLabel(entry.key),
                      value: entry.value,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StageOwnerLine extends StatelessWidget {
  const _StageOwnerLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? const Color(0xFF2F3134)
                : const Color(0xFFE8E8E5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFA3A39E)
                    : const Color(0xFF66736E),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFF2F2F0)
                    : const Color(0xFF1A1A1A),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasizeValue = false,
  });

  final String label;
  final String value;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1D20) : const Color(0xFFF5F5F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF3E4044) : const Color(0xFFE8E8E5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFA3A39E)
                  : const Color(0xFF6B6B68),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFF2F2F0)
                  : const Color(0xFF1A1A1A),
              height: 1.25,
              fontWeight: emphasizeValue ? FontWeight.w800 : FontWeight.w600,
              fontSize: emphasizeValue ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

enum _FileInfoStatus { available, missing, restricted }

class _FileInfoRow extends StatelessWidget {
  const _FileInfoRow({
    required this.label,
    required this.value,
    this.filePath,
    this.status,
  });

  final String label;
  final String value;
  final String? filePath;
  final _FileInfoStatus? status;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _detailAccentColorForLabel(label, isDarkMode);
    final isClickable =
        filePath != null &&
        filePath!.trim().isNotEmpty &&
        value.trim().isNotEmpty;
    final effectiveStatus =
        status ??
        (isClickable
            ? _FileInfoStatus.available
            : _inferFileStatusFromValue(value));
    final statusLabel = switch (effectiveStatus) {
      _FileInfoStatus.available => 'Disponível',
      _FileInfoStatus.missing => 'Pendente',
      _FileInfoStatus.restricted => 'Restrito',
    };
    final statusColor = switch (effectiveStatus) {
      _FileInfoStatus.available =>
        isDarkMode ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
      _FileInfoStatus.missing =>
        isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      _FileInfoStatus.restricted =>
        isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
    };
    final titleColor = isDarkMode
        ? const Color(0xFFF2F2F0)
        : const Color(0xFF1A1A1A);
    final helperColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1D20) : const Color(0xFFF5F5F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF3E4044) : const Color(0xFFE8E8E5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: helperColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value.trim().isEmpty ? 'Nenhum arquivo informado' : value,
                      style: TextStyle(
                        color: titleColor,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: isDarkMode ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (effectiveStatus == _FileInfoStatus.available && isClickable) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _openLocalFile(context, filePath),
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: isDarkMode ? 0.12 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Abrir arquivo',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              switch (effectiveStatus) {
                _FileInfoStatus.available =>
                  'Arquivo cadastrado, mas sem link disponível nesta estação.',
                _FileInfoStatus.missing =>
                  'Nenhum anexo enviado para este item até o momento.',
                _FileInfoStatus.restricted =>
                  'Este documento existe, mas o acesso está bloqueado na etapa atual.',
              },
              style: TextStyle(
                color: helperColor,
                height: 1.32,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSectionLabel extends StatelessWidget {
  const _DetailSectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDarkMode
                ? const Color(0xFFF2F2F0)
                : const Color(0xFF1A1A1A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode
                ? const Color(0xFFA3A39E)
                : const Color(0xFF6B6B68),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _CollapsibleDetailSection extends StatefulWidget {
  const _CollapsibleDetailSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleDetailSection> createState() =>
      _CollapsibleDetailSectionState();
}

class _CollapsibleDetailSectionState extends State<_CollapsibleDetailSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);
    final surfaceColor = isDarkMode
        ? const Color(0xFF1C1D20)
        : const Color(0xFFF5F5F3);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DetailSectionLabel(
                      title: widget.title,
                      subtitle: widget.subtitle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withValues(alpha: 0.14)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode
                          ? const Color(0xFFA3A39E)
                          : const Color(0xFF6B6B68),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: !_expanded
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: widget.child,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsHero extends StatelessWidget {
  const _OrderDetailsHero({
    required this.order,
    required this.allOrders,
    required this.secondaryTextColor,
    required this.headerActionPanel,
    required this.headerActions,
    required this.showStandaloneEditAction,
    required this.inlineHeaderMinWidth,
    required this.progressTrackColor,
  });

  final WorkflowOrder order;
  final List<WorkflowOrder> allOrders;
  final Color secondaryTextColor;
  final Widget? headerActionPanel;
  final List<Widget> headerActions;
  final bool showStandaloneEditAction;
  final double inlineHeaderMinWidth;
  final Color progressTrackColor;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final stageColor = order.currentStage.color;
    final displayCode = _displayOrderCode(order, allOrders);
    final effectiveProgress = _effectiveOrderProgress(order);
    final visitProgressLabel = _visitProgressLabelForOrder(order);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF202225) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF3E4044) : const Color(0xFFE8E8E5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final keepInlineHeader =
              headerActions.isEmpty ||
              (showStandaloneEditAction && constraints.maxWidth >= 320) ||
              constraints.maxWidth >= inlineHeaderMinWidth;
          final metadata = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _HeroMetaChip(
                icon: Icons.layers_outlined,
                label: _proposalVersionTitle(order),
                color: order.proposalVersion > 1
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF475569),
              ),
              if (order.isServiceOrder)
                const _HeroMetaChip(
                  icon: Icons.assignment_outlined,
                  label: 'Ordem de serviço',
                  color: Color(0xFF92400E),
                ),
              _HeroMetaChip(
                icon: Icons.route_rounded,
                label: order.currentStage.title,
                color: stageColor,
              ),
              _HeroMetaChip(
                icon: Icons.badge_outlined,
                label: 'Cliente ${order.client.id}',
                color: isDarkMode
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF475569),
              ),
              if (visitProgressLabel != null)
                _HeroMetaChip(
                  icon: Icons.event_available_outlined,
                  label: visitProgressLabel,
                  color: Color(0xFF1D4ED8),
                ),
            ],
          );

          final titleColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayCode,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFA3A39E)
                      : const Color(0xFF6B6B68),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                order.workName,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFF2F2F0)
                      : const Color(0xFF1A1A1A),
                  fontSize: constraints.maxWidth >= 700 ? 24 : 20,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.client.name} • ${order.client.phone}',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              metadata,
            ],
          );

          final progressBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Progresso',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(effectiveProgress * 100).round()}%',
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFF2F2F0)
                          : const Color(0xFF1A1A1A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: effectiveProgress,
                minHeight: 6,
                backgroundColor: progressTrackColor,
                valueColor: AlwaysStoppedAnimation(stageColor),
                borderRadius: BorderRadius.circular(99),
              ),
            ],
          );

          final hasActions = headerActionPanel != null;
          final actionsBlock = !hasActions
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: headerActionPanel!,
                  ),
                );

          if (!keepInlineHeader) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleColumn,
                const SizedBox(height: 14),
                progressBlock,
                if (hasActions) actionsBlock,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleColumn),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: constraints.maxWidth >= 880 ? 220 : 180,
                    child: progressBlock,
                  ),
                ],
              ),
              if (hasActions) actionsBlock,
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _detailAccentColorForLabel(String label, bool isDarkMode) {
  final normalized = label.trim().toLowerCase();

  if (normalized.contains('telefone')) {
    return isDarkMode ? const Color(0xFF67E8F9) : const Color(0xFF0891B2);
  }
  if (normalized.contains('endereço') || normalized.contains('endereco')) {
    return isDarkMode ? const Color(0xFFF9A8D4) : const Color(0xFFBE185D);
  }
  if (normalized.contains('cliente') || normalized.contains('obra')) {
    return isDarkMode ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
  }
  if (normalized.contains('proposta') || normalized.contains('contrato')) {
    return isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
  }
  if (normalized.contains('materiais') || normalized.contains('projeto')) {
    return isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
  }

  return isDarkMode ? const Color(0xFF99F6E4) : const Color(0xFF0F766E);
}

_FileInfoStatus _inferFileStatusFromValue(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('restrito')) {
    return _FileInfoStatus.restricted;
  }
  if (normalized.isEmpty || normalized.contains('não anexado')) {
    return _FileInfoStatus.missing;
  }
  return _FileInfoStatus.available;
}

BoxDecoration _panelDecoration(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return BoxDecoration(
    color: isDarkMode ? const Color(0xFF202225) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isDarkMode ? const Color(0xFF2F3134) : const Color(0xFFE8E8E5),
      width: 1,
    ),
    boxShadow: isDarkMode
        ? null
        : const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
  );
}

EngineeringChecklistStatus _normalizeEngineeringChecklistStatus(
  EngineeringChecklistStatus status,
) {
  if (status == EngineeringChecklistStatus.inProgress) {
    return EngineeringChecklistStatus.notStarted;
  }

  return status;
}
