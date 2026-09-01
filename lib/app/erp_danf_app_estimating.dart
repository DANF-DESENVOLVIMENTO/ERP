part of 'erp_danf_app.dart';

class _ServiceOrderRealizedDraft {
  const _ServiceOrderRealizedDraft({
    required this.executionDate,
    required this.executionReport,
    required this.departureTime,
    required this.returnTime,
    required this.totalHours,
    required this.travelValue,
    required this.materialsValue,
    required this.totalHoursValue,
    required this.totalValue,
  });

  final String executionDate;
  final String executionReport;
  final String departureTime;
  final String returnTime;
  final String totalHours;
  final String travelValue;
  final String materialsValue;
  final String totalHoursValue;
  final String totalValue;
}

class _ServiceOrderRealizedDialog extends StatefulWidget {
  const _ServiceOrderRealizedDialog({required this.order});
  final WorkflowOrder order;

  @override
  State<_ServiceOrderRealizedDialog> createState() =>
      _ServiceOrderRealizedDialogState();
}

class _ServiceOrderRealizedDialogState
    extends State<_ServiceOrderRealizedDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  TextEditingController get _date => _controllers[0];
  TextEditingController get _report => _controllers[1];
  TextEditingController get _departure => _controllers[2];
  TextEditingController get _return => _controllers[3];
  TextEditingController get _hours => _controllers[4];
  TextEditingController get _travel => _controllers[5];
  TextEditingController get _materials => _controllers[6];
  TextEditingController get _hoursValue => _controllers[7];
  TextEditingController get _total => _controllers[8];

  @override
  void initState() {
    super.initState();
    final completedVisit = widget.order.installationVisitHistory.reversed
        .where((visit) => visit.serviceTime.trim().isNotEmpty)
        .firstOrNull;
    _controllers = [
      TextEditingController(
        text: widget.order.serviceOrderExecutionDate.trim().isNotEmpty
            ? widget.order.serviceOrderExecutionDate
            : _formatDate(completedVisit?.createdAt ?? DateTime.now()),
      ),
      TextEditingController(text: widget.order.installationNotes),
      TextEditingController(text: widget.order.serviceOrderDepartureTime),
      TextEditingController(text: widget.order.serviceOrderReturnTime),
      TextEditingController(
        text: widget.order.serviceOrderTotalHours.trim().isNotEmpty
            ? widget.order.serviceOrderTotalHours
            : completedVisit?.serviceTime ?? '',
      ),
      TextEditingController(text: widget.order.serviceOrderTravelCost),
      TextEditingController(text: widget.order.serviceOrderMaterialsValue),
      TextEditingController(text: widget.order.serviceOrderTotalHoursValue),
      TextEditingController(text: widget.order.serviceOrderTotalValue),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo obrigatório.' : null;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _ServiceOrderRealizedDraft(
        executionDate: _date.text.trim(),
        executionReport: _report.text.trim(),
        departureTime: _departure.text.trim(),
        returnTime: _return.text.trim(),
        totalHours: _hours.text.trim(),
        travelValue: _travel.text.trim(),
        materialsValue: _materials.text.trim(),
        totalHoursValue: _hoursValue.text.trim(),
        totalValue: _total.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = WorkflowStage.estimating.color;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 850),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.black, .4)!],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OS realizada',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Revise a execução e feche os valores comerciais.',
                          style: TextStyle(color: Color(0xFFE2E8F0)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accent,
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 650
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      Widget field(
                        TextEditingController controller,
                        String label, {
                        bool money = false,
                      }) => SizedBox(
                        width: width,
                        child: _DialogField(
                          controller: controller,
                          label: label,
                          validator: _required,
                          keyboardType: money
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                )
                              : TextInputType.text,
                          inputFormatters: money
                              ? _currencyInputFormatters()
                              : null,
                        ),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Execução',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              field(_date, 'Data da execução'),
                              field(_hours, 'Total de horas trabalhadas'),
                              field(_departure, 'Horário de saída da DANF'),
                              field(_return, 'Horário de retorno na DANF'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _DialogField(
                            controller: _report,
                            label: 'Execução / relatório do serviço',
                            validator: _required,
                            maxLines: 5,
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Comercial',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              field(
                                _travel,
                                'Valor de deslocamento (R\$)',
                                money: true,
                              ),
                              field(
                                _materials,
                                'Valor de materiais (R\$)',
                                money: true,
                              ),
                              field(
                                _hoursValue,
                                'Valor total das horas (R\$)',
                                money: true,
                              ),
                              field(_total, 'Valor total (R\$)', money: true),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar OS realizada'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOrderBudgetDraft {
  const _ServiceOrderBudgetDraft({
    required this.proposalNumber,
    required this.serviceType,
    required this.serviceDescription,
    required this.travelCost,
    required this.technicalHourValue,
    required this.danfClientDiscount,
    required this.materialsValue,
  });

  final String proposalNumber;
  final String serviceType;
  final String serviceDescription;
  final String travelCost;
  final String technicalHourValue;
  final String danfClientDiscount;
  final String materialsValue;
}

class _ServiceOrderBudgetDialog extends StatefulWidget {
  const _ServiceOrderBudgetDialog({required this.order});

  final WorkflowOrder order;

  @override
  State<_ServiceOrderBudgetDialog> createState() =>
      _ServiceOrderBudgetDialogState();
}

class _ServiceOrderBudgetDialogState extends State<_ServiceOrderBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _proposalNumberController;
  late final TextEditingController _serviceDescriptionController;
  late final TextEditingController _travelCostController;
  late final TextEditingController _technicalHourValueController;
  late final TextEditingController _danfClientDiscountController;
  late final TextEditingController _materialsValueController;
  late String _serviceType;

  static const _serviceTypes = [
    'Orçamento',
    'Inspeção técnica',
    'Manutenção preventiva',
    'Assistência técnica',
  ];

  @override
  void initState() {
    super.initState();
    _proposalNumberController = TextEditingController(
      text: widget.order.commercialProposalNumber,
    );
    _serviceDescriptionController = TextEditingController(
      text: widget.order.serviceDescription,
    );
    _travelCostController = TextEditingController(
      text: widget.order.serviceOrderTravelCost.trim().isEmpty
          ? '80,00'
          : widget.order.serviceOrderTravelCost,
    );
    _technicalHourValueController = TextEditingController(
      text: widget.order.serviceOrderTechnicalHourValue.trim().isEmpty
          ? '200,00'
          : widget.order.serviceOrderTechnicalHourValue,
    );
    _danfClientDiscountController = TextEditingController(
      text: widget.order.serviceOrderDanfClientDiscount.trim().isEmpty
          ? '80,00'
          : widget.order.serviceOrderDanfClientDiscount,
    );
    _materialsValueController = TextEditingController(
      text: widget.order.serviceOrderMaterialsValue,
    );
    _serviceType = _serviceTypes.contains(widget.order.serviceOrderServiceType)
        ? widget.order.serviceOrderServiceType
        : 'Assistência técnica';
  }

  @override
  void dispose() {
    _proposalNumberController.dispose();
    _serviceDescriptionController.dispose();
    _travelCostController.dispose();
    _technicalHourValueController.dispose();
    _danfClientDiscountController.dispose();
    _materialsValueController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo obrigatório.' : null;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _ServiceOrderBudgetDraft(
        proposalNumber: _proposalNumberController.text.trim(),
        serviceType: _serviceType,
        serviceDescription: _serviceDescriptionController.text.trim(),
        travelCost: _travelCostController.text.trim(),
        technicalHourValue: _technicalHourValueController.text.trim(),
        danfClientDiscount: _danfClientDiscountController.text.trim(),
        materialsValue: _materialsValueController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final accentColor = WorkflowStage.estimating.color;

    Widget infoTile(IconData icon, String label, String value) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.trim().isEmpty ? 'Não informado' : value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget section({
      required String title,
      required String subtitle,
      required IconData icon,
      required Widget child,
    }) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 640 ? 12 : 32,
        vertical: 20,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 900),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor,
                    Color.lerp(accentColor, Colors.black, 0.42)!,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.request_quote_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Orçamento da ordem de serviço',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.order.code} • Preencha as condições do atendimento',
                          style: const TextStyle(color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentColor,
                      hoverColor: const Color(0xFFE2E8F0),
                    ),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 680;
                      final fieldWidth = twoColumns
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Column(
                        children: [
                          section(
                            title: 'Dados do cliente',
                            subtitle:
                                'Informações trazidas automaticamente da OS',
                            icon: Icons.person_outline,
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: fieldWidth,
                                  child: infoTile(
                                    Icons.business_outlined,
                                    'Cliente',
                                    widget.order.client.name,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: infoTile(
                                    Icons.phone_outlined,
                                    'Contato',
                                    widget.order.client.phone,
                                  ),
                                ),
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: infoTile(
                                    Icons.location_on_outlined,
                                    'Endereço',
                                    widget.order.address,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          section(
                            title: 'Dados do atendimento',
                            subtitle: 'Identificação e escopo da proposta',
                            icon: Icons.assignment_outlined,
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _DialogField(
                                        controller: _proposalNumberController,
                                        label: 'Número da proposta',
                                        validator: _required,
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _serviceType,
                                        decoration: const InputDecoration(
                                          labelText: 'Tipo do atendimento',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(
                                            Icons.design_services_outlined,
                                          ),
                                        ),
                                        items: _serviceTypes
                                            .map(
                                              (type) => DropdownMenuItem(
                                                value: type,
                                                child: Text(type),
                                              ),
                                            )
                                            .toList(growable: false),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(
                                              () => _serviceType = value,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _DialogField(
                                  controller: _serviceDescriptionController,
                                  label: 'Serviço solicitado',
                                  validator: _required,
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          section(
                            title: 'Condições comerciais',
                            subtitle:
                                'Valores utilizados na composição do orçamento',
                            icon: Icons.payments_outlined,
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final field in [
                                  (
                                    _travelCostController,
                                    'Custo de deslocamento',
                                    false,
                                  ),
                                  (
                                    _technicalHourValueController,
                                    'Valor da hora técnica',
                                    false,
                                  ),
                                  (
                                    _danfClientDiscountController,
                                    'Desconto cliente DANF',
                                    false,
                                  ),
                                  (
                                    _materialsValueController,
                                    'Valor de materiais',
                                    true,
                                  ),
                                ])
                                  SizedBox(
                                    width: fieldWidth,
                                    child: _DialogField(
                                      controller: field.$1,
                                      label:
                                          '${field.$2} (R\$)${field.$3 ? ' • opcional' : ''}',
                                      validator: field.$3
                                          ? (_) => null
                                          : _required,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters:
                                          _currencyInputFormatters(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar orçamento'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _estimatingIncludedVisitLabelsForOrder(WorkflowOrder order) {
  final labels = <String>['Projeto'];
  for (final service in order.proposalServices) {
    if (service.consolidated.trim().toLowerCase() != 'sim') {
      continue;
    }
    final label = service.serviceName.trim();
    if (label.isEmpty || labels.contains(label)) {
      continue;
    }
    labels.add(label);
  }
  return labels;
}

class _EstimatingIncludedVisitFormRow {
  _EstimatingIncludedVisitFormRow({required this.label})
    : daysController = TextEditingController();

  final String label;
  final TextEditingController daysController;

  void dispose() {
    daysController.dispose();
  }
}

class _EstimatingMaterialFormRow {
  _EstimatingMaterialFormRow()
    : quantityController = TextEditingController(),
      descriptionController = TextEditingController(),
      modelController = TextEditingController();

  final TextEditingController quantityController;
  final TextEditingController descriptionController;
  final TextEditingController modelController;

  bool get hasAnyValue =>
      quantityController.text.trim().isNotEmpty ||
      descriptionController.text.trim().isNotEmpty ||
      modelController.text.trim().isNotEmpty;

  void dispose() {
    quantityController.dispose();
    descriptionController.dispose();
    modelController.dispose();
  }
}

List<String> _estimatingClosedServiceNamesForOrder(WorkflowOrder order) {
  final names = <String>[];
  for (final service in order.proposalServices) {
    if (service.consolidated.trim().toLowerCase() != 'sim') {
      continue;
    }
    final name = service.serviceName.trim();
    if (name.isEmpty || names.contains(name)) {
      continue;
    }
    names.add(name);
  }
  return names;
}

class _EstimatingMaterialGroup {
  _EstimatingMaterialGroup({required this.serviceName});

  final String serviceName;
  final List<_EstimatingMaterialFormRow> rows = [];

  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
  }
}

class _EstimatingWorksheetDraft {
  const _EstimatingWorksheetDraft({
    required this.includedVisits,
    required this.materials,
  });

  final List<EstimatingIncludedVisitEntry> includedVisits;
  final List<EstimatingMaterialEntry> materials;
}

class _EstimatingWorksheetDialog extends StatefulWidget {
  const _EstimatingWorksheetDialog({required this.order});

  final WorkflowOrder order;

  @override
  State<_EstimatingWorksheetDialog> createState() =>
      _EstimatingWorksheetDialogState();
}

class _EstimatingWorksheetDialogState
    extends State<_EstimatingWorksheetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<_EstimatingIncludedVisitFormRow> _visitRows;
  late final List<_EstimatingMaterialGroup> _materialGroups;

  @override
  void initState() {
    super.initState();
    _visitRows = _estimatingIncludedVisitLabelsForOrder(widget.order)
        .map((label) => _EstimatingIncludedVisitFormRow(label: label))
        .toList(growable: false);
    for (final row in _visitRows) {
      final existing = widget.order.estimatingIncludedVisits.where(
        (entry) => entry.label == row.label,
      );
      if (existing.isNotEmpty) {
        row.daysController.text = existing.first.days;
      }
    }

    final closedServiceNames = _estimatingClosedServiceNamesForOrder(
      widget.order,
    );
    final groupNames = closedServiceNames.isEmpty ? [''] : closedServiceNames;
    _materialGroups = groupNames
        .map((name) => _EstimatingMaterialGroup(serviceName: name))
        .toList(growable: false);

    final materialsByService = <String, List<EstimatingMaterialEntry>>{};
    for (final material in widget.order.estimatingMaterials) {
      materialsByService
          .putIfAbsent(material.serviceName, () => [])
          .add(material);
    }
    for (final group in _materialGroups) {
      final existing = materialsByService.remove(group.serviceName) ?? [];
      for (final material in existing) {
        final row = _EstimatingMaterialFormRow();
        row.quantityController.text = material.quantity;
        row.descriptionController.text = material.description;
        row.modelController.text = material.model;
        group.rows.add(row);
      }
    }
    for (final leftover in materialsByService.values.expand((m) => m)) {
      final row = _EstimatingMaterialFormRow();
      row.quantityController.text = leftover.quantity;
      row.descriptionController.text = leftover.description;
      row.modelController.text = leftover.model;
      _materialGroups.first.rows.add(row);
    }
    for (final group in _materialGroups) {
      if (group.rows.isEmpty) {
        group.rows.add(_EstimatingMaterialFormRow());
      }
    }
  }

  @override
  void dispose() {
    for (final row in _visitRows) {
      row.dispose();
    }
    for (final group in _materialGroups) {
      group.dispose();
    }
    super.dispose();
  }

  void _addMaterialRow(_EstimatingMaterialGroup group) {
    setState(() {
      group.rows.add(_EstimatingMaterialFormRow());
    });
  }

  void _removeMaterialRow(_EstimatingMaterialGroup group, int index) {
    if (group.rows.length == 1) {
      return;
    }
    setState(() {
      final row = group.rows.removeAt(index);
      row.dispose();
    });
  }

  String? _requiredField(String? value, {String label = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label obrigatório.';
    }
    return null;
  }

  String? _validateQuantity(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Quantidade obrigatória.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      return 'Use apenas números.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final materials = <EstimatingMaterialEntry>[];
    for (final group in _materialGroups) {
      for (final row in group.rows) {
        final entry = EstimatingMaterialEntry(
          quantity: row.quantityController.text.trim(),
          description: row.descriptionController.text.trim(),
          model: row.modelController.text.trim(),
          serviceName: group.serviceName,
        );
        if (entry.quantity.isNotEmpty ||
            entry.description.isNotEmpty ||
            entry.model.isNotEmpty) {
          materials.add(entry);
        }
      }
    }

    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um material no Orçamentista.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _EstimatingWorksheetDraft(
        includedVisits: _visitRows
            .map(
              (row) => EstimatingIncludedVisitEntry(
                label: row.label,
                days: row.daysController.text.trim(),
              ),
            )
            .toList(growable: false),
        materials: materials,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 860;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 640 ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 860),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                color: Color(0xFF1A1A1A),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.request_quote_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Levantamento do Orçamentista',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 22 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.order.code} • ${widget.order.workName}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmAndClose(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: _panelDecoration(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quantidade de visitas inclusas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            for (final row in _visitRows) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Text(
                                        row.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DialogField(
                                      controller: row.daysController,
                                      label: 'Dias',
                                      validator: (value) =>
                                          _requiredField(value, label: 'Dias'),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final group in _materialGroups) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: _panelDecoration(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      group.serviceName.isEmpty
                                          ? 'Materiais'
                                          : '${group.serviceName}:',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _addMaterialRow(group),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Adicionar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              for (
                                var index = 0;
                                index < group.rows.length;
                                index++
                              ) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE0E0DD),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Material ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (group.rows.length > 1)
                                            IconButton(
                                              onPressed: () =>
                                                  _removeMaterialRow(
                                                    group,
                                                    index,
                                                  ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _DialogField(
                                              controller: group
                                                  .rows[index]
                                                  .quantityController,
                                              label: 'Quantidade',
                                              validator: _validateQuantity,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: _DialogField(
                                              controller: group
                                                  .rows[index]
                                                  .descriptionController,
                                              label: 'Descrição',
                                              validator: (value) =>
                                                  _requiredField(
                                                    value,
                                                    label: 'Descrição',
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: _DialogField(
                                              controller: group
                                                  .rows[index]
                                                  .modelController,
                                              label: 'Modelo',
                                              validator: (value) =>
                                                  _requiredField(
                                                    value,
                                                    label: 'Modelo',
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar levantamento'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimatingWorksheetSummaryCard extends StatelessWidget {
  const _EstimatingWorksheetSummaryCard({
    required this.order,
    required this.canEdit,
    this.onEditWorksheet,
    this.showConsolidatedProjects = false,
  });

  final WorkflowOrder order;
  final bool canEdit;
  final Future<void> Function()? onEditWorksheet;
  final bool showConsolidatedProjects;

  Map<String, List<EstimatingMaterialEntry>> get _materialsByService {
    final map = <String, List<EstimatingMaterialEntry>>{};
    for (final material in order.estimatingMaterials) {
      map.putIfAbsent(material.serviceName, () => []).add(material);
    }
    return map;
  }

  bool get _hasNamedMaterialGroups =>
      _materialsByService.keys.any((key) => key.isNotEmpty);

  List<ProposalServiceEntry> get proposalServiceDetails => order
      .proposalServices
      .where(
        (service) =>
            service.consolidated.trim().isNotEmpty ||
            service.prepareInProject.trim().isNotEmpty ||
            service.observations.trim().isNotEmpty,
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final hasWorksheet =
        order.estimatingIncludedVisits.isNotEmpty &&
        order.estimatingMaterials.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Levantamento do Orçamentista',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (canEdit && onEditWorksheet != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await onEditWorksheet!();
                  },
                  icon: Icon(
                    hasWorksheet
                        ? Icons.edit_note_outlined
                        : Icons.playlist_add_check_circle_outlined,
                  ),
                  label: Text(
                    hasWorksheet ? 'Editar levantamento' : 'Preencher lista',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasWorksheet)
            const Text(
              'Nenhum levantamento preenchido ainda para esta etapa.',
              style: TextStyle(color: Color(0xFFB91C1C)),
            )
          else ...[
            const Text(
              'Visitas inclusas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final visit in order.estimatingIncludedVisits)
              if (visit.days.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(visit.label)),
                      Text(
                        '${visit.days} dia(s)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 14),
            if (!_hasNamedMaterialGroups) ...[
              const Text(
                'Materiais',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _MaterialsTable(materials: order.estimatingMaterials),
            ] else
              for (final entry in _materialsByService.entries) ...[
                Text(
                  entry.key.isEmpty ? 'Outros materiais' : '${entry.key}:',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                _MaterialsTable(materials: entry.value),
                const SizedBox(height: 14),
              ],
          ],
          if (showConsolidatedProjects &&
              proposalServiceDetails.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE0E0DD)),
            const SizedBox(height: 14),
            const Text(
              'Consolidação da proposta',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            for (final service in proposalServiceDetails)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.serviceName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Consolidado: ${service.consolidated.trim().isEmpty ? 'Não informado' : service.consolidated}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B68),
                      ),
                    ),
                    Text(
                      'Projeto: ${service.prepareInProject.trim().isEmpty ? 'Não informado' : service.prepareInProject}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B68),
                      ),
                    ),
                    Text(
                      'Observação: ${service.observations.trim().isEmpty ? 'Sem observação' : service.observations.trim()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B68),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MaterialsTable extends StatelessWidget {
  const _MaterialsTable({required this.materials});

  final List<EstimatingMaterialEntry> materials;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(
                width: 72,
                child: Text(
                  'Material',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B6B68),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Descrição',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B6B68),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Modelo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B6B68),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final material in materials)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      material.quantity,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(material.description)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      material.model,
                      style: const TextStyle(color: Color(0xFF6B6B68)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
