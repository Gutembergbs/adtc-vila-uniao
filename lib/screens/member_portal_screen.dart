import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../configuracao_supabase.dart';
import '../models/department.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../utils/account_deletion_request.dart';
import '../utils/member_date_utils.dart';
import '../widgets/app_navigation_actions.dart';

class MemberPortalScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onOpenDrawer;
  final int registrationRequestToken;

  const MemberPortalScreen({
    super.key,
    required this.authService,
    required this.onOpenDrawer,
    this.registrationRequestToken = 0,
  });

  @override
  State<MemberPortalScreen> createState() => _MemberPortalScreenState();
}

class _MemberPortalScreenState extends State<MemberPortalScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _registrationMode = false;
  bool _uploadingPhoto = false;
  bool _sendingPasswordRecovery = false;
  int _failedLoginAttempts = 0;
  late int _loginAttemptsResetVersion;
  String _accountType = 'membro';
  String? _authError;

  @override
  void initState() {
    super.initState();
    _loginAttemptsResetVersion = widget.authService.loginAttemptsResetVersion;
    widget.authService.addListener(_handleAuthServiceChange);
  }

  @override
  void didUpdateWidget(covariant MemberPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authService != oldWidget.authService) {
      oldWidget.authService.removeListener(_handleAuthServiceChange);
      _loginAttemptsResetVersion = widget.authService.loginAttemptsResetVersion;
      widget.authService.addListener(_handleAuthServiceChange);
    }
    if (widget.registrationRequestToken != oldWidget.registrationRequestToken) {
      setState(() {
        _registrationMode = true;
        _authError = null;
      });
    }
  }

  void _handleAuthServiceChange() {
    final resetVersion = widget.authService.loginAttemptsResetVersion;
    if (resetVersion == _loginAttemptsResetVersion) return;
    _loginAttemptsResetVersion = resetVersion;
    if (!mounted) return;
    setState(() {
      _failedLoginAttempts = 0;
      _authError = null;
    });
  }

  @override
  void dispose() {
    widget.authService.removeListener(_handleAuthServiceChange);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _authError = 'Por favor, preencha o e-mail e a senha.');
      return;
    }

    setState(() => _authError = null);
    try {
      await widget.authService.login(email, password);
      if (mounted) setState(() => _failedLoginAttempts = 0);
    } catch (error) {
      final failedAttempts = await widget.authService.loginFailedAttempts(
        email,
      );
      if (mounted) {
        setState(() {
          _failedLoginAttempts = failedAttempts;
          _authError = _friendlyAuthError(error);
        });
      }
    }
  }

  Future<void> _sendPasswordRecovery() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(
        () => _authError = 'Informe um e-mail válido para recuperar a senha.',
      );
      return;
    }

    setState(() {
      _sendingPasswordRecovery = true;
      _authError = null;
    });
    try {
      await widget.authService.sendPasswordRecoveryEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se houver uma conta com esse e-mail, você receberá um link para redefinir a senha.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _authError = _friendlyAuthError(error));
      }
    } finally {
      if (mounted) setState(() => _sendingPasswordRecovery = false);
    }
  }

  Future<void> _handleRegistration() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.length < 8) {
      setState(
        () => _authError =
            'Informe nome, e-mail e senha com pelo menos 8 caracteres.',
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _authError = 'As senhas não coincidem.');
      return;
    }

    setState(() => _authError = null);
    try {
      final result = await widget.authService.registerMember(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        accountType: _accountType,
      );
      if (!mounted) return;
      if (result == MemberRegistrationResult.authenticated) {
        final message =
            _accountType == 'membro' && widget.authService.isAwaitingApproval
            ? 'Cadastro concluído. Você já pode usar o app; o cartão de membro e os detalhes da agenda serão liberados após aprovação da administração.'
            : 'Cadastro concluído. Bem-vindo!';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() => _registrationMode = false);
        final message = _accountType == 'membro'
            ? 'Cadastro criado. Confirme o e-mail recebido; depois você poderá usar o app enquanto a administração analisa seu acesso de membro.'
            : 'Cadastro criado. Confirme o e-mail recebido para entrar no app.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: Duration(seconds: 6)),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _authError = _friendlyAuthError(error));
    }
  }

  String _friendlyAuthError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('database error saving new user')) {
        return 'Não foi possível concluir o cadastro por um problema no banco. '
            'Ajustamos a configuração; tente novamente. Se continuar, '
            'entre em contato com a administração.';
      }
      if (message.contains('email rate limit exceeded') ||
          (message.contains('rate limit') && message.contains('email'))) {
        return 'O serviço de e-mail atingiu o limite temporário de envios. '
            'Aguarde antes de tentar novamente e confira se já recebeu a '
            'confirmação. Se o problema continuar, a administração precisa '
            'configurar um servidor SMTP próprio no Supabase.';
      }
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _requestAccountDeletion(UserProfile member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solicitar exclusão da conta?'),
        content: const Text(
          'Seu aplicativo de e-mail será aberto com uma solicitação preenchida. '
          'Depois que você enviar a mensagem, a administração confirmará a '
          'solicitação e removerá a conta e os dados pessoais associados. '
          'Não inclua sua senha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final requestUri = buildAccountDeletionRequestUri(
      name: member.name,
      email: member.email,
      userId: member.id,
    );
    try {
      final opened = await launchUrl(
        requestUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showAccountDeletionEmailFallback();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível abrir o e-mail: $error. '
            'Envie a solicitação para $accountDeletionSupportEmail.',
          ),
        ),
      );
    }
  }

  void _showAccountDeletionEmailFallback() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi encontrado um aplicativo de e-mail. '
          'Solicite a exclusão escrevendo para '
          '$accountDeletionSupportEmail.',
        ),
        duration: Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, _) {
        final isAuthenticated = widget.authService.isAuthenticated;
        if (!isAuthenticated) {
          return Scaffold(
            appBar: AppBar(
              leading: AppNavigationMenuButton(
                onPressed: widget.onOpenDrawer,
                showBackButton: true,
                user: widget.authService.isAuthenticated
                    ? widget.authService.currentUser
                    : null,
              ),
              title: const Text('Seja bem-vindo'),
            ),
            body: _buildLoginView(),
          );
        }

        if (!widget.authService.hasApprovedMemberAccess) {
          return Scaffold(
            appBar: AppBar(
              leading: AppNavigationMenuButton(
                onPressed: widget.onOpenDrawer,
                showBackButton: true,
                user: widget.authService.currentUser,
              ),
              title: const Text('Área do membro'),
            ),
            body: _buildRestrictedAccessMessage(),
          );
        }

        return DefaultTabController(
          length: 1,
          child: Scaffold(
            appBar: AppBar(
              leading: AppNavigationMenuButton(
                onPressed: widget.onOpenDrawer,
                showBackButton: true,
                user: widget.authService.currentUser,
              ),
              title: const Text('Área do membro'),
              bottom: const TabBar(tabs: [Tab(text: 'Cartão do membro')]),
            ),
            body: TabBarView(children: [_buildMemberCardTab()]),
          ),
        );
      },
    );
  }

  Widget _buildLoginView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/church_logo.png',
                width: 82,
                height: 82,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                _registrationMode
                    ? 'Crie seu acesso ao app'
                    : 'Entrar no aplicativo',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entre ou crie um cadastro para acessar o app. O cartão de membro e os detalhes da agenda dependem da aprovação da administração.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569)),
              ),
              const SizedBox(height: 24),
              if (widget.authService.isAwaitingApproval) ...[
                Card(
                  color: const Color(0xFFFFF7E6),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          color: Color(0xFF9A5B00),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Você poderá entrar e usar os recursos básicos do app. O cartão de membro e os detalhes da agenda serão liberados após a aprovação da administração.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_registrationMode) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _accountType == 'membro'
                          ? 'Você poderá usar o app após entrar. O cartão de membro e os detalhes da agenda serão liberados depois da aprovação da administração.'
                          : 'O cadastro de visitante libera os recursos básicos e o mural de oração. O cartão de membro e os detalhes da agenda são exclusivos para membros aprovados.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _accountType,
                  decoration: const InputDecoration(
                    labelText: 'Quero me cadastrar como',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'membro',
                      child: Text('Membro da igreja'),
                    ),
                    DropdownMenuItem(
                      value: 'visitante',
                      child: Text('Visitante'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _accountType = value);
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (!supabaseInicializado)
                const Text(
                  'O login e o cadastro estão indisponíveis porque o Supabase não foi inicializado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9A5B00)),
                ),
              if (!supabaseInicializado && erroConfiguracaoSupabase != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    erroConfiguracaoSupabase!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
              if (_authError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _authError!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
              ],
              if (_registrationMode) ...[
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _phoneFocusNode.requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _emailFocusNode.requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (value) async {
                  final attempts = await widget.authService.loginFailedAttempts(
                    value,
                  );
                  if (mounted) setState(() => _failedLoginAttempts = attempts);
                },
                onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                textInputAction: _registrationMode
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) {
                  if (_registrationMode) {
                    _confirmPasswordFocusNode.requestFocus();
                  } else {
                    _handleLogin();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Senha (mínimo de 8 caracteres)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              if (_registrationMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegistration(),
                  decoration: const InputDecoration(
                    labelText: 'Confirme a senha',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    !supabaseInicializado ||
                        widget.authService.isLoading ||
                        (!_registrationMode && _failedLoginAttempts >= 3)
                    ? null
                    : (_registrationMode ? _handleRegistration : _handleLogin),
                icon: Icon(
                  _registrationMode
                      ? Icons.person_add_alt_rounded
                      : Icons.login_rounded,
                ),
                label: Text(
                  widget.authService.isLoading
                      ? 'Aguarde...'
                      : (_registrationMode ? 'Criar cadastro' : 'Entrar'),
                ),
              ),
              if (!_registrationMode && _failedLoginAttempts > 0)
                TextButton.icon(
                  onPressed: _sendingPasswordRecovery
                      ? null
                      : _sendPasswordRecovery,
                  icon: _sendingPasswordRecovery
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset_rounded),
                  label: Text(
                    _sendingPasswordRecovery
                        ? 'Enviando link...'
                        : 'Esqueci minha senha',
                  ),
                ),
              TextButton(
                onPressed: () => setState(() {
                  _registrationMode = !_registrationMode;
                  _accountType = 'membro';
                  _authError = null;
                }),
                child: Text(
                  _registrationMode
                      ? 'Já tenho cadastro. Entrar'
                      : 'Ainda não tenho cadastro. Cadastrar-me',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictedAccessMessage() {
    final user = widget.authService.currentUser;
    final isPending = widget.authService.isAwaitingApproval;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPending
                        ? Icons.hourglass_top_rounded
                        : Icons.lock_outline_rounded,
                    color: const Color(0xFF0F766E),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPending
                        ? 'Aguardando aprovação'
                        : 'Área exclusiva para membros',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPending
                        ? 'Olá, ${user?.displayName ?? 'membro'}. Seu cadastro já permite usar o app e participar do mural de oração. O cartão de membro e os detalhes e arquivos da agenda serão liberados quando a administração aprovar seu acesso.'
                        : 'Seu cadastro como visitante permite usar os recursos básicos do app. O cartão de membro e os detalhes e arquivos da agenda são liberados para membros após aprovação da administração.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCardTab() {
    final member = widget.authService.currentUser;
    if (member == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0A2540), Color(0xFF0F766E)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            _buildMemberAvatar(member, 30),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: IconButton(
                                onPressed: _uploadingPhoto
                                    ? null
                                    : _pickMemberPhoto,
                                tooltip: 'Alterar foto do cartão',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0F766E),
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                ),
                                icon: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt, size: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CARTÃO DE MEMBRO',
                                style: TextStyle(
                                  color: Color(0xFFD5F5EF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Image.asset(
                                'assets/church_logo.png',
                                width: 38,
                                height: 38,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                member.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFD5F5EF),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _memberCardField(
                          'Matrícula',
                          member.membershipNumber ?? 'Em emissão',
                        ),
                        _memberCardField('E-mail', member.email),
                        _memberCardField(
                          'Telefone',
                          member.phone.isEmpty ? 'Não informado' : member.phone,
                        ),
                        _memberCardField('Congregação', member.congregation),
                        _memberCardField(
                          'Batismo',
                          formatMemberDate(member.baptismDate),
                        ),
                        _memberCardField(
                          'Nascimento',
                          formatMemberDate(member.birthDate),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Meus departamentos',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (member.departments.isEmpty)
                          Text(
                            'Nenhum departamento informado no cadastro.',
                            style: TextStyle(color: Colors.grey.shade600),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: member.departments
                                .map(
                                  (department) => Chip(
                                    avatar: const Icon(
                                      Icons.groups_rounded,
                                      size: 17,
                                    ),
                                    label: Text(department),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _editMemberProfile,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar meus dados'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => _requestAccountDeletion(member),
                            icon: const Icon(
                              Icons.person_remove_alt_1_outlined,
                              color: Color(0xFFB42318),
                            ),
                            label: const Text(
                              'Solicitar exclusão da conta',
                              style: TextStyle(color: Color(0xFFB42318)),
                            ),
                          ),
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
    );
  }

  Widget _buildMemberAvatar(UserProfile member, double radius) {
    final photoUrl = member.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitialAvatar(member.initials, radius),
        ),
      );
    }
    return _buildInitialAvatar(member.initials, radius);
  }

  Widget _buildInitialAvatar(String initials, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF0F766E),
          fontSize: radius * 0.63,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _pickMemberPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final extension = image.name.split('.').last.toLowerCase();
      const supportedTypes = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      };
      final contentType = supportedTypes[extension];
      if (contentType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escolha uma foto nos formatos JPG, PNG ou WEBP.'),
          ),
        );
        return;
      }

      setState(() => _uploadingPhoto = true);
      await widget.authService.updateMemberPhoto(
        bytes: await image.readAsBytes(),
        contentType: contentType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto do cartão atualizada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final errorDetails = error.toString();
        final message =
            errorDetails.contains('statusCode: 403') ||
                errorDetails.contains('row-level security policy')
            ? 'Não foi possível atualizar a foto. Saia e entre novamente com a conta autorizada; se persistir, peça à administração para conferir o acesso deste membro.'
            : 'Não foi possível atualizar a foto: $error';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _memberCardField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMemberProfile() async {
    final member = widget.authService.currentUser;
    if (member == null) return;
    late final List<Department> departments;
    try {
      departments = await ContentService.listDepartments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar os departamentos: $error'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: member.name);
    final nicknameController = TextEditingController(
      text: member.nickname ?? '',
    );
    final phoneController = TextEditingController(text: member.phone);
    final congregationController = TextEditingController(
      text: member.congregation,
    );
    final baptismController = TextEditingController(
      text: member.baptismDate ?? '',
    );
    final birthController = TextEditingController(text: member.birthDate ?? '');
    final selectedDepartments = member.departments.toSet();
    final departmentOptions = {
      ...departments.map((department) => department.displayName),
      ...selectedDepartments,
    }.toList()..sort();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: const Text('Editar dados do membro'),
            content: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width < 640
                  ? MediaQuery.sizeOf(dialogContext).width * 0.8
                  : 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Informe seu nome.'
                            : null,
                      ),
                      TextFormField(
                        controller: nicknameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Apelido / como gosta de ser chamado',
                          hintText: 'Ex.: Ir. Guto',
                        ),
                      ),
                      TextFormField(
                        initialValue: member.email,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                        ),
                      ),
                      TextFormField(
                        controller: congregationController,
                        decoration: const InputDecoration(
                          labelText: 'Congregação',
                        ),
                      ),
                      TextFormField(
                        controller: baptismController,
                        decoration: const InputDecoration(
                          labelText: 'Data de batismo',
                        ),
                      ),
                      TextFormField(
                        controller: birthController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: dialogContext,
                            initialDate:
                                DateTime.tryParse(birthController.text) ??
                                DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (selected != null) {
                            birthController.text =
                                '${selected.year.toString().padLeft(4, '0')}-'
                                '${selected.month.toString().padLeft(2, '0')}-'
                                '${selected.day.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Departamentos em que serve',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (departmentOptions.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Nenhum departamento cadastrado.'),
                        )
                      else
                        ...departmentOptions.map(
                          (department) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(department),
                            value: selectedDepartments.contains(department),
                            onChanged: (selected) => updateDialog(() {
                              if (selected == true) {
                                selectedDepartments.add(department);
                              } else {
                                selectedDepartments.remove(department);
                              }
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await widget.authService.updateMemberProfile(
                      name: nameController.text,
                      nickname: nicknameController.text,
                      phone: phoneController.text,
                      congregation: congregationController.text,
                      baptismDate: baptismController.text,
                      birthDate: birthController.text,
                      department: departmentOptions
                          .where(selectedDepartments.contains)
                          .join('; '),
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Não foi possível salvar: $error'),
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados cadastrais atualizados.')),
        );
      }
    } finally {
      nameController.dispose();
      nicknameController.dispose();
      phoneController.dispose();
      congregationController.dispose();
      baptismController.dispose();
      birthController.dispose();
    }
  }
}
