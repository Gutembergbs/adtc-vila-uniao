import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/schedule_event.dart';
import 'web_push_notifications_stub.dart'
    if (dart.library.html) 'web_push_notifications_web.dart'
    as web_push;

@pragma('vm:entry-point')
Future<void> agendaFirebaseBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  if (message.notification != null) return;

  await AgendaNotificationService.mostrarPushEmSegundoPlano(message);
}

/// Preferências de lembretes e avisos de mudanças guardadas neste aparelho.
class AgendaNotificationPreferences {
  final bool lembretesAtivos;
  final bool avisarMudancas;
  final int minutosAntes;

  const AgendaNotificationPreferences({
    this.lembretesAtivos = false,
    this.avisarMudancas = false,
    this.minutosAntes = 30,
  });
}

/// Gerencia lembretes locais e a inscrição opcional no tópico de notificações.
class AgendaNotificationService {
  AgendaNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;
  static bool _firebaseInicializado = false;
  static bool _pushAgendaAtivo = false;
  static bool _listenerPushRegistrado = false;
  static bool _listenerTokenRegistrado = false;
  static String? _registeredDeviceToken;
  static String? _lastPushRegistrationError;
  static ValueChanged<String>? _eventTapHandler;
  static String? _pendingEventId;
  static ValueChanged<String>? _noticeTapHandler;
  static String? _pendingNoticeId;
  static const _chaveTokenDispositivo = 'notificacao_token_dispositivo';
  static const _chaveLembretes = 'notificacoes_agenda_lembretes';
  static const _chaveMudancas = 'notificacoes_agenda_mudancas';
  static const _chaveMinutos = 'notificacoes_agenda_minutos_antes';
  static const _topicoAgenda = 'agenda';
  static const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static const _firebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
  );
  static const _firebaseWebVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
  );
  static const _firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const _firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const _firebaseBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );

  /// Indica se as opções públicas do aplicativo Firebase foram incluídas no build.
  static bool get pushFirebaseConfigurado =>
      _firebaseSenderId.isNotEmpty &&
      _firebaseProjectId.isNotEmpty &&
      (kIsWeb
          ? _firebaseWebApiKey.isNotEmpty &&
                _firebaseWebAppId.isNotEmpty &&
                _firebaseWebVapidKey.isNotEmpty
          : _firebaseApiKey.isNotEmpty && _firebaseAppId.isNotEmpty);

  static String? get lastPushRegistrationError => _lastPushRegistrationError;

  /// Informa se este aparelho confirmou inscrição no tópico de push.
  static bool get pushAgendaAtivo => _pushAgendaAtivo;

  static String _describePushRegistrationError(Object error) {
    final details = error.toString();
    final normalized = details.toLowerCase();
    if (normalized.contains('api key not valid') ||
        normalized.contains('invalid_api_key')) {
      return 'A chave API do Firebase Web está inválida. Atualize FIREBASE_WEB_API_KEY com a chave do app Web deste projeto e publique novamente.';
    }
    if (normalized.contains('permission denied') ||
        normalized.contains('registration failed')) {
      return 'O navegador recusou o registro de notificações. Permita notificações para https://igreja-flutter.web.app nas configurações do navegador e, se usar o app instalado, confira também a permissão de notificações desse app.';
    }
    return 'Falha ao registrar o token no navegador: $details';
  }

  /// Define quem recebe eventos abertos por notificações.
  static void setEventTapHandler(ValueChanged<String>? handler) {
    _eventTapHandler = handler;
    final pendingEventId = _pendingEventId;
    if (handler != null && pendingEventId != null) {
      _pendingEventId = null;
      handler(pendingEventId);
    }
  }

  static void openEventFromInbox(String eventId) {
    _dispatchEventTap(eventId);
  }

  static void setNoticeTapHandler(ValueChanged<String>? handler) {
    _noticeTapHandler = handler;
    final pendingNoticeId = _pendingNoticeId;
    if (handler != null && pendingNoticeId != null) {
      _pendingNoticeId = null;
      handler(pendingNoticeId);
    }
  }

  static void _dispatchEventTap(String? eventId) {
    final normalizedEventId = eventId?.trim();
    if (normalizedEventId == null || normalizedEventId.isEmpty) return;
    final handler = _eventTapHandler;
    if (handler == null) {
      _pendingEventId = normalizedEventId;
    } else {
      handler(normalizedEventId);
    }
  }

  static void _dispatchNoticeTap(String? noticeId) {
    final normalizedNoticeId = noticeId?.trim();
    if (normalizedNoticeId == null || normalizedNoticeId.isEmpty) return;
    final handler = _noticeTapHandler;
    if (handler == null) {
      _pendingNoticeId = normalizedNoticeId;
    } else {
      handler(normalizedNoticeId);
    }
  }

  static void _dispatchLocalNotificationTap(String? payload) {
    if (payload?.startsWith('notice:') == true) {
      _dispatchNoticeTap(payload!.substring('notice:'.length));
    } else if (payload?.startsWith('event:') == true) {
      _dispatchEventTap(payload!.substring('event:'.length));
    } else {
      _dispatchEventTap(payload);
    }
  }

  /// Registra o handler antes do runApp para mensagens recebidas em segundo plano.
  static void registrarHandlerSegundoPlano() {
    if (!_suportaNotificacoesLocais || !pushFirebaseConfigurado) return;
    FirebaseMessaging.onBackgroundMessage(agendaFirebaseBackgroundHandler);
  }

  /// Mostra mensagens FCM somente de dados, que o sistema não apresenta sozinho.
  static Future<void> mostrarPushEmSegundoPlano(RemoteMessage mensagem) async {
    if (!_suportaNotificacoesLocais) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _criarCanaisAndroid();
    await _mostrarNotificacao(
      id: mensagem.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: mensagem.data['title']?.toString() ?? 'Agenda da congregação',
      body:
          mensagem.data['body']?.toString() ??
          'A programação da congregação foi alterada.',
      payload: mensagem.data['eventId'] == null
          ? null
          : 'event:${mensagem.data['eventId']}',
    );
  }

  /// Prepara plugin e fuso horário sem pedir permissão antes da escolha do usuário.
  static Future<void> inicializar() async {
    if (_inicializado) return;

    if (_suportaNotificacoesLocais) {
      timezone_data.initializeTimeZones();
      try {
        final fuso = await FlutterTimezone.getLocalTimezone();
        timezone.setLocalLocation(timezone.getLocation(fuso.identifier));
      } catch (_) {
        timezone.setLocalLocation(timezone.getLocation('America/Fortaleza'));
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          _dispatchLocalNotificationTap(response.payload);
        },
      );
      await _criarCanaisAndroid();
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _dispatchEventTap(launchDetails?.notificationResponse?.payload);
      }
    }
    _inicializado = true;

    final preferencias = await carregarPreferencias();
    final firebaseDisponivel = await _inicializarFirebase();
    if ((preferencias.avisarMudancas ||
            (kIsWeb && preferencias.lembretesAtivos)) &&
        firebaseDisponivel &&
        kIsWeb) {
      _pushAgendaAtivo = true;
    } else if (preferencias.avisarMudancas && firebaseDisponivel) {
      await FirebaseMessaging.instance.subscribeToTopic(_topicoAgenda);
      _pushAgendaAtivo = true;
    }
  }

  /// Informa se este dispositivo consegue apresentar notificações nativas.
  static bool get _suportaNotificacoesLocais =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Cria os canais antes de o FCM tentar exibir uma notificação em background.
  static Future<void> _criarCanaisAndroid() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'agenda_alteracoes',
        'Alterações na agenda',
        description: 'Mudanças em cultos e eventos da congregação.',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'agenda_cultos',
        'Lembretes da agenda',
        description: 'Avisos antes dos cultos e reuniões.',
        importance: Importance.high,
      ),
    );
  }

  /// Lê as preferências locais, usando notificações desligadas por padrão.
  static Future<AgendaNotificationPreferences> carregarPreferencias() async {
    final armazenamento = await SharedPreferences.getInstance();
    return AgendaNotificationPreferences(
      lembretesAtivos: armazenamento.getBool(_chaveLembretes) ?? false,
      avisarMudancas: armazenamento.getBool(_chaveMudancas) ?? false,
      minutosAntes: armazenamento.getInt(_chaveMinutos) ?? 30,
    );
  }

  /// Salva preferências e solicita autorização somente quando algo for ativado.
  static Future<bool> salvarPreferencias({
    required bool lembretesAtivos,
    required bool avisarMudancas,
    required int minutosAntes,
    required List<ScheduleEvent> eventos,
  }) async {
    final pushWebAtivo = kIsWeb && (lembretesAtivos || avisarMudancas);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (pushWebAtivo && userId == null) {
      _lastPushRegistrationError =
          'Entre na conta de membro antes de ativar notificações no navegador.';
      return false;
    }
    if ((lembretesAtivos || avisarMudancas) &&
        !await _solicitarPermissao(
          agendaEnabled: avisarMudancas,
          agendaRemindersEnabled: lembretesAtivos,
          agendaReminderMinutes: minutosAntes,
        )) {
      return false;
    }

    final armazenamento = await SharedPreferences.getInstance();
    await armazenamento.setBool(_chaveLembretes, lembretesAtivos);
    await armazenamento.setInt(_chaveMinutos, minutosAntes);

    var pushAtivo = false;
    if (avisarMudancas || (kIsWeb && lembretesAtivos)) {
      pushAtivo = await _inscreverNoTopicoAgenda();
    } else {
      await _cancelarInscricaoNoTopico();
    }
    if (!lembretesAtivos && !avisarMudancas && userId != null) {
      await _desativarPreferenciaPush(userId);
    } else if (userId != null &&
        !await registerCurrentDeviceToken(
          agendaEnabled: kIsWeb ? avisarMudancas : avisarMudancas && pushAtivo,
          agendaRemindersEnabled: kIsWeb && lembretesAtivos,
          agendaReminderMinutes: minutosAntes,
          notificationsEnabled: lembretesAtivos || avisarMudancas,
        )) {
      debugPrint(
        'O token deste aparelho não foi registrado para avisos pessoais.',
      );
      if (pushWebAtivo) {
        await armazenamento.setBool(_chaveMudancas, false);
        await armazenamento.setBool(_chaveLembretes, false);
        throw StateError(
          _lastPushRegistrationError ??
              'O navegador não conseguiu registrar este aparelho para notificações.',
        );
      }
    }
    await armazenamento.setBool(
      _chaveMudancas,
      kIsWeb ? avisarMudancas : avisarMudancas && pushAtivo,
    );

    if (lembretesAtivos && !kIsWeb) {
      await sincronizarLembretes(eventos);
    } else if (_inicializado && !kIsWeb) {
      await _plugin.cancelAll();
    }
    return true;
  }

  /// Inicializa Firebase somente quando o build contém as opções necessárias.
  static Future<bool> _inicializarFirebase() async {
    if (_firebaseInicializado) return true;
    if (!pushFirebaseConfigurado ||
        (!kIsWeb &&
            defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _lastPushRegistrationError = kIsWeb
          ? 'A configuração de notificações do Firebase Web está incompleta.'
          : null;
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: kIsWeb ? _firebaseWebApiKey : _firebaseApiKey,
            appId: kIsWeb ? _firebaseWebAppId : _firebaseAppId,
            messagingSenderId: _firebaseSenderId,
            projectId: _firebaseProjectId,
            authDomain: _firebaseAuthDomain.isEmpty
                ? null
                : _firebaseAuthDomain,
            storageBucket: _firebaseBucket.isEmpty ? null : _firebaseBucket,
            iosBundleId: _firebaseIosBundleId.isEmpty
                ? null
                : _firebaseIosBundleId,
          ),
        );
      }
      if (kIsWeb && !await FirebaseMessaging.instance.isSupported()) {
        _lastPushRegistrationError =
            'Este navegador ou modo de instalação não oferece suporte a notificações push.';
        return false;
      }

      if (!_listenerPushRegistrado) {
        FirebaseMessaging.onMessage.listen(_mostrarPushEmPrimeiroPlano);
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final noticeId = message.data['noticeId']?.toString();
          if (noticeId != null) {
            _dispatchNoticeTap(noticeId);
          } else {
            _dispatchEventTap(message.data['eventId']?.toString());
          }
        });
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        final noticeId = initialMessage?.data['noticeId']?.toString();
        if (noticeId != null) {
          _dispatchNoticeTap(noticeId);
        } else {
          _dispatchEventTap(initialMessage?.data['eventId']?.toString());
        }
        _listenerPushRegistrado = true;
      }
      _firebaseInicializado = true;
      return true;
    } catch (erro) {
      _lastPushRegistrationError =
          'Não foi possível inicializar as notificações Firebase: $erro';
      debugPrint('Não foi possível inicializar o FCM: $erro');
      return false;
    }
  }

  static Future<bool> registerCurrentDeviceToken({
    bool? agendaEnabled,
    bool? agendaRemindersEnabled,
    int? agendaReminderMinutes,
    bool? notificationsEnabled,
  }) async {
    _lastPushRegistrationError = null;
    if (!await _inicializarFirebase()) {
      _lastPushRegistrationError ??=
          'Não foi possível inicializar o serviço de notificações.';
      return false;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _lastPushRegistrationError =
          'Entre na conta de membro antes de ativar notificações.';
      return false;
    }
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        _lastPushRegistrationError =
            'A permissão de notificações não está autorizada para este site/app instalado.';
        return false;
      }
      if (!_listenerTokenRegistrado) {
        // The Firebase Admin SDK sends to FCM registration tokens, not installation IDs.
        // ignore: deprecated_member_use
        FirebaseMessaging.instance.onTokenRefresh.listen((
          refreshedToken,
        ) async {
          _registeredDeviceToken = refreshedToken;
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          try {
            final preferences = await SharedPreferences.getInstance();
            await preferences.setString(_chaveTokenDispositivo, refreshedToken);
            if (currentUserId != null) {
              await _saveDeviceToken(
                currentUserId,
                refreshedToken,
                agendaEnabled:
                    kIsWeb && (preferences.getBool(_chaveMudancas) ?? false),
                agendaRemindersEnabled:
                    kIsWeb && (preferences.getBool(_chaveLembretes) ?? false),
                agendaReminderMinutes: preferences.getInt(_chaveMinutos) ?? 30,
                notificationsEnabled:
                    (preferences.getBool(_chaveMudancas) ?? false) ||
                    (preferences.getBool(_chaveLembretes) ?? false),
              );
            }
          } catch (error) {
            debugPrint('Não foi possível atualizar o token push: $error');
          }
        });
        _listenerTokenRegistrado = true;
      }
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _firebaseWebVapidKey : null,
        serviceWorkerScriptPath: kIsWeb
            ? _firebaseMessagingServiceWorkerPath
            : null,
      );
      if (token == null || token.isEmpty) {
        _lastPushRegistrationError =
            'O navegador não retornou um token de notificações. Verifique o service worker e a chave VAPID do Firebase.';
        return false;
      }
      _registeredDeviceToken = token;
      final preferences = await SharedPreferences.getInstance();
      await _saveDeviceToken(
        userId,
        token,
        agendaEnabled:
            kIsWeb &&
            (agendaEnabled ?? (preferences.getBool(_chaveMudancas) ?? false)),
        agendaRemindersEnabled:
            kIsWeb &&
            (agendaRemindersEnabled ??
                (preferences.getBool(_chaveLembretes) ?? false)),
        agendaReminderMinutes:
            agendaReminderMinutes ?? preferences.getInt(_chaveMinutos) ?? 30,
        notificationsEnabled:
            notificationsEnabled ??
            ((preferences.getBool(_chaveMudancas) ?? false) ||
                (preferences.getBool(_chaveLembretes) ?? false)),
      );
      await preferences.setString(_chaveTokenDispositivo, token);
      return true;
    } catch (error) {
      _lastPushRegistrationError = _describePushRegistrationError(error);
      debugPrint('Não foi possível registrar o token push do membro: $error');
      return false;
    }
  }

  static Future<bool> unregisterCurrentDeviceToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final token =
          _registeredDeviceToken ??
          preferences.getString(_chaveTokenDispositivo);
      if (token == null || token.isEmpty) return true;
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
      await preferences.remove(_chaveTokenDispositivo);
      return true;
    } catch (error) {
      debugPrint('Não foi possível remover o token push do membro: $error');
      return false;
    }
  }

  static Future<void> _saveDeviceToken(
    String userId,
    String token, {
    required bool agendaEnabled,
    required bool agendaRemindersEnabled,
    required int agendaReminderMinutes,
    required bool notificationsEnabled,
  }) async {
    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    await Supabase.instance.client.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'agenda_enabled': agendaEnabled,
      'agenda_reminders_enabled': agendaRemindersEnabled,
      'agenda_reminder_minutes': agendaReminderMinutes,
      'notifications_enabled': notificationsEnabled,
    }, onConflict: 'user_id,token');
  }

  static Future<void> _desativarPreferenciaPush(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final token =
        _registeredDeviceToken ?? preferences.getString(_chaveTokenDispositivo);
    if (token == null || token.isEmpty) return;
    await Supabase.instance.client
        .from('device_tokens')
        .update({
          'agenda_enabled': false,
          'agenda_reminders_enabled': false,
          'notifications_enabled': false,
        })
        .eq('user_id', userId)
        .eq('token', token);
  }

  /// Solicita autorização e inscreve este aparelho nas mudanças da agenda.
  static Future<bool> _inscreverNoTopicoAgenda() async {
    if (!await _inicializarFirebase()) return false;
    if (kIsWeb) {
      _pushAgendaAtivo = true;
      return true;
    }
    try {
      final permissao = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permissao.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
      await FirebaseMessaging.instance.subscribeToTopic(_topicoAgenda);
      _pushAgendaAtivo = true;
      return true;
    } catch (erro) {
      debugPrint('Não foi possível ativar push da agenda: $erro');
      return false;
    }
  }

  /// Remove este aparelho do tópico quando a preferência é desligada.
  static Future<void> _cancelarInscricaoNoTopico() async {
    if (kIsWeb) {
      _pushAgendaAtivo = false;
      return;
    }
    if (!await _inicializarFirebase()) {
      _pushAgendaAtivo = false;
      return;
    }
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_topicoAgenda);
    } catch (erro) {
      debugPrint('Não foi possível desativar push da agenda: $erro');
    } finally {
      _pushAgendaAtivo = false;
    }
  }

  /// Exibe localmente mensagens FCM recebidas enquanto o app está aberto.
  static Future<void> _mostrarPushEmPrimeiroPlano(
    RemoteMessage mensagem,
  ) async {
    if (!_inicializado) return;
    final titulo =
        mensagem.notification?.title ??
        mensagem.data['title']?.toString() ??
        'Agenda da congregação';
    final corpo =
        mensagem.notification?.body ??
        mensagem.data['body']?.toString() ??
        'A programação foi alterada.';
    if (kIsWeb) {
      web_push.showForegroundNotification(titulo, corpo);
      return;
    }
    await _mostrarNotificacao(
      id: mensagem.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: titulo,
      body: corpo,
      payload: mensagem.data['noticeId'] != null
          ? 'notice:${mensagem.data['noticeId']}'
          : mensagem.data['eventId'] == null
          ? null
          : 'event:${mensagem.data['eventId']}',
    );
  }

  static Future<void> _mostrarNotificacao({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'agenda_alteracoes',
          'Alterações na agenda',
          channelDescription: 'Mudanças em cultos e eventos da congregação.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Pede permissão de notificações ao sistema operacional.
  static Future<bool> _solicitarPermissao({
    required bool agendaEnabled,
    required bool agendaRemindersEnabled,
    required int agendaReminderMinutes,
  }) async {
    if (!_suportaNotificacoesLocais && !kIsWeb) return false;
    await inicializar();

    if (kIsWeb) {
      if (!await _inicializarFirebase()) return false;
      try {
        var permission = await FirebaseMessaging.instance
            .getNotificationSettings();
        if (permission.authorizationStatus != AuthorizationStatus.authorized &&
            permission.authorizationStatus != AuthorizationStatus.provisional) {
          permission = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
        }
        if (permission.authorizationStatus != AuthorizationStatus.authorized &&
            permission.authorizationStatus != AuthorizationStatus.provisional) {
          _lastPushRegistrationError =
              'A permissão deste site/app está negada ou não foi concedida. Habilite notificações nas configurações do navegador e tente novamente.';
          return false;
        }
        return await registerCurrentDeviceToken(
          agendaEnabled: agendaEnabled,
          agendaRemindersEnabled: agendaRemindersEnabled,
          agendaReminderMinutes: agendaReminderMinutes,
        );
      } catch (error) {
        _lastPushRegistrationError =
            'Não foi possível verificar a permissão ou registrar o navegador: $error';
        debugPrint(
          'Não foi possível solicitar permissão push no navegador: $error',
        );
        return false;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final concedida = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return concedida ?? false;
    }

    final concedida = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return concedida ?? false;
  }

  static String get _firebaseMessagingServiceWorkerPath {
    final config = <String, String>{
      'apiKey': _firebaseWebApiKey,
      'appId': _firebaseWebAppId,
      'messagingSenderId': _firebaseSenderId,
      'projectId': _firebaseProjectId,
    };
    if (_firebaseAuthDomain.isNotEmpty) {
      config['authDomain'] = _firebaseAuthDomain;
    }
    if (_firebaseBucket.isNotEmpty) {
      config['storageBucket'] = _firebaseBucket;
    }
    return Uri(
      path: '/firebase-messaging-sw.js',
      queryParameters: config,
    ).toString();
  }

  /// Recalcula até 45 dias de lembretes para não acumular alarmes antigos.
  static Future<void> sincronizarLembretes(List<ScheduleEvent> eventos) async {
    if (!_inicializado || !_suportaNotificacoesLocais) {
      return;
    }
    final preferencias = await carregarPreferencias();
    if (!preferencias.lembretesAtivos) return;

    await _plugin.cancelAll();
    final agora = DateTime.now();
    final agendamentosPorHorario =
        <DateTime, ({DateTime horario, ScheduleEvent evento})>{};

    for (var deslocamento = 0; deslocamento <= 45; deslocamento++) {
      final dia = DateTime(agora.year, agora.month, agora.day + deslocamento);
      for (final evento in eventos) {
        if (!_ocorreNoDia(evento, dia)) continue;
        final horarioEvento = _horarioDoEvento(evento, dia);
        if (horarioEvento == null) continue;
        final horarioAviso = horarioEvento.subtract(
          Duration(minutes: preferencias.minutosAntes),
        );
        if (horarioAviso.isAfter(agora)) {
          final agendamento = agendamentosPorHorario[horarioAviso];
          if (agendamento == null ||
              (evento.monthlyTheme && !agendamento.evento.monthlyTheme)) {
            agendamentosPorHorario[horarioAviso] = (
              horario: horarioAviso,
              evento: evento,
            );
          }
        }
      }
    }

    final agendamentos = agendamentosPorHorario.values.toList();
    agendamentos.sort(
      (primeiro, segundo) => primeiro.horario.compareTo(segundo.horario),
    );
    for (final agendamento in agendamentos.take(50)) {
      await _plugin.zonedSchedule(
        id: _idNotificacao(agendamento.evento.id, agendamento.horario),
        title:
            '${_eventReminderTitle(agendamento.evento.type)}: '
            '${agendamento.evento.title}',
        body:
            'Começa em ${preferencias.minutosAntes} min • ${agendamento.evento.location}',
        scheduledDate: timezone.TZDateTime.from(
          agendamento.horario,
          timezone.local,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'agenda_cultos',
            'Lembretes da agenda',
            channelDescription: 'Avisos antes dos eventos da agenda.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: agendamento.evento.id,
      );
    }
  }

  static String _eventReminderTitle(EventType type) => switch (type) {
    EventType.culto => 'Culto próximo',
    EventType.oracao => 'Oração próxima',
    EventType.ensaio => 'Ensaio próximo',
    EventType.estudo => 'Estudo próximo',
    EventType.consagracao => 'Consagração próxima',
    EventType.missao => 'Missão próxima',
    EventType.especial => 'Evento próximo',
  };

  /// Confere se um compromisso semanal ou mensal ocorre na data selecionada.
  static bool _ocorreNoDia(ScheduleEvent evento, DateTime dia) {
    if (evento.eventDate != null) {
      return evento.eventDate!.year == dia.year &&
          evento.eventDate!.month == dia.month &&
          evento.eventDate!.day == dia.day;
    }
    if (evento.monthlyTheme) {
      final recorrencia = evento.recurringCycle ?? evento.daysDescription;
      final numero = int.tryParse(
        RegExp(r'\d+').firstMatch(recorrencia)?.group(0) ?? '',
      );
      return dia.weekday == DateTime.sunday &&
          numero != null &&
          ((dia.day - 1) ~/ 7) + 1 == numero;
    }
    return evento.dayOfWeek == null || evento.dayOfWeek == dia.weekday;
  }

  /// Combina dia e horário cadastrado, ignorando registros malformados.
  static DateTime? _horarioDoEvento(ScheduleEvent evento, DateTime dia) {
    final partes = evento.time.split(':');
    if (partes.length < 2) return null;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null || hora > 23 || minuto > 59) return null;
    return DateTime(dia.year, dia.month, dia.day, hora, minuto);
  }

  /// Gera um identificador estável entre inicializações e dias de culto.
  static int _idNotificacao(String texto, DateTime data) {
    var hash = 0x811c9dc5;
    for (final unidade in texto.codeUnits) {
      hash = ((hash ^ unidade) * 0x01000193) & 0x7fffffff;
    }
    hash = ((hash ^ data.year) * 0x01000193) & 0x7fffffff;
    hash = ((hash ^ data.month) * 0x01000193) & 0x7fffffff;
    hash = ((hash ^ data.day) * 0x01000193) & 0x7fffffff;
    return hash;
  }
}
