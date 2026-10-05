import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthRepository _repository;

  AuthNotifier(this._ref, this._repository)
      : super(const AuthState(status: AuthStatus.initial)) {
    // When a request fails even after token refresh, the ApiClient has already
    // cleared tokens — reflect that in auth state so the router returns to login.
    _ref.read(apiClientProvider).onSessionExpired = () {
      state = const AuthState(status: AuthStatus.unauthenticated);
    };
    restoreSession();
  }

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
        // Hydrate persisted user preferences
        if (user.locale.isNotEmpty) {
          _ref.read(localeProvider.notifier).state = Locale(user.locale);
        }
        if (user.numeralSystem.isNotEmpty) {
          _ref.read(numeralSystemProvider.notifier).state = user.numeralSystem;
        }
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      if (user.locale.isNotEmpty) {
        _ref.read(localeProvider.notifier).state = Locale(user.locale);
      }
      if (user.numeralSystem.isNotEmpty) {
        _ref.read(numeralSystemProvider.notifier).state = user.numeralSystem;
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: formatApiErrorMessage(e),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String dateOfBirth,
    required double heightCm,
    String sexForCalculation = 'unspecified',
    required bool termsConsent,
    required bool healthConsent,
    required bool aiConsent,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final currentLocale = _ref.read(localeProvider).languageCode;
      final currentNumeral = _ref.read(numeralSystemProvider);

      final user = await _repository.register(
        email: email,
        password: password,
        dateOfBirth: dateOfBirth,
        heightCm: heightCm,
        sexForCalculation: sexForCalculation,
        locale: currentLocale,
        numeralSystem: currentNumeral,
        termsConsent: termsConsent,
        healthConsent: healthConsent,
        aiConsent: aiConsent,
      );
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: formatApiErrorMessage(e),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(ref, repo);
});
