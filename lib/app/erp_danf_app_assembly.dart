part of 'erp_danf_app.dart';

class _AssemblyPreparationChecklistCard extends StatelessWidget {
  const _AssemblyPreparationChecklistCard({
    required this.order,
    required this.canEdit,
    this.onOpenChecklist,
  });

  final WorkflowOrder order;
  final bool canEdit;
  final Future<void> Function()? onOpenChecklist;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final surfaceColor = isDarkMode
        ? const Color(0xFF1C1D20)
        : const Color(0xFFF5F5F3);
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);
    final isExecutionStage =
        order.assemblyWorkflowStatus == AssemblyWorkflowStatus.doing ||
        order.assemblyWorkflowStatus == AssemblyWorkflowStatus.panelTesting ||
        order.assemblyWorkflowStatus == AssemblyWorkflowStatus.done;
    final sections = isExecutionStage
        ? assemblyExecutionChecklistSections
        : const [assemblyPreparationChecklistSection];
    final checklist = isExecutionStage
        ? _assemblyExecutionChecklistSnapshot(order)
        : _assemblyPreparationChecklistSnapshot(order);
    final completedCount = checklist.values
        .where((isChecked) => isChecked)
        .length;
    final totalCount = checklist.length;
    final isComplete = completedCount == totalCount && totalCount > 0;
    final pendingItems = _pendingAssemblyPreparationChecklistItems(order);
    final pendingExecutionItems = _pendingAssemblyExecutionChecklistItems(
      order,
    );
    final pendingSummary = isExecutionStage
        ? pendingExecutionItems
        : pendingItems;
    final title = isExecutionStage
        ? 'Execução da montagem'
        : 'Preparação inicial';
    final description = isExecutionStage
        ? (isComplete
              ? 'Checklist operacional concluído. O painel pode ser finalizado e enviado.'
              : 'Da etapa 2 em diante o montador marca o andamento aqui e fecha o checklist antes de concluir.')
        : (isComplete
              ? 'Checklist concluído. O pedido já pode ser liberado para montagem.'
              : 'É obrigatório baixar todos os itens antes de mover de Aguardando para Liberado para Montagem.');
    final buttonLabel = isExecutionStage
        ? (canEdit
              ? 'Atualizar checklist da execução'
              : 'Ver checklist da execução')
        : (canEdit ? 'Dar baixa no checklist' : 'Ver checklist');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
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
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: secondaryTextColor, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(
                label: '$completedCount/$totalCount itens',
                color: isComplete
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB45309),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final section in sections) ...[
            Text(
              section.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in section.items)
                  _ChecklistPill(
                    label: item,
                    selected: checklist[item] == true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (pendingSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Pendentes: ${pendingSummary.join(', ')}',
              style: TextStyle(color: secondaryTextColor, height: 1.35),
            ),
          ],
          if (onOpenChecklist != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  await onOpenChecklist!();
                },
                icon: const Icon(Icons.checklist_rtl_outlined),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistPill extends StatelessWidget {
  const _ChecklistPill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF15803D) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssemblyChecklistDialog extends StatefulWidget {
  const _AssemblyChecklistDialog({
    required this.order,
    required this.title,
    required this.sections,
    required this.initialChecklist,
    required this.requireCompletion,
  });

  final WorkflowOrder order;
  final String title;
  final List<AssemblyChecklistSection> sections;
  final Map<String, bool> initialChecklist;
  final bool requireCompletion;

  @override
  State<_AssemblyChecklistDialog> createState() =>
      _AssemblyChecklistDialogState();
}

class _AssemblyChecklistDialogState extends State<_AssemblyChecklistDialog> {
  late final Map<String, bool> _checklist;

  @override
  void initState() {
    super.initState();
    _checklist = {
      for (final section in widget.sections)
        for (final item in section.items)
          item: widget.initialChecklist[item] == true,
    };
  }

  void _submit() {
    final pendingItems = _checklist.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (widget.requireCompletion && pendingItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Baixe todos os itens antes de liberar: ${pendingItems.join(', ')}',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(_checklist);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 640 ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      Icons.checklist_rtl_outlined,
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
                          widget.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_displayOrderCode(widget.order)} • ${widget.order.workName}',
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.requireCompletion
                          ? 'Baixe todos os itens desta etapa antes de concluir.'
                          : 'Marque os itens já executados para este pedido.',
                      style: const TextStyle(
                        color: Color(0xFF6B6B68),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final section in widget.sections) ...[
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...section.items.map((item) {
                        return CheckboxListTile(
                          value: _checklist[item] == true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item),
                          onChanged: (value) {
                            setState(() {
                              _checklist[item] = value == true;
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
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
                            label: Text(
                              widget.requireCompletion
                                  ? 'Salvar e concluir'
                                  : 'Salvar checklist',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssemblyTeamSelectionDialog extends StatefulWidget {
  const _AssemblyTeamSelectionDialog({
    required this.profiles,
    required this.initialSelectedEmails,
    this.title = 'Equipe da montagem',
    this.subtitle = 'Selecione os funcionários que vão executar esta montagem.',
    this.emptySelectionMessage =
        'Selecione pelo menos um funcionário da montagem.',
  });

  final List<EmployeeWorkspaceProfile> profiles;
  final List<String> initialSelectedEmails;
  final String title;
  final String subtitle;
  final String emptySelectionMessage;

  @override
  State<_AssemblyTeamSelectionDialog> createState() =>
      _AssemblyTeamSelectionDialogState();
}

class _AssemblyTeamSelectionDialogState
    extends State<_AssemblyTeamSelectionDialog> {
  late Set<String> _selectedEmails;

  @override
  void initState() {
    super.initState();
    _selectedEmails = widget.initialSelectedEmails
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  void _submit() {
    if (_selectedEmails.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.emptySelectionMessage)));
      return;
    }

    final selectedEmails = widget.profiles
        .map((profile) => profile.email.trim().toLowerCase())
        .where(_selectedEmails.contains)
        .toList(growable: false);
    Navigator.of(context).pop(selectedEmails);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 640 ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      Icons.groups_2_outlined,
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
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE0E0DD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Funcionários disponíveis',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.profiles.map((profile) {
                            final email = profile.email.trim().toLowerCase();
                            final isSelected = _selectedEmails.contains(email);
                            return CheckboxListTile(
                              value: isSelected,
                              contentPadding: EdgeInsets.zero,
                              activeColor: profile.accent,
                              title: Text(
                                profile.name.trim().isEmpty
                                    ? profile.login
                                    : profile.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                profile.role.trim().isEmpty
                                    ? '@${profile.login}'
                                    : '${profile.role} • @${profile.login}',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedEmails.add(email);
                                  } else {
                                    _selectedEmails.remove(email);
                                  }
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirmar equipe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
