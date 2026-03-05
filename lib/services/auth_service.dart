import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String userRole,
    String? crefNumber,
  }) async {
    // Salva metadata (útil para pós-login)
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'user_role': userRole,
        // guarda também o CREF/CRN, para reconstruir no login se precisar
        if (crefNumber != null) ...{'cref_number': crefNumber},
      },
    );

    // Se já houver sessão (confirm email OFF), cria perfil agora.
    if (response.session != null) {
      await ensureProfileFromMetadata(
        overrideCrefNumber: crefNumber,
      );
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    await ensureProfileFromMetadata();
    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> ensureProfileFromMetadata({
    String? overrideCrefNumber,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    final metadata = user.userMetadata ?? {};
    final fullName = (metadata['full_name'] ?? '').toString();
    final userRole = (metadata['user_role'] ?? '').toString();
    final email = user.email ?? '';

    if (userRole.isEmpty) {
      throw Exception('user_role não encontrado no metadata do usuário.');
    }

    // profiles (tem full_name)
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
      // coaches exige cref_number
      final crefNumber = overrideCrefNumber ??
          (metadata['cref_number'] ?? '').toString();

      if (crefNumber.trim().isEmpty) {
        throw Exception('CREF/CRN obrigatório para treinador.');
      }

      await _client.from('coaches').upsert({
        'id': user.id,
        'professional_type': 'coach',
        'verification_status': 'pending',
        'cref_number': crefNumber.trim(),
      });
    }
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = currentUser;
    if (user == null) return null;

    return await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }
}
