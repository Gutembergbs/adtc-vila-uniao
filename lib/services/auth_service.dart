import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../configuracao_supabase.dart';
import '../models/user_profile.dart';
import 'agenda_notification_service.dart';

class MemberAccessDeniedException implements Exception {
  final String message;
  final bool isPending;

  const MemberAccessDeniedException(this.message, {this.isPending = false});

  @override
  String toString() => message;
}

class LoginAttemptsExceededException implements Exception {
  const LoginAttemptsExceededException();

  @override
  String toString() =>
      'Acesso bloqueado após três tentativas. Entre em contato com a administração.';
}

enum MemberRegistrationResult {
  authenticated,
  emailConfirmationRequired,
  awaitingApproval,
}

class AuthService extends ChangeNotifier {
  static const _pendingEmailConfirmationKey = 'adtc_pending_email_confirmation';
  static const _pendingApprovalEmailKey = 'adtc_pending_approval_email';
  static const _webEmailConfirmationUrl = 'https://igreja-flutter.web.app';
  static const _maximumLoginAttempts = 3;

  UserProfile? _currentUser;
  String? _awaitingApprovalEmail;
  bool _isLoading = true;
  bool _passwordRecoveryPending = false;
  bool _emailConfirmationRedirectPending = false;
  int _loginAttemptsResetVersion = 0;
  StreamSubscription<AuthState>? _authStateSubscription;
  Future<void>? _emailConfirmationRedirectCheck;

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated =>
      _currentUser != null &&
      _currentUser!.id != 'guest_1' &&
      !_currentUser!.id.startsWith('visitor_');
  bool get isVisitorMode => !isAuthenticated;
  bool get isAwaitingApproval =>
      _awaitingApprovalEmail != null ||
      (_currentUser != null &&
          !_currentUser!.isVisitor &&
          _currentUser!.accessStatus == 'pendente');
  bool get hasApprovedMemberAccess =>
      isAuthenticated && _currentUser?.hasApprovedMemberAccess == true;
  bool get emailConfirmationRedirectPending =>
      _emailConfirmationRedirectPending;

  AuthService({bool emailConfirmationCallback = false}) {
    _emailConfirmationRedirectPending = emailConfirmationCallback;
    if (supabaseInicializado) {
      _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((authState) {
            if (authState.event == AuthChangeEvent.passwordRecovery) {
              _passwordRecoveryPending = true;
              notifyListeners();
            }
            if (authState.event == AuthChangeEvent.signedIn) {
              unawaited(
                _redirectToLoginAfterEmailConfirmation(
                  authState.session?.user.email,
                ).catchError((Object error, StackTrace stackTrace) {
                  debugPrint(
                    'Não foi possível redirecionar após confirmar o e-mail: '
                    '$error',
                  );
                }),
              );
            }
          });
    }
    _loadUserFromStorage();
  }

  bool get passwordRecoveryPending => _passwordRecoveryPending;
  int get loginAttemptsResetVersion => _loginAttemptsResetVersion;

  bool consumeEmailConfirmationRedirect() {
    if (!_emailConfirmationRedirectPending) return false;
    _emailConfirmationRedirectPending = false;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> sendPasswordRecoveryEmail(String email) async {
    if (!supabaseInicializado) {
      throw StateError('A conexão com o Supabase não está configurada.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      throw ArgumentError.value(email, 'email', 'Informe um e-mail válido.');
    }
    await Supabase.instance.client.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: kIsWeb ? Uri.base.origin : 'adtc-vila-uniao://reset-password',
    );
  }

  Future<int> loginFailedAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_loginAttemptsKey(email)) ?? 0;
  }

  Future<void> updatePassword(String password) async {
    if (!supabaseInicializado) {
      throw StateError('A conexão com o Supabase não está configurada.');
    }
    if (password.length < 8) {
      throw ArgumentError.value(
        password,
        'password',
        'A nova senha deve ter pelo menos 8 caracteres.',
      );
    }
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: password),
    );
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loginAttemptsKey(email));
    }
    _loginAttemptsResetVersion++;
    _passwordRecoveryPending = false;
    notifyListeners();
  }

  void dismissPasswordRecovery() {
    if (!_passwordRecoveryPending) return;
    _passwordRecoveryPending = false;
    notifyListeners();
  }

  Future<void> _loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _awaitingApprovalEmail = prefs.getString(_pendingApprovalEmailKey);
      if (supabaseInicializado) {
        final usuario = Supabase.instance.client.auth.currentUser;
        if (usuario != null) {
          await _redirectToLoginAfterEmailConfirmation(usuario.email);
          if (Supabase.instance.client.auth.currentUser == null) return;
          _currentUser = await _loadMemberProfile(usuario.id);
          await _clearAwaitingApproval();
          return;
        }
      }

      final userData = prefs.getString('adtc_user_profile');
      if (userData != null) {
        final map = jsonDecode(userData) as Map<String, dynamic>;
        final savedProfile = UserProfile.fromJson(map);
        if (savedProfile.isVisitor) _currentUser = savedProfile;
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      if (e is MemberAccessDeniedException &&
          Supabase.instance.client.auth.currentUser != null) {
        final email = Supabase.instance.client.auth.currentUser?.email;
        await Supabase.instance.client.auth.signOut();
        if (e.isPending && email != null) {
          await _markAwaitingApproval(email);
        } else {
          await _clearAwaitingApproval();
        }
      }
    } finally {
      _currentUser ??= _visitorProfile();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveUserToStorage(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adtc_user_profile', jsonEncode(user.toJson()));
  }

  Future<bool> login(String email, String password) async {
    if (!supabaseInicializado) {
      throw StateError('A conexão com o Supabase não está configurada.');
    }

    _isLoading = true;
    notifyListeners();
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptsKey = _loginAttemptsKey(normalizedEmail);
      final failedAttempts = prefs.getInt(attemptsKey) ?? 0;
      if (failedAttempts >= _maximumLoginAttempts) {
        throw const LoginAttemptsExceededException();
      }
      if (_awaitingApprovalEmail != null &&
          _awaitingApprovalEmail != normalizedEmail) {
        await _clearAwaitingApproval();
      }

      final AuthResponse resposta;
      try {
        resposta = await Supabase.instance.client.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
      } on AuthException {
        final nextAttempts = failedAttempts + 1;
        await prefs.setInt(attemptsKey, nextAttempts);
        if (nextAttempts >= _maximumLoginAttempts) {
          throw const LoginAttemptsExceededException();
        }
        rethrow;
      }
      final usuario = resposta.user;
      if (usuario == null) throw StateError('Usuário não encontrado.');

      _currentUser = await _loadMemberProfile(usuario.id);
      await prefs.remove(attemptsKey);
      await _clearAwaitingApproval();
      return true;
    } catch (error) {
      await Supabase.instance.client.auth.signOut();
      if (error is MemberAccessDeniedException && error.isPending) {
        await _markAwaitingApproval(normalizedEmail);
      } else if (error is MemberAccessDeniedException) {
        await _clearAwaitingApproval();
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cria uma conta e distingue a confirmação de e-mail da aprovação de acesso.
  Future<MemberRegistrationResult> registerMember({
    required String name,
    required String email,
    required String phone,
    required String password,
    String accountType = 'membro',
  }) async {
    if (!supabaseInicializado) {
      throw StateError('A conexão com o Supabase não está configurada.');
    }

    _isLoading = true;
    notifyListeners();
    var sessionCreated = false;
    try {
      final resposta = await Supabase.instance.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: kIsWeb ? Uri.base.origin : _webEmailConfirmationUrl,
        data: {
          'nome': name.trim(),
          'telefone': phone.trim(),
          'tipo_cadastro': accountType,
        },
      );
      final usuario = resposta.user;
      if (usuario == null) throw StateError('Não foi possível criar a conta.');
      sessionCreated = resposta.session != null;
      final prefs = await SharedPreferences.getInstance();
      if (resposta.session == null) {
        await prefs.setString(
          _pendingEmailConfirmationKey,
          email.trim().toLowerCase(),
        );
        return MemberRegistrationResult.emailConfirmationRequired;
      }

      await prefs.remove(_pendingEmailConfirmationKey);
      try {
        _currentUser = await _loadMemberProfile(usuario.id);
        await _clearAwaitingApproval();
        return MemberRegistrationResult.authenticated;
      } on MemberAccessDeniedException catch (error) {
        if (!error.isPending) rethrow;
        await Supabase.instance.client.auth.signOut();
        await _markAwaitingApproval(email);
        return MemberRegistrationResult.awaitingApproval;
      }
    } catch (_) {
      if (sessionCreated) {
        await Supabase.instance.client.auth.signOut();
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _markAwaitingApproval(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;
    _awaitingApprovalEmail = normalizedEmail;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingApprovalEmailKey, normalizedEmail);
    notifyListeners();
  }

  Future<void> _clearAwaitingApproval() async {
    _awaitingApprovalEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingApprovalEmailKey);
    notifyListeners();
  }

  Future<void> _redirectToLoginAfterEmailConfirmation(String? email) {
    final ongoingCheck = _emailConfirmationRedirectCheck;
    if (ongoingCheck != null) return ongoingCheck;

    final check = _checkEmailConfirmation(email);
    late final Future<void> trackedCheck;
    trackedCheck = check.whenComplete(() {
      if (identical(_emailConfirmationRedirectCheck, trackedCheck)) {
        _emailConfirmationRedirectCheck = null;
      }
    });
    _emailConfirmationRedirectCheck = trackedCheck;
    return trackedCheck;
  }

  Future<void> _checkEmailConfirmation(String? email) async {
    if (email == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pendingEmail = prefs.getString(_pendingEmailConfirmationKey);
    if (pendingEmail != email.toLowerCase()) return;

    await Supabase.instance.client.auth.signOut();
    await prefs.remove(_pendingEmailConfirmationKey);
    _currentUser = null;
    _emailConfirmationRedirectPending = true;
    notifyListeners();
  }

  /// Atualiza dados editáveis do cartão e recarrega o perfil autenticado.
  Future<void> updateMemberProfile({
    required String name,
    required String nickname,
    required String phone,
    required String congregation,
    required String baptismDate,
    required String birthDate,
    required String department,
  }) async {
    if (!supabaseInicializado ||
        _currentUser == null ||
        _currentUser!.isVisitor) {
      throw StateError('Entre na sua conta de membro para editar o perfil.');
    }

    final usuarioId = _currentUser!.id;
    await Supabase.instance.client
        .from('membros')
        .update({
          'nome': name.trim(),
          'apelido': nickname.trim().isEmpty ? null : nickname.trim(),
          'telefone': phone.trim(),
          'congregacao': congregation.trim(),
          'data_batismo': baptismDate.trim().isEmpty
              ? null
              : baptismDate.trim(),
          'data_nascimento': birthDate.trim().isEmpty ? null : birthDate.trim(),
          'departamento': department.trim(),
        })
        .eq('usuario_id', usuarioId);
    _currentUser = await _reloadMemberProfile(usuarioId);
    notifyListeners();
  }

  Future<void> updateMemberPhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!supabaseInicializado ||
        _currentUser == null ||
        _currentUser!.isVisitor) {
      throw StateError('Entre na sua conta de membro para alterar a foto.');
    }

    final userId = _currentUser!.id;
    if (Supabase.instance.client.auth.currentUser?.id != userId) {
      await Supabase.instance.client.auth.signOut();
      _currentUser = null;
      notifyListeners();
      throw const MemberAccessDeniedException(
        'Sua sessão mudou. Entre novamente com a conta de membro que possui acesso autorizado.',
      );
    }
    final photoPath = '$userId/perfil';
    await Supabase.instance.client.storage
        .from('fotos-membros')
        .uploadBinary(
          photoPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await Supabase.instance.client
        .from('membros')
        .update({'foto_path': photoPath})
        .eq('usuario_id', userId);
    _currentUser = await _reloadMemberProfile(userId);
    notifyListeners();
  }

  Future<UserProfile> _reloadMemberProfile(String userId) async {
    try {
      return await _loadMemberProfile(userId);
    } on MemberAccessDeniedException {
      await Supabase.instance.client.auth.signOut();
      _currentUser = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Carrega o cadastro ativo correspondente à sessão Auth atual.
  Future<UserProfile> _loadMemberProfile(String userId) async {
    final visitorRow = await Supabase.instance.client
        .from('visitantes')
        .select()
        .eq('usuario_id', userId)
        .maybeSingle();
    if (visitorRow != null) {
      return UserProfile.fromVisitorDatabase(
        Map<String, dynamic>.from(visitorRow),
      );
    }

    final row = await Supabase.instance.client
        .from('membros')
        .select()
        .eq('usuario_id', userId)
        .maybeSingle();
    if (row == null) {
      throw const MemberAccessDeniedException(
        'Não foi encontrado um cadastro de membro vinculado a esta conta. '
        'Peça ajuda à secretaria.',
      );
    }
    final accessStatus = row['status_acesso'] as String? ?? 'autorizado';
    if (accessStatus == 'bloqueado' ||
        (row['ativo'] != true && accessStatus != 'pendente')) {
      throw MemberAccessDeniedException(
        'O acesso ao portal está bloqueado. Entre em contato com a secretaria.',
      );
    }
    final adminRow = await Supabase.instance.client
        .from('administradores')
        .select('usuario_id')
        .eq('usuario_id', userId)
        .maybeSingle();
    final photoPath = row['foto_path'] as String?;
    final photoUrl = photoPath == null
        ? null
        : await Supabase.instance.client.storage
              .from('fotos-membros')
              .createSignedUrl(photoPath, 604800);
    final profile = UserProfile.fromDatabase(
      Map<String, dynamic>.from(row),
      isAdmin: adminRow != null,
      photoUrl: photoUrl,
    );
    await AgendaNotificationService.registerCurrentDeviceToken();
    return profile;
  }

  /// Perfil local sem privilégios para quem escolhe continuar como visitante.
  UserProfile _visitorProfile() => const UserProfile(
    id: 'guest_1',
    name: 'Irmão(ã) Visitante',
    email: '',
    phone: '',
    role: 'visitante',
    congregation: 'ADTC Vila União - Sobral',
  );

  String _loginAttemptsKey(String email) =>
      'adtc_login_failed_attempts_${email.trim().toLowerCase()}';

  Future<void> registerVisitor({
    required String name,
    required String phone,
    String? neighborhood,
    String? prayerNeed,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    final visitorUser = UserProfile(
      id: 'visitor_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Visitante Querido(a)' : name.trim(),
      email: '',
      phone: phone,
      role: 'visitante',
      department: neighborhood != null ? 'Bairro: $neighborhood' : 'Visitante',
      congregation: 'ADTC Vila União - Sobral',
    );

    _currentUser = visitorUser;
    await _saveUserToStorage(visitorUser);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> switchToVisitorMode() async {
    if (supabaseInicializado) {
      await AgendaNotificationService.unregisterCurrentDeviceToken();
      await Supabase.instance.client.auth.signOut();
    }
    _currentUser = _visitorProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('adtc_user_profile');
    notifyListeners();
  }

  Future<void> logout() async {
    await switchToVisitorMode();
  }
}
