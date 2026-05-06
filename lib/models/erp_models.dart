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
  EngineeringChecklistTask(key: 'depending_on_client', label: 'Aguardando'),
  EngineeringChecklistTask(
    key: 'awaiting_presentation',
    label: 'Aguardando Apresentação',
    supportsScheduling: true,
  ),
  EngineeringChecklistTask(
    key: 'presentation_done',
    label: 'Apresentação realizada',
  ),
  EngineeringChecklistTask(
    key: 'meeting_electrician',
    label: 'Reunião com Eletricista',
    supportsScheduling: true,
  ),
  EngineeringChecklistTask(
    key: 'executing_electrical',
    label: 'Executando elétrica',
  ),
  EngineeringChecklistTask(
    key: 'released_for_conference',
    label: 'Liberado para conferencia',
    supportsScheduling: true,
  ),
  EngineeringChecklistTask(
    key: 'conference_done',
    label: 'Conferencia realizada',
  ),
];

const List<String> _legacyEngineeringTaskKeys = [
  'project_presentation',
  'review',
  'site_presentation',
  'cable_conference',
  'site_folder',
];

class FinanceContractTask {
  const FinanceContractTask({required this.key, required this.label});

  final String key;
  final String label;
}

const List<FinanceContractTask> financeContractTasks = [
  FinanceContractTask(key: 'waiting', label: 'Aguardando'),
  FinanceContractTask(key: 'generate_contract', label: 'Gerar contrato'),
  FinanceContractTask(key: 'contract_sent', label: 'Enviado contrato'),
  FinanceContractTask(
    key: 'signed_contract_received',
    label: 'Receber contrato assinado',
  ),
  FinanceContractTask(
    key: 'registered_accounts_receivable',
    label: 'Cadastrar no contas a receber',
  ),
];

class EstimatingKanbanTask {
  const EstimatingKanbanTask({required this.key, required this.label});

  final String key;
  final String label;
}

const List<EstimatingKanbanTask> estimatingKanbanTasks = [
  EstimatingKanbanTask(
    key: 'waiting',
    label: 'Aguardando',
  ),
  EstimatingKanbanTask(
    key: 'doing',
    label: 'Executando',
  ),
];

class RelationshipKanbanTask {
  const RelationshipKanbanTask({required this.key, required this.label});

  final String key;
  final String label;
}

const List<RelationshipKanbanTask> relationshipKanbanTasks = [
  RelationshipKanbanTask(
    key: 'in_progress',
    label: 'Em Andamento',
  ),
  RelationshipKanbanTask(
    key: 'create_omie_material_order',
    label: 'Criar Pedido Omie',
  ),
  RelationshipKanbanTask(
    key: 'update_worksheet',
    label: 'Planilha de Obras',
  ),
  RelationshipKanbanTask(
    key: 'create_whatsapp_group',
    label: 'Grupo Whats',
  ),
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

enum AssemblyWorkflowStatus { released, waiting, doing, panelTesting, done }

class AssemblyChecklistSection {
  const AssemblyChecklistSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

const AssemblyChecklistSection assemblyPreparationChecklistSection =
    AssemblyChecklistSection(
      title: '1. Preparação Inicial',
      items: [
        'Módulos DMC / DMD',
        'Carcaça dos módulos',
        'Anilhas',
        'Central DSC',
        'Fonte',
        'Bornes de comunicação',
        'Canaletas',
        'Trilhos DIN',
        'Disjuntor monopolar 10A p/ fonte',
      ],
    );

const AssemblyChecklistSection
assemblyMechanicalCanaletasChecklistSection = AssemblyChecklistSection(
  title: '2.1 Canaletas',
  items: [
    'Cortar as canaletas conforme medidas do layout',
    'Fixar as canaletas no painel com parafusos brocantes',
    'Furar fundo das canaletas conforme placa de montagem para fixação no painel',
    'Apagar todos os riscos de lápis ou outros que houver',
  ],
);

const AssemblyChecklistSection assemblyMechanicalModulesChecklistSection =
    AssemblyChecklistSection(
      title: '2.2 Módulos e Trilhos',
      items: [
        'Fixar as carcaças dos módulos DANF',
        'Instalar os trilhos DIN',
        'Inserir os bornes e o disjuntor no trilho DIN',
        'Fixar a central e a fonte conforme o layout',
        'Fixar os módulos em suas carcaças',
      ],
    );

const AssemblyChecklistSection
assemblyPulseWiringChecklistSection = AssemblyChecklistSection(
  title: '3.1 Cabeamento de Pulso',
  items: [
    'Realizar o cabeamento de pulso dos módulos até os bornes (cabo vermelho)',
    'Identificar e anilhar corretamente todos os cabos',
  ],
);

const AssemblyChecklistSection
assemblyPower24ChecklistSection = AssemblyChecklistSection(
  title: '3.2 Alimentação 24 VCC',
  items: [
    'Realizar o cabeamento de +24 VCC e -24 VCC para todos os módulos e fonte',
    'Conectar o +24 VCC nos bornes 9, 18 ...',
  ],
);

const AssemblyChecklistSection
assemblyPower127ChecklistSection = AssemblyChecklistSection(
  title: '3.3 Alimentação 127 VCA',
  items: [
    'Fazer as ligações de 127 VCA dos módulos (dois módulos por fase cabo amarelo)',
    'Deixar o último módulo com rabicho para conexão da fase vinda do painel de energia',
  ],
);

const AssemblyChecklistSection assemblyFinalizationChecklistSection =
    AssemblyChecklistSection(
      title: '4. Finalização',
      items: [
        'Cortar as tampas das canaletas deixar sem risco',
        'Ajustar endereçamento dos módulos',
        'Conferir identificação e limpeza do painel',
        'Fazer teste completo do painel (funcionalidade e continuidade)',
        'Enviar para Automação fazer o teste',
      ],
    );

const List<AssemblyChecklistSection> assemblyChecklistSections = [
  assemblyPreparationChecklistSection,
  assemblyMechanicalCanaletasChecklistSection,
  assemblyMechanicalModulesChecklistSection,
  assemblyPulseWiringChecklistSection,
  assemblyPower24ChecklistSection,
  assemblyPower127ChecklistSection,
  assemblyFinalizationChecklistSection,
];

final List<String> assemblyPreparationChecklistItems = [
  ...assemblyPreparationChecklistSection.items,
];

const List<AssemblyChecklistSection> assemblyExecutionChecklistSections = [
  assemblyMechanicalCanaletasChecklistSection,
  assemblyMechanicalModulesChecklistSection,
  assemblyPulseWiringChecklistSection,
  assemblyPower24ChecklistSection,
  assemblyPower127ChecklistSection,
  assemblyFinalizationChecklistSection,
];

final List<String> assemblyExecutionChecklistItems = [
  ...assemblyMechanicalCanaletasChecklistSection.items,
  ...assemblyMechanicalModulesChecklistSection.items,
  ...assemblyPulseWiringChecklistSection.items,
  ...assemblyPower24ChecklistSection.items,
  ...assemblyPower127ChecklistSection.items,
  ...assemblyFinalizationChecklistSection.items,
];

extension AssemblyWorkflowStatusPresentation on AssemblyWorkflowStatus {
  String get title => switch (this) {
    AssemblyWorkflowStatus.released => 'Liberado para Montagem',
    AssemblyWorkflowStatus.waiting => 'Aguardando',
    AssemblyWorkflowStatus.doing => 'Em andamento',
    AssemblyWorkflowStatus.panelTesting => 'Teste de painel',
    AssemblyWorkflowStatus.done => 'Concluído',
  };

  Color get color => switch (this) {
    AssemblyWorkflowStatus.released => const Color(0xFF64748B),
    AssemblyWorkflowStatus.waiting => const Color(0xFFB45309),
    AssemblyWorkflowStatus.doing => const Color(0xFF2563EB),
    AssemblyWorkflowStatus.panelTesting => const Color(0xFF7C3AED),
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
    required this.serviceTime,
    required this.notes,
    required this.createdAt,
  });

  final DateTime scheduledAt;
  final List<String> employeeEmails;
  final List<String> plannedItems;
  final List<String> completedItems;
  final String serviceTime;
  final String notes;
  final DateTime createdAt;

  InstallationVisitLog copyWith({
    DateTime? scheduledAt,
    List<String>? employeeEmails,
    List<String>? plannedItems,
    List<String>? completedItems,
    String? serviceTime,
    String? notes,
    DateTime? createdAt,
  }) {
    return InstallationVisitLog(
      scheduledAt: scheduledAt ?? this.scheduledAt,
      employeeEmails: employeeEmails ?? List<String>.from(this.employeeEmails),
      plannedItems: plannedItems ?? List<String>.from(this.plannedItems),
      completedItems: completedItems ?? List<String>.from(this.completedItems),
      serviceTime: serviceTime ?? this.serviceTime,
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
      'serviceTime': serviceTime,
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
      serviceTime: (map['serviceTime'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: _readDateTime(map['createdAt']),
    );
  }
}

class ClientProfile {
  const ClientProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.email,
    required this.rg,
    required this.cpf,
    required this.city,
    required this.postalCode,
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.complement,
    required this.segment,
    required this.contact,
    required this.phone,
    required this.temperature,
  });

  final String id;
  final String name;
  final String birthDate;
  final String email;
  final String rg;
  final String cpf;
  final String city;
  final String postalCode;
  final String street;
  final String number;
  final String neighborhood;
  final String complement;
  final String segment;
  final String contact;
  final String phone;
  final String temperature;

  ClientProfile copyWith({
    String? id,
    String? name,
    String? birthDate,
    String? email,
    String? rg,
    String? cpf,
    String? city,
    String? postalCode,
    String? street,
    String? number,
    String? neighborhood,
    String? complement,
    String? segment,
    String? contact,
    String? phone,
    String? temperature,
  }) {
    return ClientProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      email: email ?? this.email,
      rg: rg ?? this.rg,
      cpf: cpf ?? this.cpf,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      street: street ?? this.street,
      number: number ?? this.number,
      neighborhood: neighborhood ?? this.neighborhood,
      complement: complement ?? this.complement,
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
      'birthDate': birthDate,
      'email': email,
      'rg': rg,
      'cpf': cpf,
      'city': city,
      'postalCode': postalCode,
      'street': street,
      'number': number,
      'neighborhood': neighborhood,
      'complement': complement,
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
      birthDate: (map['birthDate'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      rg: (map['rg'] ?? '').toString(),
      cpf: (map['cpf'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      postalCode: (map['postalCode'] ?? '').toString(),
      street: (map['street'] ?? '').toString(),
      number: (map['number'] ?? '').toString(),
      neighborhood: (map['neighborhood'] ?? '').toString(),
      complement: (map['complement'] ?? '').toString(),
      segment: (map['segment'] ?? '').toString(),
      contact: (map['contact'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      temperature: (map['temperature'] ?? '').toString(),
    );
  }
}

class ProposalServiceEntry {
  const ProposalServiceEntry({
    required this.serviceName,
    required this.consolidated,
    required this.prepareInProject,
    required this.observations,
  });

  final String serviceName;
  final String consolidated;
  final String prepareInProject;
  final String observations;

  ProposalServiceEntry copyWith({
    String? serviceName,
    String? consolidated,
    String? prepareInProject,
    String? observations,
  }) {
    return ProposalServiceEntry(
      serviceName: serviceName ?? this.serviceName,
      consolidated: consolidated ?? this.consolidated,
      prepareInProject: prepareInProject ?? this.prepareInProject,
      observations: observations ?? this.observations,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'serviceName': serviceName,
      'consolidated': consolidated,
      'prepareInProject': prepareInProject,
      'observations': observations,
    };
  }

  factory ProposalServiceEntry.fromMap(Map<String, dynamic> map) {
    return ProposalServiceEntry(
      serviceName: (map['serviceName'] ?? '').toString(),
      consolidated: (map['consolidated'] ?? '').toString(),
      prepareInProject: (map['prepareInProject'] ?? '').toString(),
      observations: (map['observations'] ?? '').toString(),
    );
  }
}

class WhatsappGroupMember {
  const WhatsappGroupMember({
    required this.name,
    required this.phone,
    required this.role,
  });

  final String name;
  final String phone;
  final String role;

  WhatsappGroupMember copyWith({String? name, String? phone, String? role}) {
    return WhatsappGroupMember(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toMap() {
    return {'name': name, 'phone': phone, 'role': role};
  }

  factory WhatsappGroupMember.fromMap(Map<String, dynamic> map) {
    return WhatsappGroupMember(
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
    );
  }
}

class EstimatingIncludedVisitEntry {
  const EstimatingIncludedVisitEntry({required this.label, required this.days});

  final String label;
  final String days;

  EstimatingIncludedVisitEntry copyWith({String? label, String? days}) {
    return EstimatingIncludedVisitEntry(
      label: label ?? this.label,
      days: days ?? this.days,
    );
  }

  Map<String, Object?> toMap() {
    return {'label': label, 'days': days};
  }

  factory EstimatingIncludedVisitEntry.fromMap(Map<String, dynamic> map) {
    return EstimatingIncludedVisitEntry(
      label: (map['label'] ?? '').toString(),
      days: (map['days'] ?? '').toString(),
    );
  }
}

class EstimatingMaterialEntry {
  const EstimatingMaterialEntry({
    required this.quantity,
    required this.description,
    required this.model,
  });

  final String quantity;
  final String description;
  final String model;

  EstimatingMaterialEntry copyWith({
    String? quantity,
    String? description,
    String? model,
  }) {
    return EstimatingMaterialEntry(
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      model: model ?? this.model,
    );
  }

  Map<String, Object?> toMap() {
    return {'quantity': quantity, 'description': description, 'model': model};
  }

  factory EstimatingMaterialEntry.fromMap(Map<String, dynamic> map) {
    return EstimatingMaterialEntry(
      quantity: (map['quantity'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      model: (map['model'] ?? '').toString(),
    );
  }
}

class WorkflowOrder {
  const WorkflowOrder({
    required this.code,
    required this.client,
    required this.workName,
    required this.address,
    required this.workPostalCode,
    required this.workStreet,
    required this.workNumber,
    required this.workNeighborhood,
    required this.workComplement,
    required this.proposalFileName,
    this.proposalFilePath,
    required this.detailFileName,
    this.detailFilePath,
    required this.materialFileName,
    this.materialFilePath,
    required this.estimatingIncludedVisits,
    required this.estimatingMaterials,
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
    required this.financeContractStatuses,
    required this.estimatingKanbanStatuses,
    required this.relationshipKanbanStatuses,
    required this.assemblyPreparationChecklist,
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
    required this.commercialProposalNumber,
    required this.paymentType,
    required this.paymentMethod,
    required this.paymentObservation,
    required this.installmentValue,
    required this.installmentCount,
    required this.paymentDate,
    required this.rtValue,
    required this.integratorValue,
    required this.integratorName,
    required this.architectName,
    required this.proposalServices,
    required this.isDanfClient,
    required this.danfInstallerName,
    required this.canHaveDanfPlate,
    required this.hasWhatsappGroup,
    required this.whatsappGroupMembers,
    required this.whatsappGroupObservation,
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
  final String workPostalCode;
  final String workStreet;
  final String workNumber;
  final String workNeighborhood;
  final String workComplement;
  final String proposalFileName;
  final String? proposalFilePath;
  final String detailFileName;
  final String? detailFilePath;
  final String materialFileName;
  final String? materialFilePath;
  final List<EstimatingIncludedVisitEntry> estimatingIncludedVisits;
  final List<EstimatingMaterialEntry> estimatingMaterials;
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
  final Map<String, EngineeringChecklistStatus> financeContractStatuses;
  final Map<String, EngineeringChecklistStatus> estimatingKanbanStatuses;
  final Map<String, EngineeringChecklistStatus> relationshipKanbanStatuses;
  final Map<String, bool> assemblyPreparationChecklist;
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
  final String commercialProposalNumber;
  final String paymentType;
  final String paymentMethod;
  final String paymentObservation;
  final String installmentValue;
  final String installmentCount;
  final String paymentDate;
  final String rtValue;
  final String integratorValue;
  final String integratorName;
  final String architectName;
  final List<ProposalServiceEntry> proposalServices;
  final String isDanfClient;
  final String danfInstallerName;
  final String canHaveDanfPlate;
  final String hasWhatsappGroup;
  final List<WhatsappGroupMember> whatsappGroupMembers;
  final String whatsappGroupObservation;
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
    String? workPostalCode,
    String? workStreet,
    String? workNumber,
    String? workNeighborhood,
    String? workComplement,
    String? proposalFileName,
    String? proposalFilePath,
    String? detailFileName,
    String? detailFilePath,
    String? materialFileName,
    String? materialFilePath,
    List<EstimatingIncludedVisitEntry>? estimatingIncludedVisits,
    List<EstimatingMaterialEntry>? estimatingMaterials,
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
    String? commercialProposalNumber,
    String? paymentType,
    String? paymentMethod,
    String? paymentObservation,
    String? installmentValue,
    String? installmentCount,
    String? paymentDate,
    String? rtValue,
    String? integratorValue,
    String? integratorName,
    String? architectName,
    List<ProposalServiceEntry>? proposalServices,
    String? isDanfClient,
    String? danfInstallerName,
    String? canHaveDanfPlate,
    String? hasWhatsappGroup,
    List<WhatsappGroupMember>? whatsappGroupMembers,
    String? whatsappGroupObservation,
    DateTime? deadline,
    String? nextAction,
    String? blocker,
    double? progress,
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
    Map<String, EngineeringChecklistStatus>? financeContractStatuses,
    Map<String, EngineeringChecklistStatus>? estimatingKanbanStatuses,
    Map<String, EngineeringChecklistStatus>? relationshipKanbanStatuses,
    Map<String, bool>? assemblyPreparationChecklist,
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
      workPostalCode: workPostalCode ?? this.workPostalCode,
      workStreet: workStreet ?? this.workStreet,
      workNumber: workNumber ?? this.workNumber,
      workNeighborhood: workNeighborhood ?? this.workNeighborhood,
      workComplement: workComplement ?? this.workComplement,
      proposalFileName: proposalFileName ?? this.proposalFileName,
      proposalFilePath: proposalFilePath ?? this.proposalFilePath,
      detailFileName: detailFileName ?? this.detailFileName,
      detailFilePath: detailFilePath ?? this.detailFilePath,
      materialFileName: materialFileName ?? this.materialFileName,
      materialFilePath: materialFilePath ?? this.materialFilePath,
      estimatingIncludedVisits:
          estimatingIncludedVisits ??
          List<EstimatingIncludedVisitEntry>.from(
            this.estimatingIncludedVisits,
          ),
      estimatingMaterials:
          estimatingMaterials ??
          List<EstimatingMaterialEntry>.from(this.estimatingMaterials),
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
      financeContractStatuses:
          financeContractStatuses ??
          Map<String, EngineeringChecklistStatus>.from(
            this.financeContractStatuses,
          ),
      estimatingKanbanStatuses:
          estimatingKanbanStatuses ??
          Map<String, EngineeringChecklistStatus>.from(
            this.estimatingKanbanStatuses,
          ),
      relationshipKanbanStatuses:
          relationshipKanbanStatuses ??
          Map<String, EngineeringChecklistStatus>.from(
            this.relationshipKanbanStatuses,
          ),
      assemblyPreparationChecklist:
          assemblyPreparationChecklist ??
          Map<String, bool>.from(this.assemblyPreparationChecklist),
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
      commercialProposalNumber:
          commercialProposalNumber ?? this.commercialProposalNumber,
      paymentType: paymentType ?? this.paymentType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentObservation: paymentObservation ?? this.paymentObservation,
      installmentValue: installmentValue ?? this.installmentValue,
      installmentCount: installmentCount ?? this.installmentCount,
      paymentDate: paymentDate ?? this.paymentDate,
      rtValue: rtValue ?? this.rtValue,
      integratorValue: integratorValue ?? this.integratorValue,
      integratorName: integratorName ?? this.integratorName,
      architectName: architectName ?? this.architectName,
      proposalServices:
          proposalServices ??
          List<ProposalServiceEntry>.from(this.proposalServices),
      isDanfClient: isDanfClient ?? this.isDanfClient,
      danfInstallerName: danfInstallerName ?? this.danfInstallerName,
      canHaveDanfPlate: canHaveDanfPlate ?? this.canHaveDanfPlate,
      hasWhatsappGroup: hasWhatsappGroup ?? this.hasWhatsappGroup,
      whatsappGroupMembers:
          whatsappGroupMembers ??
          List<WhatsappGroupMember>.from(this.whatsappGroupMembers),
      whatsappGroupObservation:
          whatsappGroupObservation ?? this.whatsappGroupObservation,
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
      'workPostalCode': workPostalCode,
      'workStreet': workStreet,
      'workNumber': workNumber,
      'workNeighborhood': workNeighborhood,
      'workComplement': workComplement,
      'proposalFileName': proposalFileName,
      'proposalFilePath': proposalFilePath,
      'detailFileName': detailFileName,
      'detailFilePath': detailFilePath,
      'materialFileName': materialFileName,
      'materialFilePath': materialFilePath,
      'estimatingIncludedVisits': estimatingIncludedVisits
          .map((entry) => entry.toMap())
          .toList(growable: false),
      'estimatingMaterials': estimatingMaterials
          .map((entry) => entry.toMap())
          .toList(growable: false),
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
      'financeContractStatuses': {
        for (final entry in financeContractStatuses.entries)
          entry.key: entry.value.name,
      },
      'estimatingKanbanStatuses': {
        for (final entry in estimatingKanbanStatuses.entries)
          entry.key: entry.value.name,
      },
      'relationshipKanbanStatuses': {
        for (final entry in relationshipKanbanStatuses.entries)
          entry.key: entry.value.name,
      },
      'assemblyPreparationChecklist': assemblyPreparationChecklist,
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
      'commercialProposalNumber': commercialProposalNumber,
      'paymentType': paymentType,
      'paymentMethod': paymentMethod,
      'paymentObservation': paymentObservation,
      'installmentValue': installmentValue,
      'installmentCount': installmentCount,
      'paymentDate': paymentDate,
      'rtValue': rtValue,
      'integratorValue': integratorValue,
      'integratorName': integratorName,
      'architectName': architectName,
      'proposalServices': proposalServices
          .map((service) => service.toMap())
          .toList(growable: false),
      'isDanfClient': isDanfClient,
      'danfInstallerName': danfInstallerName,
      'canHaveDanfPlate': canHaveDanfPlate,
      'hasWhatsappGroup': hasWhatsappGroup,
      'whatsappGroupMembers': whatsappGroupMembers
          .map((member) => member.toMap())
          .toList(growable: false),
      'whatsappGroupObservation': whatsappGroupObservation,
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
    final rawFinanceContractStatuses = map['financeContractStatuses'];
    final rawEstimatingKanbanStatuses = map['estimatingKanbanStatuses'];
    final rawRelationshipKanbanStatuses = map['relationshipKanbanStatuses'];
    final rawAssemblyPreparationChecklist = map['assemblyPreparationChecklist'];
    final rawAssemblyAssignedEmployeeEmails =
        map['assemblyAssignedEmployeeEmails'];
    final rawInstallationAssignedEmployeeEmails =
        map['installationAssignedEmployeeEmails'];
    final rawInstallationVisitHistory = map['installationVisitHistory'];
    final rawProposalServices = map['proposalServices'];
    final rawStageOwners = map['stageOwners'];
    final rawConversationMessages = map['conversationMessages'];
    final rawWhatsappGroupMembers = map['whatsappGroupMembers'];
    final rawEstimatingIncludedVisits = map['estimatingIncludedVisits'];
    final rawEstimatingMaterials = map['estimatingMaterials'];
    return WorkflowOrder(
      code: (map['code'] ?? '').toString(),
      client: ClientProfile.fromMap(
        rawClient is Map<String, dynamic>
            ? rawClient
            : Map<String, dynamic>.from(rawClient as Map? ?? const {}),
      ),
      workName: (map['workName'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      workPostalCode: (map['workPostalCode'] ?? '').toString(),
      workStreet: (map['workStreet'] ?? '').toString(),
      workNumber: (map['workNumber'] ?? '').toString(),
      workNeighborhood: (map['workNeighborhood'] ?? '').toString(),
      workComplement: (map['workComplement'] ?? '').toString(),
      proposalFileName: (map['proposalFileName'] ?? '').toString(),
      proposalFilePath: _readOptionalString(map['proposalFilePath']),
      detailFileName: (map['detailFileName'] ?? '').toString(),
      detailFilePath: _readOptionalString(map['detailFilePath']),
      materialFileName: (map['materialFileName'] ?? '').toString(),
      materialFilePath: _readOptionalString(map['materialFilePath']),
      estimatingIncludedVisits: rawEstimatingIncludedVisits is Iterable
          ? rawEstimatingIncludedVisits
                .map(
                  (item) => EstimatingIncludedVisitEntry.fromMap(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map? ?? const {}),
                  ),
                )
                .toList(growable: false)
          : const [],
      estimatingMaterials: rawEstimatingMaterials is Iterable
          ? rawEstimatingMaterials
                .map(
                  (item) => EstimatingMaterialEntry.fromMap(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map? ?? const {}),
                  ),
                )
                .toList(growable: false)
          : const [],
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
          ? _readEngineeringChecklistStatuses(
              Map<String, dynamic>.from(rawEngineeringChecklistStatuses),
            )
          : const {},
      engineeringActivitySchedules: rawEngineeringActivitySchedules is Map
          ? _readEngineeringActivitySchedules(
              Map<String, dynamic>.from(rawEngineeringActivitySchedules),
            )
          : const {},
      financeContractStatuses: rawFinanceContractStatuses is Map
          ? _readFinanceContractStatuses(
              Map<String, dynamic>.from(rawFinanceContractStatuses),
            )
          : const {},
      estimatingKanbanStatuses: rawEstimatingKanbanStatuses is Map
          ? _readEstimatingKanbanStatuses(
              Map<String, dynamic>.from(rawEstimatingKanbanStatuses),
            )
          : const {},
      relationshipKanbanStatuses: rawRelationshipKanbanStatuses is Map
          ? _readRelationshipKanbanStatuses(
              Map<String, dynamic>.from(rawRelationshipKanbanStatuses),
            )
          : const {},
      assemblyPreparationChecklist: rawAssemblyPreparationChecklist is Map
          ? _readAssemblyPreparationChecklist(
              Map<String, dynamic>.from(rawAssemblyPreparationChecklist),
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
      commercialProposalNumber: (map['commercialProposalNumber'] ?? '')
          .toString(),
      paymentType: (map['paymentType'] ?? '').toString(),
      paymentMethod: (map['paymentMethod'] ?? '').toString(),
      paymentObservation: (map['paymentObservation'] ?? '').toString(),
      installmentValue: (map['installmentValue'] ?? '').toString(),
      installmentCount: (map['installmentCount'] ?? '').toString(),
      paymentDate: (map['paymentDate'] ?? '').toString(),
      rtValue: (map['rtValue'] ?? '').toString(),
      integratorValue: (map['integratorValue'] ?? '').toString(),
      integratorName: (map['integratorName'] ?? '').toString(),
      architectName: (map['architectName'] ?? '').toString(),
      proposalServices: rawProposalServices is Iterable
          ? rawProposalServices
                .map(
                  (item) => ProposalServiceEntry.fromMap(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map? ?? const {}),
                  ),
                )
                .toList(growable: false)
          : const [],
      isDanfClient: (map['isDanfClient'] ?? '').toString(),
      danfInstallerName: (map['danfInstallerName'] ?? '').toString(),
      canHaveDanfPlate: (map['canHaveDanfPlate'] ?? '').toString(),
      hasWhatsappGroup: (map['hasWhatsappGroup'] ?? '').toString(),
      whatsappGroupMembers: rawWhatsappGroupMembers is Iterable
          ? rawWhatsappGroupMembers
                .map(
                  (item) => WhatsappGroupMember.fromMap(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map? ?? const {}),
                  ),
                )
                .toList(growable: false)
          : const [],
      whatsappGroupObservation: (map['whatsappGroupObservation'] ?? '')
          .toString(),
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

Map<String, EngineeringChecklistStatus> _readEngineeringChecklistStatuses(
  Map<String, dynamic> rawStatuses,
) {
  final currentTaskKeys = engineeringChecklistTasks
      .map((task) => task.key)
      .toSet();
  final hasCurrentKeys = rawStatuses.keys.any(currentTaskKeys.contains);
  final hasLegacyKeys = rawStatuses.keys.any(
    _legacyEngineeringTaskKeys.contains,
  );

  if (hasLegacyKeys && !hasCurrentKeys) {
    final completedCount = _legacyEngineeringTaskKeys
        .where(
          (key) =>
              _readEngineeringChecklistStatus(rawStatuses[key]?.toString()) ==
              EngineeringChecklistStatus.done,
        )
        .length;
    final migrated = <String, EngineeringChecklistStatus>{};
    for (var index = 0; index < engineeringChecklistTasks.length; index++) {
      migrated[engineeringChecklistTasks[index].key] = index < completedCount
          ? EngineeringChecklistStatus.done
          : EngineeringChecklistStatus.notStarted;
    }
    return migrated;
  }

  return rawStatuses.map(
    (key, value) =>
        MapEntry(key, _readEngineeringChecklistStatus(value?.toString())),
  );
}

Map<String, bool> _readAssemblyPreparationChecklist(
  Map<String, dynamic> rawChecklist,
) {
  final normalized = <String, bool>{};
  for (final section in assemblyChecklistSections) {
    for (final item in section.items) {
      normalized[item] = rawChecklist[item] == true;
    }
  }
  return normalized;
}

Map<String, EngineeringTaskSchedule> _readEngineeringActivitySchedules(
  Map<String, dynamic> rawSchedules,
) {
  const legacyToCurrent = <String, String>{
    'project_presentation': 'awaiting_presentation',
    'site_presentation': 'meeting_electrician',
    'cable_conference': 'released_for_conference',
  };

  return rawSchedules.map((key, value) {
    final normalizedKey = legacyToCurrent[key] ?? key;
    return MapEntry(
      normalizedKey,
      EngineeringTaskSchedule.fromMap(
        value is Map<String, dynamic>
            ? value
            : Map<String, dynamic>.from(value as Map? ?? const {}),
      ),
    );
  });
}

Map<String, EngineeringChecklistStatus> _readFinanceContractStatuses(
  Map<String, dynamic> rawStatuses,
) {
  final validTaskKeys = financeContractTasks
      .map((task) => task.key)
      .toSet();
  final normalized = rawStatuses.entries
      .where((entry) => validTaskKeys.contains(entry.key))
      .map(
        (entry) => MapEntry(
          entry.key,
          _readEngineeringChecklistStatus(entry.value?.toString()),
        ),
      )
      .fold<Map<String, EngineeringChecklistStatus>>(
        <String, EngineeringChecklistStatus>{},
        (map, entry) => map..[entry.key] = entry.value,
      );
  if (normalized.isNotEmpty && !normalized.containsKey('waiting')) {
    normalized['waiting'] = EngineeringChecklistStatus.done;
  }
  return normalized;
}

Map<String, EngineeringChecklistStatus> _readRelationshipKanbanStatuses(
  Map<String, dynamic> rawStatuses,
) {
  final validTaskKeys = relationshipKanbanTasks.map((task) => task.key).toSet();
  final normalized = rawStatuses.entries
      .where((entry) => validTaskKeys.contains(entry.key))
      .map(
        (entry) => MapEntry(
          entry.key,
          _readEngineeringChecklistStatus(entry.value?.toString()),
        ),
      )
      .fold<Map<String, EngineeringChecklistStatus>>(
        <String, EngineeringChecklistStatus>{},
        (map, entry) => map..[entry.key] = entry.value,
      );
  if (normalized.isNotEmpty && !normalized.containsKey('waiting')) {
    normalized['in_progress'] = EngineeringChecklistStatus.done;
  }
  if (normalized.isEmpty) {
    const previousWrongKeys = <String>['waiting', 'doing'];
    final wrongCompletedCount = previousWrongKeys
        .where(
          (key) =>
              _readEngineeringChecklistStatus(rawStatuses[key]?.toString()) ==
              EngineeringChecklistStatus.done,
        )
        .length;
    if (wrongCompletedCount > 0) {
      normalized['in_progress'] = EngineeringChecklistStatus.done;
    }
    if (wrongCompletedCount > 1) {
      normalized['create_omie_material_order'] = EngineeringChecklistStatus.done;
    }
  }
  return normalized;
}

Map<String, EngineeringChecklistStatus> _readEstimatingKanbanStatuses(
  Map<String, dynamic> rawStatuses,
) {
  final validTaskKeys = estimatingKanbanTasks.map((task) => task.key).toSet();
  final normalized = rawStatuses.entries
      .where((entry) => validTaskKeys.contains(entry.key))
      .map(
        (entry) => MapEntry(
          entry.key,
          _readEngineeringChecklistStatus(entry.value?.toString()),
        ),
      )
      .fold<Map<String, EngineeringChecklistStatus>>(
        <String, EngineeringChecklistStatus>{},
        (map, entry) => map..[entry.key] = entry.value,
      );
  if (normalized.isNotEmpty && !normalized.containsKey('waiting')) {
    normalized['waiting'] = EngineeringChecklistStatus.done;
  }
  return normalized;
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
