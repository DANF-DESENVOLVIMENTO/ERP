part of 'erp_danf_app.dart';

class _EngineeringStageCalendarBoard extends StatefulWidget {
  const _EngineeringStageCalendarBoard({
    required this.orders,
    required this.onOrderSelected,
    this.selectedOrder,
  });

  final List<WorkflowOrder> orders;
  final WorkflowOrder? selectedOrder;
  final ValueChanged<WorkflowOrder> onOrderSelected;

  @override
  State<_EngineeringStageCalendarBoard> createState() =>
      _EngineeringStageCalendarBoardState();
}

class _EngineeringStageCalendarBoardState
    extends State<_EngineeringStageCalendarBoard> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _resolveInitialDate(widget.orders);
  }

  @override
  void didUpdateWidget(covariant _EngineeringStageCalendarBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders != widget.orders && widget.orders.isNotEmpty) {
      final hasSchedulesForCurrentDate = widget.orders.any(
        (order) => order.engineeringActivitySchedules.values.any(
          (schedule) => _isSameDate(schedule.scheduledAt, _selectedDate),
        ),
      );
      if (!hasSchedulesForCurrentDate) {
        _selectedDate = _resolveInitialDate(widget.orders);
      }
    }
  }

  DateTime _resolveInitialDate(List<WorkflowOrder> orders) {
    DateTime? earliestSchedule;
    for (final order in orders) {
      for (final schedule in order.engineeringActivitySchedules.values) {
        if (earliestSchedule == null ||
            schedule.scheduledAt.isBefore(earliestSchedule)) {
          earliestSchedule = schedule.scheduledAt;
        }
      }
    }

    return DateUtils.dateOnly(earliestSchedule ?? DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? const Color(0xFF29403A)
        : const Color(0xFFE2E8F0);
    final surfaceColor = isDarkMode ? const Color(0xFF121E1B) : Colors.white;
    final secondaryTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);
    final stageOrders = widget.orders
        .where((order) => order.currentStage == WorkflowStage.engineering)
        .toList(growable: false);
    final scheduledEntries = <_EngineeringCalendarEntry>[];
    for (final order in stageOrders) {
      for (final entry in order.engineeringActivitySchedules.entries) {
        final task = _engineeringChecklistTaskByKey(entry.key);
        if (task == null) {
          continue;
        }
        scheduledEntries.add(
          _EngineeringCalendarEntry(
            order: order,
            task: task,
            schedule: entry.value,
          ),
        );
      }
    }
    scheduledEntries.sort(
      (left, right) =>
          left.schedule.scheduledAt.compareTo(right.schedule.scheduledAt),
    );
    final selectedDayEntries = scheduledEntries
        .where(
          (entry) => _isSameDate(entry.schedule.scheduledAt, _selectedDate),
        )
        .toList(growable: false);
    final ordersWithSchedule = stageOrders
        .where((order) => order.engineeringActivitySchedules.isNotEmpty)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendário da engenharia',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Concentre aqui as apresentações, visitas em obra e conferências de cabos já agendadas.',
            style: TextStyle(color: secondaryTextColor, height: 1.35),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CalendarMetricPill(
                label: 'Atividades',
                value: '${scheduledEntries.length}',
                accent: WorkflowStage.engineering.color,
              ),
              _CalendarMetricPill(
                label: 'Pedidos com agenda',
                value: '$ordersWithSchedule',
                accent: const Color(0xFF0F766E),
              ),
              _CalendarMetricPill(
                label: 'Dia selecionado',
                value: '${selectedDayEntries.length}',
                accent: const Color(0xFF475569),
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
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  currentDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035, 12, 31),
                  onDateChanged: (value) {
                    setState(() {
                      _selectedDate = DateUtils.dateOnly(value);
                    });
                  },
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
                      _formatDayWithWeekday(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDayEntries.isEmpty
                          ? 'Nenhuma atividade técnica marcada para este dia.'
                          : '${selectedDayEntries.length} atividade(s) técnica(s) programada(s).',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    const SizedBox(height: 16),
                    if (selectedDayEntries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black.withValues(alpha: 0.12)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'Abra um pedido em Trabalhos para agendar as atividades do checklist técnico. Elas aparecem aqui automaticamente.',
                          style: TextStyle(
                            color: secondaryTextColor,
                            height: 1.35,
                          ),
                        ),
                      )
                    else
                      ...selectedDayEntries.map((entry) {
                        final isSelected =
                            widget.selectedOrder?.code == entry.order.code;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => widget.onOrderSelected(entry.order),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? WorkflowStage.engineering.color
                                          .withValues(alpha: 0.08)
                                    : isDarkMode
                                    ? const Color(0xFF0E1715)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? WorkflowStage.engineering.color
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
                                          color: WorkflowStage.engineering.color
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _formatTimeOnly(
                                            entry.schedule.scheduledAt,
                                          ),
                                          style: TextStyle(
                                            color:
                                                WorkflowStage.engineering.color,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _displayOrderCode(
                                            entry.order,
                                            widget.orders,
                                          ),
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
                                    entry.task.label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${entry.order.workName} • ${entry.order.client.name}',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (entry.schedule.notes
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      entry.schedule.notes,
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
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

class _EngineeringCalendarEntry {
  const _EngineeringCalendarEntry({
    required this.order,
    required this.task,
    required this.schedule,
  });

  final WorkflowOrder order;
  final EngineeringChecklistTask task;
  final EngineeringTaskSchedule schedule;
}

class _CalendarMetricPill extends StatelessWidget {
  const _CalendarMetricPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EngineeringActivityScheduleDraft {
  const _EngineeringActivityScheduleDraft({
    required this.scheduledAt,
    required this.notes,
  });

  final DateTime scheduledAt;
  final String notes;
}

class _EngineeringActivityScheduleDialog extends StatefulWidget {
  const _EngineeringActivityScheduleDialog({
    required this.order,
    required this.task,
    required this.initialDraft,
  });

  final WorkflowOrder order;
  final EngineeringChecklistTask task;
  final _EngineeringActivityScheduleDraft initialDraft;

  @override
  State<_EngineeringActivityScheduleDialog> createState() =>
      _EngineeringActivityScheduleDialogState();
}

class _EngineeringActivityScheduleDialogState
    extends State<_EngineeringActivityScheduleDialog> {
  late DateTime _scheduledAt;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _scheduledAt = widget.initialDraft.scheduledAt;
    _notesController = TextEditingController(text: widget.initialDraft.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
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
    Navigator.of(context).pop(
      _EngineeringActivityScheduleDraft(
        scheduledAt: _scheduledAt,
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
        constraints: const BoxConstraints(maxWidth: 720),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F2),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                color: Color(0xFF14211D),
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
                      Icons.event_note_outlined,
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
                          widget.task.label,
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
                    _DialogField(
                      controller: _notesController,
                      label: 'Observações',
                      validator: (_) => null,
                      hintText:
                          'Ponto de encontro, responsável na obra, dependências, materiais...',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Salvar agenda'),
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

class _EngineeringChecklistCard extends StatelessWidget {
  const _EngineeringChecklistCard({
    required this.order,
    required this.isEditable,
    this.onScheduleActivity,
    this.onStatusChanged,
  });

  final WorkflowOrder order;
  final bool isEditable;
  final Future<void> Function(String taskKey)? onScheduleActivity;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);
    final surfaceColor = isDarkMode
        ? const Color(0xFF121E1B)
        : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? const Color(0xFF29403A)
        : const Color(0xFFE2E8F0);
    final flowSnapshot = _engineeringFlowSnapshot(order);

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
          const Text(
            'Checklist da engenharia',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            isEditable
                ? 'Use o kanban interno da Engenharia e conclua cada etapa antes de liberar para Montagem.'
                : 'Visualização do andamento técnico e da agenda registrada pela Engenharia.',
            style: TextStyle(color: secondaryTextColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          _EngineeringFlowKanban(
            order: order,
            flowSnapshot: flowSnapshot,
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            isEditable: isEditable,
            onScheduleActivity: onScheduleActivity,
            onStatusChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _EngineeringTaskScheduleLine extends StatelessWidget {
  const _EngineeringTaskScheduleLine({
    required this.task,
    required this.schedule,
    required this.isDarkMode,
    required this.borderColor,
    required this.canEdit,
    this.onSchedule,
  });

  final EngineeringChecklistTask task;
  final EngineeringTaskSchedule? schedule;
  final bool isDarkMode;
  final Color borderColor;
  final bool canEdit;
  final Future<void> Function()? onSchedule;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? const Color(0xFF0E1715) : Colors.white;
    final mutedTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);
    final hasSchedule = schedule != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSchedule
                      ? 'Agendado para ${_formatDateTime(schedule!.scheduledAt)}'
                      : 'Sem agendamento definido',
                  style: TextStyle(
                    color: hasSchedule
                        ? const Color(0xFF0F766E)
                        : mutedTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasSchedule && schedule!.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    schedule!.notes,
                    style: TextStyle(color: mutedTextColor, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          if (canEdit)
            OutlinedButton.icon(
              onPressed: onSchedule == null
                  ? null
                  : () async {
                      await onSchedule!();
                    },
              icon: Icon(
                hasSchedule
                    ? Icons.event_repeat_outlined
                    : Icons.event_available_outlined,
              ),
              label: Text(hasSchedule ? 'Reagendar' : 'Agendar'),
            ),
        ],
      ),
    );
  }
}

class _EngineeringFlowKanban extends StatelessWidget {
  const _EngineeringFlowKanban({
    required this.order,
    required this.flowSnapshot,
    required this.isDarkMode,
    required this.borderColor,
    required this.isEditable,
    this.onScheduleActivity,
    this.onStatusChanged,
  });

  final WorkflowOrder order;
  final _EngineeringFlowSnapshot flowSnapshot;
  final bool isDarkMode;
  final Color borderColor;
  final bool isEditable;
  final Future<void> Function(String taskKey)? onScheduleActivity;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 980;
        final columns = [
          _EngineeringFlowKanbanColumn(
            title: 'Concluídas',
            accent: const Color(0xFF15803D),
            tasks: flowSnapshot.completedTasks,
            emptyMessage: 'Nenhuma etapa concluída ainda.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            order: order,
            isEditable: isEditable,
            onScheduleActivity: onScheduleActivity,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.completed,
          ),
          _EngineeringFlowKanbanColumn(
            title: 'Etapa atual',
            accent: const Color(0xFFC2410C),
            tasks: flowSnapshot.currentTask == null
                ? const <EngineeringChecklistTask>[]
                : [flowSnapshot.currentTask!],
            emptyMessage: 'Fluxo técnico concluído e pronto para Montagem.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            order: order,
            isEditable: isEditable,
            onScheduleActivity: onScheduleActivity,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.current,
          ),
          _EngineeringFlowKanbanColumn(
            title: 'Próximas',
            accent: const Color(0xFF64748B),
            tasks: flowSnapshot.upcomingTasks,
            emptyMessage: 'Não existem próximas etapas pendentes.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            order: order,
            isEditable: isEditable,
            onScheduleActivity: onScheduleActivity,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.upcoming,
          ),
        ];

        if (useColumn) {
          return Column(
            children: [
              for (var index = 0; index < columns.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                columns[index],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < columns.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: columns[index]),
            ],
          ],
        );
      },
    );
  }
}

enum _EngineeringFlowTaskState { completed, current, upcoming }

class _EngineeringFlowKanbanColumn extends StatelessWidget {
  const _EngineeringFlowKanbanColumn({
    required this.title,
    required this.accent,
    required this.tasks,
    required this.emptyMessage,
    required this.isDarkMode,
    required this.borderColor,
    required this.order,
    required this.isEditable,
    required this.taskState,
    this.onScheduleActivity,
    this.onStatusChanged,
  });

  final String title;
  final Color accent;
  final List<EngineeringChecklistTask> tasks;
  final String emptyMessage;
  final bool isDarkMode;
  final Color borderColor;
  final WorkflowOrder order;
  final bool isEditable;
  final _EngineeringFlowTaskState taskState;
  final Future<void> Function(String taskKey)? onScheduleActivity;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode
        ? const Color(0xFF0E1715)
        : const Color(0xFFFFFFFF);
    final mutedTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.12)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                emptyMessage,
                style: TextStyle(color: mutedTextColor, height: 1.35),
              ),
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EngineeringFlowTaskCard(
                  task: task,
                  taskState: taskState,
                  accent: accent,
                  order: order,
                  isDarkMode: isDarkMode,
                  borderColor: borderColor,
                  isEditable: isEditable,
                  onScheduleActivity: onScheduleActivity,
                  onStatusChanged: onStatusChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EngineeringFlowTaskCard extends StatelessWidget {
  const _EngineeringFlowTaskCard({
    required this.task,
    required this.taskState,
    required this.accent,
    required this.order,
    required this.isDarkMode,
    required this.borderColor,
    required this.isEditable,
    this.onScheduleActivity,
    this.onStatusChanged,
  });

  final EngineeringChecklistTask task;
  final _EngineeringFlowTaskState taskState;
  final Color accent;
  final WorkflowOrder order;
  final bool isDarkMode;
  final Color borderColor;
  final bool isEditable;
  final Future<void> Function(String taskKey)? onScheduleActivity;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final schedule = order.engineeringActivitySchedules[task.key];
    final helperText = switch (taskState) {
      _EngineeringFlowTaskState.completed => 'Etapa já concluída no fluxo.',
      _EngineeringFlowTaskState.current =>
        'Etapa atual do kanban interno da Engenharia.',
      _EngineeringFlowTaskState.upcoming =>
        'Aguardando a conclusão da etapa anterior.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDarkMode ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.label,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFD2E1DB)
                  : const Color(0xFF52605C),
              height: 1.3,
              fontSize: 12,
            ),
          ),
          if (task.supportsScheduling) ...[
            const SizedBox(height: 10),
            _EngineeringTaskScheduleLine(
              task: task,
              schedule: schedule,
              isDarkMode: isDarkMode,
              borderColor: borderColor,
              canEdit:
                  isEditable && taskState == _EngineeringFlowTaskState.current,
              onSchedule:
                  !isEditable ||
                      taskState != _EngineeringFlowTaskState.current ||
                      onScheduleActivity == null
                  ? null
                  : () async {
                      await onScheduleActivity!(task.key);
                    },
            ),
          ],
          if (isEditable && onStatusChanged != null) ...[
            const SizedBox(height: 10),
            if (taskState == _EngineeringFlowTaskState.current)
              FilledButton.icon(
                onPressed: () async {
                  await onStatusChanged!(
                    task.key,
                    EngineeringChecklistStatus.done,
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Concluir e avançar'),
              ),
            if (taskState == _EngineeringFlowTaskState.completed)
              OutlinedButton.icon(
                onPressed: () async {
                  await onStatusChanged!(
                    task.key,
                    EngineeringChecklistStatus.notStarted,
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reabrir daqui'),
              ),
          ],
        ],
      ),
    );
  }
}

class _EngineeringFlowSnapshot {
  const _EngineeringFlowSnapshot({
    required this.completedTasks,
    required this.currentTask,
    required this.upcomingTasks,
  });

  final List<EngineeringChecklistTask> completedTasks;
  final EngineeringChecklistTask? currentTask;
  final List<EngineeringChecklistTask> upcomingTasks;

  bool get isComplete => currentTask == null && upcomingTasks.isEmpty;
}

_EngineeringFlowSnapshot _engineeringFlowSnapshot(WorkflowOrder order) {
  return _engineeringFlowSnapshotFromStatuses(
    order.engineeringChecklistStatuses,
  );
}

Map<String, bool> _assemblyPreparationChecklistSnapshot(WorkflowOrder order) {
  return {
    for (final item in assemblyPreparationChecklistItems)
      item: order.assemblyPreparationChecklist[item] == true,
  };
}

Map<String, bool> _assemblyExecutionChecklistSnapshot(WorkflowOrder order) {
  return {
    for (final item in assemblyExecutionChecklistItems)
      item: order.assemblyPreparationChecklist[item] == true,
  };
}

bool _isAssemblyPreparationChecklistComplete(WorkflowOrder order) {
  final checklist = _assemblyPreparationChecklistSnapshot(order);
  return checklist.values.every((isChecked) => isChecked);
}

List<String> _pendingAssemblyPreparationChecklistItems(WorkflowOrder order) {
  final checklist = _assemblyPreparationChecklistSnapshot(order);
  return checklist.entries
      .where((entry) => !entry.value)
      .map((entry) => entry.key)
      .toList(growable: false);
}

List<String> _pendingAssemblyExecutionChecklistItems(WorkflowOrder order) {
  final checklist = _assemblyExecutionChecklistSnapshot(order);
  return checklist.entries
      .where((entry) => !entry.value)
      .map((entry) => entry.key)
      .toList(growable: false);
}

double _effectiveOrderProgress(WorkflowOrder order) {
  if (order.isServiceOrder) {
    final stepIndex = _serviceOrderFlowStageIndex(order);
    final stepFraction = switch (stepIndex) {
      0 => 0.70,
      1 => 0.85,
      2 => 0.75,
      3 => switch (order.installationWorkflowStatus) {
        InstallationWorkflowStatus.waiting => 0.15,
        InstallationWorkflowStatus.scheduled => 0.35,
        InstallationWorkflowStatus.doing => 0.70,
        InstallationWorkflowStatus.done => 1.0,
      },
      4 => 0.75,
      5 => 0.90,
      6 => 1.0,
      _ => 0.35,
    };
    final progress =
        stepIndex == _serviceOrderFlowSteps.length - 1 &&
            order.serviceOrderFinanceStatus == ServiceOrderFinanceStatus.paid
        ? 1.0
        : (stepIndex + stepFraction) / _serviceOrderFlowSteps.length;
    return progress.clamp(0.02, 1);
  }

  final stageIndex = workflowStages.indexOf(order.currentStage);
  if (stageIndex == -1) {
    return order.progress.clamp(0, 1);
  }

  final stageFraction = _stageProgressFraction(order);
  final progress = (stageIndex + stageFraction) / workflowStages.length;
  return progress.clamp(0.02, 1);
}

double _stageProgressFraction(WorkflowOrder order) {
  return switch (order.currentStage) {
    WorkflowStage.customerRegistration => 0.35,
    WorkflowStage.estimating =>
      order.isServiceOrder
          ? (order.serviceOrderFileName.trim().isEmpty ? 0.35 : 0.85)
          : _estimatingKanbanProgressFraction(order),
    WorkflowStage.finance =>
      order.isServiceOrder
          ? (order.financeClientApproved ? 0.85 : 0.40)
          : _financeContractProgressFraction(order),
    WorkflowStage.relationship =>
      order.isServiceOrder ? 0.55 : _relationshipKanbanProgressFraction(order),
    WorkflowStage.engineering => _engineeringProgressFraction(order),
    WorkflowStage.assembly => switch (order.assemblyWorkflowStatus) {
      AssemblyWorkflowStatus.waiting => 0.05,
      AssemblyWorkflowStatus.released => 0.15,
      AssemblyWorkflowStatus.doing => 0.60,
      AssemblyWorkflowStatus.panelTesting => 0.80,
      AssemblyWorkflowStatus.done => 0.95,
    },
    WorkflowStage.installation => switch (order.installationWorkflowStatus) {
      InstallationWorkflowStatus.waiting => 0.10,
      InstallationWorkflowStatus.scheduled => 0.35,
      InstallationWorkflowStatus.doing => 0.70,
      InstallationWorkflowStatus.done => 1.0,
    },
  };
}

double _estimatingKanbanProgressFraction(WorkflowOrder order) {
  final completedCount = estimatingKanbanTasks
      .where(
        (task) =>
            _normalizeEngineeringChecklistStatus(
              order.estimatingKanbanStatuses[task.key] ??
                  EngineeringChecklistStatus.notStarted,
            ) ==
            EngineeringChecklistStatus.done,
      )
      .length;
  if (estimatingKanbanTasks.isEmpty) {
    return 0.35;
  }
  return (completedCount / estimatingKanbanTasks.length).clamp(0.08, 1.0);
}

double _financeContractProgressFraction(WorkflowOrder order) {
  final completedCount = financeContractTasks
      .where(
        (task) =>
            _normalizeEngineeringChecklistStatus(
              order.financeContractStatuses[task.key] ??
                  EngineeringChecklistStatus.notStarted,
            ) ==
            EngineeringChecklistStatus.done,
      )
      .length;
  if (financeContractTasks.isEmpty) {
    return 0.35;
  }
  return (completedCount / financeContractTasks.length).clamp(0.08, 1.0);
}

double _relationshipKanbanProgressFraction(WorkflowOrder order) {
  final completedCount = relationshipKanbanTasks
      .where(
        (task) =>
            _normalizeEngineeringChecklistStatus(
              order.relationshipKanbanStatuses[task.key] ??
                  EngineeringChecklistStatus.notStarted,
            ) ==
            EngineeringChecklistStatus.done,
      )
      .length;
  if (relationshipKanbanTasks.isEmpty) {
    return 0.35;
  }
  return (completedCount / relationshipKanbanTasks.length).clamp(0.08, 1.0);
}

double _engineeringProgressFraction(WorkflowOrder order) {
  final completedCount = engineeringChecklistTasks
      .where(
        (task) =>
            _normalizeEngineeringChecklistStatus(
              order.engineeringChecklistStatuses[task.key] ??
                  EngineeringChecklistStatus.notStarted,
            ) ==
            EngineeringChecklistStatus.done,
      )
      .length;
  if (engineeringChecklistTasks.isEmpty) {
    return 0.35;
  }
  return (completedCount / engineeringChecklistTasks.length).clamp(0.08, 1.0);
}

_EngineeringFlowSnapshot _engineeringFlowSnapshotFromStatuses(
  Map<String, EngineeringChecklistStatus> statuses,
) {
  final completedTasks = <EngineeringChecklistTask>[];
  EngineeringChecklistTask? currentTask;
  final upcomingTasks = <EngineeringChecklistTask>[];

  for (final task in engineeringChecklistTasks) {
    final status = _normalizeEngineeringChecklistStatus(
      statuses[task.key] ?? EngineeringChecklistStatus.notStarted,
    );
    if (currentTask == null && status != EngineeringChecklistStatus.done) {
      currentTask = task;
      continue;
    }

    if (currentTask == null) {
      completedTasks.add(task);
    } else {
      upcomingTasks.add(task);
    }
  }

  return _EngineeringFlowSnapshot(
    completedTasks: completedTasks,
    currentTask: currentTask,
    upcomingTasks: upcomingTasks,
  );
}

class _FinanceContractChecklistCard extends StatelessWidget {
  const _FinanceContractChecklistCard({
    required this.order,
    required this.isEditable,
    this.onAttachContract,
    this.onStatusChanged,
  });

  final WorkflowOrder order;
  final bool isEditable;
  final Future<void> Function()? onAttachContract;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);
    final surfaceColor = isDarkMode
        ? const Color(0xFF121E1B)
        : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? const Color(0xFF29403A)
        : const Color(0xFFE2E8F0);
    final flowSnapshot = _financeContractFlowSnapshot(order);

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
          const Text(
            'Kanban do contrato',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            isEditable
                ? 'Avance cada etapa do contrato até concluir o cadastro no contas a receber.'
                : 'Visualização do andamento do contrato dentro do Financeiro.',
            style: TextStyle(color: secondaryTextColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          _FinanceContractFlowKanban(
            order: order,
            flowSnapshot: flowSnapshot,
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            isEditable: isEditable,
            onAttachContract: onAttachContract,
            onStatusChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _FinanceContractFlowKanban extends StatelessWidget {
  const _FinanceContractFlowKanban({
    required this.order,
    required this.flowSnapshot,
    required this.isDarkMode,
    required this.borderColor,
    required this.isEditable,
    this.onAttachContract,
    this.onStatusChanged,
  });

  final WorkflowOrder order;
  final _FinanceContractFlowSnapshot flowSnapshot;
  final bool isDarkMode;
  final Color borderColor;
  final bool isEditable;
  final Future<void> Function()? onAttachContract;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 980;
        final columns = [
          _FinanceContractFlowKanbanColumn(
            title: 'Concluídas',
            accent: const Color(0xFF15803D),
            tasks: flowSnapshot.completedTasks,
            emptyMessage: 'Nenhuma etapa concluída ainda.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            order: order,
            isEditable: isEditable,
            onAttachContract: onAttachContract,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.completed,
          ),
          _FinanceContractFlowKanbanColumn(
            title: 'Etapa atual',
            accent: WorkflowStage.finance.color,
            tasks: flowSnapshot.currentTask == null
                ? const <FinanceContractTask>[]
                : [flowSnapshot.currentTask!],
            emptyMessage: 'Fluxo do contrato concluído.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            order: order,
            isEditable: isEditable,
            onAttachContract: onAttachContract,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.current,
          ),
          _FinanceContractFlowKanbanColumn(
            title: 'Próximas',
            accent: const Color(0xFF64748B),
            tasks: flowSnapshot.upcomingTasks,
            emptyMessage: 'Não existem próximas etapas pendentes.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            order: order,
            isEditable: isEditable,
            onAttachContract: onAttachContract,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.upcoming,
          ),
        ];

        if (useColumn) {
          return Column(
            children: [
              for (var index = 0; index < columns.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                columns[index],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < columns.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: columns[index]),
            ],
          ],
        );
      },
    );
  }
}

class _FinanceContractFlowKanbanColumn extends StatelessWidget {
  const _FinanceContractFlowKanbanColumn({
    required this.title,
    required this.accent,
    required this.tasks,
    required this.emptyMessage,
    required this.isDarkMode,
    required this.borderColor,
    required this.order,
    required this.isEditable,
    required this.taskState,
    this.onAttachContract,
    this.onStatusChanged,
  });

  final String title;
  final Color accent;
  final List<FinanceContractTask> tasks;
  final String emptyMessage;
  final bool isDarkMode;
  final Color borderColor;
  final WorkflowOrder order;
  final bool isEditable;
  final _EngineeringFlowTaskState taskState;
  final Future<void> Function()? onAttachContract;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode
        ? const Color(0xFF0E1715)
        : const Color(0xFFFFFFFF);
    final mutedTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.12)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                emptyMessage,
                style: TextStyle(color: mutedTextColor, height: 1.35),
              ),
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FinanceContractFlowTaskCard(
                  task: task,
                  taskState: taskState,
                  accent: accent,
                  order: order,
                  isDarkMode: isDarkMode,
                  borderColor: borderColor,
                  isEditable: isEditable,
                  onAttachContract: onAttachContract,
                  onStatusChanged: onStatusChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FinanceContractFlowTaskCard extends StatelessWidget {
  const _FinanceContractFlowTaskCard({
    required this.task,
    required this.taskState,
    required this.accent,
    required this.order,
    required this.isDarkMode,
    required this.borderColor,
    required this.isEditable,
    this.onAttachContract,
    this.onStatusChanged,
  });

  final FinanceContractTask task;
  final _EngineeringFlowTaskState taskState;
  final Color accent;
  final WorkflowOrder order;
  final bool isDarkMode;
  final Color borderColor;
  final bool isEditable;
  final Future<void> Function()? onAttachContract;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final helperText = switch (taskState) {
      _EngineeringFlowTaskState.completed => 'Etapa já concluída no fluxo.',
      _EngineeringFlowTaskState.current =>
        'Etapa atual do kanban interno do Financeiro.',
      _EngineeringFlowTaskState.upcoming =>
        'Aguardando a conclusão da etapa anterior.',
    };
    final isGenerateContractTask = task.key == 'generate_contract';
    final hasContractFile = order.contractFileName.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDarkMode ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.label,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFD2E1DB)
                  : const Color(0xFF52605C),
              height: 1.3,
              fontSize: 12,
            ),
          ),
          if (isGenerateContractTask) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF0E1715) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasContractFile
                        ? order.contractFileName
                        : 'Nenhum contrato anexado ainda',
                    style: TextStyle(
                      color: hasContractFile
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF52605C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isEditable &&
                      taskState == _EngineeringFlowTaskState.current)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        onPressed: onAttachContract == null
                            ? null
                            : () async {
                                await onAttachContract!();
                              },
                        style: _attachmentReadyButtonStyle(hasContractFile),
                        icon: Icon(
                          hasContractFile
                              ? Icons.upload_file_outlined
                              : Icons.description_outlined,
                        ),
                        label: Text(
                          hasContractFile
                              ? 'Trocar contrato'
                              : 'Anexar contrato',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (isEditable && onStatusChanged != null) ...[
            const SizedBox(height: 10),
            if (taskState == _EngineeringFlowTaskState.current)
              FilledButton.icon(
                onPressed: () async {
                  await onStatusChanged!(
                    task.key,
                    EngineeringChecklistStatus.done,
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Concluir e avançar'),
              ),
            if (taskState == _EngineeringFlowTaskState.completed)
              OutlinedButton.icon(
                onPressed: () async {
                  await onStatusChanged!(
                    task.key,
                    EngineeringChecklistStatus.notStarted,
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reabrir daqui'),
              ),
          ],
        ],
      ),
    );
  }
}

class _FinanceContractFlowSnapshot {
  const _FinanceContractFlowSnapshot({
    required this.completedTasks,
    required this.currentTask,
    required this.upcomingTasks,
  });

  final List<FinanceContractTask> completedTasks;
  final FinanceContractTask? currentTask;
  final List<FinanceContractTask> upcomingTasks;

  bool get isComplete => currentTask == null && upcomingTasks.isEmpty;
}

_FinanceContractFlowSnapshot _financeContractFlowSnapshot(WorkflowOrder order) {
  return _financeContractFlowSnapshotFromStatuses(
    order.financeContractStatuses,
  );
}

_FinanceContractFlowSnapshot _financeContractFlowSnapshotFromStatuses(
  Map<String, EngineeringChecklistStatus> statuses,
) {
  final completedTasks = <FinanceContractTask>[];
  FinanceContractTask? currentTask;
  final upcomingTasks = <FinanceContractTask>[];

  for (final task in financeContractTasks) {
    final status = _normalizeEngineeringChecklistStatus(
      statuses[task.key] ?? EngineeringChecklistStatus.notStarted,
    );
    if (currentTask == null && status != EngineeringChecklistStatus.done) {
      currentTask = task;
      continue;
    }

    if (currentTask == null) {
      completedTasks.add(task);
    } else {
      upcomingTasks.add(task);
    }
  }

  return _FinanceContractFlowSnapshot(
    completedTasks: completedTasks,
    currentTask: currentTask,
    upcomingTasks: upcomingTasks,
  );
}

class _EstimatingKanbanFlowSnapshot {
  const _EstimatingKanbanFlowSnapshot({
    required this.completedTasks,
    required this.currentTask,
    required this.upcomingTasks,
  });

  final List<EstimatingKanbanTask> completedTasks;
  final EstimatingKanbanTask? currentTask;
  final List<EstimatingKanbanTask> upcomingTasks;

  bool get isComplete => currentTask == null && upcomingTasks.isEmpty;
}

_EstimatingKanbanFlowSnapshot _estimatingKanbanFlowSnapshot(
  WorkflowOrder order,
) {
  return _estimatingKanbanFlowSnapshotFromStatuses(
    order.estimatingKanbanStatuses,
  );
}

_EstimatingKanbanFlowSnapshot _estimatingKanbanFlowSnapshotFromStatuses(
  Map<String, EngineeringChecklistStatus> statuses,
) {
  final completedTasks = <EstimatingKanbanTask>[];
  EstimatingKanbanTask? currentTask;
  final upcomingTasks = <EstimatingKanbanTask>[];

  for (final task in estimatingKanbanTasks) {
    final status = _normalizeEngineeringChecklistStatus(
      statuses[task.key] ?? EngineeringChecklistStatus.notStarted,
    );
    if (currentTask == null && status != EngineeringChecklistStatus.done) {
      currentTask = task;
      continue;
    }

    if (currentTask == null) {
      completedTasks.add(task);
    } else {
      upcomingTasks.add(task);
    }
  }

  return _EstimatingKanbanFlowSnapshot(
    completedTasks: completedTasks,
    currentTask: currentTask,
    upcomingTasks: upcomingTasks,
  );
}

class _RelationshipChecklistCard extends StatelessWidget {
  const _RelationshipChecklistCard({
    required this.order,
    required this.isEditable,
    this.onStatusChanged,
  });

  final WorkflowOrder order;
  final bool isEditable;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);
    final surfaceColor = isDarkMode
        ? const Color(0xFF121E1B)
        : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? const Color(0xFF29403A)
        : const Color(0xFFE2E8F0);
    final flowSnapshot = _relationshipKanbanFlowSnapshot(order);

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
          const Text(
            'Kanban do relacionamento',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            isEditable
                ? 'Atualize o andamento do Relacionamento até concluir o encaminhamento do pedido.'
                : 'Visualização do andamento operacional do Relacionamento.',
            style: TextStyle(color: secondaryTextColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          _RelationshipFlowKanban(
            flowSnapshot: flowSnapshot,
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            isEditable: isEditable,
            onStatusChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _RelationshipFlowKanban extends StatelessWidget {
  const _RelationshipFlowKanban({
    required this.flowSnapshot,
    required this.isDarkMode,
    required this.borderColor,
    required this.isEditable,
    this.onStatusChanged,
  });

  final _RelationshipKanbanFlowSnapshot flowSnapshot;
  final bool isDarkMode;
  final Color borderColor;
  final bool isEditable;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 980;
        final columns = [
          _RelationshipFlowKanbanColumn(
            title: 'Concluídas',
            accent: const Color(0xFF15803D),
            tasks: flowSnapshot.completedTasks,
            emptyMessage: 'Nenhuma etapa concluída ainda.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            isEditable: isEditable,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.completed,
          ),
          _RelationshipFlowKanbanColumn(
            title: 'Etapa atual',
            accent: WorkflowStage.relationship.color,
            tasks: flowSnapshot.currentTask == null
                ? const <RelationshipKanbanTask>[]
                : [flowSnapshot.currentTask!],
            emptyMessage: 'Fluxo do relacionamento concluído.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            isEditable: isEditable,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.current,
          ),
          _RelationshipFlowKanbanColumn(
            title: 'Próximas',
            accent: const Color(0xFF64748B),
            tasks: flowSnapshot.upcomingTasks,
            emptyMessage: 'Não existem próximas etapas pendentes.',
            isDarkMode: isDarkMode,
            borderColor: borderColor,
            isEditable: isEditable,
            onStatusChanged: onStatusChanged,
            taskState: _EngineeringFlowTaskState.upcoming,
          ),
        ];

        if (useColumn) {
          return Column(
            children: [
              for (var index = 0; index < columns.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                columns[index],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < columns.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: columns[index]),
            ],
          ],
        );
      },
    );
  }
}

class _RelationshipFlowKanbanColumn extends StatelessWidget {
  const _RelationshipFlowKanbanColumn({
    required this.title,
    required this.accent,
    required this.tasks,
    required this.emptyMessage,
    required this.isDarkMode,
    required this.borderColor,
    required this.isEditable,
    required this.taskState,
    this.onStatusChanged,
  });

  final String title;
  final Color accent;
  final List<RelationshipKanbanTask> tasks;
  final String emptyMessage;
  final bool isDarkMode;
  final Color borderColor;
  final bool isEditable;
  final _EngineeringFlowTaskState taskState;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode
        ? const Color(0xFF0E1715)
        : const Color(0xFFFFFFFF);
    final mutedTextColor = isDarkMode
        ? const Color(0xFF9FB2AC)
        : const Color(0xFF52605C);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.12)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                emptyMessage,
                style: TextStyle(color: mutedTextColor, height: 1.35),
              ),
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RelationshipFlowTaskCard(
                  task: task,
                  taskState: taskState,
                  accent: accent,
                  isDarkMode: isDarkMode,
                  isEditable: isEditable,
                  onStatusChanged: onStatusChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RelationshipFlowTaskCard extends StatelessWidget {
  const _RelationshipFlowTaskCard({
    required this.task,
    required this.taskState,
    required this.accent,
    required this.isDarkMode,
    required this.isEditable,
    this.onStatusChanged,
  });

  final RelationshipKanbanTask task;
  final _EngineeringFlowTaskState taskState;
  final Color accent;
  final bool isDarkMode;
  final bool isEditable;
  final Future<void> Function(
    String taskKey,
    EngineeringChecklistStatus status,
  )?
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final helperText = switch (taskState) {
      _EngineeringFlowTaskState.completed => 'Etapa já concluída no fluxo.',
      _EngineeringFlowTaskState.current =>
        'Etapa atual do kanban interno do Relacionamento.',
      _EngineeringFlowTaskState.upcoming =>
        'Aguardando a conclusão da etapa anterior.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDarkMode ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.label,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFD2E1DB)
                  : const Color(0xFF52605C),
              height: 1.3,
              fontSize: 12,
            ),
          ),
          if (isEditable && onStatusChanged != null) ...[
            const SizedBox(height: 10),
            if (taskState == _EngineeringFlowTaskState.current)
              FilledButton.icon(
                onPressed: () async {
                  await onStatusChanged!(
                    task.key,
                    EngineeringChecklistStatus.done,
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Concluir e avançar'),
              ),
            if (taskState == _EngineeringFlowTaskState.completed)
              OutlinedButton.icon(
                onPressed: () async {
                  await onStatusChanged!(
                    task.key,
                    EngineeringChecklistStatus.notStarted,
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reabrir daqui'),
              ),
          ],
        ],
      ),
    );
  }
}

class _RelationshipKanbanFlowSnapshot {
  const _RelationshipKanbanFlowSnapshot({
    required this.completedTasks,
    required this.currentTask,
    required this.upcomingTasks,
  });

  final List<RelationshipKanbanTask> completedTasks;
  final RelationshipKanbanTask? currentTask;
  final List<RelationshipKanbanTask> upcomingTasks;

  bool get isComplete => currentTask == null && upcomingTasks.isEmpty;
}

_RelationshipKanbanFlowSnapshot _relationshipKanbanFlowSnapshot(
  WorkflowOrder order,
) {
  return _relationshipKanbanFlowSnapshotFromStatuses(
    order.relationshipKanbanStatuses,
  );
}

_RelationshipKanbanFlowSnapshot _relationshipKanbanFlowSnapshotFromStatuses(
  Map<String, EngineeringChecklistStatus> statuses,
) {
  final completedTasks = <RelationshipKanbanTask>[];
  RelationshipKanbanTask? currentTask;
  final upcomingTasks = <RelationshipKanbanTask>[];

  for (final task in relationshipKanbanTasks) {
    final status = _normalizeEngineeringChecklistStatus(
      statuses[task.key] ?? EngineeringChecklistStatus.notStarted,
    );
    if (currentTask == null && status != EngineeringChecklistStatus.done) {
      currentTask = task;
      continue;
    }

    if (currentTask == null) {
      completedTasks.add(task);
    } else {
      upcomingTasks.add(task);
    }
  }

  return _RelationshipKanbanFlowSnapshot(
    completedTasks: completedTasks,
    currentTask: currentTask,
    upcomingTasks: upcomingTasks,
  );
}

ImageProvider<Object>? _resolveProfileImageProvider(String? filePath) {
  final normalized = filePath?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(normalized);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return NetworkImage(_normalizeProfileImageUrl(normalized));
  }

  if (kIsWeb) {
    return null;
  }

  return FileImage(io.File(normalized));
}

String _normalizeProfileImageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return url;
  }

  if (uri.host.contains('drive.google.com')) {
    final idFromQuery = uri.queryParameters['id']?.trim();
    if (idFromQuery != null && idFromQuery.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$idFromQuery';
    }

    final segments = uri.pathSegments;
    final fileIndex = segments.indexOf('d');
    if (fileIndex != -1 && fileIndex + 1 < segments.length) {
      final fileId = segments[fileIndex + 1].trim();
      if (fileId.isNotEmpty) {
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }
    }
  }

  return url;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

int _extractOrderNumber(String code) {
  final firstNumber = RegExp(r'(\d+)').firstMatch(code)?.group(1) ?? '';
  return int.tryParse(firstNumber) ?? 0;
}

String _displayOrderCode(
  WorkflowOrder order, [
  List<WorkflowOrder> allOrders = const [],
]) {
  final baseCode = 'OP-${order.client.id}';
  if (!order.isServiceOrder) {
    final version = order.proposalVersion <= 0 ? 1 : order.proposalVersion;
    if (version <= 1) {
      return baseCode;
    }

    return '$baseCode-P$version';
  }

  final explicitSuffix = RegExp(r'(-OS\d+)$').firstMatch(order.code.trim());
  if (explicitSuffix != null) {
    return '$baseCode${explicitSuffix.group(1)!}';
  }

  if (allOrders.isNotEmpty) {
    final clientServiceOrders = allOrders
        .where(
          (item) => item.client.id == order.client.id && item.isServiceOrder,
        )
        .toList(growable: false);

    if (clientServiceOrders.isNotEmpty) {
      clientServiceOrders.sort((left, right) {
        final codeCompare = _extractOrderNumber(
          left.code,
        ).compareTo(_extractOrderNumber(right.code));
        if (codeCompare != 0) {
          return codeCompare;
        }

        return left.workName.toLowerCase().compareTo(
          right.workName.toLowerCase(),
        );
      });
      final index = clientServiceOrders.indexWhere(
        (item) => item.code == order.code,
      );
      if (index != -1) {
        return '$baseCode-OS${index + 1}';
      }
    }
  }

  return '$baseCode-OS1';
}

String _proposalBadgeLabel(WorkflowOrder order) {
  return 'P${order.proposalVersion <= 0 ? 1 : order.proposalVersion}';
}

String _proposalVersionTitle(WorkflowOrder order) {
  return _proposalVersionTitleFromNumber(order.proposalVersion);
}

String _proposalVersionTitleFromNumber(int proposalVersion) {
  if (proposalVersion <= 1) {
    return 'Proposta principal';
  }

  return '${proposalVersion}a proposta';
}

EngineeringChecklistTask? _engineeringChecklistTaskByKey(String taskKey) {
  for (final task in engineeringChecklistTasks) {
    if (task.key == taskKey) {
      return task;
    }
  }

  return null;
}

Color _engineeringTaskAccent(String taskKey) {
  return switch (taskKey) {
    'depending_on_client' => const Color(0xFF94A3B8),
    'awaiting_presentation' => const Color(0xFF737373),
    'presentation_done' => const Color(0xFF00D084),
    'meeting_electrician' => const Color(0xFFA3E635),
    'executing_electrical' => const Color(0xFF0EA5E9),
    'released_for_conference' => const Color(0xFF7DD3FC),
    'conference_done' => const Color(0xFF00D084),
    _ => WorkflowStage.engineering.color,
  };
}

IconData _engineeringTaskIcon(String taskKey) {
  return switch (taskKey) {
    'depending_on_client' => Icons.chevron_right_rounded,
    'awaiting_presentation' => Icons.chevron_right_rounded,
    'presentation_done' => Icons.chevron_right_rounded,
    'meeting_electrician' => Icons.chevron_right_rounded,
    'executing_electrical' => Icons.chevron_right_rounded,
    'released_for_conference' => Icons.chevron_right_rounded,
    'conference_done' => Icons.chevron_right_rounded,
    _ => Icons.architecture_outlined,
  };
}

List<WorkflowOrder> _proposalGroupOrders(
  List<WorkflowOrder> allOrders,
  WorkflowOrder order,
) {
  final proposalGroupCode = order.proposalGroupCode.trim().isEmpty
      ? order.code
      : order.proposalGroupCode.trim();
  final groupedOrders = allOrders
      .where((item) => item.proposalGroupCode.trim() == proposalGroupCode)
      .toList(growable: false);

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

  return groupedOrders;
}

List<WorkflowOrder> _proposalExtensionsForPrimary(
  List<WorkflowOrder> allOrders,
  WorkflowOrder order,
) {
  if (!order.isPrimaryProposal) {
    return const <WorkflowOrder>[];
  }

  return _proposalGroupOrders(
    allOrders,
    order,
  ).where((item) => item.code != order.code).toList(growable: false);
}

String _formatTimeOnly(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDateWithWeekday(DateTime date) {
  const weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  final weekday = weekdays[date.weekday - 1];
  return '$weekday, ${_formatDate(date)} às ${_formatTimeOnly(date)}';
}

String _formatDayWithWeekday(DateTime date) {
  const weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  final weekday = weekdays[date.weekday - 1];
  return '$weekday, ${_formatDate(date)}';
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} ${_formatTimeOnly(date)}';
}
