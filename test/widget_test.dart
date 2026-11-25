import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adtc_vila_uniao/main.dart';
import 'package:adtc_vila_uniao/models/department.dart';
import 'package:adtc_vila_uniao/models/schedule_event.dart';
import 'package:adtc_vila_uniao/models/user_profile.dart';
import 'package:adtc_vila_uniao/screens/contributions_screen.dart';
import 'package:adtc_vila_uniao/screens/department_detail_screen.dart';
import 'package:adtc_vila_uniao/screens/admin_department_details_screen.dart';
import 'package:adtc_vila_uniao/screens/member_portal_screen.dart';
import 'package:adtc_vila_uniao/screens/schedule_event_details_screen.dart';
import 'package:adtc_vila_uniao/services/auth_service.dart';
import 'package:adtc_vila_uniao/widgets/app_navigation_actions.dart';
import 'package:adtc_vila_uniao/widgets/member_avatar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('member registration asks to confirm the password', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberPortalScreen(authService: authService, onOpenDrawer: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ainda não tenho cadastro. Cadastrar-me'));
    await tester.pumpAndSettle();

    expect(find.text('Confirme a senha'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('pressing enter in the password field submits login', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberPortalScreen(authService: authService, onOpenDrawer: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).last);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.text('Por favor, preencha o e-mail e a senha.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('registration explains public signup and approval process', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberPortalScreen(authService: authService, onOpenDrawer: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ainda não tenho cadastro. Cadastrar-me'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Entre ou crie um cadastro'), findsOneWidget);
    expect(
      find.textContaining('Você poderá usar o app após entrar'),
      findsOneWidget,
    );
    expect(find.text('Membro da igreja'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Visitante'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('pending approval is shown after reopening the app', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'adtc_pending_approval_email': 'member@example.com',
    });
    final authService = AuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberPortalScreen(authService: authService, onOpenDrawer: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Você poderá entrar e usar os recursos básicos'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('visitor home opens the side menu without bottom navigation', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('A paz do Senhor,'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('visitante!'),
      ),
      findsOneWidget,
    );
    expect(find.text('ADTC Vila União'), findsNothing);
    expect(find.text('Sobral - CE'), findsNothing);
    expect(find.text('A paz do Senhor! Seja bem-vindo(a)'), findsNothing);
    expect(find.text('A paz do Senhor,'), findsOneWidget);
    expect(find.text('visitante!'), findsOneWidget);
    expect(find.text('Aniversariantes'), findsNothing);
    expect(find.text('Oração 12h'), findsNothing);
    expect(find.text('Programação da Semana'), findsNothing);
    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(find.text('Contribuições'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Acesse sua conta')).dy,
      greaterThan(tester.getTopLeft(find.text('Versículo do Dia')).dy),
    );
    expect(find.text('Já tenho cadastro • Entrar'), findsOneWidget);
    expect(find.text('Criar cadastro'), findsOneWidget);
    expect(find.text('Departamentos & Conjuntos'), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Abrir menu do membro').first);
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    expect(
      find.descendant(
        of: drawer,
        matching: find.text('Agenda Semanal & Mensal'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Mídia & Instagram')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Harpa Cristã')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Contribuições')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Área de Membros')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Meus dados de membro')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Notificações')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Área administrativa')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Mural de Oração')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: drawer,
        matching: find.text('Boas-Vindas aos Visitantes'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Notificações'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha os avisos que deseja receber'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Acesse sua conta'), findsOneWidget);
  });

  testWidgets('home omits the removed shortcuts and weekly preview', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text('Aniversariantes'), findsNothing);
    expect(find.text('Oração 12h'), findsNothing);
    expect(find.text('Programação da Semana'), findsNothing);
    expect(find.text('Mural Oração'), findsOneWidget);
  });

  testWidgets('home content stays centered and bounded on desktop', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    final content = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedBox && widget.constraints.maxWidth == 1040,
    );
    expect(content, findsOneWidget);
    expect(tester.getSize(content).width, 1040);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home menu button uses the member photo when available', (
    WidgetTester tester,
  ) async {
    const member = UserProfile(
      id: 'member-1',
      name: 'Pessoa Membro',
      email: 'membro@example.com',
      phone: '',
      role: 'membro',
      photoUrl: 'https://example.test/member.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppNavigationMenuButton(onPressed: _noop, user: member),
        ),
      ),
    );

    expect(find.byType(MemberAvatar), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('quick access no longer displays scales', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text('Escalas'), findsNothing);
  });

  testWidgets('member portal omits unread notifications and department roles', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Abrir menu do membro').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Seja bem-vindo'), findsOneWidget);
    expect(find.byTooltip('Entre para ver notificações'), findsNothing);
    expect(find.byTooltip('Notificações não lidas'), findsNothing);
    expect(find.text('Cargos nos departamentos'), findsNothing);
    expect(find.text('Continuar como visitante'), findsNothing);
  });

  testWidgets('department roster is hidden from visitors', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    const department = Department(
      id: 'jovens',
      name: 'Departamento de Jovens',
      conjuntoName: 'Celebra',
      description: 'Grupo de jovens.',
      responsibilities: [],
      leaderName: 'Liderança',
      meetingSchedule: 'Sábados',
      icon: Icons.groups_rounded,
      color: Color(0xFF0F766E),
      tags: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DepartmentDetailScreen(
          department: department,
          authService: authService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Membros do departamento'), findsNothing);
    final leaderCard = find.ancestor(
      of: find.text('Liderança').last,
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(leaderCard.first).onTap, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('visitor mode sees the restricted schedule details screen', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    const event = ScheduleEvent(
      id: 'event-1',
      title: 'Culto de domingo',
      subtitle: 'Celebração',
      time: '18:00',
      daysDescription: 'Domingo',
      location: 'Templo',
      type: EventType.culto,
      icon: Icons.church,
      color: Colors.blue,
      notes: 'Informações internas',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleEventDetailsScreen(
          event: event,
          authService: authService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Informações restritas'), findsOneWidget);
    expect(find.text('Informações internas'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('department details expose one edit action', (
    WidgetTester tester,
  ) async {
    const department = Department(
      id: 'jovens',
      name: 'Departamento de Jovens',
      description: 'Grupo de jovens.',
      responsibilities: [],
      leaderName: 'Liderança',
      meetingSchedule: 'Sábados',
      icon: Icons.groups_rounded,
      color: Color(0xFF0F766E),
      tags: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDepartmentDetailsScreen(
          department: department,
          onEditOptions: (_) async {},
          onDelete: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Editar departamento'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('Editar departamento'), findsNothing);
  });

  testWidgets('next event card opens restricted details for visitors', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    final detailsButton = find.text('Ver detalhes deste evento');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleEventDetailsScreen), findsOneWidget);
    expect(find.text('Informações restritas'), findsOneWidget);
    expect(find.text('Data'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('tapping an agenda event opens its details', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Agenda').first);
    await tester.tap(find.text('Agenda').first);
    await tester.pumpAndSettle();

    expect(find.text('Calendário'), findsNothing);
    expect(find.text('Domingos'), findsNothing);
    expect(find.text('Oração 12h'), findsNothing);

    final eventTitle = find.text('Oração do Meio-Dia').first;
    await tester.ensureVisible(eventTitle);
    expect(
      find.text(
        'Momento diário de busca ao Senhor, onde toda a igreja se une ao meio-dia para clamar pelas famílias, enfermos e congregação.',
      ),
      findsNothing,
    );
    expect(find.textContaining('Detalhes restritos.'), findsNothing);
    await tester.tap(eventTitle);
    await tester.pumpAndSettle();

    expect(find.text('Informações restritas'), findsOneWidget);
    expect(find.text('Intercessão Diária da Igreja'), findsNothing);
    expect(
      find.text('Templo ADTC Vila União & Corrente de Oração'),
      findsNothing,
    );
  });

  testWidgets('event details use two columns on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authService = _ApprovedMemberAuthService();
    final event = ScheduleEvent(
      id: 'event-1',
      title: 'Evento teste',
      subtitle: 'Encontro especial',
      time: '18:30',
      eventDate: DateTime(2026, 11, 15),
      daysDescription: 'Evento único',
      location: 'Templo',
      type: EventType.culto,
      icon: Icons.church,
      color: const Color(0xFF0F766E),
      notes: 'Informações complementares do evento.',
      linkUrl: 'https://example.com/evento',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleEventDetailsScreen(
          event: event,
          authService: authService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Link do evento')).dx,
      greaterThan(tester.getTopLeft(find.text('Data')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Informações')).dx,
      lessThan(tester.getTopLeft(find.text('Link do evento')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Informações complementares do evento.')).dx,
      lessThan(tester.getTopLeft(find.text('Link do evento')).dx),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('event details stay stacked on narrow screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authService = _ApprovedMemberAuthService();
    final event = ScheduleEvent(
      id: 'event-1',
      title: 'Evento teste',
      subtitle: 'Encontro especial',
      time: '18:30',
      eventDate: DateTime(2026, 11, 15),
      daysDescription: 'Evento único',
      location: 'Templo',
      type: EventType.culto,
      icon: Icons.church,
      color: const Color(0xFF0F766E),
      notes: 'Informações complementares do evento.',
      linkUrl: 'https://example.com/evento',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleEventDetailsScreen(
          event: event,
          authService: authService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Link do evento')).dy,
      greaterThan(tester.getTopLeft(find.text('Data')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('media screen displays the LGPD image-use notice', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Mídia'));
    await tester.tap(find.text('Mídia').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('AUTORIZAÇÃO DE USO DE IMAGEM'));
    expect(find.text('AUTORIZAÇÃO DE USO DE IMAGEM'), findsOneWidget);
    expect(find.textContaining('LGPD'), findsOneWidget);
  });

  testWidgets('contributions show the church Pix phone key', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authService = _ApprovedMemberAuthService();
    await tester.pumpWidget(ADTCApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Contribuições'));
    await tester.tap(find.text('Contribuições').first);
    await tester.pumpAndSettle();

    expect(find.text('88 99300-2992'), findsOneWidget);
    expect(
      find.bySemanticsLabel('QR Code Pix para contribuição'),
      findsOneWidget,
    );
    expect(find.text('Enviar comprovante pelo WhatsApp'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Dízimos, ofertas e missões')).dx,
      lessThan(tester.getTopLeft(find.text('PIX oficial')).dx),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });

  testWidgets('contributions are restricted to visitors', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await tester.pumpWidget(
      MaterialApp(home: ContributionsScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(find.text('PIX oficial'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    authService.dispose();
  });
}

class _ApprovedMemberAuthService extends AuthService {
  static const _member = UserProfile(
    id: 'member-1',
    name: 'Membro Teste',
    email: 'member@example.com',
    phone: '',
    role: 'membro',
  );

  @override
  UserProfile? get currentUser => _member;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasApprovedMemberAccess => true;

  @override
  bool get isAwaitingApproval => false;
}

void _noop() {}
