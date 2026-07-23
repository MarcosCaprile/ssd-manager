import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../utils/user_error_message.dart';
import 'api_providers.dart';

enum AuthStatus { checking, unauthenticated, authenticated }

class AuthState {
  const AuthState({required this.status, this.user, this.errorMessage});

  const AuthState.checking() : this(status: AuthStatus.checking);
  const AuthState.unauthenticated({String? errorMessage})
    : this(status: AuthStatus.unauthenticated, errorMessage: errorMessage);
  const AuthState.authenticated(User user)
    : this(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final User? user;
  final String? errorMessage;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.checking();

  Future<void> bootstrap() async {
    state = const AuthState.checking();
    try {
      final user = await ref.read(authRepositoryProvider).bootstrap();
      state = user == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(user);
    } catch (_) {
      await ref.read(authRepositoryProvider).clearLocalSession();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login(String identifier, String password) async {
    state = const AuthState.checking();
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password);
      state = AuthState.authenticated(user);
    } catch (error) {
      state = AuthState.unauthenticated(
        errorMessage: userErrorMessage(
          error,
          fallback: 'Die Anmeldung ist fehlgeschlagen. Prüfe deine Eingaben.',
        ),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required bool revokeOtherDevices,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          revokeOtherDevices: revokeOtherDevices,
        );
    state = AuthState.authenticated(user);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
