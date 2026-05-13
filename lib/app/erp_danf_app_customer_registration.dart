part of 'erp_danf_app.dart';

class _CustomerRegistrationSubtabs extends StatelessWidget {
  const _CustomerRegistrationSubtabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE5E1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useColumn = constraints.maxWidth < 560;

          if (useColumn) {
            return Column(
              children: [
                _CustomerRegistrationSubtabButton(
                  label: 'Cadastro em andamento',
                  selected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
                const SizedBox(height: 10),
                _CustomerRegistrationSubtabButton(
                  label: 'Clientes cadastrados',
                  selected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _CustomerRegistrationSubtabButton(
                  label: 'Cadastro em andamento',
                  selected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CustomerRegistrationSubtabButton(
                  label: 'Clientes cadastrados',
                  selected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StageWorkspaceSubtabs extends StatelessWidget {
  const _StageWorkspaceSubtabs({
    required this.selectedIndex,
    required this.accentColor,
    this.showCalendarTab = false,
    required this.onSelected,
  });

  final int selectedIndex;
  final Color accentColor;
  final bool showCalendarTab;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBE8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useColumn = constraints.maxWidth < 560;

          if (useColumn) {
            return Column(
              children: [
                _CustomerRegistrationSubtabButton(
                  label: 'Trabalhos',
                  selected: selectedIndex == 0,
                  selectedColor: accentColor,
                  onTap: () => onSelected(0),
                ),
                const SizedBox(height: 6),
                if (showCalendarTab) ...[
                  _CustomerRegistrationSubtabButton(
                    label: 'Calendário',
                    selected: selectedIndex == 1,
                    selectedColor: accentColor,
                    onTap: () => onSelected(1),
                  ),
                  const SizedBox(height: 6),
                ],
                _CustomerRegistrationSubtabButton(
                  label: 'Clientes cadastrados',
                  selected: selectedIndex == (showCalendarTab ? 2 : 1),
                  selectedColor: accentColor,
                  onTap: () => onSelected(showCalendarTab ? 2 : 1),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _CustomerRegistrationSubtabButton(
                  label: 'Trabalhos',
                  selected: selectedIndex == 0,
                  selectedColor: accentColor,
                  onTap: () => onSelected(0),
                ),
              ),
              const SizedBox(width: 6),
              if (showCalendarTab) ...[
                Expanded(
                  child: _CustomerRegistrationSubtabButton(
                    label: 'Calendário',
                    selected: selectedIndex == 1,
                    selectedColor: accentColor,
                    onTap: () => onSelected(1),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: _CustomerRegistrationSubtabButton(
                  label: 'Clientes cadastrados',
                  selected: selectedIndex == (showCalendarTab ? 2 : 1),
                  selectedColor: accentColor,
                  onTap: () => onSelected(showCalendarTab ? 2 : 1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RegisteredClientsPreviewSubtabs extends StatelessWidget {
  const _RegisteredClientsPreviewSubtabs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 1,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5EBE8)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useColumn = constraints.maxWidth < 560;

              if (useColumn) {
                return Column(
                  children: const [
                    _CustomerRegistrationPreviewTabButton(
                      label: 'Cadastro em andamento',
                      selected: false,
                    ),
                    SizedBox(height: 6),
                    _CustomerRegistrationPreviewTabButton(
                      label: 'Clientes cadastrados',
                      selected: true,
                    ),
                  ],
                );
              }

              return const Row(
                children: [
                  Expanded(
                    child: _CustomerRegistrationPreviewTabButton(
                      label: 'Cadastro em andamento',
                      selected: false,
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: _CustomerRegistrationPreviewTabButton(
                      label: 'Clientes cadastrados',
                      selected: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomerRegistrationSubtabButton extends StatelessWidget {
  const _CustomerRegistrationSubtabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = const Color(0xFF2563EB),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.24)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? selectedColor : const Color(0xFF14211D),
          ),
        ),
      ),
    );
  }
}

class _CustomerRegistrationPreviewTabButton extends StatelessWidget {
  const _CustomerRegistrationPreviewTabButton({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: 0.22)
              : Colors.transparent,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? const Color(0xFF2563EB) : const Color(0xFF14211D),
        ),
      ),
    );
  }
}

class _CustomerRegistrationUtilityCard extends StatelessWidget {
  const _CustomerRegistrationUtilityCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    this.child,
    this.headerTrailing,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final Widget? child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? accent.withValues(alpha: 0.14)
                      : accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF52605C),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (headerTrailing != null) ...[
                const SizedBox(width: 12),
                headerTrailing!,
              ],
            ],
          ),
          if (child != null) ...[const SizedBox(height: 10), child!],
        ],
      ),
    );
  }
}

class _CustomerRegistrationDraft {
  const _CustomerRegistrationDraft({
    required this.fullName,
    required this.birthDate,
    required this.email,
    required this.rg,
    required this.cpf,
    required this.workName,
    required this.phone,
    required this.billingPostalCode,
    required this.billingStreet,
    required this.billingNumber,
    required this.billingNeighborhood,
    required this.billingComplement,
    required this.billingCity,
    required this.workPostalCode,
    required this.workStreet,
    required this.workNumber,
    required this.workNeighborhood,
    required this.workComplement,
    required this.workCity,
    required this.address,
    required this.commercialProposalNumber,
    required this.paymentType,
    required this.consolidatedValue,
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
    required this.proposalFileName,
    this.proposalFilePath,
    required this.detailFileName,
    this.detailFilePath,
  });

  final String fullName;
  final String birthDate;
  final String email;
  final String rg;
  final String cpf;
  final String workName;
  final String phone;
  final String billingPostalCode;
  final String billingStreet;
  final String billingNumber;
  final String billingNeighborhood;
  final String billingComplement;
  final String billingCity;
  final String workPostalCode;
  final String workStreet;
  final String workNumber;
  final String workNeighborhood;
  final String workComplement;
  final String workCity;
  final String address;
  final String commercialProposalNumber;
  final String paymentType;
  final String consolidatedValue;
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
  final String proposalFileName;
  final String? proposalFilePath;
  final String detailFileName;
  final String? detailFilePath;
}

class _ServiceOrderClientOption {
  const _ServiceOrderClientOption({
    required this.client,
    required this.address,
    required this.referenceWorkName,
  });

  final ClientProfile client;
  final String address;
  final String referenceWorkName;

  String get label => '${client.id} • ${client.name}';
}

class _ServiceOrderDraft {
  const _ServiceOrderDraft({
    required this.client,
    required this.address,
    required this.serviceTitle,
    required this.serviceDescription,
  });

  final ClientProfile client;
  final String address;
  final String serviceTitle;
  final String serviceDescription;
}

const List<String> _proposalServiceNames = [
  'Elétrica Inteligente',
  'Automação da EI',
  'Automação de Ar e Janelas (IR-RF)',
  'Dados',
  'Home Cinema',
  'Projeção',
  'Som Ambiente',
  'Aspiração Central',
  'Piso Aquecido',
];

const List<String> _yesNoOptions = ['Sim', 'Não'];
const List<String> _paymentTypeOptions = ['Pix', 'Cartão de crédito', 'Boleto'];
const List<String> _paymentMethodOptions = ['À vista', 'Parcelado', 'Outro'];

class _ProposalServiceFormRow {
  _ProposalServiceFormRow({required this.serviceName})
    : consolidatedController = TextEditingController(),
      prepareController = TextEditingController(),
      observationsController = TextEditingController();

  final String serviceName;
  final TextEditingController consolidatedController;
  final TextEditingController prepareController;
  final TextEditingController observationsController;

  void dispose() {
    consolidatedController.dispose();
    prepareController.dispose();
    observationsController.dispose();
  }
}

class _WhatsappMemberFormRow {
  _WhatsappMemberFormRow()
    : nameController = TextEditingController(),
      phoneController = TextEditingController(),
      roleController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController roleController;

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    roleController.dispose();
  }
}

class _ServiceOrderDialog extends StatefulWidget {
  const _ServiceOrderDialog({required this.clients});

  final List<_ServiceOrderClientOption> clients;

  @override
  State<_ServiceOrderDialog> createState() => _ServiceOrderDialogState();
}

class _ServiceOrderDialogState extends State<_ServiceOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serviceTitleController = TextEditingController();
  final _serviceDescriptionController = TextEditingController();
  String? _selectedClientId;

  _ServiceOrderClientOption? get _selectedClient {
    final clientId = _selectedClientId;
    if (clientId == null) {
      return null;
    }

    for (final option in widget.clients) {
      if (option.client.id == clientId) {
        return option;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _serviceTitleController.dispose();
    _serviceDescriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedClient = _selectedClient;
    if (selectedClient == null) {
      return;
    }

    Navigator.of(context).pop(
      _ServiceOrderDraft(
        client: selectedClient.client,
        address: selectedClient.address,
        serviceTitle: _serviceTitleController.text.trim(),
        serviceDescription: _serviceDescriptionController.text.trim(),
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final selectedClient = _selectedClient;
    final isCompact = screenWidth < 720;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 640 ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
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
                      Icons.assignment_outlined,
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
                          'Nova ordem de serviço',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 22 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Selecione o cliente, informe a observação para abertura de OS e envie a OS para o Orçamentista.',
                          style: TextStyle(color: Colors.white70),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClientId,
                        decoration: const InputDecoration(
                          labelText: 'Cliente',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.clients
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.client.id,
                                child: Text(option.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() {
                            _selectedClientId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Selecione o cliente.';
                          }

                          return null;
                        },
                      ),
                      if (selectedClient != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFDCE5E1)),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 220,
                                child: _InfoRow(
                                  label: 'Cliente',
                                  value: selectedClient.client.name,
                                  emphasizeValue: true,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _InfoRow(
                                  label: 'Telefone',
                                  value: selectedClient.client.phone,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _InfoRow(
                                  label: 'Última referência',
                                  value: selectedClient.referenceWorkName,
                                ),
                              ),
                              SizedBox(
                                width: 320,
                                child: _InfoRow(
                                  label: 'Endereço',
                                  value: selectedClient.address,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _DialogField(
                        controller: _serviceTitleController,
                        label: 'Título do serviço',
                        validator: _requiredField,
                        hintText:
                            'Ex.: Manutenção corretiva no quadro elétrico',
                      ),
                      const SizedBox(height: 16),
                      _DialogField(
                        controller: _serviceDescriptionController,
                        label: 'Observação para abertura de OS',
                        validator: _requiredField,
                        hintText:
                            'Descreva o escopo, materiais previstos e o contexto para abertura da OS.',
                        maxLines: 5,
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
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Criar e enviar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdditionalProposalDraft {
  const _AdditionalProposalDraft({
    required this.workName,
    required this.address,
    required this.proposalFileName,
    this.proposalFilePath,
  });

  final String workName;
  final String address;
  final String proposalFileName;
  final String? proposalFilePath;
}

class _AdditionalProposalClientPickerDialog extends StatefulWidget {
  const _AdditionalProposalClientPickerDialog({required this.baseOrders});

  final List<WorkflowOrder> baseOrders;

  @override
  State<_AdditionalProposalClientPickerDialog> createState() =>
      _AdditionalProposalClientPickerDialogState();
}

class _AdditionalProposalClientPickerDialogState
    extends State<_AdditionalProposalClientPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<WorkflowOrder> get _filteredOrders {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.baseOrders;
    }

    return widget.baseOrders
        .where((order) {
          return order.client.id.toLowerCase().contains(normalizedQuery) ||
              order.client.name.toLowerCase().contains(normalizedQuery) ||
              order.workName.toLowerCase().contains(normalizedQuery) ||
              order.client.phone.toLowerCase().contains(normalizedQuery) ||
              order.address.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final filteredOrders = _filteredOrders;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 640 ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F2),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
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
                      Icons.people_alt_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selecionar cliente',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Escolha o cliente para gerar uma nova proposta vinculada.',
                          style: TextStyle(color: Colors.white70),
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Pesquisar cliente',
                        hintText: 'ID, nome, obra, telefone ou endereço',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFDCE5E1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: filteredOrders.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDCE5E1),
                                ),
                              ),
                              child: const Text(
                                'Nenhum cliente encontrado com esse filtro.',
                                style: TextStyle(
                                  color: Color(0xFF52605C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredOrders.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = filteredOrders[index];
                                return InkWell(
                                  onTap: () => Navigator.of(context).pop(order),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFDCE5E1),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${order.client.id} • ${order.client.name}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF2FF),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                _proposalVersionTitle(order),
                                                style: const TextStyle(
                                                  color: Color(0xFF3730A3),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          order.workName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${order.client.phone} • ${order.address}',
                                          style: const TextStyle(
                                            color: Color(0xFF52605C),
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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

class _AdditionalProposalDialog extends StatefulWidget {
  const _AdditionalProposalDialog({
    required this.baseOrder,
    required this.proposalVersion,
  });

  final WorkflowOrder baseOrder;
  final int proposalVersion;

  @override
  State<_AdditionalProposalDialog> createState() =>
      _AdditionalProposalDialogState();
}

class _AdditionalProposalDialogState extends State<_AdditionalProposalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _workNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _proposalController = TextEditingController();
  String? _proposalFilePath;

  @override
  void initState() {
    super.initState();
    _workNameController.text = widget.baseOrder.workName;
    _addressController.text = widget.baseOrder.address;
  }

  @override
  void dispose() {
    _workNameController.dispose();
    _addressController.dispose();
    _proposalController.dispose();
    super.dispose();
  }

  Future<void> _pickProposalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'xls', 'xlsx'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        _proposalController.text = result.files.single.name;
        _proposalFilePath = result.files.single.path;
      });
    } on MissingPluginException {
      _showPickerUnavailable();
    } catch (error) {
      final message = error.toString();
      if (message.contains('LateInitializationError') ||
          message.contains('LateError') ||
          error is UnimplementedError) {
        _showPickerUnavailable();
        return;
      }

      rethrow;
    }
  }

  void _showPickerUnavailable() {
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

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório.';
    }

    return null;
  }

  String? _validateAttachment(String? value) {
    final requiredError = _requiredField(value);
    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.trim().toLowerCase();
    if (normalized.endsWith('.pdf') ||
        normalized.endsWith('.xls') ||
        normalized.endsWith('.xlsx')) {
      return null;
    }

    return 'Use arquivo PDF, XLS ou XLSX.';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _AdditionalProposalDraft(
        workName: _workNameController.text.trim(),
        address: _addressController.text.trim(),
        proposalFileName: _proposalController.text.trim(),
        proposalFilePath: _proposalFilePath,
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
        constraints: const BoxConstraints(maxWidth: 860),
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
                      Icons.post_add_outlined,
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
                          'Nova proposta vinculada',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 22 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.baseOrder.client.id} • ${widget.baseOrder.client.name} • ${_proposalVersionTitleFromNumber(widget.proposalVersion)}',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDCE5E1)),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 220,
                              child: _InfoRow(
                                label: 'Cliente',
                                value: widget.baseOrder.client.name,
                                emphasizeValue: true,
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: _InfoRow(
                                label: 'Telefone',
                                value: widget.baseOrder.client.phone,
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: _InfoRow(
                                label: 'Card principal',
                                value: widget.baseOrder.code,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogField(
                        controller: _workNameController,
                        label: 'Nome da obra / proposta',
                        validator: _requiredField,
                      ),
                      const SizedBox(height: 16),
                      _DialogField(
                        controller: _addressController,
                        label: 'Endereço',
                        validator: _requiredField,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _AttachmentPickerField(
                        label: 'Arquivo da nova proposta',
                        helper:
                            'Anexe o arquivo da proposta que seguirá no fluxo.',
                        controller: _proposalController,
                        onPick: _pickProposalFile,
                        validator: _validateAttachment,
                        onClear: _proposalController.text.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _proposalController.clear();
                                  _proposalFilePath = null;
                                });
                              },
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
                              label: const Text('Criar proposta'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerRegistrationDialog extends StatefulWidget {
  const _CustomerRegistrationDialog({
    this.initialDraft,
    this.isEditing = false,
  });

  final _CustomerRegistrationDraft? initialDraft;
  final bool isEditing;

  @override
  State<_CustomerRegistrationDialog> createState() =>
      _CustomerRegistrationDialogState();
}

class _CustomerRegistrationDialogState
    extends State<_CustomerRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _rgController = TextEditingController();
  final _cpfController = TextEditingController();
  final _workNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _billingPostalCodeController = TextEditingController();
  final _billingStreetController = TextEditingController();
  final _billingNumberController = TextEditingController();
  final _billingNeighborhoodController = TextEditingController();
  final _billingComplementController = TextEditingController();
  final _billingCityController = TextEditingController();
  final _workPostalCodeController = TextEditingController();
  final _workStreetController = TextEditingController();
  final _workNumberController = TextEditingController();
  final _workNeighborhoodController = TextEditingController();
  final _workComplementController = TextEditingController();
  final _workCityController = TextEditingController();
  final _commercialProposalNumberController = TextEditingController();
  final _paymentTypeController = TextEditingController();
  final _consolidatedValueController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _paymentObservationController = TextEditingController();
  final _installmentValueController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _rtValueController = TextEditingController();
  final _integratorValueController = TextEditingController();
  final _integratorNameController = TextEditingController();
  final _architectNameController = TextEditingController();
  final _isDanfClientController = TextEditingController();
  final _danfInstallerNameController = TextEditingController();
  final _canHaveDanfPlateController = TextEditingController();
  final _hasWhatsappGroupController = TextEditingController();
  final _whatsappGroupObservationController = TextEditingController();
  late final List<_ProposalServiceFormRow> _proposalServiceRows;
  final List<_WhatsappMemberFormRow> _whatsappMemberRows = [];
  bool _isLoadingBillingPostalCode = false;
  bool _isLoadingWorkPostalCode = false;

  @override
  void initState() {
    super.initState();
    _proposalServiceRows = _proposalServiceNames
        .map((serviceName) => _ProposalServiceFormRow(serviceName: serviceName))
        .toList(growable: false);
    final draft = widget.initialDraft;
    if (draft == null) {
      _whatsappMemberRows.add(_WhatsappMemberFormRow());
      return;
    }

    _fullNameController.text = draft.fullName;
    _birthDateController.text = draft.birthDate;
    _emailController.text = draft.email;
    _rgController.text = draft.rg;
    _cpfController.text = draft.cpf;
    _workNameController.text = draft.workName;
    _phoneController.text = draft.phone;
    _billingPostalCodeController.text = draft.billingPostalCode;
    _billingStreetController.text = draft.billingStreet.trim().isEmpty
        ? draft.address
        : draft.billingStreet;
    _billingNumberController.text = draft.billingNumber;
    _billingNeighborhoodController.text = draft.billingNeighborhood;
    _billingComplementController.text = draft.billingComplement;
    _billingCityController.text = draft.billingCity;
    _workPostalCodeController.text = draft.workPostalCode;
    _workStreetController.text = draft.workStreet;
    _workNumberController.text = draft.workNumber;
    _workNeighborhoodController.text = draft.workNeighborhood;
    _workComplementController.text = draft.workComplement;
    _workCityController.text = draft.workCity;
    _commercialProposalNumberController.text = draft.commercialProposalNumber;
    _paymentTypeController.text = draft.paymentType;
    _consolidatedValueController.text = draft.consolidatedValue;
    _paymentMethodController.text = draft.paymentMethod;
    _paymentObservationController.text = draft.paymentObservation;
    _installmentValueController.text = draft.installmentValue;
    _installmentCountController.text = draft.installmentCount;
    _paymentDateController.text = draft.paymentDate;
    _rtValueController.text = draft.rtValue;
    _integratorValueController.text = draft.integratorValue;
    _integratorNameController.text = draft.integratorName;
    _architectNameController.text = draft.architectName;
    _isDanfClientController.text = draft.isDanfClient;
    _danfInstallerNameController.text = draft.danfInstallerName;
    _canHaveDanfPlateController.text = draft.canHaveDanfPlate;
    _hasWhatsappGroupController.text = draft.hasWhatsappGroup;
    _whatsappGroupObservationController.text = draft.whatsappGroupObservation;
    for (final row in _proposalServiceRows) {
      final saved = draft.proposalServices.where(
        (entry) => entry.serviceName == row.serviceName,
      );
      if (saved.isNotEmpty) {
        final entry = saved.first;
        row.consolidatedController.text = entry.consolidated;
        row.prepareController.text = entry.prepareInProject;
        row.observationsController.text = entry.observations;
      }
    }
    if (draft.whatsappGroupMembers.isEmpty) {
      _whatsappMemberRows.add(_WhatsappMemberFormRow());
    } else {
      for (final member in draft.whatsappGroupMembers) {
        final row = _WhatsappMemberFormRow();
        row.nameController.text = member.name;
        row.phoneController.text = member.phone;
        row.roleController.text = member.role;
        _whatsappMemberRows.add(row);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _rgController.dispose();
    _cpfController.dispose();
    _workNameController.dispose();
    _phoneController.dispose();
    _billingPostalCodeController.dispose();
    _billingStreetController.dispose();
    _billingNumberController.dispose();
    _billingNeighborhoodController.dispose();
    _billingComplementController.dispose();
    _billingCityController.dispose();
    _workPostalCodeController.dispose();
    _workStreetController.dispose();
    _workNumberController.dispose();
    _workNeighborhoodController.dispose();
    _workComplementController.dispose();
    _workCityController.dispose();
    _commercialProposalNumberController.dispose();
    _paymentTypeController.dispose();
    _consolidatedValueController.dispose();
    _paymentMethodController.dispose();
    _paymentObservationController.dispose();
    _installmentValueController.dispose();
    _installmentCountController.dispose();
    _paymentDateController.dispose();
    _rtValueController.dispose();
    _integratorValueController.dispose();
    _integratorNameController.dispose();
    _architectNameController.dispose();
    _isDanfClientController.dispose();
    _danfInstallerNameController.dispose();
    _canHaveDanfPlateController.dispose();
    _hasWhatsappGroupController.dispose();
    _whatsappGroupObservationController.dispose();
    for (final row in _proposalServiceRows) {
      row.dispose();
    }
    for (final row in _whatsappMemberRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CustomerRegistrationDraft(
        fullName: _fullNameController.text.trim(),
        birthDate: _birthDateController.text.trim(),
        email: _emailController.text.trim(),
        rg: _rgController.text.trim(),
        cpf: _cpfController.text.trim(),
        workName: _workNameController.text.trim(),
        phone: _phoneController.text.trim(),
        billingPostalCode: _billingPostalCodeController.text.trim(),
        billingStreet: _billingStreetController.text.trim(),
        billingNumber: _billingNumberController.text.trim(),
        billingNeighborhood: _billingNeighborhoodController.text.trim(),
        billingComplement: _billingComplementController.text.trim(),
        billingCity: _billingCityController.text.trim(),
        workPostalCode: _workPostalCodeController.text.trim(),
        workStreet: _workStreetController.text.trim(),
        workNumber: _workNumberController.text.trim(),
        workNeighborhood: _workNeighborhoodController.text.trim(),
        workComplement: _workComplementController.text.trim(),
        workCity: _workCityController.text.trim(),
        address: _composeCustomerAddress(
          street: _workStreetController.text.trim(),
          number: _workNumberController.text.trim(),
          neighborhood: _workNeighborhoodController.text.trim(),
          complement: _workComplementController.text.trim(),
          city: _workCityController.text.trim(),
          postalCode: _workPostalCodeController.text.trim(),
        ),
        commercialProposalNumber: _commercialProposalNumberController.text
            .trim(),
        paymentType: _paymentTypeController.text.trim(),
        consolidatedValue: _consolidatedValueController.text.trim(),
        paymentMethod: _paymentMethodController.text.trim(),
        paymentObservation: _paymentObservationController.text.trim(),
        installmentValue: _installmentValueController.text.trim(),
        installmentCount: _installmentCountController.text.trim(),
        paymentDate: _paymentDateController.text.trim(),
        rtValue: _rtValueController.text.trim(),
        integratorValue: _integratorValueController.text.trim(),
        integratorName: _integratorNameController.text.trim(),
        architectName: _architectNameController.text.trim(),
        proposalServices: _proposalServiceRows
            .map(
              (row) => ProposalServiceEntry(
                serviceName: row.serviceName,
                consolidated: row.consolidatedController.text.trim(),
                prepareInProject: row.prepareController.text.trim(),
                observations: row.observationsController.text.trim(),
              ),
            )
            .toList(growable: false),
        isDanfClient: _isDanfClientController.text.trim(),
        danfInstallerName: _danfInstallerNameController.text.trim(),
        canHaveDanfPlate: _canHaveDanfPlateController.text.trim(),
        hasWhatsappGroup: _hasWhatsappGroupController.text.trim(),
        whatsappGroupMembers: _whatsappMemberRows
            .map(
              (row) => WhatsappGroupMember(
                name: row.nameController.text.trim(),
                phone: row.phoneController.text.trim(),
                role: row.roleController.text.trim(),
              ),
            )
            .where(
              (member) =>
                  member.name.isNotEmpty ||
                  member.phone.isNotEmpty ||
                  member.role.isNotEmpty,
            )
            .toList(growable: false),
        whatsappGroupObservation: _whatsappGroupObservationController.text
            .trim(),
        proposalFileName: widget.initialDraft?.proposalFileName ?? '',
        proposalFilePath: widget.initialDraft?.proposalFilePath,
        detailFileName: widget.initialDraft?.detailFileName ?? '',
        detailFilePath: widget.initialDraft?.detailFilePath,
      ),
    );
  }

  String? _validatePhoneNumber(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Informe o telefone.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      return 'Digite apenas números.';
    }
    return null;
  }

  String? _validatePostalCode(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return 'Informe o CEP.';
    }
    if (normalized.length != 8) {
      return 'CEP deve ter 8 números.';
    }
    return null;
  }

  String? _validateDate(String? value, {required String label}) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Informe $label.';
    }
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(normalized)) {
      return '$label deve estar no formato DD/MM/AAAA.';
    }
    return null;
  }

  String? _validateDigitsOnly(String? value, {required String label}) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Informe $label.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      return '$label deve conter apenas números.';
    }
    return null;
  }

  String? _validateDecimalWithComma(String? value, {required String label}) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Informe $label.';
    }
    if (!RegExp(r'^[0-9]+(,[0-9]{1,2})?$').hasMatch(normalized)) {
      return '$label deve estar no formato 0,00.';
    }
    return null;
  }

  Future<void> _lookupPostalCode({
    required TextEditingController postalCodeController,
    required TextEditingController streetController,
    required TextEditingController neighborhoodController,
    required TextEditingController cityController,
    required bool isBilling,
  }) async {
    final validationError = _validatePostalCode(postalCodeController.text);
    if (validationError != null) {
      _showFormMessage(validationError);
      return;
    }

    final postalCode = postalCodeController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    setState(() {
      if (isBilling) {
        _isLoadingBillingPostalCode = true;
      } else {
        _isLoadingWorkPostalCode = true;
      }
    });

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$postalCode/json/'),
      );
      if (response.statusCode != 200) {
        _showFormMessage('Não foi possível consultar o CEP agora.');
        return;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic> || payload['erro'] == true) {
        _showFormMessage('CEP não encontrado.');
        return;
      }

      setState(() {
        streetController.text = (payload['logradouro'] ?? '').toString();
        neighborhoodController.text = (payload['bairro'] ?? '').toString();
        final city = (payload['localidade'] ?? '').toString().trim();
        final state = (payload['uf'] ?? '').toString().trim();
        cityController.text = [
          city,
          state,
        ].where((part) => part.isNotEmpty).join(' - ');
      });
    } catch (_) {
      _showFormMessage('Falha ao consultar o CEP.');
    } finally {
      if (mounted) {
        setState(() {
          if (isBilling) {
            _isLoadingBillingPostalCode = false;
          } else {
            _isLoadingWorkPostalCode = false;
          }
        });
      }
    }
  }

  void _showFormMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPostalLookupRow({
    required TextEditingController postalCodeController,
    required TextEditingController streetController,
    required TextEditingController neighborhoodController,
    required TextEditingController cityController,
    required bool isBilling,
  }) {
    final isLoading = isBilling
        ? _isLoadingBillingPostalCode
        : _isLoadingWorkPostalCode;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DialogField(
            controller: postalCodeController,
            label: 'CEP',
            keyboardType: TextInputType.number,
            validator: _validatePostalCode,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: isLoading
                ? null
                : () async {
                    await _lookupPostalCode(
                      postalCodeController: postalCodeController,
                      streetController: streetController,
                      neighborhoodController: neighborhoodController,
                      cityController: cityController,
                      isBilling: isBilling,
                    );
                  },
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ),
      ],
    );
  }

  void _addWhatsappMemberRow() {
    setState(() {
      _whatsappMemberRows.add(_WhatsappMemberFormRow());
    });
  }

  void _removeWhatsappMemberRow(int index) {
    if (_whatsappMemberRows.length == 1) {
      return;
    }
    setState(() {
      final row = _whatsappMemberRows.removeAt(index);
      row.dispose();
    });
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          return Container(
            constraints: const BoxConstraints(maxWidth: 900),
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFF12372A), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
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
                              widget.isEditing
                                  ? 'Editar cadastro do cliente'
                                  : 'Novo cadastro do cliente',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 22 : 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isEditing
                                  ? 'Atualize obra, telefone, endereço e anexos no mesmo padrão visual do ERP.'
                                  : 'Crie a obra com telefone, endereço e anexos iniciais no mesmo padrão visual do ERP.',
                              style: TextStyle(color: Colors.white70),
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildSectionCard(
                            context,
                            title: 'Pedido consolidado',
                            children: [
                              _DialogField(
                                controller: _fullNameController,
                                label: 'Nome completo',
                                validator: _requiredField,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller: _birthDateController,
                                      label: 'Data de nascimento',
                                      validator: (value) => _validateDate(
                                        value,
                                        label: 'a data de nascimento',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        _DateTextInputFormatter(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _emailController,
                                      label: 'E-mail',
                                      validator: _requiredField,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller: _rgController,
                                      label: 'RG',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o RG',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _cpfController,
                                      label: 'CPF',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o CPF',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _phoneController,
                                      label: 'Telefone',
                                      keyboardType: TextInputType.phone,
                                      validator: _validatePhoneNumber,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            context,
                            title: 'Endereço de cobrança',
                            children: [
                              _buildPostalLookupRow(
                                postalCodeController:
                                    _billingPostalCodeController,
                                streetController: _billingStreetController,
                                neighborhoodController:
                                    _billingNeighborhoodController,
                                cityController: _billingCityController,
                                isBilling: true,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _DialogField(
                                      controller: _billingStreetController,
                                      label: 'Rua',
                                      validator: _requiredField,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _billingNumberController,
                                      label: 'Número',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o número',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller:
                                          _billingNeighborhoodController,
                                      label: 'Bairro / condomínio',
                                      validator: _requiredField,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _billingComplementController,
                                      label: 'Complemento',
                                      validator: (_) => null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _DialogField(
                                controller: _billingCityController,
                                label: 'Cidade',
                                validator: _requiredField,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            context,
                            title: 'Endereço da obra',
                            children: [
                              _DialogField(
                                controller: _workNameController,
                                label: 'Nome da obra',
                                validator: _requiredField,
                              ),
                              const SizedBox(height: 16),
                              _buildPostalLookupRow(
                                postalCodeController: _workPostalCodeController,
                                streetController: _workStreetController,
                                neighborhoodController:
                                    _workNeighborhoodController,
                                cityController: _workCityController,
                                isBilling: false,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _DialogField(
                                      controller: _workStreetController,
                                      label: 'Rua',
                                      validator: _requiredField,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _workNumberController,
                                      label: 'Número',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o número',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller: _workNeighborhoodController,
                                      label: 'Bairro / condomínio',
                                      validator: _requiredField,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _workComplementController,
                                      label: 'Complemento',
                                      validator: (_) => null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _DialogField(
                                controller: _workCityController,
                                label: 'Cidade',
                                validator: _requiredField,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            context,
                            title: 'Informações comerciais',
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller:
                                          _commercialProposalNumberController,
                                      label: 'Número da proposta',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o número da proposta',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _consolidatedValueController,
                                      label: 'Valor consolidado',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o valor consolidado',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogChoiceField(
                                      value:
                                          _paymentTypeController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : _paymentTypeController.text.trim(),
                                      label: 'Pagamento',
                                      options: _paymentTypeOptions,
                                      validator: _requiredField,
                                      onChanged: (value) {
                                        setState(() {
                                          _paymentTypeController.text =
                                              value ?? '';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogChoiceField(
                                      value:
                                          _paymentMethodController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : _paymentMethodController.text
                                                .trim(),
                                      label: 'Forma de pagamento',
                                      options: _paymentMethodOptions,
                                      validator: _requiredField,
                                      onChanged: (value) {
                                        setState(() {
                                          _paymentMethodController.text =
                                              value ?? '';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _installmentValueController,
                                      label: 'Valor da parcela',
                                      validator: (value) =>
                                          _validateDecimalWithComma(
                                            value,
                                            label: 'o valor da parcela',
                                          ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9,]'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _installmentCountController,
                                      label: 'Qtde de parcelas',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'a quantidade de parcelas',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _DialogField(
                                controller: _paymentObservationController,
                                label: 'Observação',
                                validator: _validatePaymentObservation,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller: _integratorValueController,
                                      label: 'Valor integrador',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o valor integrador',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _integratorNameController,
                                      label: 'Nome do integrador',
                                      validator: _requiredField,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogField(
                                      controller: _paymentDateController,
                                      label: 'Data do pagamento',
                                      validator: (value) => _validateDate(
                                        value,
                                        label: 'a data do pagamento',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        _DateTextInputFormatter(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _rtValueController,
                                      label: 'Valor RT',
                                      validator: (value) => _validateDigitsOnly(
                                        value,
                                        label: 'o valor RT',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogField(
                                      controller: _architectNameController,
                                      label: 'Nome do arquiteto',
                                      validator: _requiredField,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            context,
                            title: 'Etapa 2',
                            children: [
                              const Text(
                                'Serviços',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final row in _proposalServiceRows) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFDCE5E1),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row.serviceName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _DialogChoiceField(
                                              value:
                                                  row
                                                      .consolidatedController
                                                      .text
                                                      .trim()
                                                      .isEmpty
                                                  ? null
                                                  : row
                                                        .consolidatedController
                                                        .text
                                                        .trim(),
                                              label: 'Consolidado',
                                              options: _yesNoOptions,
                                              validator: _requiredField,
                                              onChanged: (value) {
                                                setState(() {
                                                  row
                                                          .consolidatedController
                                                          .text =
                                                      value ?? '';
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _DialogChoiceField(
                                              value:
                                                  row.prepareController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? null
                                                  : row.prepareController.text
                                                        .trim(),
                                              label: 'Preparar no projeto',
                                              options: _yesNoOptions,
                                              validator: _requiredField,
                                              onChanged: (value) {
                                                setState(() {
                                                  row.prepareController.text =
                                                      value ?? '';
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _DialogField(
                                        controller: row.observationsController,
                                        label: 'Observações',
                                        validator: (_) => null,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _DialogChoiceField(
                                      value:
                                          _isDanfClientController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : _isDanfClientController.text.trim(),
                                      label: 'Já é cliente DANF?',
                                      options: _yesNoOptions,
                                      validator: _requiredField,
                                      onChanged: (value) {
                                        setState(() {
                                          _isDanfClientController.text =
                                              value ?? '';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _DialogChoiceField(
                                      value:
                                          _danfInstallerNameController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : _danfInstallerNameController.text
                                                .trim(),
                                      label: 'DANF que vai fazer a instalação?',
                                      options: _yesNoOptions,
                                      validator: _requiredField,
                                      onChanged: (value) {
                                        setState(() {
                                          _danfInstallerNameController.text =
                                              value ?? '';
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _DialogChoiceField(
                                value:
                                    _canHaveDanfPlateController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : _canHaveDanfPlateController.text.trim(),
                                label: 'Pode ter placa da DANF na obra?',
                                options: _yesNoOptions,
                                validator: _requiredField,
                                onChanged: (value) {
                                  setState(() {
                                    _canHaveDanfPlateController.text =
                                        value ?? '';
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _DialogChoiceField(
                                value:
                                    _hasWhatsappGroupController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : _hasWhatsappGroupController.text.trim(),
                                label: 'Tem grupo criado no WhatsApp?',
                                options: _yesNoOptions,
                                validator: _requiredField,
                                onChanged: (value) {
                                  setState(() {
                                    _hasWhatsappGroupController.text =
                                        value ?? '';
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Membros do Grupo de WhatsApp',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _addWhatsappMemberRow,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Adicionar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              for (
                                var index = 0;
                                index < _whatsappMemberRows.length;
                                index++
                              ) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFDCE5E1),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Membro ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (_whatsappMemberRows.length > 1)
                                            IconButton(
                                              onPressed: () =>
                                                  _removeWhatsappMemberRow(
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
                                              controller:
                                                  _whatsappMemberRows[index]
                                                      .nameController,
                                              label: 'Nome',
                                              validator: _requiredField,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _DialogField(
                                              controller:
                                                  _whatsappMemberRows[index]
                                                      .phoneController,
                                              label: 'Telefone',
                                              validator: _validatePhoneNumber,
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
                                            child: _DialogField(
                                              controller:
                                                  _whatsappMemberRows[index]
                                                      .roleController,
                                              label: 'Cargo / função',
                                              validator: _requiredField,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _DialogField(
                                controller: _whatsappGroupObservationController,
                                label: 'Observação sobre o grupo de WhatsApp',
                                validator: (_) => null,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          widget.isEditing
                              ? 'Salvar alterações'
                              : 'Criar cadastro',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório.';
    }

    return null;
  }

  String? _validatePaymentObservation(String? value) {
    if (_paymentMethodController.text.trim() == 'Outro') {
      return _requiredField(value);
    }

    return null;
  }
}

String _composeCustomerAddress({
  required String street,
  required String number,
  required String neighborhood,
  required String complement,
  required String city,
  required String postalCode,
}) {
  final lineOne = [
    street,
    number,
  ].where((part) => part.trim().isNotEmpty).join(', ');
  final lineTwoParts = [
    neighborhood.trim(),
    if (complement.trim().isNotEmpty) 'Compl. ${complement.trim()}',
    city.trim(),
    if (postalCode.trim().isNotEmpty) 'CEP ${postalCode.trim()}',
  ].where((part) => part.isNotEmpty);

  return [
    lineOne,
    lineTwoParts.join(' • '),
  ].where((part) => part.trim().isNotEmpty).join(' — ');
}

class _DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length && index < 8; index++) {
      if (index == 2 || index == 4) {
        buffer.write('/');
      }
      buffer.write(digits[index]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _AttachmentPickerField extends FormField<String> {
  _AttachmentPickerField({
    required String label,
    required String helper,
    required TextEditingController controller,
    Future<void> Function()? onPick,
    required String? Function(String?) validator,
    VoidCallback? onClear,
    String? lockedMessage,
  }) : super(
         validator: validator,
         builder: (field) {
           final hasFile = controller.text.isNotEmpty;
           final isLocked = lockedMessage != null;
           return Container(
             padding: const EdgeInsets.all(20),
             decoration: _panelDecoration(field.context),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   label,
                   style: const TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.w700,
                   ),
                 ),
                 const SizedBox(height: 6),
                 Text(helper, style: const TextStyle(color: Color(0xFF52605C))),
                 const SizedBox(height: 16),
                 OutlinedButton.icon(
                   onPressed: onPick == null
                       ? null
                       : () async {
                           await onPick();
                           field.didChange(controller.text);
                         },
                   icon: const Icon(Icons.attach_file_outlined),
                   label: Text(
                     onPick == null
                         ? 'Arquivo bloqueado'
                         : hasFile
                         ? 'Trocar arquivo'
                         : 'Adicionar arquivo',
                   ),
                 ),
                 const SizedBox(height: 12),
                 if (isLocked)
                   TextFormField(
                     initialValue: lockedMessage,
                     readOnly: true,
                     decoration: const InputDecoration(
                       labelText: 'Arquivo selecionado',
                       border: OutlineInputBorder(),
                     ),
                   )
                 else if (hasFile)
                   TextFormField(
                     controller: controller,
                     readOnly: true,
                     validator: validator,
                     decoration: InputDecoration(
                       labelText: 'Arquivo selecionado',
                       border: const OutlineInputBorder(),
                       suffixIcon: onClear == null
                           ? null
                           : IconButton(
                               onPressed: () {
                                 onClear();
                                 field.didChange(controller.text);
                               },
                               icon: const Icon(Icons.close),
                             ),
                     ),
                   )
                 else
                   TextFormField(
                     controller: controller,
                     readOnly: true,
                     validator: validator,
                     decoration: const InputDecoration(
                       labelText: 'Arquivo selecionado',
                       hintText: 'Nenhum arquivo adicionado',
                       border: OutlineInputBorder(),
                     ),
                   ),
                 if (field.hasError) ...[
                   const SizedBox(height: 8),
                   Text(
                     field.errorText!,
                     style: const TextStyle(color: Color(0xFFB91C1C)),
                   ),
                 ],
               ],
             ),
           );
         },
       );
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
    this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: enabled,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _DialogChoiceField extends StatelessWidget {
  const _DialogChoiceField({
    required this.value,
    required this.label,
    required this.options,
    required this.onChanged,
    required this.validator,
  });

  final String? value;
  final String label;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value?.trim().toLowerCase();
    final Color accentColor = switch (normalizedValue) {
      'sim' => const Color(0xFF14804A),
      'não' || 'nao' => const Color(0xFFC62828),
      _ => const Color(0xFF52605C),
    };
    final Color fillColor = switch (normalizedValue) {
      'sim' => const Color(0xFFE7F6ED),
      'não' || 'nao' => const Color(0xFFFCEAEA),
      _ => Colors.white,
    };

    return DropdownButtonFormField<String>(
      initialValue: value,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: fillColor,
        labelStyle: TextStyle(color: accentColor),
        border: OutlineInputBorder(borderSide: BorderSide(color: accentColor)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor, width: 1.6),
        ),
      ),
      style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
      iconEnabledColor: accentColor,
      items: options
          .map(
            (option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}
