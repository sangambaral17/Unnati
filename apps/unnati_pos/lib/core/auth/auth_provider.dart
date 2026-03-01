// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'role_guard.dart';

/// Auth state holding the currently logged-in staff's identity.
class AuthState {
  final String? staffId;
  final String? name;
  final StaffRole role;
  final String? deviceId;
  final String? token;
  final bool isAuthenticated;

  const AuthState({
    this.staffId,
    this.name,
    this.role = StaffRole.cashier,
    this.deviceId,
    this.token,
    this.isAuthenticated = false,
  });

  const AuthState.unauthenticated()
      : staffId = null,
        name = null,
        role = StaffRole.cashier,
        deviceId = null,
        token = null,
        isAuthenticated = false;

  AuthState copyWith({
    String? staffId,
    String? name,
    StaffRole? role,
    String? deviceId,
    String? token,
    bool? isAuthenticated,
  }) {
    return AuthState(
      staffId: staffId ?? this.staffId,
      name: name ?? this.name,
      role: role ?? this.role,
      deviceId: deviceId ?? this.deviceId,
      token: token ?? this.token,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Riverpod StateNotifier for auth state management.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.unauthenticated());

  Future<void> login({
    required String staffId,
    required String name,
    required StaffRole role,
    required String token,
    required String deviceId,
  }) async {
    state = AuthState(
      staffId: staffId,
      name: name,
      role: role,
      token: token,
      deviceId: deviceId,
      isAuthenticated: true,
    );
  }

  void logout() {
    state = const AuthState.unauthenticated();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
