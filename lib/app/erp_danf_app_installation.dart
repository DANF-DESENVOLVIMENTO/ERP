part of 'erp_danf_app.dart';

class _InstallationScheduleCard extends StatelessWidget {
  const _InstallationScheduleCard({
    required this.order,
    required this.workspaceProfiles,
    required this.canEdit,
    this.onScheduleInstallation,
    this.onToggleExecutionItem,
  });

  final WorkflowOrder order;
  final List<EmployeeWorkspaceProfile> workspaceProfiles;
  final bool canEdit;
  final Future<void> Function()? onScheduleInstallation;
  final Future<void> Function(int visitIndex, String item)?
  onToggleExecutionItem;

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
    final scheduledAt = order.installationScheduledAt;
    final hasSchedule = scheduledAt != null;
    final assignedProfiles = _profilesForEmails(
      order.installationAssignedEmployeeEmails,
      workspaceProfiles,
    );
    final team = assignedProfiles.isNotEmpty
        ? assignedProfiles
              .map(
                (profile) =>
                    profile.name.trim().isEmpty ? profile.login : profile.name,
              )
              .join(', ')
        : order.installationAssignedTeam.trim();
    final plannedVisit = _plannedVisitForCurrentInstallationSchedule(order);
    final notes = plannedVisit?.notes.trim() ?? order.installationNotes.trim();
    final status = order.installationWorkflowStatus;
    final plannedItems = plannedVisit?.plannedItems ?? const <String>[];

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
                    _StatusBadge(label: status.title, color: status.color),
                    const SizedBox(height: 10),
                    Text(
                      hasSchedule
                          ? _formatDateWithWeekday(scheduledAt)
                          : 'Defina uma data e hora para organizar a execução em campo.',
                      style: TextStyle(color: secondaryTextColor, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (canEdit && onScheduleInstallation != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await onScheduleInstallation!();
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(hasSchedule ? 'Reagendar' : 'Agendar'),
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
                      label: 'Data da instalação',
                      value: hasSchedule
                          ? _formatDate(scheduledAt)
                          : 'Ainda não agendada',
                      emphasizeValue: hasSchedule,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoRow(
                      label: 'Horário',
                      value: hasSchedule
                          ? _formatTimeOnly(scheduledAt)
                          : 'Definir horário',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoRow(
                      label: 'Equipe responsável',
                      value: team.isEmpty ? 'Não informada' : team,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoRow(
                      label: 'Observações',
                      value: notes.isEmpty ? 'Sem observações.' : notes,
                    ),
                  ),
                ],
              );
            },
          ),
          if (plannedItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Trabalhos planejados',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFF2F2F0)
                    : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plannedItems
                  .map(
                    (item) => Chip(
                      label: Text(item),
                      backgroundColor: status.color.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: status.color.withValues(alpha: 0.18),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (assignedProfiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignedProfiles
                  .map(
                    (profile) => Chip(
                      avatar: CircleAvatar(
                        backgroundColor: profile.accent.withValues(alpha: 0.15),
                        backgroundImage: _resolveProfileImageProvider(
                          profile.photoFilePath,
                        ),
                        onBackgroundImageError: (_, _) {},
                        child:
                            profile.photoFilePath == null ||
                                profile.photoFilePath!.trim().isEmpty
                            ? Text(
                                (profile.name.trim().isEmpty
                                        ? profile.login
                                        : profile.name)
                                    .trim()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: profile.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      label: Text(
                        profile.name.trim().isEmpty
                            ? profile.login
                            : profile.name,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (order.installationVisitHistory.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Relatórios da instalação',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFF2F2F0)
                    : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...order.installationVisitHistory.asMap().entries.map((entry) {
              final visitIndex = entry.key;
              final visit = entry.value;
              final visitProfiles = _profilesForEmails(
                visit.employeeEmails,
                workspaceProfiles,
              );
              final visitTeam = visitProfiles.isEmpty
                  ? visit.employeeEmails.join(', ')
                  : visitProfiles
                        .map(
                          (profile) => profile.name.trim().isEmpty
                              ? profile.login
                              : profile.name,
                        )
                        .join(', ');

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1C1D20) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDateWithWeekday(visit.scheduledAt),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registrado em ${_formatDateTime(visit.createdAt)}',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visitTeam.isEmpty
                            ? 'Equipe não registrada'
                            : 'Equipe: $visitTeam',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      if (visit.serviceTime.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tempo de serviço: ${visit.serviceTime}',
                          style: TextStyle(color: secondaryTextColor),
                        ),
                      ],
                      if (visit.plannedItems.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Trabalhos',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...visit.plannedItems.map((item) {
                          final isChecked = visit.completedItems.contains(item);
                          final canToggle =
                              canEdit &&
                              onToggleExecutionItem != null &&
                              order.installationWorkflowStatus ==
                                  InstallationWorkflowStatus.doing &&
                              visitIndex ==
                                  order.installationVisitHistory.length - 1;
                          return CheckboxListTile(
                            value: isChecked,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(item),
                            onChanged: canToggle
                                ? (_) async {
                                    await onToggleExecutionItem!(
                                      visitIndex,
                                      item,
                                    );
                                  }
                                : null,
                          );
                        }),
                      ],
                      if (visit.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          visit.notes,
                          style: TextStyle(
                            color: secondaryTextColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _InstallationCalendarBoard extends StatefulWidget {
  const _InstallationCalendarBoard({
    required this.orders,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onOrderSelected,
    this.selectedOrder,
    this.onScheduleSelectedOrder,
  });

  final List<WorkflowOrder> orders;
  final DateTime selectedDate;
  final WorkflowOrder? selectedOrder;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<WorkflowOrder> onOrderSelected;
  final Future<void> Function()? onScheduleSelectedOrder;

  @override
  State<_InstallationCalendarBoard> createState() =>
      _InstallationCalendarBoardState();
}

class _InstallationCalendarBoardState
    extends State<_InstallationCalendarBoard> {
  late DateTime _focusedMonth;

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  static const _weekdayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  @override
  void didUpdateWidget(_InstallationCalendarBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDate(oldWidget.selectedDate, widget.selectedDate) &&
        (oldWidget.selectedDate.year != widget.selectedDate.year ||
            oldWidget.selectedDate.month != widget.selectedDate.month)) {
      _focusedMonth = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
      );
    }
  }

  void _changeFocusedMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  Widget _buildCalendarGrid({
    required Set<DateTime> scheduledDates,
    required Color secondaryTextColor,
    required Color accent,
  }) {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final leadingBlanks =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    Widget buildDayCell(int index) {
      final dayNumber = index - leadingBlanks + 1;
      if (dayNumber < 1 || dayNumber > daysInMonth) {
        return const SizedBox();
      }

      final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
      final isSelected = _isSameDate(date, widget.selectedDate);
      final isToday = _isSameDate(date, DateTime.now());
      final hasSchedule = scheduledDates.any((d) => _isSameDate(d, date));

      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onDateSelected(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.16) : null,
            border: isToday && !isSelected ? Border.all(color: accent) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? accent : null,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasSchedule
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFB7B7B2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeFocusedMonth(-1),
            ),
            Text(
              '${_monthNames[_focusedMonth.month - 1]} de ${_focusedMonth.year}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeFocusedMonth(1),
            ),
          ],
        ),
        Row(
          children: _weekdayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rowCount; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: buildDayCell(row * 7 + col)),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    final selectedDate = widget.selectedDate;
    final selectedOrder = widget.selectedOrder;
    final onOrderSelected = widget.onOrderSelected;
    final onScheduleSelectedOrder = widget.onScheduleSelectedOrder;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? const Color(0xFF3E4044)
        : const Color(0xFFE8E8E5);
    final surfaceColor = isDarkMode ? const Color(0xFF1C1D20) : Colors.white;
    final secondaryTextColor = isDarkMode
        ? const Color(0xFFA3A39E)
        : const Color(0xFF6B6B68);
    final stageOrders = orders
        .where((order) => order.currentStage == WorkflowStage.installation)
        .toList(growable: false);
    final scheduledOrders =
        stageOrders
            .where((order) => order.installationScheduledAt != null)
            .toList(growable: false)
          ..sort(
            (left, right) => left.installationScheduledAt!.compareTo(
              right.installationScheduledAt!,
            ),
          );
    final selectedDayOrders = scheduledOrders
        .where(
          (order) => _isSameDate(order.installationScheduledAt!, selectedDate),
        )
        .toList(growable: false);
    final unscheduledCount = stageOrders
        .where((order) => order.installationScheduledAt == null)
        .length;
    final canScheduleSelectedOrder =
        selectedOrder?.currentStage == WorkflowStage.installation &&
        onScheduleSelectedOrder != null;

    return Container(
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
                    const Text(
                      'Calendário de instalação',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Planeje as visitas da equipe e visualize os pedidos do dia selecionado.',
                      style: TextStyle(color: secondaryTextColor, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (canScheduleSelectedOrder)
                FilledButton.icon(
                  onPressed: () async {
                    await onScheduleSelectedOrder!();
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Agendar pedido selecionado'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CalendarMetricPill(
                label: 'Agendados',
                value: '${scheduledOrders.length}',
                accent: const Color(0xFF0F766E),
              ),
              _CalendarMetricPill(
                label: 'Sem agenda',
                value: '$unscheduledCount',
                accent: const Color(0xFFB45309),
              ),
              _CalendarMetricPill(
                label: 'Dia selecionado',
                value: '${selectedDayOrders.length}',
                accent: WorkflowStage.installation.color,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumn = constraints.maxWidth < 980;
              final calendar = Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(12),
                child: _buildCalendarGrid(
                  scheduledDates: scheduledOrders
                      .map((order) => order.installationScheduledAt!)
                      .toSet(),
                  secondaryTextColor: secondaryTextColor,
                  accent: WorkflowStage.installation.color,
                ),
              );
              final agenda = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDayWithWeekday(selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDayOrders.isEmpty
                          ? 'Nenhuma instalação marcada para este dia.'
                          : '${selectedDayOrders.length} instalação(ões) programada(s).',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    const SizedBox(height: 16),
                    if (selectedDayOrders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black.withValues(alpha: 0.12)
                              : const Color(0xFFF5F5F3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'Selecione um pedido da lista de Instalação e use o botão de agendamento para preencher este calendário.',
                          style: TextStyle(
                            color: secondaryTextColor,
                            height: 1.35,
                          ),
                        ),
                      )
                    else
                      ...selectedDayOrders.map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => onOrderSelected(order),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selectedOrder?.code == order.code
                                    ? WorkflowStage.installation.color
                                          .withValues(alpha: 0.08)
                                    : isDarkMode
                                    ? const Color(0xFF1C1D20)
                                    : const Color(0xFFF5F5F3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedOrder?.code == order.code
                                      ? WorkflowStage.installation.color
                                      : borderColor,
                                ),
                              ),
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
                                          color: WorkflowStage
                                              .installation
                                              .color
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _formatTimeOnly(
                                            order.installationScheduledAt!,
                                          ),
                                          style: TextStyle(
                                            color: WorkflowStage
                                                .installation
                                                .color,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          order.code,
                                          style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    order.workName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${order.client.name} • ${order.address}',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (order.installationAssignedTeam
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Equipe: ${order.installationAssignedTeam}',
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );

              if (useColumn) {
                return Column(
                  children: [calendar, const SizedBox(height: 16), agenda],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: calendar),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: agenda),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InstallationScheduleDraft {
  const _InstallationScheduleDraft({
    required this.scheduledAt,
    required this.assignedTeam,
    required this.plannedItems,
    required this.notes,
  });

  final DateTime scheduledAt;
  final String assignedTeam;
  final List<String> plannedItems;
  final String notes;
}

class _InstallationExecutionDraft {
  const _InstallationExecutionDraft({
    required this.plannedItems,
    required this.notes,
  });

  final List<String> plannedItems;
  final String notes;
}

class _InstallationChecklistSelector extends StatefulWidget {
  const _InstallationChecklistSelector({
    required this.selectedItems,
    required this.onChanged,
  });

  final Set<String> selectedItems;
  final void Function(String item, bool selected) onChanged;

  @override
  State<_InstallationChecklistSelector> createState() =>
      _InstallationChecklistSelectorState();
}

class _InstallationChecklistSelectorState
    extends State<_InstallationChecklistSelector> {
  static const double _visibleItemCount = 3;
  static const double _itemExtent = 56;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = WorkflowStage.installation.checklist;

    return SizedBox(
      height: _visibleItemCount * _itemExtent,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: items.length > _visibleItemCount,
        child: ListView.builder(
          controller: _scrollController,
          primary: false,
          itemExtent: _itemExtent,
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return CheckboxListTile(
              value: widget.selectedItems.contains(item),
              contentPadding: EdgeInsets.zero,
              title: Text(item),
              onChanged: (value) => widget.onChanged(item, value == true),
            );
          },
        ),
      ),
    );
  }
}

class _InstallationExecutionDialog extends StatefulWidget {
  const _InstallationExecutionDialog({required this.order});

  final WorkflowOrder order;

  @override
  State<_InstallationExecutionDialog> createState() =>
      _InstallationExecutionDialogState();
}

class _InstallationExecutionDialogState
    extends State<_InstallationExecutionDialog> {
  final Set<String> _selectedItems = {...WorkflowStage.installation.checklist};
  late final TextEditingController _customItemsController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _customItemsController = TextEditingController();
    _notesController = TextEditingController(
      text: widget.order.installationNotes,
    );
  }

  @override
  void dispose() {
    _customItemsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final customItems = _customItemsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    final plannedItems = {
      ..._selectedItems,
      ...customItems,
    }.toList(growable: false);
    if (plannedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ou descreva pelo menos uma execução.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _InstallationExecutionDraft(
        plannedItems: plannedItems,
        notes: _notesController.text.trim(),
      ),
    );
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
                        const Text(
                          'Execução da instalação',
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
                    onPressed: () => _confirmAndClose(context),
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
                    const Text(
                      'O que será executado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InstallationChecklistSelector(
                      selectedItems: _selectedItems,
                      onChanged: (item, value) {
                        setState(() {
                          if (value) {
                            _selectedItems.add(item);
                          } else {
                            _selectedItems.remove(item);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _DialogField(
                      controller: _customItemsController,
                      label: 'Outras execuções',
                      validator: (_) => null,
                      hintText: 'Uma execução por linha',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _DialogField(
                      controller: _notesController,
                      label: 'Observação desta execução',
                      validator: (_) => null,
                      hintText:
                          'Descreva acesso, pendências, materiais, impedimentos...',
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
                            icon: const Icon(Icons.play_arrow_outlined),
                            label: const Text('Iniciar execução'),
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

class _InstallationScheduleDialog extends StatefulWidget {
  const _InstallationScheduleDialog({
    required this.order,
    required this.initialDraft,
  });

  final WorkflowOrder order;
  final _InstallationScheduleDraft initialDraft;

  @override
  State<_InstallationScheduleDialog> createState() =>
      _InstallationScheduleDialogState();
}

class _InstallationScheduleDialogState
    extends State<_InstallationScheduleDialog> {
  late DateTime _scheduledAt;
  late final TextEditingController _notesController;
  final Set<String> _selectedItems = <String>{};
  late final TextEditingController _customItemsController;

  @override
  void initState() {
    super.initState();
    _scheduledAt = widget.initialDraft.scheduledAt;
    _notesController = TextEditingController(text: widget.initialDraft.notes);
    _customItemsController = TextEditingController();
    for (final item in widget.initialDraft.plannedItems) {
      if (WorkflowStage.installation.checklist.contains(item)) {
        _selectedItems.add(item);
      }
    }
    final customItems = widget.initialDraft.plannedItems
        .where((item) => !WorkflowStage.installation.checklist.contains(item))
        .join('\n');
    _customItemsController.text = customItems;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customItemsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (pickedDate == null) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (pickedTime == null) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _submit() {
    final customItems = _customItemsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    final plannedItems = {
      ..._selectedItems,
      ...customItems,
    }.toList(growable: false);
    if (plannedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe pelo menos um trabalho da instalação.'),
        ),
      );
      return;
    }
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A observação da instalação é obrigatória.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _InstallationScheduleDraft(
        scheduledAt: _scheduledAt,
        assignedTeam: '',
        plannedItems: plannedItems,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 720;

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
                      Icons.event_available_outlined,
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
                          'Calendário de instalação',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 22 : 26,
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
                    onPressed: () => _confirmAndClose(context),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useTwoColumns = constraints.maxWidth >= 560;
                        final fieldWidth = useTwoColumns
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: _SchedulePickerTile(
                                label: 'Data',
                                value: _formatDate(_scheduledAt),
                                icon: Icons.calendar_month_outlined,
                                onTap: _pickDate,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _SchedulePickerTile(
                                label: 'Horário',
                                value: _formatTimeOnly(_scheduledAt),
                                icon: Icons.schedule_outlined,
                                onTap: _pickTime,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Trabalhos da instalação',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InstallationChecklistSelector(
                      selectedItems: _selectedItems,
                      onChanged: (item, value) {
                        setState(() {
                          if (value) {
                            _selectedItems.add(item);
                          } else {
                            _selectedItems.remove(item);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _DialogField(
                      controller: _customItemsController,
                      label: 'Outros trabalhos',
                      validator: (_) => null,
                      hintText: 'Um trabalho por linha',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _DialogField(
                      controller: _notesController,
                      label: 'Observação da instalação',
                      validator: (_) => null,
                      hintText:
                          'Ex.: Instalar 3 unifi, 2 switch poe, acesso ao local, materiais pendentes...',
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
                            label: const Text('Salvar agenda'),
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

class _SchedulePickerTile extends StatelessWidget {
  const _SchedulePickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
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
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6B6B68),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
