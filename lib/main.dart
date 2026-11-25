import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'configuracao_supabase.dart';
import 'services/agenda_notification_service.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/departments_screen.dart';
import 'screens/media_screen.dart';
import 'screens/member_portal_screen.dart';
import 'screens/admin_content_screen.dart';
import 'screens/about_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/password_recovery_screen.dart';
import 'screens/member_notifications_screen.dart';
import 'models/schedule_event.dart';
import 'utils/auth_redirect_utils.dart';
import 'widgets/custom_drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final emailConfirmationCallback = isEmailConfirmationCallback(Uri.base);
  await inicializarSupabase();
  AgendaNotificationService.registrarHandlerSegundoPlano();
  await AgendaNotificationService.inicializar();
  final authService = AuthService(
    emailConfirmationCallback: emailConfirmationCallback,
  );
  runApp(ADTCApp(authService: authService));
}

class ADTCApp extends StatelessWidget {
  final AuthService authService;

  const ADTCApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADTC Vila União - Sobral',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: MainNavigationScreen(authService: authService),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final AuthService authService;

  const MainNavigationScreen({super.key, required this.authService});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<int> _navigationHistory = [];
  late final AnimationController _tabTransitionController;
  late final Animation<Offset> _tabSlide;
  int _currentIndex = 0;
  int _departmentsRefreshToken = 0;
  int _registrationRequestToken = 0;
  DateTime? _lastBackPress;
  bool _isTransitioning = false;
  bool _wasAuthenticated = false;
  bool _openingPasswordRecovery = false;
  bool _handlingEmailConfirmationRedirect = false;
  ScheduleEvent? _eventToOpenInSchedule;
  String? _eventIdToOpenInSchedule;
  String? _pendingNoticeId;

  @override
  void initState() {
    super.initState();
    _wasAuthenticated = widget.authService.isAuthenticated;
    widget.authService.addListener(_handleAuthenticationChange);
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _tabSlide = Tween<Offset>(begin: const Offset(0.025, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _tabTransitionController,
            curve: Curves.easeOutCubic,
          ),
        );
    AgendaNotificationService.setEventTapHandler(_openScheduleEventFromPush);
    AgendaNotificationService.setNoticeTapHandler(_openMemberNoticeFromPush);
  }

  @override
  void dispose() {
    AgendaNotificationService.setEventTapHandler(null);
    AgendaNotificationService.setNoticeTapHandler(null);
    widget.authService.removeListener(_handleAuthenticationChange);
    widget.authService.removeListener(_handlePendingNoticeTap);
    _tabTransitionController.dispose();
    super.dispose();
  }

  void _openMemberNoticeFromPush(String noticeId) {
    _pendingNoticeId = noticeId;
    _handlePendingNoticeTap();
    if (widget.authService.isLoading) {
      widget.authService.addListener(_handlePendingNoticeTap);
    }
  }

  void _handlePendingNoticeTap() {
    if (widget.authService.isLoading) return;
    widget.authService.removeListener(_handlePendingNoticeTap);

    final noticeId = _pendingNoticeId;
    final user = widget.authService.currentUser;
    if (noticeId == null ||
        !widget.authService.isAuthenticated ||
        user == null) {
      _pendingNoticeId = null;
      return;
    }
    _pendingNoticeId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MemberNotificationsScreen(userId: user.id),
        ),
      );
    });
  }

  Future<void> _onSelectTab(int index) async {
    await _transitionToTab(index);
  }

  Future<void> _openRegistrationPortal() async {
    setState(() => _registrationRequestToken++);
    await _transitionToTab(4);
  }

  void _handleAuthenticationChange() {
    final isAuthenticated = widget.authService.isAuthenticated;
    final justAuthenticated = !_wasAuthenticated && isAuthenticated;
    _wasAuthenticated = isAuthenticated;
    if (justAuthenticated && _currentIndex != 0) {
      unawaited(_transitionToTab(0));
    }
  }

  void _handleNavigationBack() {
    if (_navigationHistory.isNotEmpty) {
      final previousIndex = _navigationHistory.removeLast();
      unawaited(_transitionToTab(previousIndex, addToHistory: false));
      return;
    }
    if (_currentIndex != 0) {
      unawaited(_transitionToTab(0, addToHistory: false));
    }
  }

  Future<void> _openScheduleEvent(ScheduleEvent event) async {
    await _transitionToTab(1);
    if (!mounted) return;
    setState(() {
      _eventToOpenInSchedule = event;
      _eventIdToOpenInSchedule = null;
    });
  }

  Future<void> _openScheduleEventFromPush(String eventId) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await _transitionToTab(1);
    if (!mounted) return;
    setState(() {
      _eventToOpenInSchedule = null;
      _eventIdToOpenInSchedule = eventId;
    });
  }

  void _onScheduleEventOpened() {
    if (_eventToOpenInSchedule == null && _eventIdToOpenInSchedule == null) {
      return;
    }
    setState(() {
      _eventToOpenInSchedule = null;
      _eventIdToOpenInSchedule = null;
    });
  }

  Future<void> _transitionToTab(int index, {bool addToHistory = true}) async {
    if (index == _currentIndex || _isTransitioning) return;
    _isTransitioning = true;
    await _tabTransitionController.reverse();
    if (!mounted) return;
    setState(() {
      if (addToHistory) _navigationHistory.add(_currentIndex);
      _currentIndex = index;
      if (index == 2) _departmentsRefreshToken++;
    });
    await _tabTransitionController.forward();
    _isTransitioning = false;
  }

  void _openLoginAfterEmailConfirmation() {
    if (_handlingEmailConfirmationRedirect ||
        !widget.authService.emailConfirmationRedirectPending) {
      return;
    }

    _handlingEmailConfirmationRedirect = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.authService.consumeEmailConfirmationRedirect()) {
        _handlingEmailConfirmationRedirect = false;
        return;
      }

      while (_isTransitioning && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!mounted) return;

      await _transitionToTab(4);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-mail confirmado. Entre no portal com sua conta.'),
        ),
      );
      _handlingEmailConfirmationRedirect = false;
    });
  }

  void _handleSystemBack() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }

    if (_navigationHistory.isNotEmpty) {
      final previousIndex = _navigationHistory.removeLast();
      _transitionToTab(previousIndex, addToHistory: false);
      _lastBackPress = null;
      return;
    }

    final now = DateTime.now();
    final lastBackPress = _lastBackPress;
    if (lastBackPress != null &&
        now.difference(lastBackPress) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Pressione voltar novamente para sair do aplicativo.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _openAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AboutScreen(authService: widget.authService),
      ),
    );
  }

  Future<void> _openAdminContent() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminContentScreen(authService: widget.authService),
      ),
    );
    if (!mounted) return;
    setState(() => _departmentsRefreshToken++);
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NotificationSettingsScreen(authService: widget.authService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, _) {
        if (widget.authService.isLoading &&
            widget.authService.currentUser == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/church_logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  const Text('Carregando sua área...'),
                ],
              ),
            ),
          );
        }

        if (widget.authService.passwordRecoveryPending &&
            !_openingPasswordRecovery) {
          _openingPasswordRecovery = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    PasswordRecoveryScreen(authService: widget.authService),
              ),
            );
            if (!mounted) return;
            widget.authService.dismissPasswordRecovery();
            _openingPasswordRecovery = false;
          });
        }

        _openLoginAfterEmailConfirmation();

        final List<Widget> screens = [
          HomeScreen(
            authService: widget.authService,
            onNavigateTab: _onSelectTab,
            onOpenRegistration: _openRegistrationPortal,
            onOpenScheduleEvent: _openScheduleEvent,
            onOpenDrawer: _openDrawer,
          ),
          ScheduleScreen(
            authService: widget.authService,
            onOpenDrawer: _handleNavigationBack,
            onLoginRequired: () => _onSelectTab(4),
            eventToOpen: _eventToOpenInSchedule,
            eventIdToOpen: _eventIdToOpenInSchedule,
            onEventRequestHandled: _onScheduleEventOpened,
          ),
          DepartmentsScreen(
            authService: widget.authService,
            onOpenDrawer: _handleNavigationBack,
            onLoginRequired: () => _onSelectTab(4),
            isVisible: _currentIndex == 2,
            refreshToken: _departmentsRefreshToken,
          ),
          MediaScreen(
            authService: widget.authService,
            onOpenDrawer: _handleNavigationBack,
            onLoginRequired: () => _onSelectTab(4),
          ),
          MemberPortalScreen(
            authService: widget.authService,
            onOpenDrawer: _handleNavigationBack,
            registrationRequestToken: _registrationRequestToken,
          ),
        ];

        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _handleSystemBack();
          },
          child: Scaffold(
            key: _scaffoldKey,
            drawer: CustomDrawer(
              authService: widget.authService,
              onSelectTab: _onSelectTab,
              onOpenAbout: _openAbout,
              onOpenAdmin: _openAdminContent,
              onOpenNotificationSettings: _openNotificationSettings,
            ),
            body: FadeTransition(
              opacity: _tabTransitionController,
              child: SlideTransition(
                position: _tabSlide,
                child: IndexedStack(index: _currentIndex, children: screens),
              ),
            ),
          ),
        );
      },
    );
  }
}
