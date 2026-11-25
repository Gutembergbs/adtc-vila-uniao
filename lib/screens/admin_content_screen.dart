import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../configuracao_supabase.dart';
import '../models/announcement.dart';
import '../models/department.dart';
import '../models/department_assignment.dart';
import '../models/member_record.dart';
import '../models/pedido_oracao.dart';
import '../models/scale_item.dart';
import '../models/schedule_event.dart';
import 'admin_department_details_screen.dart';
import 'admin_member_details_screen.dart';
import '../services/content_service.dart';
import '../services/church_share_service.dart';
import '../services/servico_pedidos_oracao.dart';
import '../services/auth_service.dart';
import '../widgets/app_navigation_actions.dart';
import 'department_member_map_screen.dart';

/// Área administrativa protegida pelo Supabase Auth e pelas políticas RLS.
class AdminContentScreen extends StatefulWidget {
  final int initialTab;
  final AuthService? authService;

  const AdminContentScreen({super.key, this.initialTab = 0, this.authService});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  List<Department> _departments = [];
  List<ScheduleEvent> _events = [];
  final List<ScaleItem> _scales = [];
  final List<Announcement> _announcements = [];
  List<Announcement> _customNotifications = [];
  List<PedidoOracao> _prayerRequests = [];
  List<MemberRecord> _members = [];
  List<Map<String, dynamic>> _visitors = [];
  List<DepartmentAssignment> _departmentAssignments = [];
  DateTime _selectedAgendaDate = DateTime.now();
  List<int> _overviewCardOrder = [1, 2, 3, 4];
  String _prayerCategoryFilter = 'Todos';
  String _prayerAuthorFilter = 'Todos';
  bool _checkingAccess = true;
  bool _isAdmin = false;
  bool _loadingContent = false;
  bool _showPrayerFilters = false;
  bool _savingDepartmentOrder = false;
  bool _sendingPasswordRecovery = false;
  bool? _realtimeConnected;
  int _membersTabIndex = 0;
  int _failedLoginAttempts = 0;
  String? _errorMessage;
  String? _realtimeError;
  RealtimeChannel? _adminRealtimeChannel;
  Timer? _realtimeRefreshTimer;

  static const _icons = <IconData>[
    Icons.church_rounded,
    Icons.groups_rounded,
    Icons.menu_book_rounded,
    Icons.volunteer_activism_rounded,
    Icons.music_note_rounded,
    Icons.public_rounded,
    Icons.wb_sunny_rounded,
    Icons.favorite_rounded,
    Icons.camera_alt_rounded,
    Icons.child_care_rounded,
    Icons.emoji_people_rounded,
    Icons.local_fire_department_rounded,
    Icons.shield_rounded,
    Icons.home_rounded,
    Icons.person_add_alt_1_rounded,
    Icons.access_time_filled_rounded,
    Icons.auto_stories_rounded,
    Icons.apartment_rounded,
    Icons.wine_bar_rounded,
    Icons.family_restroom_rounded,
    Icons.event_rounded,
    Icons.event_available_rounded,
    Icons.calendar_month_rounded,
    Icons.school_rounded,
    Icons.lightbulb_rounded,
    Icons.handshake_rounded,
    Icons.mic_rounded,
    Icons.headphones_rounded,
    Icons.spa_rounded,
    Icons.savings_rounded,
    Icons.restaurant_rounded,
    Icons.water_drop_rounded,
    Icons.health_and_safety_rounded,
    Icons.directions_car_rounded,
    Icons.emoji_events_rounded,
    Icons.star_rounded,
    Icons.bolt_rounded,
  ];

  static const _colors = <Color>[
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFF0891B2),
    Color(0xFF0284C7),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF9333EA),
    Color(0xFFBE185D),
    Color(0xFFDB2777),
    Color(0xFFDC2626),
    Color(0xFFB42318),
    Color(0xFFEA580C),
    Color(0xFFB45309),
    Color(0xFFD97706),
    Color(0xFFCA8A04),
    Color(0xFF65A30D),
    Color(0xFF15803D),
    Color(0xFF059669),
    Color(0xFF334155),
    Color(0xFF475569),
    Color(0xFF854D0E),
    Color(0xFF7F1D1D),
    Color(0xFF1E3A8A),
    Color(0xFF312E81),
  ];

  static const _weekdays = <int, String>{
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
    7: 'Domingo',
  };

  static const _announcementCategories = [
    'Aviso Geral',
    'Escala',
    'Liderança',
    'Pastoral',
    'Santa Ceia',
    'Oração',
    'DENOC',
  ];

  int get _pendingMemberAccessCount =>
      _members.where((member) => member.accessStatus == 'pendente').length;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOverviewCardOrder());
    _checkSavedSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _realtimeRefreshTimer?.cancel();
    final channel = _adminRealtimeChannel;
    if (channel != null && supabaseInicializado) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _loadOverviewCardOrder() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedOrder = preferences
          .getStringList('admin_overview_card_order')
          ?.map(int.tryParse)
          .whereType<int>()
          .toList();
      if (!mounted || savedOrder == null) return;
      const cardIds = {1, 2, 3, 4};
      if (savedOrder.length != cardIds.length ||
          savedOrder.toSet().length != cardIds.length ||
          !savedOrder.toSet().containsAll(cardIds)) {
        return;
      }
      setState(() => _overviewCardOrder = savedOrder);
    } catch (error) {
      _showError('Não foi possível carregar a ordem dos cards: $error');
    }
  }

  Future<void> _reorderOverviewCards(int draggedId, int targetId) async {
    if (draggedId == targetId) return;
    final targetIndex = _overviewCardOrder.indexOf(targetId);
    final draggedIndex = _overviewCardOrder.indexOf(draggedId);
    if (targetIndex == -1 || draggedIndex == -1) return;
    final reordered = List<int>.from(_overviewCardOrder)..remove(draggedId);
    reordered.insert(
      targetIndex - (draggedIndex < targetIndex ? 1 : 0),
      draggedId,
    );
    setState(() => _overviewCardOrder = reordered);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        'admin_overview_card_order',
        reordered.map((id) => id.toString()).toList(),
      );
    } catch (error) {
      _showError('Não foi possível salvar a ordem dos cards: $error');
    }
  }

  /// Reutiliza uma sessão Supabase salva, mas nunca confia no perfil local.
  Future<void> _checkSavedSession() async {
    if (!supabaseInicializado) {
      setState(() {
        _checkingAccess = false;
        _errorMessage =
            erroConfiguracaoSupabase ?? 'Não foi possível acessar o Supabase.';
      });
      return;
    }

    final usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) {
      setState(() => _checkingAccess = false);
      return;
    }
    await _checkAdministratorPermission(usuario.id);
  }

  /// Confere a permissão no banco antes de mostrar as ferramentas de edição.
  Future<void> _checkAdministratorPermission(String userId) async {
    try {
      final cadastro = await Supabase.instance.client
          .from('administradores')
          .select('usuario_id')
          .eq('usuario_id', userId)
          .maybeSingle();
      if (!mounted) return;

      if (cadastro == null) {
        await Supabase.instance.client.auth.signOut();
        setState(() {
          _checkingAccess = false;
          _isAdmin = false;
          _errorMessage = 'Esta conta não está cadastrada como administradora.';
        });
        return;
      }

      setState(() {
        _checkingAccess = false;
        _isAdmin = true;
        _errorMessage = null;
      });
      await _loadContent();
      _subscribeToAdminChanges();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingAccess = false;
        _isAdmin = false;
        _errorMessage =
            'Não foi possível verificar a permissão administrativa.';
      });
    }
  }

  /// Autentica pela conta Supabase e valida a associação administrativa.
  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _checkingAccess = true;
      _errorMessage = null;
    });

    try {
      final resposta = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final usuario = resposta.user;
      if (usuario == null) throw StateError('Usuário não encontrado.');
      _failedLoginAttempts = 0;
      await _checkAdministratorPermission(usuario.id);
    } on AuthException catch (erro) {
      if (!mounted) return;
      setState(() {
        _failedLoginAttempts++;
        _checkingAccess = false;
        _errorMessage = erro.message;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _checkingAccess = false;
        _errorMessage = 'Não foi possível entrar: $erro';
      });
    }
  }

  Future<void> _sendPasswordRecovery() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Informe um e-mail válido.');
      return;
    }

    setState(() {
      _sendingPasswordRecovery = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'adtc-vila-uniao://reset-password',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se houver uma conta com esse e-mail, você receberá um link para redefinir a senha.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Não foi possível enviar o link: $error');
    } finally {
      if (mounted) setState(() => _sendingPasswordRecovery = false);
    }
  }

  /// Atualiza todas as listas após login, gravação ou exclusão.
  Future<void> _loadContent({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      _loadingContent = showLoading;
      _errorMessage = null;
    });
    try {
      final departments = await ContentService.listDepartments();
      final events = await ContentService.listScheduleEvents();
      final prayerRequests = await ServicoPedidosOracao.listarPedidosAdmin();
      final members = await ContentService.listMembers();
      final visitors = await ContentService.listVisitors();
      final departmentAssignments =
          await ContentService.listDepartmentAssignments();
      final customNotifications = await ContentService.listAdminNotifications();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _events = events;
        _prayerRequests = prayerRequests;
        _members = members;
        _visitors = visitors;
        _departmentAssignments = departmentAssignments;
        _customNotifications = customNotifications;
        _loadingContent = false;
      });
    } catch (erro) {
      if (!mounted) return;
      final message = 'Não foi possível carregar o conteúdo: $erro';
      setState(() {
        _loadingContent = false;
        _errorMessage = message;
      });
      _showError(message);
    }
  }

  void _subscribeToAdminChanges() {
    if (!supabaseInicializado || _adminRealtimeChannel != null) return;

    _adminRealtimeChannel = Supabase.instance.client
        .channel('admin-content-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eventos_agenda',
          callback: _onAdminDataChanged,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedidos_oracao',
          callback: _onAdminDataChanged,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'membros',
          callback: _onAdminDataChanged,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'visitantes',
          callback: _onAdminDataChanged,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificacoes',
          callback: _onAdminDataChanged,
        )
        .subscribe((status, error) {
          if (!mounted) return;
          setState(() {
            _realtimeConnected = status == RealtimeSubscribeStatus.subscribed;
            _realtimeError = error?.toString();
          });
        });
  }

  void _onAdminDataChanged(PostgresChangePayload _) {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadContent(showLoading: false));
    });
  }

  /// Carrega exemplos só nas tabelas vazias, sem substituir conteúdo existente.
  Future<void> _importExamples() async {
    try {
      final tabelasImportadas =
          await ContentService.importEmptyTablesWithExamples();
      await _loadContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tabelasImportadas == 0
                ? 'As tabelas já possuem conteúdo.'
                : 'Conteúdo inicial carregado em $tabelasImportadas tabela(s).',
          ),
        ),
      );
    } catch (erro) {
      _showError('Não foi possível importar os exemplos: $erro');
    }
  }

  /// Encerra somente a sessão administrativa do Supabase.
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    _realtimeRefreshTimer?.cancel();
    final channel = _adminRealtimeChannel;
    _adminRealtimeChannel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    setState(() {
      _isAdmin = false;
      _realtimeConnected = null;
      _realtimeError = null;
      _departments = [];
      _events = [];
      _prayerRequests = [];
      _members = [];
      _departmentAssignments = [];
      _errorMessage = null;
    });
  }

  /// Exibe falhas de operação sem ocultar a tela que o admin está editando.
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB42318),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!supabaseInicializado) return _buildLoginScreen();
    if (!_isAdmin) return _buildLoginScreen();

    return DefaultTabController(
      length: 6,
      initialIndex: widget.initialTab.clamp(0, 5),
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return AnimatedBuilder(
            animation: tabController,
            builder: (context, _) => PopScope<void>(
              canPop: tabController.index == 0,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && tabController.index != 0) {
                  tabController.animateTo(0);
                }
              },
              child: Scaffold(
                appBar: AppBar(
                  leading: AppNavigationMenuButton(
                    tooltip: tabController.index == 0
                        ? 'Voltar ao aplicativo'
                        : 'Voltar à visão geral',
                    user: widget.authService?.currentUser,
                    showBackButton: true,
                    onPressed: () {
                      if (tabController.index != 0) {
                        tabController.animateTo(0);
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  title: const Text('Gerenciar conteúdo'),
                  actions: [
                    if (_isAdmin) _buildRealtimeStatus(),
                    IconButton(
                      tooltip: 'Sair da administração',
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                  bottom: TabBar(
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Color(0xFFB7C9D6),
                    indicatorColor: Color(0xFFF59E0B),
                    indicatorWeight: 3,
                    tabs: [
                      const Tab(text: 'Visão geral'),
                      const Tab(text: 'Departamentos'),
                      const Tab(text: 'Agenda'),
                      Tab(
                        text: _pendingMemberAccessCount == 0
                            ? 'Membros'
                            : 'Membros ($_pendingMemberAccessCount)',
                      ),
                      const Tab(text: 'Pedidos de oração'),
                      const Tab(text: 'Notificações'),
                    ],
                  ),
                ),
                body: Stack(
                  children: [
                    TabBarView(
                      children: [
                        _buildAdminOverview(tabController),
                        _responsivePanel(_buildDepartmentsTab()),
                        _responsivePanel(_buildEventsTab()),
                        _buildMembersTab(),
                        _responsivePanel(_buildPrayerRequestsTab()),
                        _responsivePanel(_buildCustomNotificationsTab()),
                      ],
                    ),
                    if (_loadingContent)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withAlpha(210),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Evita listas excessivamente largas em monitores e mantém a largura móvel.
  Widget _responsivePanel(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: child,
      ),
    );
  }

  Widget _buildRealtimeStatus() {
    final connected = _realtimeConnected == true;
    final connecting = _realtimeConnected == null;
    final color = connected
        ? const Color(0xFF86EFAC)
        : connecting
        ? const Color(0xFFFCD34D)
        : const Color(0xFFFCA5A5);
    final label = connected
        ? 'Realtime conectado'
        : connecting
        ? 'Conectando Realtime'
        : 'Realtime desconectado';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: _realtimeError == null ? label : '$label: $_realtimeError',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: color,
              size: 18,
            ),
            if (MediaQuery.sizeOf(context).width >= 700) ...[
              const SizedBox(width: 6),
              Text(
                connected
                    ? 'Realtime'
                    : (connecting ? 'Conectando' : 'Offline'),
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Resume o conteúdo e oferece atalhos para as ferramentas de administração.
  Widget _buildAdminOverview(TabController tabController) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 28.0;
        final contentWidth =
            (constraints.maxWidth.clamp(0.0, 1180.0) - horizontalPadding * 2)
                .clamp(0.0, 1180.0);
        final columns = contentWidth >= 900 ? 4 : 2;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: RefreshIndicator(
              onRefresh: () => _loadContent(showLoading: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(horizontalPadding),
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      constraints.maxWidth < 600 ? 18 : 26,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10324A), Color(0xFF1E5570)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(24),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFFF2B544),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Painel da congregação',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Acesse rapidamente o conteúdo e as ferramentas administrativas.',
                                style: TextStyle(color: Color(0xFFD7E2E9)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Resumo e atalhos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _overviewCardOrder.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: constraints.maxWidth < 600 ? 150 : 210,
                    ),
                    itemBuilder: (context, index) {
                      final cardId = _overviewCardOrder[index];
                      return _buildDraggableOverviewCard(
                        cardId: cardId,
                        tabController: tabController,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Toque em um card para abrir a área ou arraste para reorganizar.',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Administra a visibilidade e a remoção dos pedidos enviados ao mural.
  Widget _buildPrayerRequestsTab() {
    final requests = _prayerRequests.where((request) {
      final matchesCategory =
          _prayerCategoryFilter == 'Todos' ||
          request.categoria == _prayerCategoryFilter;
      final matchesAuthor = switch (_prayerAuthorFilter) {
        'Anônimos' => request.anonimo,
        'Com nome' => !request.anonimo,
        _ => true,
      };
      return matchesCategory && matchesAuthor;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pedidos recebidos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: _showPrayerFilters
                    ? 'Ocultar filtros'
                    : 'Mostrar filtros',
                onPressed: () =>
                    setState(() => _showPrayerFilters = !_showPrayerFilters),
                icon: Badge(
                  isLabelVisible:
                      _prayerCategoryFilter != 'Todos' ||
                      _prayerAuthorFilter != 'Todos',
                  child: Icon(
                    _showPrayerFilters
                        ? Icons.filter_list_off_rounded
                        : Icons.filter_list_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showPrayerFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar pedidos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final category in [
                      'Todos',
                      'Família',
                      'Saúde',
                      'Emprego',
                      'Espiritual',
                      'Gratidão',
                      'Outros',
                    ])
                      ChoiceChip(
                        label: Text(category),
                        selected: _prayerCategoryFilter == category,
                        onSelected: (_) =>
                            setState(() => _prayerCategoryFilter = category),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final authorFilter in [
                      'Todos',
                      'Anônimos',
                      'Com nome',
                    ])
                      ChoiceChip(
                        label: Text(authorFilter),
                        selected: _prayerAuthorFilter == authorFilter,
                        onSelected: (_) =>
                            setState(() => _prayerAuthorFilter = authorFilter),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '“Com nome” não confirma vínculo de membro; o mural não associa pedidos a contas.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadContent(showLoading: false),
            child: requests.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 140),
                      Center(child: Text('Nenhum pedido encontrado.')),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: request.oculto
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFFFCE7F3),
                                  child: Icon(
                                    request.anonimo
                                        ? Icons.visibility_off_outlined
                                        : Icons.person_outline_rounded,
                                    color: request.oculto
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFFBE185D),
                                  ),
                                ),
                                title: Text(
                                  request.anonimo
                                      ? 'Pedido anônimo'
                                      : request.nomeAutor,
                                ),
                                subtitle: Text(
                                  '${request.categoria} • ${DateFormat('dd/MM/yyyy').format(request.dataCriacao.toLocal())} • ${request.oculto ? 'Oculto' : 'Visível'}',
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(request.pedido),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _setPrayerRequestHidden(
                                      request,
                                      !request.oculto,
                                    ),
                                    icon: Icon(
                                      request.oculto
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                    ),
                                    label: Text(
                                      request.oculto ? 'Mostrar' : 'Ocultar',
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _deletePrayerRequest(request),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    label: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _setPrayerRequestHidden(
    PedidoOracao request,
    bool hidden,
  ) async {
    try {
      await ServicoPedidosOracao.definirOculto(
        identificador: request.identificador,
        oculto: hidden,
      );
      if (!mounted) return;
      setState(() {
        final index = _prayerRequests.indexWhere(
          (item) => item.identificador == request.identificador,
        );
        if (index != -1) {
          _prayerRequests[index] = request.copyWith(oculto: hidden);
        }
      });
    } catch (error) {
      _showError(
        'Não foi possível ${hidden ? 'ocultar' : 'mostrar'} o pedido: $error',
      );
    }
  }

  Future<void> _deletePrayerRequest(PedidoOracao request) async {
    if (!await _confirmDelete(
      'pedido de ${request.anonimo ? 'autor anônimo' : request.nomeAutor}',
    )) {
      return;
    }
    try {
      await ServicoPedidosOracao.excluirPedido(request.identificador);
      if (!mounted) return;
      setState(
        () => _prayerRequests.removeWhere(
          (item) => item.identificador == request.identificador,
        ),
      );
    } catch (error) {
      _showError('Não foi possível excluir o pedido: $error');
    }
  }

  /// Card clicável que resume uma área e abre sua aba de gerenciamento.
  Widget _overviewCountCard({
    required TabController tabController,
    required int tabIndex,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
    required Widget dragHandle,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          if (tabController.index != tabIndex) {
            tabController.animateTo(tabIndex);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withAlpha(24),
                    foregroundColor: color,
                    radius: 17,
                    child: Icon(icon),
                  ),
                  const Spacer(),
                  dragHandle,
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableOverviewCard({
    required int cardId,
    required TabController tabController,
  }) {
    final dragHandle = LongPressDraggable<int>(
      data: cardId,
      feedback: Material(
        color: Colors.transparent,
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 28,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      childWhenDragging: const SizedBox(
        width: 28,
        height: 36,
        child: Icon(Icons.drag_indicator_rounded, color: Colors.black26),
      ),
      child: const SizedBox(
        width: 28,
        height: 36,
        child: Icon(Icons.drag_indicator_rounded),
      ),
    );
    final card = switch (cardId) {
      1 => _overviewCountCard(
        tabController: tabController,
        tabIndex: 1,
        label: 'Departamentos',
        count: _departments.length,
        icon: Icons.groups_rounded,
        color: const Color(0xFF0F766E),
        subtitle: 'Ministérios e equipes',
        dragHandle: dragHandle,
      ),
      2 => _overviewCountCard(
        tabController: tabController,
        tabIndex: 2,
        label: 'Agenda',
        count: _events.length,
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2563EB),
        subtitle: 'Cultos e programações',
        dragHandle: dragHandle,
      ),
      3 => _overviewCountCard(
        tabController: tabController,
        tabIndex: 3,
        label: 'Membros',
        count: _members.length,
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF0891B2),
        subtitle: 'Pré-cadastros e equipes',
        dragHandle: dragHandle,
      ),
      _ => _overviewCountCard(
        tabController: tabController,
        tabIndex: 4,
        label: 'Pedidos de oração',
        count: _prayerRequests.length,
        icon: Icons.volunteer_activism_rounded,
        color: const Color(0xFFDB2777),
        subtitle: 'Revisar, ocultar ou excluir',
        dragHandle: dragHandle,
      ),
    };

    return DragTarget<int>(
      onAcceptWithDetails: (details) =>
          _reorderOverviewCards(details.data, cardId),
      builder: (context, candidates, rejected) => card,
    );
  }

  /// Apresenta login por e-mail e senha do Supabase Auth.
  Widget _buildLoginScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso administrativo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _loginFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 48,
                    color: Color(0xFF0F766E),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Entrar como administrador',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Informe um e-mail válido.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha do Supabase',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Informe a senha.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: supabaseInicializado ? _login : null,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Entrar'),
                  ),
                  if (_failedLoginAttempts >= 3)
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mostra os departamentos e os comandos de edição correspondentes.
  Widget _buildDepartmentsTab() {
    return Column(
      children: [
        _buildImportButton(),
        if (_departments.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Segure e arraste para alterar a ordem.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: _departments.isEmpty
              ? const Center(child: Text('Nenhum departamento cadastrado.'))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _departments.length,
                  onReorderItem: _reorderDepartments,
                  itemBuilder: (context, index) {
                    final department = _departments[index];
                    return Card(
                      key: ValueKey(department.id),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showDepartmentDetails(department),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    backgroundColor: department.color.withAlpha(
                                      25,
                                    ),
                                    child: Icon(
                                      department.icon,
                                      color: department.color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          department.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          department.conjuntoName ??
                                              department.leaderName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey.shade500,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _editDepartment(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar departamento'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _reorderDepartments(int oldIndex, int newIndex) async {
    if (_savingDepartmentOrder) return;

    final previousOrder = List<Department>.from(_departments);
    final reordered = List<Department>.from(_departments);
    final department = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, department);
    final orderedDepartments = [
      for (var index = 0; index < reordered.length; index++)
        reordered[index].copyWith(order: index),
    ];

    setState(() {
      _departments = orderedDepartments;
      _savingDepartmentOrder = true;
    });

    try {
      await ContentService.reorderDepartments(
        orderedDepartments.map((department) => department.id).toList(),
      );
      if (!mounted) return;
      final savedDepartments = await ContentService.listDepartments();
      final savedIds = savedDepartments.map((department) => department.id);
      final expectedIds = orderedDepartments.map((department) => department.id);
      if (savedIds.length != expectedIds.length ||
          List.generate(
            orderedDepartments.length,
            (index) =>
                savedDepartments[index].id != orderedDepartments[index].id,
          ).any((isDifferent) => isDifferent)) {
        throw StateError(
          'A ordem retornada pelo banco não corresponde à ordem solicitada.',
        );
      }
      if (!mounted) return;
      setState(() => _departments = savedDepartments);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem dos departamentos atualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _departments = previousOrder);
      _showError('Não foi possível salvar a ordem dos departamentos: $error');
    } finally {
      if (mounted) setState(() => _savingDepartmentOrder = false);
    }
  }

  /// Calendário administrativo para selecionar o dia de criação/edição.
  Widget _buildEventsTab() {
    final dailyEvents = _eventsForDate(_selectedAgendaDate);
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final selectedDateLabel = DateFormat(
      'dd/MM/yyyy',
    ).format(_selectedAgendaDate);

    Widget calendar() => Card(
      margin: const EdgeInsets.all(8),
      child: CalendarDatePicker(
        initialDate: _selectedAgendaDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        onDateChanged: (date) => setState(() => _selectedAgendaDate = date),
      ),
    );

    Widget eventCard(ScheduleEvent event) => Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _showAdminEventDetails(event),
        leading: CircleAvatar(
          backgroundColor: event.color.withAlpha(25),
          child: Icon(event.icon, color: event.color),
        ),
        title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${event.time} • ${DateFormat('dd/MM/yyyy').format(event.eventDate ?? _selectedAgendaDate)}'
          '${event.attachmentName == null ? '' : ' • Anexo: ${event.attachmentName}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );

    Widget selectedDayEvents({required bool scrollable}) {
      final children = <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            'Eventos em $selectedDateLabel',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (dailyEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Nenhum evento em $selectedDateLabel.'),
          )
        else
          ...dailyEvents.map(eventCard),
      ];
      if (!scrollable) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }
      return RefreshIndicator(
        onRefresh: () => _loadContent(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: children,
        ),
      );
    }

    return Column(
      children: [
        _buildImportButton(),
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 360, child: calendar()),
                    const VerticalDivider(width: 1),
                    Expanded(child: selectedDayEvents(scrollable: true)),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: () => _loadContent(showLoading: false),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: 340, child: calendar()),
                        selectedDayEvents(scrollable: false),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _buildAddAgendaEventButton(),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        if (wide)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildAddAgendaEventButton(),
          ),
      ],
    );
  }

  Widget _buildAddAgendaEventButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: () => _editEvent(null, date: _selectedAgendaDate),
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'Adicionar evento em ${DateFormat('dd/MM').format(_selectedAgendaDate)}',
      ),
    ),
  );

  Future<void> _showAdminEventDetails(ScheduleEvent event) async {
    final eventDate = event.eventDate ?? _selectedAgendaDate;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(event.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.subtitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _adminEventDetailRow(
                  Icons.calendar_month_outlined,
                  'Data',
                  DateFormat('dd/MM/yyyy').format(eventDate),
                ),
                _adminEventDetailRow(
                  Icons.schedule_outlined,
                  'Horário',
                  event.time,
                ),
                _adminEventDetailRow(
                  Icons.location_on_outlined,
                  'Local',
                  event.location,
                ),
                if (event.recurringCycle?.isNotEmpty == true)
                  _adminEventDetailRow(
                    Icons.repeat_rounded,
                    'Repetição',
                    event.recurringCycle!,
                  ),
                if (event.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Informações',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(event.notes),
                ],
                if (event.attachmentName?.isNotEmpty == true)
                  _adminEventDetailRow(
                    Icons.attach_file_rounded,
                    'Anexo',
                    event.attachmentName!,
                  ),
                if (event.linkUrl?.isNotEmpty == true)
                  _adminEventDetailRow(
                    Icons.link_rounded,
                    event.linkText?.trim().isNotEmpty == true
                        ? event.linkText!
                        : 'Link',
                    event.linkUrl!,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _editEvent(event, copyAsNew: true, date: _selectedAgendaDate);
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _notifyEvent(event);
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Notificar'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _editEvent(event);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteEvent(event);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Widget _adminEventDetailRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: const Color(0xFF0F766E)),
            const SizedBox(width: 10),
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  List<ScheduleEvent> _eventsForDate(DateTime date) {
    return _events.where((event) {
      final eventDate = event.eventDate;
      if (eventDate != null) {
        return eventDate.year == date.year &&
            eventDate.month == date.month &&
            eventDate.day == date.day;
      }
      if (event.monthlyTheme) {
        if (date.weekday != DateTime.sunday) return false;
        final cycle = event.recurringCycle;
        final ordinal = cycle == null || cycle.isEmpty
            ? null
            : int.tryParse(cycle.substring(0, 1));
        return ordinal == null || ((date.day - 1) ~/ 7) + 1 == ordinal;
      }
      return event.matchesDay(date.weekday);
    }).toList()..sort(ScheduleEvent.compareByTime);
  }

  /// Lista as escalas internas e apresenta acesso às ações administrativas.
  // ignore: unused_element
  Widget _buildScalesTab() {
    return Column(
      children: [
        _buildImportButton(),
        Expanded(
          child: _scales.isEmpty
              ? const Center(child: Text('Nenhuma escala cadastrada.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _scales.length,
                  itemBuilder: (context, index) {
                    final scale = _scales[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE5F3F0),
                          child: Icon(
                            Icons.event_available_rounded,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        title: Text(scale.department),
                        subtitle: Text(
                          '${scale.serviceName} • ${scale.date} às ${scale.time}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _buildRowActions(
                          onEdit: () => _editScale(scale),
                          onDelete: () => _deleteScale(scale),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _editScale(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar escala'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomNotificationsTab() {
    return RefreshIndicator(
      onRefresh: () => _loadContent(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Crie comunicados para todos os membros ativos. Ao notificar, '
                'o aviso fica salvo na caixa de entrada e também é enviado '
                'aos aparelhos com notificações habilitadas.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _editCustomNotification(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar notificação'),
          ),
          const SizedBox(height: 8),
          if (_customNotifications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Nenhuma notificação personalizada cadastrada.'),
              ),
            )
          else
            ..._customNotifications.map(
              (notification) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notification.notificationSent
                        ? const Color(0xFFE0F2FE)
                        : const Color(0xFFFFF3D6),
                    child: Icon(
                      notification.notificationSent
                          ? Icons.notifications_active_outlined
                          : Icons.drafts_outlined,
                      color: notification.notificationSent
                          ? const Color(0xFF0369A1)
                          : const Color(0xFF9A5B00),
                    ),
                  ),
                  title: Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${notification.category} • '
                    '${notification.notificationSent ? 'Notificada' : 'Rascunho'}\n'
                    '${notification.summary.isEmpty ? notification.content : notification.summary}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: _buildRowActions(
                    onNotify: () => _notifyCustomNotification(notification),
                    onEdit: () => _editCustomNotification(notification),
                    onDelete: () => _deleteCustomNotification(notification),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editCustomNotification(Announcement? existing) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: existing?.title ?? '');
    final summaryController = TextEditingController(
      text: existing?.summary ?? '',
    );
    final contentController = TextEditingController(
      text: existing?.content ?? '',
    );
    var category = _announcementCategories.contains(existing?.category)
        ? existing!.category
        : _announcementCategories.first;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              existing == null
                  ? 'Nova notificação personalizada'
                  : 'Editar notificação',
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width < 640
                  ? MediaQuery.sizeOf(dialogContext).width * 0.8
                  : 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _textField(
                        titleController,
                        'Título',
                        requiredField: true,
                      ),
                      _textField(summaryController, 'Resumo'),
                      _textField(
                        contentController,
                        'Mensagem',
                        multiline: true,
                        requiredField: true,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                        items: _announcementCategories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => category = value);
                          }
                        },
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
                    await ContentService.saveCustomNotification(
                      id: existing?.notificationId,
                      title: titleController.text,
                      summary: summaryController.text,
                      content: contentController.text,
                      category: category,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (error) {
                    _showError('Não foi possível salvar a notificação: $error');
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      );
      if (saved == true) {
        await _loadContent();
      }
    } finally {
      titleController.dispose();
      summaryController.dispose();
      contentController.dispose();
    }
  }

  Future<void> _notifyCustomNotification(Announcement notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notificar os membros?'),
        content: Text(
          '“${notification.title}” será publicado na caixa de entrada de '
          'todos os membros ativos e enviado aos aparelhos habilitados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Notificar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await ContentService.sendCustomNotification(
        notification.notificationId ?? notification.id,
      );
      await _loadContent(showLoading: false);
      if (!mounted) return;
      final recipientCount = result['recipientCount'] as int? ?? 0;
      final pushSuccessCount = result['pushSuccessCount'] as int? ?? 0;
      final pushError = result['pushError'] as String?;
      final pushFailureCount = result['pushFailureCount'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notificação publicada para $recipientCount membro(s); '
            '$pushSuccessCount aparelho(s) notificado(s).'
            '${pushFailureCount > 0 ? ' Falha ao notificar $pushFailureCount aparelho(s).' : ''}'
            '${pushError == null ? '' : ' Push indisponível: $pushError.'}',
          ),
        ),
      );
    } catch (error) {
      _showError('Não foi possível notificar os membros: $error');
    }
  }

  Future<void> _deleteCustomNotification(Announcement notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir notificação?'),
        content: Text(
          'A notificação “${notification.title}” e seus registros da caixa '
          'de entrada serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ContentService.deleteCustomNotification(
        notification.notificationId ?? notification.id,
      );
      await _loadContent(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notificação excluída.')));
    } catch (error) {
      _showError('Não foi possível excluir a notificação: $error');
    }
  }

  /// Lista avisos internos sem expor o conteúdo a visitantes.
  // ignore: unused_element
  Widget _buildAnnouncementsTab() {
    return Column(
      children: [
        _buildImportButton(),
        Expanded(
          child: _announcements.isEmpty
              ? const Center(child: Text('Nenhum aviso interno cadastrado.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final notice = _announcements[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF3D6),
                          child: Icon(
                            Icons.campaign_outlined,
                            color: Color(0xFF9A5B00),
                          ),
                        ),
                        title: Text(notice.title),
                        subtitle: Text(
                          '${notice.category} • ${notice.date}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Compartilhar aviso',
                              icon: const Icon(Icons.share_outlined),
                              onPressed: () => ChurchShareService.chooseShareMode(
                                context,
                                title: notice.title,
                                text:
                                    '${notice.category} • ${notice.date}\n\n${notice.summary}\n\n${notice.content}',
                              ),
                            ),
                            _buildRowActions(
                              onEdit: () => _editAnnouncement(notice),
                              onDelete: () => _deleteAnnouncement(notice),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _editAnnouncement(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar aviso interno'),
            ),
          ),
        ),
      ],
    );
  }

  /// Lista membros por grupo e permite editar seus vínculos e funções.
  Widget _buildMembersTab() {
    final pendingCount = _pendingMemberAccessCount;
    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) => Stack(
          children: [
            Column(
              children: [
                if (pendingCount > 0)
                  MaterialBanner(
                    content: Text(
                      '$pendingCount solicitação(ões) aguardando aprovação.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() => _membersTabIndex = 2);
                          DefaultTabController.of(context).animateTo(2);
                        },
                        child: const Text('Analisar'),
                      ),
                    ],
                  ),
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    isScrollable: true,
                    onTap: (index) => setState(() => _membersTabIndex = index),
                    tabs: [
                      Tab(text: 'Membros (${_members.length})'),
                      Tab(text: 'Visitantes (${_visitors.length})'),
                      Tab(
                        text: pendingCount == 0
                            ? 'Acesso ao app'
                            : 'Acesso ao app ($pendingCount)',
                      ),
                      const Tab(text: 'Departamentos'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMembersList(),
                      _buildVisitorsList(),
                      _buildMemberAccessList(),
                      _buildDepartmentDirectory(),
                    ],
                  ),
                ),
              ],
            ),
            if (_membersTabIndex == 0)
              Positioned(
                right: 20,
                bottom: 20,
                child: FloatingActionButton(
                  tooltip: 'Pré-cadastrar membro',
                  onPressed: () => _editMember(null),
                  child: const Icon(Icons.add_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAccessList() {
    final accounts = _members.where((member) => member.userId != null).toList()
      ..sort((first, second) {
        final firstPending = first.accessStatus == 'pendente';
        final secondPending = second.accessStatus == 'pendente';
        if (firstPending != secondPending) {
          return firstPending ? -1 : 1;
        }
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });
    final pendingCount = accounts
        .where((member) => member.accessStatus == 'pendente')
        .length;

    if (accounts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma conta solicitou acesso ainda. As solicitações de cadastro aparecerão aqui.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Color(0xFF0F766E),
            ),
            title: const Text('Aprovação de acesso ao portal'),
            subtitle: Text(
              pendingCount == 0
                  ? 'Não há solicitações aguardando análise.'
                  : '$pendingCount solicitação(ões) aguardando análise.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...accounts.map(_buildMemberAccessCard),
      ],
    );
  }

  Widget _buildMemberAccessCard(MemberRecord member) {
    final pending = member.accessStatus == 'pendente';
    final authorized = member.accessStatus == 'autorizado' && member.isActive;
    final statusLabel = pending
        ? 'Aguardando autorização'
        : authorized
        ? 'Acesso autorizado'
        : 'Acesso bloqueado';
    final statusColor = pending
        ? const Color(0xFFB45309)
        : authorized
        ? const Color(0xFF0F766E)
        : const Color(0xFFB42318);
    final actionLabel = authorized ? 'Bloquear acesso' : 'Autorizar acesso';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Row(
              children: [
                Icon(
                  pending
                      ? Icons.hourglass_top_rounded
                      : authorized
                      ? Icons.verified_user_outlined
                      : Icons.lock_outline_rounded,
                  color: statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (member.email.isNotEmpty) member.email,
                          statusLabel,
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: member.email.isEmpty
                      ? null
                      : () => _sendUserPasswordRecovery(
                          member.email,
                          member.name,
                        ),
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Redefinir senha'),
                ),
                FilledButton.tonal(
                  onPressed: () => _changeMemberAccess(member, !authorized),
                  child: Text(actionLabel),
                ),
              ],
            );

            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                Flexible(child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVisitorsList() {
    if (_visitors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum visitante cadastrado. Os cadastros feitos como visitante aparecerão aqui.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.person_pin_circle_outlined,
              color: Color(0xFF0F766E),
            ),
            title: const Text('Contas de visitantes'),
            subtitle: Text(
              '${_visitors.length} visitante(s), separados do cadastro de membros.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._visitors.map(_buildVisitorCard),
      ],
    );
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    final id = visitor['id'] as String?;
    final email = visitor['email'] as String? ?? '';
    final name = visitor['nome'] as String? ?? 'Visitante';
    final phone = visitor['telefone'] as String? ?? '';
    final identity = Row(
      children: [
        const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                [email, phone].where((value) => value.isNotEmpty).join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          onPressed: email.isEmpty
              ? null
              : () => _sendUserPasswordRecovery(email, name),
          icon: const Icon(Icons.lock_reset_rounded),
          label: const Text('Redefinir senha'),
        ),
        FilledButton.tonalIcon(
          onPressed: id == null ? null : () => _promoteVisitor(visitor),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Tornar membro'),
        ),
        IconButton(
          tooltip: 'Excluir cadastro do visitante',
          onPressed: id == null ? null : () => _deleteVisitor(visitor),
          color: const Color(0xFFB42318),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 680) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                Flexible(child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendUserPasswordRecovery(String email, String name) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'adtc-vila-uniao://reset-password',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Link de redefinição enviado para o e-mail cadastrado de $name.',
          ),
        ),
      );
    } catch (error) {
      _showError('Não foi possível enviar o link para $name: $error');
    }
  }

  Future<void> _promoteVisitor(Map<String, dynamic> visitor) async {
    final id = visitor['id'] as String?;
    if (id == null) {
      _showError('Não foi possível identificar o cadastro do visitante.');
      return;
    }
    final name = visitor['nome'] as String? ?? 'Visitante';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tornar membro?'),
        content: Text(
          '$name será transferido para a lista de membros. '
          'O acesso ficará aguardando aprovação da administração.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tornar membro'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ContentService.promoteVisitorToMember(id);
      await _loadContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name foi movido para Membros e aguarda aprovação de acesso.',
          ),
        ),
      );
    } catch (error) {
      _showError('Não foi possível tornar $name membro: $error');
    }
  }

  Future<void> _deleteVisitor(Map<String, dynamic> visitor) async {
    final id = visitor['id'] as String?;
    if (id == null) {
      _showError('Não foi possível identificar o cadastro do visitante.');
      return;
    }
    final name = visitor['nome'] as String? ?? 'Visitante';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cadastro de visitante?'),
        content: Text(
          'A conta de $name será excluída permanentemente, incluindo o acesso '
          'ao app e os dados vinculados à conta. Use esta opção somente após '
          'a solicitação do visitante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir cadastro'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ContentService.deleteVisitorAccount(id);
      await _loadContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('O cadastro de $name foi excluído.')),
      );
    } catch (error) {
      _showError('Não foi possível excluir o cadastro de $name: $error');
    }
  }

  Future<void> _changeMemberAccess(MemberRecord member, bool authorize) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(authorize ? 'Autorizar acesso?' : 'Bloquear acesso?'),
        content: Text(
          authorize
              ? 'O membro poderá entrar no portal e usar os recursos disponíveis para membros ativos.'
              : 'O membro deixará de acessar o portal, editar o perfil e consultar seus departamentos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(authorize ? 'Autorizar' : 'Bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || member.id == null) return;

    try {
      await ContentService.setMemberAccess(member.id!, authorized: authorize);
      await _loadContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authorize
                ? 'Acesso de ${member.name} autorizado.'
                : 'Acesso de ${member.name} bloqueado.',
          ),
        ),
      );
    } catch (error) {
      _showError('Não foi possível alterar o acesso: $error');
    }
  }

  Widget _buildDepartmentDirectory() {
    if (_departments.isEmpty) {
      return const Center(child: Text('Nenhum departamento cadastrado.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700
            ? 4
            : constraints.maxWidth >= 480
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _departments.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final department = _departments[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DepartmentMemberMapScreen(department: department),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: department.color.withAlpha(28),
                        child: Icon(department.icon, color: department.color),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        department.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (department.conjuntoName?.isNotEmpty == true)
                        Text(
                          department.conjuntoName!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMembersList() {
    if (_members.isEmpty) {
      return const Center(child: Text('Nenhum membro pré-cadastrado.'));
    }
    final alphabeticalMembers = [..._members]
      ..sort((first, second) {
        final firstName = first.nickname.trim().isEmpty
            ? first.name
            : first.nickname;
        final secondName = second.nickname.trim().isEmpty
            ? second.name
            : second.nickname;
        return firstName.toLowerCase().compareTo(secondName.toLowerCase());
      });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: alphabeticalMembers
          .map((member) => _buildMemberCard(member))
          .toList(),
    );
  }

  Widget _buildMemberCard(MemberRecord member) {
    final statusLabel = member.accessStatus == 'pendente'
        ? 'Aguardando aprovação'
        : member.isActive
        ? 'Ativo'
        : 'Inativo';
    return Card(
      child: ListTile(
        onTap: () => _openMemberDetails(member),
        leading: _adminMemberAvatar(member),
        title: Text(member.nickname.isEmpty ? member.name : member.nickname),
        subtitle: Text(
          [if (member.email.isNotEmpty) member.email, statusLabel].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _adminMemberAvatar(MemberRecord member) => FutureBuilder<String?>(
    future: ContentService.createMemberPhotoUrl(member.photoPath),
    builder: (context, snapshot) {
      final url = snapshot.data;
      if (url != null && url.isNotEmpty) {
        return CircleAvatar(
          backgroundColor: const Color(0xFFE5F3F0),
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (_, _) {},
          child: Text(
            member.name.trim().isEmpty
                ? '?'
                : member.name.trim()[0].toUpperCase(),
          ),
        );
      }
      return CircleAvatar(
        backgroundColor: member.isActive
            ? const Color(0xFFE5F3F0)
            : const Color(0xFFFDE8E7),
        child: Icon(
          member.isActive ? Icons.person_rounded : Icons.person_off_rounded,
          color: member.isActive
              ? const Color(0xFF0F766E)
              : const Color(0xFFB42318),
        ),
      );
    },
  );

  Future<void> _openMemberDetails(MemberRecord member) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AdminMemberDetailsScreen(
          member: member,
          departments: _departments,
          assignments: _departmentAssignments
              .where((item) => item.memberId == member.id)
              .toList(),
          onAssignmentsChanged: _loadContent,
          onDelete: () async {
            await _deleteMember(member);
            if (!context.mounted) return;
            if (!_members.any((item) => item.id == member.id)) {
              Navigator.of(context).pop();
            }
          },
          onEdit: () async {
            final saved = await _editMember(member);
            if (saved && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          onConvertToVisitor: member.userId == null
              ? null
              : () async {
                  final converted = await _convertMemberToVisitor(member);
                  if (converted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
        ),
      ),
    );
  }

  Future<bool> _convertMemberToVisitor(MemberRecord member) async {
    final memberId = member.id;
    if (memberId == null || member.userId == null) {
      _showError(
        'Somente membros vinculados a uma conta podem ser convertidos.',
      );
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transformar membro em visitante?'),
        content: Text(
          'A conta de ${member.name} será mantida, mas o cadastro de membro '
          'e seus vínculos com departamentos e escalas serão removidos. '
          'A pessoa continuará podendo entrar como visitante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Transformar em visitante'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      await ContentService.convertMemberToVisitor(memberId);
      await _loadContent();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.name} agora está cadastrado como visitante.'),
        ),
      );
      return true;
    } catch (error) {
      _showError(
        'Não foi possível converter ${member.name} em visitante: $error',
      );
      return false;
    }
  }

  /// Exibe a importação inicial enquanto existir alguma tabela vazia.
  Widget _buildImportButton() {
    if (_departments.isNotEmpty && _events.isNotEmpty) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: OutlinedButton.icon(
        onPressed: _importExamples,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Carregar exemplos nas tabelas vazias'),
      ),
    );
  }

  /// Padroniza os botões de editar e excluir em cada linha administrativa.
  Widget _buildRowActions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onCopy,
    VoidCallback? onNotify,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCopy != null)
          IconButton(
            tooltip: 'Copiar evento para outra data',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined),
          ),
        if (onNotify != null)
          IconButton(
            tooltip: 'Notificar agora',
            onPressed: onNotify,
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        IconButton(
          tooltip: 'Editar',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Excluir',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
        ),
      ],
    );
  }

  Future<void> _showDepartmentDetails(Department department) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminDepartmentDetailsScreen(
          department: department,
          onEditOptions: (selectedDepartment) async {
            if (!mounted) return;
            Navigator.of(context).pop();
            await _editDepartment(selectedDepartment);
          },
          onDelete: _deleteDepartment,
        ),
      ),
    );
  }

  /// Abre o editor de um departamento e salva os campos no Supabase.
  Future<void> _editDepartment(Department? existing) async {
    final formKey = GlobalKey<FormState>();
    final controllers = <TextEditingController>[
      TextEditingController(text: existing?.name ?? ''),
      TextEditingController(text: existing?.conjuntoName ?? ''),
      TextEditingController(text: existing?.description ?? ''),
      TextEditingController(text: existing?.responsibilities.join('\n') ?? ''),
      TextEditingController(text: existing?.leaderName ?? ''),
      TextEditingController(text: existing?.meetingSchedule ?? ''),
      TextEditingController(text: existing?.tags.join(', ') ?? ''),
      TextEditingController(text: existing?.instagram ?? ''),
      TextEditingController(text: existing?.conjuntoHistory ?? ''),
    ];
    var iconCode =
        _icons.any((icon) => icon.codePoint == existing?.icon.codePoint)
        ? existing!.icon.codePoint
        : _icons.first.codePoint;
    var color = _colors.firstWhere(
      (item) => item.toARGB32() == existing?.color.toARGB32(),
      orElse: () => _colors.first,
    );

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            existing == null ? 'Novo departamento' : 'Editar departamento',
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width < 640
                ? MediaQuery.sizeOf(dialogContext).width * 0.8
                : 520,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.65,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _textField(controllers[0], 'Nome', requiredField: true),
                      _textField(controllers[1], 'Nome do conjunto'),
                      _textField(
                        controllers[4],
                        'Responsável',
                        requiredField: true,
                      ),
                      _textField(
                        controllers[5],
                        'Horário das reuniões',
                        requiredField: true,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          children:
                              [
                                'Segunda às 19:00',
                                'Terça às 19:00',
                                'Quinta às 19:00',
                                'Domingo às 18:00',
                              ].map((schedule) {
                                return ActionChip(
                                  label: Text(schedule),
                                  onPressed: () =>
                                      controllers[5].text = schedule,
                                );
                              }).toList(),
                        ),
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Mais detalhes (opcional)'),
                        children: [
                          _textField(
                            controllers[2],
                            'Descrição',
                            multiline: true,
                          ),
                          _textField(
                            controllers[3],
                            'Responsabilidades (uma por linha)',
                            multiline: true,
                          ),
                          _textField(
                            controllers[6],
                            'Tags (separadas por vírgula)',
                          ),
                          _textField(controllers[7], 'Instagram'),
                          _textField(
                            controllers[8],
                            'Histórico do conjunto',
                            multiline: true,
                          ),
                          DropdownButtonFormField<int>(
                            initialValue: iconCode,
                            decoration: const InputDecoration(
                              labelText: 'Ícone',
                            ),
                            items: _icons
                                .map(
                                  (icon) => DropdownMenuItem(
                                    value: icon.codePoint,
                                    child: Icon(icon),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) iconCode = value;
                            },
                          ),
                          DropdownButtonFormField<Color>(
                            initialValue: color,
                            decoration: const InputDecoration(labelText: 'Cor'),
                            items: _colors
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: item,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_colorHex(item)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) color = value;
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
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
                final department = Department(
                  id:
                      existing?.id ??
                      'departamento_${DateTime.now().microsecondsSinceEpoch}',
                  name: controllers[0].text.trim(),
                  order: existing?.order ?? _departments.length,
                  conjuntoName: _nullableText(controllers[1].text),
                  conjuntoHistory: _nullableText(controllers[8].text),
                  description: controllers[2].text.trim().isEmpty
                      ? 'Departamento da congregação.'
                      : controllers[2].text.trim(),
                  responsibilities: _splitLines(controllers[3].text),
                  leaderName: controllers[4].text.trim(),
                  meetingSchedule: controllers[5].text.trim(),
                  icon: _icons.firstWhere((item) => item.codePoint == iconCode),
                  color: color,
                  tags: _splitCommaList(controllers[6].text),
                  instagram: _nullableText(controllers[7].text),
                );
                try {
                  await ContentService.saveDepartment(department);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (erro) {
                  _showError('Não foi possível salvar o departamento: $erro');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (saved == true) await _loadContent();
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  Future<void> _notifyEvent(ScheduleEvent event) async {
    var selectedType = AgendaNotificationType.added;
    final selected = await showDialog<AgendaNotificationType>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Notificar evento agora'),
          content: DropdownButton<AgendaNotificationType>(
            isExpanded: true,
            value: selectedType,
            items: AgendaNotificationType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(_agendaNotificationTypeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: (type) {
              if (type != null) {
                setDialogState(() => selectedType = type);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, selectedType),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar notificação'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    try {
      await ContentService.sendAgendaNotification(
        eventId: event.id,
        type: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notificação de "${event.title}" enviada: '
            '${_agendaNotificationTypeLabel(selected).toLowerCase()}.',
          ),
        ),
      );
    } catch (error) {
      _showError('Não foi possível notificar o evento: $error');
    }
  }

  String _agendaNotificationTypeLabel(AgendaNotificationType type) =>
      switch (type) {
        AgendaNotificationType.added => 'Novo evento',
        AgendaNotificationType.changed => 'Evento alterado',
        AgendaNotificationType.cancelled => 'Evento cancelado',
        AgendaNotificationType.event => 'Somente o evento',
      };

  /// Abre o editor semanal/mensal e salva o evento no Supabase.
  Future<void> _editEvent(
    ScheduleEvent? existing, {
    DateTime? date,
    bool copyAsNew = false,
  }) async {
    final formKey = GlobalKey<FormState>();
    final controllers = <TextEditingController>[
      TextEditingController(text: existing?.title ?? ''),
      TextEditingController(text: existing?.subtitle ?? ''),
      TextEditingController(text: existing?.time ?? ''),
      TextEditingController(text: existing?.daysDescription ?? ''),
      TextEditingController(text: existing?.location ?? ''),
      TextEditingController(text: existing?.recurringCycle ?? ''),
      TextEditingController(text: existing?.notes ?? ''),
      TextEditingController(
        text: date != null
            ? DateFormat('dd/MM/yyyy').format(date)
            : existing?.eventDate == null
            ? ''
            : DateFormat('dd/MM/yyyy').format(existing!.eventDate!),
      ),
      TextEditingController(text: existing?.linkText ?? ''),
      TextEditingController(text: existing?.linkUrl ?? ''),
    ];
    var eventType = existing?.type ?? EventType.culto;
    var weekday = existing?.dayOfWeek ?? 0;
    var departmentId =
        _departments.any(
          (department) => department.id == existing?.departmentId,
        )
        ? existing!.departmentId!
        : '';
    var iconCode =
        _icons.any((icon) => icon.codePoint == existing?.icon.codePoint)
        ? existing!.icon.codePoint
        : _icons.first.codePoint;
    var color = _colors.firstWhere(
      (item) => item.toARGB32() == existing?.color.toARGB32(),
      orElse: () => _colors.first,
    );
    var monthlyTheme = existing?.monthlyTheme ?? false;
    PlatformFile? selectedAttachment;
    var removeExistingAttachment = false;
    var savingEvent = false;
    String? attachmentPickerError;
    String? attachmentCleanupWarning;

    Future<void> pickEventAttachment(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      try {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        );
        if (file == null || !dialogContext.mounted) return;
        final fileSize = await file.length();
        if (!dialogContext.mounted) return;
        if (fileSize == null) {
          setDialogState(
            () => attachmentPickerError =
                'Não foi possível verificar o tamanho do arquivo.',
          );
          return;
        }
        if (fileSize > ContentService.eventAttachmentMaxBytes) {
          setDialogState(
            () => attachmentPickerError = 'O arquivo deve ter no máximo 20 MB.',
          );
          return;
        }
        setDialogState(() {
          selectedAttachment = file;
          removeExistingAttachment = false;
          attachmentPickerError = null;
        });
      } catch (error) {
        if (!dialogContext.mounted) return;
        setDialogState(
          () => attachmentPickerError =
              'Não foi possível selecionar o arquivo: $error',
        );
      }
    }

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              copyAsNew
                  ? 'Copiar evento'
                  : existing == null
                  ? 'Novo evento'
                  : 'Editar evento',
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width < 640
                  ? MediaQuery.sizeOf(dialogContext).width * 0.8
                  : 520,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.65,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _textField(
                          controllers[0],
                          'Título',
                          requiredField: true,
                        ),
                        _textField(
                          controllers[1],
                          'Subtítulo',
                          requiredField: true,
                        ),
                        _timePickerField(
                          dialogContext,
                          label: 'Horário',
                          controller: controllers[2],
                        ),
                        _datePickerField(
                          dialogContext,
                          label: 'Dia específico no calendário (opcional)',
                          controller: controllers[7],
                          requiredField: false,
                        ),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: weekday,
                          decoration: const InputDecoration(
                            labelText: 'Dia da semana',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 0,
                              child: Text('Todos os dias / vários dias'),
                            ),
                            ..._weekdays.entries.map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              weekday = value;
                              controllers[3].text = value == 0
                                  ? 'Todos os dias'
                                  : _weekdays[value]!;
                            }
                          },
                        ),
                        _textField(
                          controllers[4],
                          'Local',
                          requiredField: true,
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              [
                                'Semanal',
                                'Diário',
                                '1º Domingo',
                                '2º Domingo',
                                '3º Domingo',
                                '4º Domingo',
                                '5º Domingo',
                              ].contains(controllers[5].text)
                              ? controllers[5].text
                              : (monthlyTheme ? '1º Domingo' : 'Semanal'),
                          decoration: const InputDecoration(
                            labelText: 'Repetição',
                          ),
                          items:
                              const [
                                    'Semanal',
                                    'Diário',
                                    '1º Domingo',
                                    '2º Domingo',
                                    '3º Domingo',
                                    '4º Domingo',
                                    '5º Domingo',
                                  ]
                                  .map(
                                    (cycle) => DropdownMenuItem(
                                      value: cycle,
                                      child: Text(cycle),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            controllers[5].text = value;
                            monthlyTheme = value.contains('Domingo');
                            weekday = monthlyTheme ? DateTime.sunday : weekday;
                            controllers[3].text = monthlyTheme
                                ? value
                                : (weekday == 0
                                      ? 'Todos os dias'
                                      : _weekdays[weekday]!);
                          },
                        ),
                        _textField(
                          controllers[6],
                          'Observações',
                          multiline: true,
                          requiredField: true,
                        ),
                        _textField(
                          controllers[8],
                          'Texto clicável do link (opcional)',
                          requiredField: false,
                        ),
                        TextFormField(
                          controller: controllers[9],
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Link do evento (opcional)',
                            hintText: 'https://...',
                          ),
                          validator: (value) {
                            final label = controllers[8].text.trim();
                            final url = value?.trim() ?? '';
                            if (label.isEmpty != url.isEmpty) {
                              return 'Preencha o texto e o link juntos.';
                            }
                            if (url.isNotEmpty) {
                              final uri = Uri.tryParse(url);
                              if (uri == null ||
                                  !{
                                    'http',
                                    'https',
                                  }.contains(uri.scheme.toLowerCase()) ||
                                  uri.host.isEmpty) {
                                return 'Informe um endereço http ou https válido.';
                              }
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<EventType>(
                          isExpanded: true,
                          initialValue: eventType,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: EventType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(_eventTypeLabel(type)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) eventType = value;
                          },
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: departmentId,
                          decoration: const InputDecoration(
                            labelText: 'Departamento (opcional)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Nenhum'),
                            ),
                            ..._departments.map(
                              (department) => DropdownMenuItem(
                                value: department.id,
                                child: Text(
                                  department.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => departmentId = value ?? '',
                        ),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: iconCode,
                          decoration: const InputDecoration(labelText: 'Ícone'),
                          items: _icons
                              .map(
                                (icon) => DropdownMenuItem(
                                  value: icon.codePoint,
                                  child: Icon(icon),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) iconCode = value;
                          },
                        ),
                        DropdownButtonFormField<Color>(
                          isExpanded: true,
                          initialValue: color,
                          decoration: const InputDecoration(labelText: 'Cor'),
                          items: _colors
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: item,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_colorHex(item)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) color = value;
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Material do evento (opcional)',
                            style: Theme.of(dialogContext).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (selectedAttachment != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.attach_file_rounded),
                            title: Text(
                              selectedAttachment!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: const Text('Novo arquivo selecionado'),
                            trailing: IconButton(
                              tooltip: 'Cancelar seleção',
                              onPressed: savingEvent
                                  ? null
                                  : () => setDialogState(
                                      () => selectedAttachment = null,
                                    ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          )
                        else if (existing?.attachmentPath != null &&
                            !removeExistingAttachment)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.attach_file_rounded),
                            title: Text(
                              existing!.attachmentName ?? 'Arquivo anexado',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: const Text('Anexo atual'),
                            trailing: IconButton(
                              tooltip: 'Remover anexo',
                              onPressed: savingEvent
                                  ? null
                                  : () => setDialogState(
                                      () => removeExistingAttachment = true,
                                    ),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          )
                        else if (removeExistingAttachment)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFB42318),
                            ),
                            title: const Text('O anexo atual será removido'),
                            trailing: TextButton(
                              onPressed: savingEvent
                                  ? null
                                  : () => setDialogState(
                                      () => removeExistingAttachment = false,
                                    ),
                              child: const Text('Desfazer'),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: savingEvent
                                ? null
                                : () => pickEventAttachment(
                                    dialogContext,
                                    setDialogState,
                                  ),
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(
                              selectedAttachment == null
                                  ? 'Anexar imagem ou PDF'
                                  : 'Escolher outro arquivo',
                            ),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'PDF, JPG, PNG ou WEBP; até 20 MB.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (attachmentPickerError != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              attachmentPickerError!,
                              style: const TextStyle(
                                color: Color(0xFFB42318),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: savingEvent
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: savingEvent
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => savingEvent = true);
                        final event = ScheduleEvent(
                          id: existing == null || copyAsNew
                              ? 'evento_${DateTime.now().microsecondsSinceEpoch}'
                              : existing.id,
                          title: controllers[0].text.trim(),
                          subtitle: controllers[1].text.trim(),
                          time: controllers[2].text.trim(),
                          eventDate: _parseDate(controllers[7].text),
                          daysDescription: controllers[3].text.trim().isEmpty
                              ? (monthlyTheme
                                    ? controllers[5].text.trim()
                                    : weekday == 0
                                    ? 'Todos os dias'
                                    : _weekdays[weekday]!)
                              : controllers[3].text.trim(),
                          dayOfWeek: weekday == 0 ? null : weekday,
                          location: controllers[4].text.trim(),
                          type: eventType,
                          departmentId: departmentId.isEmpty
                              ? null
                              : departmentId,
                          recurringCycle:
                              _nullableText(controllers[5].text) ??
                              (monthlyTheme ? '1º Domingo' : 'Semanal'),
                          icon: _icons.firstWhere(
                            (item) => item.codePoint == iconCode,
                          ),
                          color: color,
                          notes: controllers[6].text.trim(),
                          monthlyTheme: monthlyTheme,
                          attachmentPath: existing?.attachmentPath,
                          attachmentName: existing?.attachmentName,
                          linkText: _nullableText(controllers[8].text),
                          linkUrl: _nullableText(controllers[9].text),
                        );
                        try {
                          final attachmentBytes = await selectedAttachment
                              ?.readAsBytes();
                          attachmentCleanupWarning =
                              await ContentService.saveScheduleEvent(
                                event,
                                attachmentBytes: attachmentBytes,
                                attachmentName: selectedAttachment?.name,
                                removeAttachment: removeExistingAttachment,
                              );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (erro) {
                          if (dialogContext.mounted) {
                            setDialogState(() => savingEvent = false);
                          }
                          _showError('Não foi possível salvar o evento: $erro');
                        }
                      },
                child: Text(
                  savingEvent
                      ? 'Salvando...'
                      : copyAsNew
                      ? 'Criar cópia'
                      : 'Salvar',
                ),
              ),
            ],
          ),
        ),
      );
      if (saved == true) {
        await _loadContent();
        if (attachmentCleanupWarning != null && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(attachmentCleanupWarning!)));
        }
      }
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  /// Cria ou edita uma escala e atualiza a lista após a gravação.
  Future<void> _editScale(ScaleItem? existing) async {
    final formKey = GlobalKey<FormState>();
    final controllers = <TextEditingController>[
      TextEditingController(text: existing?.serviceName ?? ''),
      TextEditingController(
        text: _parseDate(existing?.date ?? '') == null ? '' : existing!.date,
      ),
      TextEditingController(text: existing?.time ?? ''),
      TextEditingController(text: existing?.department ?? ''),
      TextEditingController(text: existing?.volunteers.join('\n') ?? ''),
      TextEditingController(text: existing?.observation ?? ''),
    ];

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'Nova escala' : 'Editar escala'),
          content: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width < 640
                ? MediaQuery.sizeOf(dialogContext).width * 0.8
                : 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _textField(
                      controllers[0],
                      'Culto / evento',
                      requiredField: true,
                    ),
                    _datePickerField(
                      dialogContext,
                      label: 'Data da escala',
                      controller: controllers[1],
                    ),
                    _timePickerField(
                      dialogContext,
                      label: 'Horário',
                      controller: controllers[2],
                    ),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _departments.any(
                            (department) =>
                                department.name == controllers[3].text,
                          )
                          ? controllers[3].text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Departamento',
                      ),
                      items: _departments
                          .map(
                            (department) => DropdownMenuItem(
                              value: department.name,
                              child: Text(department.name),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Selecione um departamento.' : null,
                      onChanged: (value) => controllers[3].text = value ?? '',
                    ),
                    if (_departments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Cadastre um departamento antes de criar uma escala.',
                          style: TextStyle(color: Color(0xFFB42318)),
                        ),
                      ),
                    _textField(
                      controllers[4],
                      'Pessoas escaladas (uma por linha)',
                      multiline: true,
                    ),
                    if (_members.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          children: _members
                              .where((member) => member.isActive)
                              .map(
                                (member) => ActionChip(
                                  avatar: const Icon(
                                    Icons.person_add_alt_1,
                                    size: 16,
                                  ),
                                  label: Text(member.name),
                                  onPressed: () => _appendVolunteer(
                                    controllers[4],
                                    member.name,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    _textField(controllers[5], 'Observação', multiline: true),
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
                final scale = ScaleItem(
                  id:
                      existing?.id ??
                      'escala_${DateTime.now().microsecondsSinceEpoch}',
                  serviceName: controllers[0].text.trim(),
                  date: controllers[1].text.trim(),
                  time: controllers[2].text.trim(),
                  department: controllers[3].text.trim(),
                  volunteers: _splitLines(controllers[4].text),
                  observation: controllers[5].text.trim(),
                );
                try {
                  await ContentService.saveScale(scale);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (erro) {
                  _showError('Não foi possível salvar a escala: $erro');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (saved == true) await _loadContent();
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  /// Cria ou edita avisos visíveis somente a membros autenticados.
  Future<void> _editAnnouncement(Announcement? existing) async {
    final formKey = GlobalKey<FormState>();
    final controllers = <TextEditingController>[
      TextEditingController(text: existing?.title ?? ''),
      TextEditingController(text: existing?.summary ?? ''),
      TextEditingController(text: existing?.content ?? ''),
      TextEditingController(
        text: _parseDate(existing?.date ?? '') == null ? '' : existing!.date,
      ),
      TextEditingController(text: existing?.category ?? 'Aviso Interno'),
      TextEditingController(text: existing?.actionUrl ?? ''),
    ];

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'Novo aviso interno' : 'Editar aviso'),
          content: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width < 640
                ? MediaQuery.sizeOf(dialogContext).width * 0.8
                : 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _textField(controllers[0], 'Título', requiredField: true),
                    _textField(controllers[1], 'Resumo', requiredField: true),
                    _textField(
                      controllers[2],
                      'Comunicado',
                      multiline: true,
                      requiredField: true,
                    ),
                    _datePickerField(
                      dialogContext,
                      label: 'Data do aviso',
                      controller: controllers[3],
                    ),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _announcementCategories.contains(controllers[4].text)
                          ? controllers[4].text
                          : _announcementCategories.first,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: _announcementCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          controllers[4].text = value ?? 'Aviso Geral',
                    ),
                    _textField(controllers[5], 'Link de ação'),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.lock_outline,
                        color: Color(0xFF0F766E),
                      ),
                      title: Text('Visível somente para membros ativos'),
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
                final announcement = Announcement(
                  id:
                      existing?.id ??
                      'aviso_${DateTime.now().microsecondsSinceEpoch}',
                  title: controllers[0].text.trim(),
                  summary: controllers[1].text.trim(),
                  content: controllers[2].text.trim(),
                  date: controllers[3].text.trim(),
                  category: controllers[4].text.trim(),
                  isMembersOnly: true,
                  actionUrl: _nullableText(controllers[5].text),
                );
                try {
                  await ContentService.saveAnnouncement(announcement);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (erro) {
                  _showError('Não foi possível salvar o aviso: $erro');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (saved == true) await _loadContent();
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  /// Pré-cadastra ou edita um membro sem criar uma senha em nome dele.
  Future<bool> _editMember(MemberRecord? existing) async {
    final formKey = GlobalKey<FormState>();
    final controllers = <TextEditingController>[
      TextEditingController(text: existing?.name ?? ''),
      TextEditingController(text: existing?.nickname ?? ''),
      TextEditingController(text: existing?.email ?? ''),
      TextEditingController(text: existing?.phone ?? ''),
      TextEditingController(text: existing?.department ?? ''),
      TextEditingController(
        text: existing?.congregation ?? 'ADTC Vila União - Sobral',
      ),
      TextEditingController(text: existing?.baptismDate ?? ''),
      TextEditingController(text: existing?.birthDate ?? ''),
    ];
    var active = existing?.isActive ?? true;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: Text(
              existing == null ? 'Pré-cadastrar membro' : 'Editar membro',
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width < 640
                  ? MediaQuery.sizeOf(dialogContext).width * 0.8
                  : 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _textField(
                        controllers[0],
                        'Nome completo',
                        requiredField: true,
                      ),
                      _textField(
                        controllers[1],
                        'Apelido / como gosta de ser chamado',
                        hintText: 'Ex.: Ir. Guto',
                      ),
                      _textField(
                        controllers[2],
                        'E-mail (opcional, para acesso ao app)',
                      ),
                      _textField(controllers[3], 'Telefone'),
                      _textField(
                        controllers[4],
                        'Departamentos em que serve',
                        hintText: 'Separe os departamentos por ponto e vírgula',
                      ),
                      _textField(
                        controllers[5],
                        'Congregação',
                        requiredField: true,
                      ),
                      _textField(controllers[6], 'Data de batismo'),
                      TextFormField(
                        controller: controllers[7],
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: dialogContext,
                            initialDate:
                                DateTime.tryParse(controllers[7].text) ??
                                DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (selected != null) {
                            controllers[7].text =
                                '${selected.year.toString().padLeft(4, '0')}-'
                                '${selected.month.toString().padLeft(2, '0')}-'
                                '${selected.day.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Membro ativo'),
                        subtitle: Text(
                          active
                              ? 'Cadastro ativo na igreja'
                              : 'Cadastro inativo',
                        ),
                        value: active,
                        onChanged: (value) =>
                            updateDialog(() => active = value),
                      ),
                      const Text(
                        'Sem e-mail, o membro fica pré-cadastrado sem acesso ao app. '
                        'Isso pode ser usado para crianças e adolescentes.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
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
                  final email = controllers[2].text.trim().toLowerCase();
                  if (email.isNotEmpty && !email.contains('@')) {
                    _showError('Informe um e-mail válido ou deixe em branco.');
                    return;
                  }
                  final member = MemberRecord(
                    id: existing?.id,
                    userId: existing?.userId,
                    membershipNumber: existing?.membershipNumber,
                    photoPath: existing?.photoPath,
                    email: email,
                    name: controllers[0].text.trim(),
                    nickname: controllers[1].text.trim(),
                    phone: controllers[3].text.trim(),
                    department: controllers[4].text.trim(),
                    congregation: controllers[5].text.trim(),
                    baptismDate: controllers[6].text.trim(),
                    birthDate: controllers[7].text.trim(),
                    isActive: active,
                    accessStatus: active
                        ? 'autorizado'
                        : existing?.accessStatus == 'pendente'
                        ? 'pendente'
                        : 'bloqueado',
                  );
                  try {
                    await ContentService.saveMember(member);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (erro) {
                    _showError('Não foi possível salvar o membro: $erro');
                  }
                },
                child: const Text('Salvar cadastro'),
              ),
            ],
          ),
        ),
      );
      if (saved == true) await _loadContent();
      return saved == true;
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  /// Confirma a exclusão e revalida a senha da sessão administrativa atual.
  Future<bool> _deleteDepartment(Department department) async {
    if (!await _confirmDepartmentDeletion(department)) return false;
    try {
      await ContentService.deleteDepartment(department.id);
      await _loadContent();
      return true;
    } catch (erro) {
      _showError('Não foi possível excluir o departamento: $erro');
      return false;
    }
  }

  Future<bool> _confirmDepartmentDeletion(Department department) async {
    final administrator = Supabase.instance.client.auth.currentUser;
    final email = administrator?.email;
    if (administrator == null || email == null || email.isEmpty) {
      _showError('Não foi possível identificar a conta administradora atual.');
      return false;
    }

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var verifying = false;
    String? verificationError;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB42318),
              size: 36,
            ),
            title: const Text('Excluir conjunto?'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta ação excluirá permanentemente "${department.displayName}" e os vínculos da equipe. Digite a senha da conta admin $email para confirmar.',
                  ),
                  if (verificationError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      verificationError!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha do administrador',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Informe sua senha.'
                        : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: verifying
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                ),
                onPressed: verifying
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        updateDialog(() {
                          verifying = true;
                          verificationError = null;
                        });
                        try {
                          final allowed = await _verifyDepartmentDeletePassword(
                            formKey,
                            email,
                            administrator.id,
                            passwordController.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, allowed);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            updateDialog(() {
                              verifying = false;
                              verificationError =
                                  'Senha incorreta ou não foi possível validar a conta: $error';
                            });
                          }
                        }
                      },
                child: verifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Validar e excluir'),
              ),
            ],
          ),
        ),
      );
      return confirmed == true;
    } finally {
      passwordController.dispose();
    }
  }

  Future<bool> _verifyDepartmentDeletePassword(
    GlobalKey<FormState> formKey,
    String email,
    String administratorId,
    String password,
  ) async {
    if (!formKey.currentState!.validate()) return false;
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user?.id != administratorId) {
      throw StateError('A conta autenticada não corresponde ao admin atual.');
    }

    final adminRecord = await Supabase.instance.client
        .from('administradores')
        .select('usuario_id')
        .eq('usuario_id', administratorId)
        .maybeSingle();
    if (adminRecord == null) {
      throw StateError('A conta atual não possui mais acesso administrativo.');
    }
    return true;
  }

  /// Confirma exclusão antes de remover o evento selecionado.
  Future<void> _deleteEvent(ScheduleEvent event) async {
    if (!await _confirmDelete(event.title)) return;
    try {
      final cleanupWarning = await ContentService.deleteScheduleEvent(event.id);
      await _loadContent();
      if (cleanupWarning != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanupWarning)));
      }
    } catch (erro) {
      _showError('Não foi possível excluir o evento: $erro');
    }
  }

  /// Confirma e remove a escala selecionada.
  Future<void> _deleteScale(ScaleItem scale) async {
    if (!await _confirmDelete(scale.department)) return;
    try {
      await ContentService.deleteScale(scale.id);
      await _loadContent();
    } catch (erro) {
      _showError('Não foi possível excluir a escala: $erro');
    }
  }

  /// Confirma e remove o aviso selecionado.
  Future<void> _deleteAnnouncement(Announcement announcement) async {
    if (!await _confirmDelete(announcement.title)) return;
    try {
      await ContentService.deleteAnnouncement(announcement.id);
      await _loadContent();
    } catch (erro) {
      _showError('Não foi possível excluir o aviso: $erro');
    }
  }

  /// Confirma e remove o pré-cadastro de membro selecionado.
  Future<void> _deleteMember(MemberRecord member) async {
    if (!await _confirmDelete(member.name)) return;
    final memberId = member.id;
    if (memberId == null) return;
    try {
      await ContentService.deleteMember(memberId);
      await _loadContent();
    } catch (erro) {
      _showError('Não foi possível excluir o membro: $erro');
    }
  }

  /// Solicita confirmação para operações destrutivas.
  Future<bool> _confirmDelete(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Excluir conteúdo?'),
            content: Text('Deseja excluir "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Cria campos de formulário consistentes para os editores de conteúdo.
  Widget _textField(
    TextEditingController controller,
    String label, {
    bool multiline = false,
    bool requiredField = false,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        maxLines: multiline ? 3 : 1,
        decoration: InputDecoration(labelText: label, hintText: hintText),
        validator: requiredField
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Preencha este campo.'
                  : null
            : null,
      ),
    );
  }

  Widget _datePickerField(
    BuildContext dialogContext, {
    required String label,
    required TextEditingController controller,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: requiredField
              ? const Icon(Icons.calendar_month_rounded)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded),
                    IconButton(
                      tooltip: 'Remover data específica',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.clear_rounded),
                    ),
                  ],
                ),
        ),
        validator: requiredField
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Selecione uma data.'
                  : null
            : null,
        onTap: () async {
          final initialDate = _parseDate(controller.text) ?? DateTime.now();
          final date = await showDatePicker(
            context: dialogContext,
            initialDate: initialDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            controller.text = DateFormat('dd/MM/yyyy').format(date);
          }
        },
      ),
    );
  }

  Widget _timePickerField(
    BuildContext dialogContext, {
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time_rounded),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Selecione um horário.'
            : null,
        onTap: () async {
          final parts = controller.text.split(':');
          final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
          final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
          final initialTime = hour == null || minute == null
              ? const TimeOfDay(hour: 18, minute: 0)
              : TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
          final time = await showTimePicker(
            context: dialogContext,
            initialTime: initialTime,
          );
          if (time != null) {
            controller.text =
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          }
        },
      ),
    );
  }

  DateTime? _parseDate(String value) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(value);
    } on FormatException {
      return null;
    }
  }

  void _appendVolunteer(TextEditingController controller, String name) {
    final volunteers = _splitLines(controller.text);
    if (volunteers.contains(name)) return;
    volunteers.add(name);
    controller.text = volunteers.join('\n');
  }

  /// Converte texto em lista sem itens vazios ou espaços extras.
  List<String> _splitLines(String value) => value
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  /// Converte tags separadas por vírgulas em uma lista para o banco.
  List<String> _splitCommaList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  String _colorHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Normaliza campos opcionais vazios para nulo.
  String? _nullableText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// Traduz os tipos internos do evento para rótulos da interface.
  String _eventTypeLabel(EventType type) => switch (type) {
    EventType.culto => 'Culto',
    EventType.oracao => 'Oração',
    EventType.ensaio => 'Ensaio',
    EventType.estudo => 'Estudo',
    EventType.consagracao => 'Consagração',
    EventType.missao => 'Missão',
    EventType.especial => 'Especial',
  };
}
