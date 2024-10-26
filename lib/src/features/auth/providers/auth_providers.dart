import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

final supabase = Supabase.instance.client;

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  FutureOr<User?> build() async {
    return supabase.auth.currentSession?.user;
  }

  Future<bool> login(String email) async {
    try {
      state = const AsyncValue.loading();
      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'http://localhost:3000/auth/callback',
      );
      state = AsyncValue.data(supabase.auth.currentUser);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      state = const AsyncValue.loading();
      await supabase.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

@riverpod
bool isAuthenticated(Ref ref) {
  final auth = ref.watch(authProvider);
  return auth.valueOrNull != null;
}