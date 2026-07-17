import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String userRole,
    String? professionalType,
    String? crefNumber,
  }) async {
    final normalizedRole = userRole.trim().toLowerCase();

    final normalizedProfessionalType =
        professionalType?.trim().toLowerCase();

    final normalizedRegistration = crefNumber?.trim();

    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'user_role': normalizedRole,
        if (normalizedProfessionalType != null &&
            normalizedProfessionalType.isNotEmpty)
          'professional_type': normalizedProfessionalType,
        if (normalizedRegistration != null &&
            normalizedRegistration.isNotEmpty)
          'cref_number': normalizedRegistration,
      },
    );

    /*
     * Quando a confirmação de e-mail estiver desabilitada,
     * o Supabase pode criar a sessão imediatamente.
     *
     * Nesse cenário, sincronizamos o perfil agora.
     * Quando houver confirmação de e-mail, a sincronização
     * acontecerá no primeiro login.
     */
    if (response.session != null) {
      await ensureProfileSafe();
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    await ensureProfileSafe();

    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /*
   * Regras:
   *
   * - Não sobrescreve um user_role já definido.
   * - Protege perfis administrativos.
   * - Cria o profile quando ele ainda não existe.
   * - Corrige user_role vazio usando os metadados.
   * - Cria a linha de athletes para atletas.
   * - Sincroniza professional_type e registro para profissionais.
   */
  Future<void> ensureProfileSafe() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final metadata = user.userMetadata ?? <String, dynamic>{};

    final fullName =
        (metadata['full_name'] ?? '').toString().trim();

    final roleFromMetadata =
        (metadata['user_role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final professionalTypeFromMetadata =
        (metadata['professional_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final registrationFromMetadata =
        (metadata['cref_number'] ?? '').toString().trim();

    final email = user.email ?? '';

    /*
     * Atualiza somente campos seguros caso o perfil já exista.
     */
    final updatedProfile = await _client
        .from('profiles')
        .update({
          'email': email,
          'full_name': fullName,
        })
        .eq('id', user.id)
        .select('id')
        .maybeSingle();

    /*
     * Se o perfil não existir, cria usando o role dos metadados.
     */
    if (updatedProfile == null) {
      final roleToInsert = roleFromMetadata.isEmpty
          ? 'athlete'
          : roleFromMetadata;

      await _client.from('profiles').insert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'user_role': roleToInsert,
      });
    }

    /*
     * Corrige somente quando user_role estiver vazio.
     * Não altera admin ou outros perfis já definidos.
     */
    final profile = await getMyProfile();

    final currentRole =
        (profile?['user_role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (currentRole.isEmpty) {
      final correctedRole = roleFromMetadata.isEmpty
          ? 'athlete'
          : roleFromMetadata;

      await _client
          .from('profiles')
          .update({'user_role': correctedRole})
          .eq('id', user.id);
    }

    final finalProfile = await getMyProfile();

    final finalRole =
        (finalProfile?['user_role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (finalRole == 'athlete') {
      await _client.from('athletes').upsert({
        'id': user.id,
      });

      return;
    }

    /*
     * A tabela coaches é criada pelo trigger existente.
     *
     * Aqui sincronizamos os dados escolhidos no primeiro
     * cadastro para evitar que nutricionistas sejam tratados
     * inicialmente como treinadores.
     */
    if (finalRole == 'coach') {
      final professionalPayload = <String, dynamic>{};

      if (professionalTypeFromMetadata.isNotEmpty) {
        professionalPayload['professional_type'] =
            professionalTypeFromMetadata;
      }

      if (registrationFromMetadata.isNotEmpty) {
        professionalPayload['cref_number'] =
            registrationFromMetadata;
      }

      if (professionalPayload.isNotEmpty) {
        await _client
            .from('coaches')
            .update(professionalPayload)
            .eq('id', user.id);
      }
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
