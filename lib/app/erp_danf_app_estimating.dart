part of 'erp_danf_app.dart';

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
                    onPressed: () => Navigator.of(context).pop(),
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

  List<ProposalServiceEntry> get consolidatedServices => order.proposalServices
      .where((service) => service.consolidated.trim().toLowerCase() == 'sim')
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
          if (showConsolidatedProjects && consolidatedServices.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE0E0DD)),
            const SizedBox(height: 14),
            const Text(
              'Projetos consolidados (Engenharia)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            for (final service in consolidatedServices)
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
                      'Preparar em projeto: ${service.prepareInProject.trim().isEmpty ? 'Não informado' : service.prepareInProject}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B68),
                      ),
                    ),
                    if (service.observations.trim().isNotEmpty)
                      Text(
                        service.observations.trim(),
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
    return Column(
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
    );
  }
}
