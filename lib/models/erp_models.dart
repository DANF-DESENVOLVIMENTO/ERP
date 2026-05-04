import 'package:flutter/material.dart';

enum WorkflowStage {
  customerRegistration,
  estimating,
  finance,
  relationship,
  engineering,
  assembly,
  installation,
}

extension WorkflowStagePresentation on WorkflowStage {
  String get title => switch (this) {
    WorkflowStage.customerRegistration => 'Cadastro de Clientes',
    WorkflowStage.estimating => 'Orçamentista',
    WorkflowStage.finance => 'Financeiro',
    WorkflowStage.relationship => 'Relacionamento',
    WorkflowStage.engineering => 'Engenharia',
    WorkflowStage.assembly => 'Montagem',
    WorkflowStage.installation => 'Instalação',
  };

  String get subtitle => switch (this) {
    WorkflowStage.customerRegistration =>
      'Documentação, perfil e viabilidade comercial.',
    WorkflowStage.estimating => 'Levantamento técnico, custos e proposta.',
    WorkflowStage.finance => 'Condições de pagamento, crédito e aprovação.',
    WorkflowStage.relationship => 'Negociação, follow-up e aceite do cliente.',
    WorkflowStage.engineering => 'Projeto executivo, detalhamento e liberação.',
    WorkflowStage.assembly => 'Preparação interna, produção e conferência.',
    WorkflowStage.installation => 'Execução em campo, entrega e aceite final.',
  };

  String get sla => switch (this) {
    WorkflowStage.customerRegistration => 'SLA 1 dia',
    WorkflowStage.estimating => 'SLA 3 dias',
    WorkflowStage.finance => 'SLA 2 dias',
    WorkflowStage.relationship => 'SLA 2 dias',
    WorkflowStage.engineering => 'SLA 5 dias',
    WorkflowStage.assembly => 'SLA 4 dias',
    WorkflowStage.installation => 'SLA 2 dias',
  };

  IconData get icon => switch (this) {
    WorkflowStage.customerRegistration => Icons.badge_outlined,
    WorkflowStage.estimating => Icons.request_quote_outlined,
    WorkflowStage.finance => Icons.account_balance_wallet_outlined,
    WorkflowStage.relationship => Icons.handshake_outlined,
    WorkflowStage.engineering => Icons.architecture_outlined,
    WorkflowStage.assembly => Icons.precision_manufacturing_outlined,
    WorkflowStage.installation => Icons.home_repair_service_outlined,
  };

  Color get color => switch (this) {
    WorkflowStage.customerRegistration => const Color(0xFF2563EB),
    WorkflowStage.estimating => const Color(0xFF4F46E5),
    WorkflowStage.finance => const Color(0xFF15803D),
    WorkflowStage.relationship => const Color(0xFFB45309),
    WorkflowStage.engineering => const Color(0xFFC2410C),
    WorkflowStage.assembly => const Color(0xFF7C3AED),
    WorkflowStage.installation => const Color(0xFFBE123C),
  };

  List<String> get checklist => switch (this) {
    WorkflowStage.customerRegistration => const [
      'Validar CNPJ/CPF e contato principal',
      'Classificar segmento, origem e prioridade',
      'Anexar briefing comercial inicial',
    ],
    WorkflowStage.estimating => const [
      'Consolidar escopo e memorial',
      'Calcular custo de material e equipe',
      'Emitir proposta com prazo de validade',
    ],
    WorkflowStage.finance => const [
      'Analisar crédito e limite',
      'Definir condição de pagamento',
      'Liberar pedido para negociação final',
    ],
    WorkflowStage.relationship => const [
      'Registrar retorno do cliente',
      'Formalizar revisão comercial',
      'Confirmar aceite e gatilho de projeto',
    ],
    WorkflowStage.engineering => const [
      'Emitir projeto executivo',
      'Aprovar lista técnica e requisitos',
      'Liberar ordem para montagem',
    ],
    WorkflowStage.assembly => const [
      'Separar componentes',
      'Executar montagem e inspeção',
      'Planejar logística de instalação',
    ],
    WorkflowStage.installation => const [
      'Agendar equipe em campo',
      'Executar instalação e testes',
      'Coletar aceite e concluir entrega',
    ],
  };
}

enum WorkflowOrderKind { standard, serviceOrder }

extension WorkflowOrderKindPresentation on WorkflowOrderKind {
  String get title => switch (this) {
    WorkflowOrderKind.standard => 'Pedido',
    WorkflowOrderKind.serviceOrder => 'Ordem de serviço',
  };

  String get shortLabel => switch (this) {
    WorkflowOrderKind.standard => 'Pedido',
    WorkflowOrderKind.serviceOrder => 'OS',
  };
}

class EngineeringChecklistTask {
  const EngineeringChecklistTask({
    required this.key,
    required this.label,
    this.supportsScheduling = false,
  });

  final String key;
  final String label;
  final bool supportsScheduling;
}

const List<EngineeringChecklistTask> engineeringChecklistTasks = [
  EngineeringChecklistTask(
    key: 'project_presentation',
    label: 'Apresentação do projeto',
    supportsScheduling: true,
  ),
  EngineeringChecklistTask(key: 'review', label: 'Revisão'),
  EngineeringChecklistTask(
    key: 'site_presentation',
    label: 'Apresentação em obra',
    supportsScheduling: true,
  ),
  EngineeringChecklistTask(
    key: 'cable_conference',
    label: 'Conferência de cabos',
    supportsScheduling: true,
  ),
  EngineeringChecklistTask(key: 'site_folder', label: 'Montar pasta da obra'),
];

class EngineeringTaskSchedule {
  const EngineeringTaskSchedule({
    required this.scheduledAt,
    required this.notes,
  });

  final DateTime scheduledAt;
  final String notes;

  EngineeringTaskSchedule copyWith({DateTime? scheduledAt, String? notes}) {
    return EngineeringTaskSchedule(
      scheduledAt: scheduledAt ?? this.scheduledAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {'scheduledAt': scheduledAt, 'notes': notes};
  }

  factory EngineeringTaskSchedule.fromMap(Map<String, dynamic> map) {
    return EngineeringTaskSchedule(
      scheduledAt: _readDateTime(map['scheduledAt']),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class OrderConversationMessage {
  const OrderConversationMessage({
    required this.id,
    required this.authorEmail,
    required this.authorName,
    required this.message,
    required this.createdAt,
    required this.mentionedUserEmails,
    required this.readByUserEmails,
  });

  final String id;
  final String authorEmail;
  final String authorName;
  final String message;
  final DateTime createdAt;
  final List<String> mentionedUserEmails;
  final List<String> readByUserEmails;

  OrderConversationMessage copyWith({
    String? id,
    String? authorEmail,
    String? authorName,
    String? message,
    DateTime? createdAt,
    List<String>? mentionedUserEmails,
    List<String>? readByUserEmails,
  }) {
    return OrderConversationMessage(
      id: id ?? this.id,
      authorEmail: authorEmail ?? this.authorEmail,
      authorName: authorName ?? this.authorName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      mentionedUserEmails:
          mentionedUserEmails ?? List<String>.from(this.mentionedUserEmails),
      readByUserEmails:
          readByUserEmails ?? List<String>.from(this.readByUserEmails),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'authorEmail': authorEmail,
      'authorName': authorName,
      'message': message,
      'createdAt': createdAt,
      'mentionedUserEmails': mentionedUserEmails,
      'readByUserEmails': readByUserEmails,
    };
  }

  factory OrderConversationMessage.fromMap(Map<String, dynamic> map) {
    final rawMentionedUserEmails = map['mentionedUserEmails'];
    final rawReadByUserEmails = map['readByUserEmails'];
    return OrderConversationMessage(
      id: (map['id'] ?? '').toString(),
      authorEmail: (map['authorEmail'] ?? '').toString().trim().toLowerCase(),
      authorName: (map['authorName'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      createdAt: _readDateTime(map['createdAt']),
      mentionedUserEmails: rawMentionedUserEmails is Iterable
          ? rawMentionedUserEmails
                .map((item) => item.toString().trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      readByUserEmails: rawReadByUserEmails is Iterable
          ? rawReadByUserEmails
                .map((item) => item.toString().trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

enum EngineeringChecklistStatus { notStarted, inProgress, done }

extension EngineeringChecklistStatusPresentation on EngineeringChecklistStatus {
  String get title => switch (this) {
    EngineeringChecklistStatus.notStarted => 'Não realizado',
    EngineeringChecklistStatus.inProgress => 'Em andamento',
    EngineeringChecklistStatus.done => 'Feito',
  };

  Color get color => switch (this) {
    EngineeringChecklistStatus.notStarted => const Color(0xFF64748B),
    EngineeringChecklistStatus.inProgress => const Color(0xFFB45309),
    EngineeringChecklistStatus.done => const Color(0xFF15803D),
  };
}

enum AssemblyWorkflowStatus { waiting, doing, done }

extension AssemblyWorkflowStatusPresentation on AssemblyWorkflowStatus {
  String get title => switch (this) {
    AssemblyWorkflowStatus.waiting => 'Aguardando',
    AssemblyWorkflowStatus.doing => 'Em andamento',
    AssemblyWorkflowStatus.done => 'Concluído',
  };

  Color get color => switch (this) {
    AssemblyWorkflowStatus.waiting => const Color(0xFFB45309),
    AssemblyWorkflowStatus.doing => const Color(0xFF2563EB),
    AssemblyWorkflowStatus.done => const Color(0xFF15803D),
  };
}

enum InstallationWorkflowStatus { waiting, scheduled, doing, done }

extension InstallationWorkflowStatusPresentation on InstallationWorkflowStatus {
  String get title => switch (this) {
    InstallationWorkflowStatus.waiting => 'Aguardando',
    InstallationWorkflowStatus.scheduled => 'Agendado',
    InstallationWorkflowStatus.doing => 'Em andamento',
    InstallationWorkflowStatus.done => 'Concluído',
  };

  Color get color => switch (this) {
    InstallationWorkflowStatus.waiting => const Color(0xFFB45309),
    InstallationWorkflowStatus.scheduled => const Color(0xFF7C3AED),
    InstallationWorkflowStatus.doing => const Color(0xFF2563EB),
    InstallationWorkflowStatus.done => const Color(0xFF15803D),
  };
}

class InstallationVisitLog {
  const InstallationVisitLog({
    required this.scheduledAt,
    required this.employeeEmails,
    required this.plannedItems,
    required this.completedItems,
    required this.notes,
    required this.createdAt,
  });

  final DateTime scheduledAt;
  final List<String> employeeEmails;
  final List<String> plannedItems;
  final List<String> completedItems;
  final String notes;
  final DateTime createdAt;

  InstallationVisitLog copyWith({
    DateTime? scheduledAt,
    List<String>? employeeEmails,
    List<String>? plannedItems,
    List<String>? completedItems,
    String? notes,
    DateTime? createdAt,
  }) {
    return InstallationVisitLog(
      scheduledAt: scheduledAt ?? this.scheduledAt,
      employeeEmails: employeeEmails ?? List<String>.from(this.employeeEmails),
      plannedItems: plannedItems ?? List<String>.from(this.plannedItems),
      completedItems: completedItems ?? List<String>.from(this.completedItems),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'scheduledAt': scheduledAt,
      'employeeEmails': employeeEmails,
      'plannedItems': plannedItems,
      'completedItems': completedItems,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory InstallationVisitLog.fromMap(Map<String, dynamic> map) {
    final rawEmployeeEmails = map['employeeEmails'];
    final rawPlannedItems = map['plannedItems'];
    final rawCompletedItems = map['completedItems'];
    return InstallationVisitLog(
      scheduledAt: _readDateTime(map['scheduledAt']),
      employeeEmails: rawEmployeeEmails is Iterable
          ? rawEmployeeEmails
                .map((item) => item.toString().trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      plannedItems: rawPlannedItems is Iterable
          ? rawPlannedItems
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      completedItems: rawCompletedItems is Iterable
          ? rawCompletedItems
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      notes: (map['notes'] ?? '').toString(),
      createdAt: _readDateTime(map['createdAt']),
    );
  }
}

class ClientProfile {
  const ClientProfile({
    required this.id,
    required this.name,
    required this.city,
    required this.segment,
    required this.contact,
    required this.phone,
    required this.temperature,
  });

  final String id;
  final String name;
  final String city;
  final String segment;
  final String contact;
  final String phone;
  final String temperature;

  ClientProfile copyWith({
    String? id,
    String? name,
    String? city,
    String? segment,
    String? contact,
    String? phone,
    String? temperature,
  }) {
    return ClientProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      segment: segment ?? this.segment,
      contact: contact ?? this.contact,
      phone: phone ?? this.phone,
      temperature: temperature ?? this.temperature,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'segment': segment,
      'contact': contact,
      'phone': phone,
      'temperature': temperature,
    };
  }

  factory ClientProfile.fromMap(Map<String, dynamic> map) {
    return ClientProfile(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      segment: (map['segment'] ?? '').toString(),
      contact: (map['contact'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      temperature: (map['temperature'] ?? '').toString(),
    );
  }
}

class WorkflowOrder {
  const WorkflowOrder({
    required this.code,
    required this.client,
    required this.workName,
    required this.address,
    required this.proposalFileName,
    this.proposalFilePath,
    required this.detailFileName,
    this.detailFilePath,
    required this.materialFileName,
    this.materialFilePath,
    required this.consolidatedProposalFileName,
    this.consolidatedProposalFilePath,
    required this.contractFileName,
    this.contractFilePath,
    required this.electricalProjectFileName,
    this.electricalProjectFilePath,
    required this.panelLayoutFileName,
    this.panelLayoutFilePath,
    required this.pushButtonTableFileName,
    this.pushButtonTableFilePath,
    required this.engineeringDataFileName,
    this.engineeringDataFilePath,
    required this.engineeringChecklistStatuses,
    required this.engineeringActivitySchedules,
    required this.assemblyWorkflowStatus,
    required this.assemblyAssignedEmployeeEmails,
    required this.currentStage,
    required this.owner,
    required this.stageOwners,
    required this.proposalGroupCode,
    required this.proposalVersion,
    required this.kind,
    required this.serviceDescription,
    required this.serviceOrderFileName,
    this.serviceOrderFilePath,
    required this.financeClientApproved,
    required this.installationWorkflowStatus,
    this.installationScheduledAt,
    required this.installationAssignedEmployeeEmails,
    required this.installationAssignedTeam,
    required this.installationNotes,
    required this.installationVisitHistory,
    required this.value,
    required this.deadline,
    required this.progress,
    required this.nextAction,
    required this.blocker,
    required this.tags,
    required this.conversationMessages,
    required this.history,
  });

  final String code;
  final ClientProfile client;
  final String workName;
  final String address;
  final String proposalFileName;
  final String? proposalFilePath;
  final String detailFileName;
  final String? detailFilePath;
  final String materialFileName;
  final String? materialFilePath;
  final String consolidatedProposalFileName;
  final String? consolidatedProposalFilePath;
  final String contractFileName;
  final String? contractFilePath;
  final String electricalProjectFileName;
  final String? electricalProjectFilePath;
  final String panelLayoutFileName;
  final String? panelLayoutFilePath;
  final String pushButtonTableFileName;
  final String? pushButtonTableFilePath;
  final String engineeringDataFileName;
  final String? engineeringDataFilePath;
  final Map<String, EngineeringChecklistStatus> engineeringChecklistStatuses;
  final Map<String, EngineeringTaskSchedule> engineeringActivitySchedules;
  final AssemblyWorkflowStatus assemblyWorkflowStatus;
  final List<String> assemblyAssignedEmployeeEmails;
  final WorkflowStage currentStage;
  final String owner;
  final Map<WorkflowStage, String> stageOwners;
  final String proposalGroupCode;
  final int proposalVersion;
  final WorkflowOrderKind kind;
  final String serviceDescription;
  final String serviceOrderFileName;
  final String? serviceOrderFilePath;
  final bool financeClientApproved;
  final InstallationWorkflowStatus installationWorkflowStatus;
  final DateTime? installationScheduledAt;
  final List<String> installationAssignedEmployeeEmails;
  final String installationAssignedTeam;
  final String installationNotes;
  final List<InstallationVisitLog> installationVisitHistory;
  final double value;
  final DateTime deadline;
  final double progress;
  final String nextAction;
  final String blocker;
  final List<String> tags;
  final List<OrderConversationMessage> conversationMessages;
  final Map<WorkflowStage, String> history;

  WorkflowOrder copyWith({
    ClientProfile? client,
    String? workName,
    String? address,
    String? proposalFileName,
    String? proposalFilePath,
    String? detailFileName,
    String? detailFilePath,
    WorkflowStage? currentStage,
    String? owner,
    Map<WorkflowStage, String>? stageOwners,
    String? proposalGroupCode,
    int? proposalVersion,
    WorkflowOrderKind? kind,
    String? serviceDescription,
    String? serviceOrderFileName,
    String? serviceOrderFilePath,
    bool? financeClientApproved,
    InstallationWorkflowStatus? installationWorkflowStatus,
    DateTime? installationScheduledAt,
    bool clearInstallationScheduledAt = false,
    List<String>? installationAssignedEmployeeEmails,
    String? installationAssignedTeam,
    String? installationNotes,
    List<InstallationVisitLog>? installationVisitHistory,
    double? value,
    DateTime? deadline,
    String? nextAction,
    String? blocker,
    double? progress,
    String? materialFileName,
    String? materialFilePath,
    String? consolidatedProposalFileName,
    String? consolidatedProposalFilePath,
    String? contractFileName,
    String? contractFilePath,
    String? electricalProjectFileName,
    String? electricalProjectFilePath,
    String? panelLayoutFileName,
    String? panelLayoutFilePath,
    String? pushButtonTableFileName,
    String? pushButtonTableFilePath,
    String? engineeringDataFileName,
    String? engineeringDataFilePath,
    Map<String, EngineeringChecklistStatus>? engineeringChecklistStatuses,
    Map<String, EngineeringTaskSchedule>? engineeringActivitySchedules,
    AssemblyWorkflowStatus? assemblyWorkflowStatus,
    List<String>? assemblyAssignedEmployeeEmails,
    List<String>? tags,
    List<OrderConversationMessage>? conversationMessages,
    Map<WorkflowStage, String>? history,
  }) {
    return WorkflowOrder(
      code: code,
      client: client ?? this.client,
      workName: workName ?? this.workName,
      address: address ?? this.address,
      proposalFileName: proposalFileName ?? this.proposalFileName,
      proposalFilePath: proposalFilePath ?? this.proposalFilePath,
      detailFileName: detailFileName ?? this.detailFileName,
      detailFilePath: detailFilePath ?? this.detailFilePath,
      materialFileName: materialFileName ?? this.materialFileName,
      materialFilePath: materialFilePath ?? this.materialFilePath,
      consolidatedProposalFileName:
          consolidatedProposalFileName ?? this.consolidatedProposalFileName,
      consolidatedProposalFilePath:
          consolidatedProposalFilePath ?? this.consolidatedProposalFilePath,
      contractFileName: contractFileName ?? this.contractFileName,
      contractFilePath: contractFilePath ?? this.contractFilePath,
      electricalProjectFileName:
          electricalProjectFileName ?? this.electricalProjectFileName,
      electricalProjectFilePath:
          electricalProjectFilePath ?? this.electricalProjectFilePath,
      panelLayoutFileName: panelLayoutFileName ?? this.panelLayoutFileName,
      panelLayoutFilePath: panelLayoutFilePath ?? this.panelLayoutFilePath,
      pushButtonTableFileName:
          pushButtonTableFileName ?? this.pushButtonTableFileName,
      pushButtonTableFilePath:
          pushButtonTableFilePath ?? this.pushButtonTableFilePath,
      engineeringDataFileName:
          engineeringDataFileName ?? this.engineeringDataFileName,
      engineeringDataFilePath:
          engineeringDataFilePath ?? this.engineeringDataFilePath,
      engineeringChecklistStatuses:
          engineeringChecklistStatuses ??
          Map<String, EngineeringChecklistStatus>.from(
            this.engineeringChecklistStatuses,
          ),
      engineeringActivitySchedules:
          engineeringActivitySchedules ??
          Map<String, EngineeringTaskSchedule>.from(
            this.engineeringActivitySchedules,
          ),
      assemblyWorkflowStatus:
          assemblyWorkflowStatus ?? this.assemblyWorkflowStatus,
      assemblyAssignedEmployeeEmails:
          assemblyAssignedEmployeeEmails ??
          List<String>.from(this.assemblyAssignedEmployeeEmails),
      currentStage: currentStage ?? this.currentStage,
      owner: owner ?? this.owner,
      stageOwners:
          stageOwners ?? Map<WorkflowStage, String>.from(this.stageOwners),
      proposalGroupCode: proposalGroupCode ?? this.proposalGroupCode,
      proposalVersion: proposalVersion ?? this.proposalVersion,
      kind: kind ?? this.kind,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      serviceOrderFileName: serviceOrderFileName ?? this.serviceOrderFileName,
      serviceOrderFilePath: serviceOrderFilePath ?? this.serviceOrderFilePath,
      financeClientApproved:
          financeClientApproved ?? this.financeClientApproved,
      installationWorkflowStatus:
          installationWorkflowStatus ?? this.installationWorkflowStatus,
      installationScheduledAt: clearInstallationScheduledAt
          ? null
          : installationScheduledAt ?? this.installationScheduledAt,
      installationAssignedEmployeeEmails:
          installationAssignedEmployeeEmails ??
          List<String>.from(this.installationAssignedEmployeeEmails),
      installationAssignedTeam:
          installationAssignedTeam ?? this.installationAssignedTeam,
      installationNotes: installationNotes ?? this.installationNotes,
      installationVisitHistory:
          installationVisitHistory ??
          List<InstallationVisitLog>.from(this.installationVisitHistory),
      value: value ?? this.value,
      deadline: deadline ?? this.deadline,
      progress: progress ?? this.progress,
      nextAction: nextAction ?? this.nextAction,
      blocker: blocker ?? this.blocker,
      tags: tags ?? this.tags,
      conversationMessages:
          conversationMessages ??
          List<OrderConversationMessage>.from(this.conversationMessages),
      history: history ?? Map<WorkflowStage, String>.from(this.history),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'code': code,
      'client': client.toMap(),
      'workName': workName,
      'address': address,
      'proposalFileName': proposalFileName,
      'proposalFilePath': proposalFilePath,
      'detailFileName': detailFileName,
      'detailFilePath': detailFilePath,
      'materialFileName': materialFileName,
      'materialFilePath': materialFilePath,
      'consolidatedProposalFileName': consolidatedProposalFileName,
      'consolidatedProposalFilePath': consolidatedProposalFilePath,
      'contractFileName': contractFileName,
      'contractFilePath': contractFilePath,
      'electricalProjectFileName': electricalProjectFileName,
      'electricalProjectFilePath': electricalProjectFilePath,
      'panelLayoutFileName': panelLayoutFileName,
      'panelLayoutFilePath': panelLayoutFilePath,
      'pushButtonTableFileName': pushButtonTableFileName,
      'pushButtonTableFilePath': pushButtonTableFilePath,
      'engineeringDataFileName': engineeringDataFileName,
      'engineeringDataFilePath': engineeringDataFilePath,
      'engineeringChecklistStatuses': {
        for (final entry in engineeringChecklistStatuses.entries)
          entry.key: entry.value.name,
      },
      'engineeringActivitySchedules': {
        for (final entry in engineeringActivitySchedules.entries)
          entry.key: entry.value.toMap(),
      },
      'assemblyWorkflowStatus': assemblyWorkflowStatus.name,
      'assemblyAssignedEmployeeEmails': assemblyAssignedEmployeeEmails,
      'currentStage': currentStage.name,
      'owner': owner,
      'stageOwners': {
        for (final entry in stageOwners.entries) entry.key.name: entry.value,
      },
      'proposalGroupCode': proposalGroupCode,
      'proposalVersion': proposalVersion,
      'kind': kind.name,
      'serviceDescription': serviceDescription,
      'serviceOrderFileName': serviceOrderFileName,
      'serviceOrderFilePath': serviceOrderFilePath,
      'financeClientApproved': financeClientApproved,
      'installationWorkflowStatus': installationWorkflowStatus.name,
      'installationScheduledAt': installationScheduledAt,
      'installationAssignedEmployeeEmails': installationAssignedEmployeeEmails,
      'installationAssignedTeam': installationAssignedTeam,
      'installationNotes': installationNotes,
      'installationVisitHistory': installationVisitHistory
          .map((visit) => visit.toMap())
          .toList(growable: false),
      'value': value,
      'deadline': deadline,
      'progress': progress,
      'nextAction': nextAction,
      'blocker': blocker,
      'tags': tags,
      'conversationMessages': conversationMessages
          .map((message) => message.toMap())
          .toList(growable: false),
      'history': {
        for (final entry in history.entries) entry.key.name: entry.value,
      },
    };
  }

  factory WorkflowOrder.fromMap(Map<String, dynamic> map) {
    final rawClient = map['client'];
    final rawHistory = map['history'];
    final rawTags = map['tags'];
    final rawEngineeringChecklistStatuses = map['engineeringChecklistStatuses'];
    final rawEngineeringActivitySchedules = map['engineeringActivitySchedules'];
    final rawAssemblyAssignedEmployeeEmails =
        map['assemblyAssignedEmployeeEmails'];
    final rawInstallationAssignedEmployeeEmails =
        map['installationAssignedEmployeeEmails'];
    final rawInstallationVisitHistory = map['installationVisitHistory'];
    final rawStageOwners = map['stageOwners'];
    final rawConversationMessages = map['conversationMessages'];
    return WorkflowOrder(
      code: (map['code'] ?? '').toString(),
      client: ClientProfile.fromMap(
        rawClient is Map<String, dynamic>
            ? rawClient
            : Map<String, dynamic>.from(rawClient as Map? ?? const {}),
      ),
      workName: (map['workName'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      proposalFileName: (map['proposalFileName'] ?? '').toString(),
      proposalFilePath: _readOptionalString(map['proposalFilePath']),
      detailFileName: (map['detailFileName'] ?? '').toString(),
      detailFilePath: _readOptionalString(map['detailFilePath']),
      materialFileName: (map['materialFileName'] ?? '').toString(),
      materialFilePath: _readOptionalString(map['materialFilePath']),
      consolidatedProposalFileName: (map['consolidatedProposalFileName'] ?? '')
          .toString(),
      consolidatedProposalFilePath: _readOptionalString(
        map['consolidatedProposalFilePath'],
      ),
      contractFileName: (map['contractFileName'] ?? '').toString(),
      contractFilePath: _readOptionalString(map['contractFilePath']),
      electricalProjectFileName: (map['electricalProjectFileName'] ?? '')
          .toString(),
      electricalProjectFilePath: _readOptionalString(
        map['electricalProjectFilePath'],
      ),
      panelLayoutFileName: (map['panelLayoutFileName'] ?? '').toString(),
      panelLayoutFilePath: _readOptionalString(map['panelLayoutFilePath']),
      pushButtonTableFileName: (map['pushButtonTableFileName'] ?? '')
          .toString(),
      pushButtonTableFilePath: _readOptionalString(
        map['pushButtonTableFilePath'],
      ),
      engineeringDataFileName: (map['engineeringDataFileName'] ?? '')
          .toString(),
      engineeringDataFilePath: _readOptionalString(
        map['engineeringDataFilePath'],
      ),
      engineeringChecklistStatuses: rawEngineeringChecklistStatuses is Map
          ? Map<String, dynamic>.from(rawEngineeringChecklistStatuses).map(
              (key, value) => MapEntry(
                key,
                _readEngineeringChecklistStatus(value?.toString()),
              ),
            )
          : const {},
      engineeringActivitySchedules: rawEngineeringActivitySchedules is Map
          ? Map<String, dynamic>.from(rawEngineeringActivitySchedules).map(
              (key, value) => MapEntry(
                key,
                EngineeringTaskSchedule.fromMap(
                  value is Map<String, dynamic>
                      ? value
                      : Map<String, dynamic>.from(value as Map? ?? const {}),
                ),
              ),
            )
          : const {},
      assemblyWorkflowStatus: _readAssemblyWorkflowStatus(
        (map['assemblyWorkflowStatus'] ?? AssemblyWorkflowStatus.waiting.name)
            .toString(),
      ),
      assemblyAssignedEmployeeEmails:
          rawAssemblyAssignedEmployeeEmails is Iterable
          ? rawAssemblyAssignedEmployeeEmails
                .map((item) => item.toString().trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      currentStage: _readWorkflowStage(
        (map['currentStage'] ?? WorkflowStage.customerRegistration.name)
            .toString(),
      ),
      owner: (map['owner'] ?? '').toString(),
      stageOwners: rawStageOwners is Map
          ? Map<String, dynamic>.from(rawStageOwners).map(
              (key, value) =>
                  MapEntry(_readWorkflowStage(key), value.toString()),
            )
          : const {},
      proposalGroupCode:
          _readOptionalString(map['proposalGroupCode']) ??
          (map['code'] ?? '').toString(),
      proposalVersion: _readInt(map['proposalVersion'], fallback: 1),
      kind: _readWorkflowOrderKind((map['kind'] ?? '').toString()),
      serviceDescription: (map['serviceDescription'] ?? '').toString(),
      serviceOrderFileName: (map['serviceOrderFileName'] ?? '').toString(),
      serviceOrderFilePath: _readOptionalString(map['serviceOrderFilePath']),
      financeClientApproved: _readBool(map['financeClientApproved']),
      installationWorkflowStatus: _readInstallationWorkflowStatus(
        (map['installationWorkflowStatus'] ?? '').toString(),
        map['installationScheduledAt'],
      ),
      installationScheduledAt: _readNullableDateTime(
        map['installationScheduledAt'],
      ),
      installationAssignedEmployeeEmails:
          rawInstallationAssignedEmployeeEmails is Iterable
          ? rawInstallationAssignedEmployeeEmails
                .map((item) => item.toString().trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      installationAssignedTeam: (map['installationAssignedTeam'] ?? '')
          .toString(),
      installationNotes: (map['installationNotes'] ?? '').toString(),
      installationVisitHistory: rawInstallationVisitHistory is Iterable
          ? rawInstallationVisitHistory
                .map(
                  (item) => InstallationVisitLog.fromMap(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map? ?? const {}),
                  ),
                )
                .toList(growable: false)
          : const [],
      value: _readDouble(map['value']),
      deadline: _readDateTime(map['deadline']),
      progress: _readDouble(map['progress']),
      nextAction: (map['nextAction'] ?? '').toString(),
      blocker: (map['blocker'] ?? '').toString(),
      tags: rawTags is Iterable
          ? rawTags.map((item) => item.toString()).toList(growable: false)
          : const [],
      conversationMessages: rawConversationMessages is Iterable
          ? rawConversationMessages
                .map(
                  (item) => OrderConversationMessage.fromMap(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map? ?? const {}),
                  ),
                )
                .toList(growable: false)
          : const [],
      history: rawHistory is Map
          ? Map<String, dynamic>.from(rawHistory).map(
              (key, value) =>
                  MapEntry(_readWorkflowStage(key), value.toString()),
            )
          : const {},
    );
  }

  String ownerForStage(WorkflowStage stage) {
    final stageOwner = stageOwners[stage]?.trim();
    if (stageOwner != null && stageOwner.isNotEmpty) {
      return stageOwner;
    }

    final fallbackOwner = owner.trim();
    if (fallbackOwner.isEmpty) {
      return '';
    }

    final currentIndex = WorkflowStage.values.indexOf(currentStage);
    final fallbackStage = currentIndex > 0
        ? WorkflowStage.values[currentIndex - 1]
        : currentStage;
    return fallbackStage == stage ? fallbackOwner : '';
  }

  Map<WorkflowStage, String> resolvedStageOwners() {
    final resolved = <WorkflowStage, String>{};

    for (final stage in WorkflowStage.values) {
      final owner = ownerForStage(stage);
      if (owner.isNotEmpty) {
        resolved[stage] = owner;
      }
    }

    return resolved;
  }

  bool get isServiceOrder => kind == WorkflowOrderKind.serviceOrder;
  bool get isPrimaryProposal => proposalVersion <= 1;
}

EngineeringChecklistStatus _readEngineeringChecklistStatus(String? rawValue) {
  if (rawValue == EngineeringChecklistStatus.inProgress.name) {
    return EngineeringChecklistStatus.notStarted;
  }

  return EngineeringChecklistStatus.values.firstWhere(
    (status) => status.name == rawValue,
    orElse: () => EngineeringChecklistStatus.notStarted,
  );
}

WorkflowOrderKind _readWorkflowOrderKind(String rawValue) {
  return WorkflowOrderKind.values.firstWhere(
    (kind) => kind.name == rawValue,
    orElse: () => WorkflowOrderKind.standard,
  );
}

enum WorkspaceTaskStatus { today, doing, waiting, done }

extension WorkspaceTaskStatusPresentation on WorkspaceTaskStatus {
  String get title => switch (this) {
    WorkspaceTaskStatus.today => 'Hoje',
    WorkspaceTaskStatus.doing => 'Em andamento',
    WorkspaceTaskStatus.waiting => 'Aguardando',
    WorkspaceTaskStatus.done => 'Concluído',
  };

  Color get color => switch (this) {
    WorkspaceTaskStatus.today => const Color(0xFF2563EB),
    WorkspaceTaskStatus.doing => const Color(0xFF7C3AED),
    WorkspaceTaskStatus.waiting => const Color(0xFFB45309),
    WorkspaceTaskStatus.done => const Color(0xFF15803D),
  };
}

class EmployeeWorkspaceProfile {
  const EmployeeWorkspaceProfile({
    required this.email,
    required this.login,
    required this.name,
    required this.cellPhone,
    required this.role,
    required this.isAdministrator,
    required this.allowedStages,
    required this.accent,
    required this.accessCodeHash,
    this.photoFileName = '',
    this.photoFilePath,
  });

  final String email;
  final String login;
  final String name;
  final String cellPhone;
  final String role;
  final bool isAdministrator;
  final List<WorkflowStage> allowedStages;
  final Color accent;
  final String accessCodeHash;
  final String photoFileName;
  final String? photoFilePath;

  EmployeeWorkspaceProfile copyWith({
    String? email,
    String? login,
    String? name,
    String? cellPhone,
    String? role,
    bool? isAdministrator,
    List<WorkflowStage>? allowedStages,
    Color? accent,
    String? accessCodeHash,
    String? photoFileName,
    String? photoFilePath,
  }) {
    return EmployeeWorkspaceProfile(
      email: email ?? this.email,
      login: login ?? this.login,
      name: name ?? this.name,
      cellPhone: cellPhone ?? this.cellPhone,
      role: role ?? this.role,
      isAdministrator: isAdministrator ?? this.isAdministrator,
      allowedStages: allowedStages ?? this.allowedStages,
      accent: accent ?? this.accent,
      accessCodeHash: accessCodeHash ?? this.accessCodeHash,
      photoFileName: photoFileName ?? this.photoFileName,
      photoFilePath: photoFilePath ?? this.photoFilePath,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'email': email,
      'login': login,
      'name': name,
      'cellPhone': cellPhone,
      'role': role,
      'isAdministrator': isAdministrator,
      'allowedStages': allowedStages.map((stage) => stage.name).toList(),
      'accent': accent.toARGB32(),
      'accessCodeHash': accessCodeHash,
      'photoFileName': photoFileName,
      'photoFilePath': photoFilePath,
    };
  }

  factory EmployeeWorkspaceProfile.fromMap(Map<String, dynamic> map) {
    final rawAllowedStages = map['allowedStages'];
    final email = (map['email'] ?? '').toString().trim().toLowerCase();
    final login = (map['login'] ?? _legacyLoginFromEmail(email)).toString();
    return EmployeeWorkspaceProfile(
      email: email,
      login: login,
      name: (map['name'] ?? '').toString(),
      cellPhone: (map['cellPhone'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      isAdministrator: map['isAdministrator'] == true,
      allowedStages: rawAllowedStages is Iterable
          ? rawAllowedStages
                .map((item) => _readWorkflowStage(item.toString()))
                .toList(growable: false)
          : const [WorkflowStage.customerRegistration],
      accent: Color(_readInt(map['accent'], fallback: 0xFF12372A)),
      accessCodeHash: (map['accessCodeHash'] ?? '').toString(),
      photoFileName: (map['photoFileName'] ?? '').toString(),
      photoFilePath: map['photoFilePath']?.toString(),
    );
  }
}

String _legacyLoginFromEmail(String email) {
  if (email.isEmpty) {
    return '';
  }

  final atIndex = email.indexOf('@');
  if (atIndex <= 0) {
    return email;
  }

  return email.substring(0, atIndex);
}

class WorkspaceTask {
  const WorkspaceTask({
    required this.id,
    required this.title,
    required this.summary,
    required this.orderCode,
    required this.stage,
    required this.status,
    required this.assigneeEmail,
    required this.priorityLabel,
    required this.dueLabel,
  });

  final String id;
  final String title;
  final String summary;
  final String orderCode;
  final WorkflowStage stage;
  final WorkspaceTaskStatus status;
  final String assigneeEmail;
  final String priorityLabel;
  final String dueLabel;
}

WorkflowStage _readWorkflowStage(String rawValue) {
  return WorkflowStage.values.firstWhere(
    (stage) => stage.name == rawValue,
    orElse: () => WorkflowStage.customerRegistration,
  );
}

AssemblyWorkflowStatus _readAssemblyWorkflowStatus(String rawValue) {
  return AssemblyWorkflowStatus.values.firstWhere(
    (status) => status.name == rawValue,
    orElse: () => AssemblyWorkflowStatus.waiting,
  );
}

InstallationWorkflowStatus _readInstallationWorkflowStatus(
  String rawValue,
  Object? legacySchedule,
) {
  return InstallationWorkflowStatus.values.firstWhere(
    (status) => status.name == rawValue,
    orElse: () => _readNullableDateTime(legacySchedule) == null
        ? InstallationWorkflowStatus.waiting
        : InstallationWorkflowStatus.scheduled,
  );
}

String? _readOptionalString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }

  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime _readDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  try {
    final dynamic dynamicValue = value;
    if (dynamicValue != null) {
      final converted = dynamicValue.toDate();
      if (converted is DateTime) {
        return converted;
      }
    }
  } catch (_) {
    // Firestore may provide a non-Date object here during local parsing.
  }

  return DateTime.now();
}

DateTime? _readNullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }

  return _readDateTime(value);
}
