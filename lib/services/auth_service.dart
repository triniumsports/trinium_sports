import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String userRole,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user == null) {
      throw Exception('Não foi possível criar o usuário.');
    }

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': email,
      'full_name': fullName,
      'user_role': userRole,
    });

    if (userRole == 'athlete') {
      await _client.from('athletes').upsert({
        'id': user.id,
      });
    }

    if (userRole == 'coach') {
      await _client.from('coaches').upsert({
        'id': user.id,
        'full_name': fullName,
        'professional_type': 'coach',
        'verification_status': 'pending',
        'cref_number': 'PENDENTE',
      });
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }
}
