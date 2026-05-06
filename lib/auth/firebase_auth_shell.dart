import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../auth/workspace_credentials.dart';
import '../auth/workspace_session.dart';
import '../data/mock_data.dart';
import '../models/erp_models.dart';
import '../services/firebase_workflow_repository.dart';

class FirebaseAuthShell extends StatefulWidget {
  const FirebaseAuthShell({
    super.key,
    required this.firebaseInitializationError,
    required this.authenticatedBuilder,
  });

  final Object? firebaseInitializationError;
  final WidgetBuilder authenticatedBuilder;

  @override
  State<FirebaseAuthShell> createState() => _FirebaseAuthShellState();
}

class _FirebaseAuthShellState extends State<FirebaseAuthShell> {
  final FirebaseWorkflowRepository _repository = FirebaseWorkflowRepository();

  bool _isBootstrapping = true;
  Object? _bootstrapError;
  String? _bootstrapWarning;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await WorkspaceSession.instance.initialize();
    } catch (error) {
      _bootstrapError = error;
    }

    try {
      if (_bootstrapError == null &&
          FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (error) {
      _bootstrapWarning =
          'Nao foi possivel autenticar no Firebase agora. '
          'O app vai abrir com os perfis locais e tentar sincronizar depois. '
          'Detalhe: $error';
    }

    try {
      await _repository.ensureWorkspaceProfiles(workspaceProfiles);
    } catch (error) {
      _bootstrapWarning ??=
          'Nao foi possivel sincronizar os perfis com o Firebase agora. '
          'O app vai abrir com os perfis locais. '
          'Detalhe: $error';
    } finally {
      _setStateSafely(() {
        _isBootstrapping = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    if (widget.firebaseInitializationError != null) {
      return FirebaseConfigurationScreen(
        error: widget.firebaseInitializationError!,
      );
    }

    if (_isBootstrapping) {
      return const _AuthLoadingScreen();
    }

    if (_bootstrapError != null) {
      return FirebaseConfigurationScreen(error: _bootstrapError!);
    }

    return ValueListenableBuilder<String?>(
      valueListenable: WorkspaceSession.instance.currentProfileIdListenable,
      builder: (context, profileId, _) {
        if (profileId == null || profileId.isEmpty) {
          return LoginPage(bootstrapWarning: _bootstrapWarning);
        }

        return widget.authenticatedBuilder(context);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.bootstrapWarning});

  final String? bootstrapWarning;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final FirebaseWorkflowRepository _repository = FirebaseWorkflowRepository();

  bool _isSubmitting = false;
  bool _obscureAccessCode = true;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<EmployeeWorkspaceProfile> profiles) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final normalizedLogin = _loginController.text.trim().toLowerCase();
    final selectedProfile = profiles
        .where((profile) => profile.login.toLowerCase() == normalizedLogin)
        .firstOrNull;
    if (selectedProfile == null) {
      setState(() {
        _errorMessage = 'Usuário ou código de acesso inválidos.';
      });
      return;
    }

    final storedHash = selectedProfile.accessCodeHash.trim();
    if (storedHash.isEmpty) {
      setState(() {
        _errorMessage =
            'Este usuário ainda não possui um código de acesso configurado.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final typedHash = hashWorkspaceAccessCode(_accessCodeController.text);
      if (typedHash != storedHash) {
        setState(() {
          _errorMessage = 'Usuário ou código de acesso inválidos.';
        });
        return;
      }

      await WorkspaceSession.instance.signIn(selectedProfile.email);
    } catch (_) {
      setState(() {
        _errorMessage = 'Não foi possível concluir o login agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    final isDarkMode = theme.brightness == Brightness.dark;

    return StreamBuilder<List<EmployeeWorkspaceProfile>>(
      stream: _repository.watchWorkspaceProfiles(),
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? const <EmployeeWorkspaceProfile>[];
        final availableProfiles = profiles.isEmpty
            ? workspaceProfiles
            : profiles;
        final syncWarning = snapshot.hasError
            ? _buildProfilesWarning(snapshot.error)
            : widget.bootstrapWarning;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? const [Color(0xFF08110F), Color(0xFF13211E)]
                    : const [Color(0xFFF3F6FB), Color(0xFFE7EEF7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 1040 : 480),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF101A18)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDarkMode
                            ? const Color(0xFF29403A)
                            : const Color(0xFFD5E0EE),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? const Color(0x66030B09)
                              : const Color(0x121E3A5F),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: isWide
                        ? Row(
                            children: [
                              _LoginBrandPanel(theme: theme),
                              Container(
                                width: 1,
                                color: isDarkMode
                                    ? const Color(0xFF29403A)
                                    : const Color(0xFFE2E8F0),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(36),
                                  child: _buildForm(
                                    theme,
                                    availableProfiles,
                                    warningMessage: syncWarning,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.all(28),
                            child: _buildForm(
                              theme,
                              availableProfiles,
                              showCompactHeader: true,
                              warningMessage: syncWarning,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(
    ThemeData theme,
    List<EmployeeWorkspaceProfile> profiles, {
    bool showCompactHeader = false,
    String? warningMessage,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final fieldFill = isDarkMode
        ? const Color(0xFF0F1A18)
        : const Color(0xFFF8FAFC);
    final fieldBorder = isDarkMode
        ? const Color(0xFF29403A)
        : const Color(0xFFD7E1DD);
    final primaryText = isDarkMode
        ? const Color(0xFFE7F1EC)
        : const Color(0xFF14211D);
    final secondaryText = isDarkMode
        ? const Color(0xFFB8CBC4)
        : const Color(0xFF52605C);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCompactHeader) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF132A46)
                    : const Color(0xFFE0EBFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: Color(0xFF2563EB),
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Acesso ao sistema',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entre com o usuário interno do ERP e o código de acesso liberado pela administração.',
            style: TextStyle(color: secondaryText, fontSize: 15, height: 1.45),
          ),
          if (warningMessage != null && warningMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text(
                warningMessage,
                style: const TextStyle(color: Color(0xFF9A3412), height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 28),
          TextFormField(
            controller: _loginController,
            style: TextStyle(color: primaryText),
            decoration: InputDecoration(
              labelText: 'Login',
              hintText: 'Digite seu login interno',
              filled: true,
              fillColor: fieldFill,
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: fieldBorder),
              ),
            ),
            validator: (value) {
              if (profiles.isEmpty) {
                return 'Nenhum usuário cadastrado.';
              }
              if ((value ?? '').trim().isEmpty) {
                return 'Digite o login.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accessCodeController,
            obscureText: _obscureAccessCode,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Código de acesso',
              hintText: 'Digite seu PIN ou senha interna',
              filled: true,
              fillColor: fieldFill,
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: fieldBorder),
              ),
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
              if ((value ?? '').trim().isEmpty) {
                return 'Informe o código de acesso.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(profiles),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting || profiles.isEmpty
                  ? null
                  : () => _submit(profiles),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(_isSubmitting ? 'Entrando...' : 'Acessar sistema'),
            ),
          ),
          if (profiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Os usuários são cadastrados pela administração e vinculados aos quadros liberados no ERP.',
              style: TextStyle(color: secondaryText, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _buildProfilesWarning(Object? error) {
    final detail = error?.toString() ?? 'erro desconhecido';
    final normalizedDetail = detail.toLowerCase();
    if (normalizedDetail.contains('permission-denied')) {
      return 'Nao foi possivel carregar os usuarios do Firebase agora. '
          'O login esta usando os perfis locais salvos no app. '
          'Verifique se o arquivo firestore.rules foi publicado no projeto e '
          'se o login anonimo esta habilitado no Firebase Authentication. '
          'Detalhe: $detail';
    }

    return 'Nao foi possivel carregar os usuarios do Firebase agora. '
        'O login esta usando os perfis locais salvos no app. '
        'Detalhe: $detail';
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF123A63), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'ERP DANF',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Agora o acesso pode ser gerenciado por usuários internos do ERP, sem depender de um e-mail e senha do Firebase para cada pessoa.',
                  style: TextStyle(
                    color: Color(0xFFE0EAFB),
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LoginFeatureRow(
                    icon: Icons.group_add_outlined,
                    label: 'Usuários criados diretamente pelo administrador',
                  ),
                  SizedBox(height: 14),
                  _LoginFeatureRow(
                    icon: Icons.view_kanban_outlined,
                    label:
                        'Liberação por quadro e setor atualizada em tempo real',
                  ),
                  SizedBox(height: 14),
                  _LoginFeatureRow(
                    icon: Icons.password_outlined,
                    label: 'Acesso com código interno simples para a operação',
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

class _LoginFeatureRow extends StatelessWidget {
  const _LoginFeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class FirebaseConfigurationScreen extends StatelessWidget {
  const FirebaseConfigurationScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
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
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: Color(0xFFEA580C),
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Firebase não configurado',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'O ERP usa o Firebase para sincronizar os dados e manter os usuários internos do sistema.',
            style: TextStyle(fontSize: 16, color: Color(0xFF52605C)),
          ),
          const SizedBox(height: 18),
          const Text(
            'Próximo passo: execute `flutterfire configure` e gere os arquivos de configuração da plataforma.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'Erro atual: $error',
            style: const TextStyle(color: Color(0xFF7F1D1D)),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: card,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
