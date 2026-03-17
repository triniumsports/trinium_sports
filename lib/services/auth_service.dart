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
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'user_role': userRole,
        if (crefNumber != null) ...{'cref_number': crefNumber},
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    await ensureProfileSafe();
    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Regras:
  /// - NÃO sobrescreve user_role se já estiver definido (protege admin).
  /// - Se profile existir: atualiza apenas email/full_name.
  /// - Se profile não existir: cria com role do metadata (fallback athlete).
  /// - Se profile existir MAS role vier vazio/null: auto-corrige usando role do metadata (ou athlete).
  Future<void> ensureProfileSafe() async {
    final user = currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    final meta = user.userMetadata ?? {};
    final fullName = (meta['full_name'] ?? '').toString();
    final roleFromMeta = (meta['user_role'] ?? '').toString().trim().toLowerCase();
    final email = user.email ?? '';

    // tenta atualizar somente campos seguros (se existir)
    final updated = await _client
        .from('profiles')
        .update({
          'email': email,
          'full_name': fullName,
        })
        .eq('id', user.id)
        .select('id')
        .maybeSingle();

    // se não existe profile, cria
    if (updated == null) {
      final roleToInsert = roleFromMeta.isEmpty ? 'athlete' : roleFromMeta;

      await _client.from('profiles').insert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'user_role': roleToInsert,
      });
    }

    // carrega profile e corrige role vazio/null se necessário
    final profile = await getMyProfile();
    final roleNow = (profile?['user_role'] ?? '').toString().trim().toLowerCase();

    if (roleNow.isEmpty) {
      // auto-correção: usa metadata ou athlete
      final fixed = roleFromMeta.isEmpty ? 'athlete' : roleFromMeta;

      // IMPORTANTE: só corrige se estava vazio; não mexe se já tinha algo (ex.: admin)
      await _client.from('profiles').update({
        'user_role': fixed,
      }).eq('id', user.id);
    }

    // cria athlete row se perfil final for atleta
    final finalProfile = await getMyProfile();
    final finalRole = (finalProfile?['user_role'] ?? '').toString().trim().toLowerCase();

    if (finalRole == 'athlete') {
      await _client.from('athletes').upsert({'id': user.id});
    }

    // coaches é criado por trigger; não mexer aqui.
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
