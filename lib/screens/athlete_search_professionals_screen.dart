import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteSearchProfessionalsScreen extends StatefulWidget {
  const AthleteSearchProfessionalsScreen({super.key});

  @override
  State<AthleteSearchProfessionalsScreen> createState() => _AthleteSearchProfessionalsScreenState();
}

class _AthleteSearchProfessionalsScreenState extends State<AthleteSearchProfessionalsScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  final _searchController = TextEditingController();
  String _typeFilter = 'all';

  List<Map<String, dynamic>> _rows = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      // coaches + join profiles
      final res = await _client
          .from('coaches')
          // Pegamos vários campos; se algum não existir no seu schema, o Supabase retorna erro.
          // Por isso, usamos apenas campos que você confirmou no CSV: phone_mobile, professional_type, specialties, cref_number (se existir), crn_number (se existir), social_link (se existir), instagram (se existir)
          .select('id, phone_mobile, professional_type, specialties, cref_number, crn_number, registration_number, instagram, social_link, profiles(id, full_name, email, avatar_url, user_role)')
          .order('updated_at', ascending: false);

      _rows = (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // fallback: schema pode não ter alguns campos (instagram/social_link/etc)
      try {
        final res = await _client
            .from('coaches')
            .select('id, phone_mobile, professional_type, specialties, profiles(id, full_name, email, avatar_url, user_role)')
            .order('updated_at', ascending: false);

        _rows = (res as List).cast<Map<String, dynamic>>();
      } catch (e2) {
        _msg = 'Erro ao carregar profissionais: $e2';
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();

    bool match(String? s) => (s ?? '').toLowerCase().contains(q);

    return _rows.where((r) {
      final prof = (r['profiles'] as Map<String, dynamic>?) ?? {};
      final name = (prof['full_name'] ?? '').toString();
      final email = (prof['email'] ?? '').toString();
      final type = (r['professional_type'] ?? '').toString();
      final specs = (r['specialties'] ?? '').toString();

      final filterOk = _typeFilter == 'all' ? true : type.toLowerCase() == _typeFilter;
      final searchOk = q.isEmpty ? true : (match(name) || match(email) || match(type) || match(specs));

      return filterOk && searchOk;
    }).toList();
  }

  Future<void> _selectCoach(String coachId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('coach_athlete_relation').insert({
        'coach_id': coachId,
        'athlete_id': user.id,
        'status': 'pending',
        'role_type': 'head_coach',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação enviada ✅ Aguarde o coach aceitar.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar (talvez já exista). Detalhe: $e')),
      );
    }
  }

  Future<void> _copyContact({required String email, required String phone, String? social}) async {
    final parts = <String>[];
    if (email.trim().isNotEmpty) parts.add('Email: $email');
    if (phone.trim().isNotEmpty) parts.add('Telefone: $phone');
    if ((social ?? '').trim().isNotEmpty) parts.add('Rede social: $social');

    final text = parts.join(' | ');
    await Clipboard.setData(ClipboardData(text: text.isEmpty ? 'Sem contato' : text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.isEmpty ? 'Sem contato para copiar' : 'Contato copiado ✅')),
    );
  }

  String _regNumber(Map<String, dynamic> r) {
    // tenta achar o registro no que existir
    final v1 = (r['registration_number'] ?? '').toString().trim();
    final v2 = (r['cref_number'] ?? '').toString().trim();
    final v3 = (r['crn_number'] ?? '').toString().trim();

    if (v2.isNotEmpty) return 'CREF: $v2';
    if (v3.isNotEmpty) return 'CRN: $v3';
    if (v1.isNotEmpty) return 'Registro: $v1';
    return '';
  }

  String? _social(Map<String, dynamic> r) {
    final ig = (r['instagram'] ?? '').toString().trim();
    final link = (r['social_link'] ?? '').toString().trim();
    if (ig.isNotEmpty) return ig.startsWith('@') ? ig : '@$ig';
    if (link.isNotEmpty) return link;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _applyFilters();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar profissionais'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Marketplace de profissionais.\n'
              'Contato e contrato são fechados fora do app.\n'
              'Depois, selecione o coach aqui para liberar acesso aos seus dados e gerar treinos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nome, especialidade ou email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Todos')),
                      DropdownMenuItem(value: 'coach', child: Text('Treinador')),
                      DropdownMenuItem(value: 'nutritionist', child: Text('Nutricionista')),
                      DropdownMenuItem(value: 'personal', child: Text('Personal / Força')),
                    ],
                    onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_loading) const LinearProgressIndicator(),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),

            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Nenhum profissional encontrado.'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final r = list[i];
                        final prof = (r['profiles'] as Map<String, dynamic>?) ?? {};
                        final coachId = (r['id'] ?? '').toString();

                        final fullName = (prof['full_name'] ?? 'Sem nome').toString();
                        final email = (prof['email'] ?? '').toString();
                        final avatar = (prof['avatar_url'] ?? '').toString();

                        final phone = (r['phone_mobile'] ?? '').toString();
                        final type = (r['professional_type'] ?? '').toString();
                        final specs = (r['specialties'] ?? '').toString();
                        final reg = _regNumber(r);
                        final social = _social(r);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                  child: avatar.isEmpty ? const Icon(Icons.person) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),

                                      if (type.isNotEmpty) Text('Tipo: $type'),
                                      if (specs.isNotEmpty) Text('Especialidades: $specs'),
                                      if (reg.isNotEmpty) Text(reg),
                                      if (email.isNotEmpty) Text('Email: $email'),
                                      if (phone.isNotEmpty) Text('Tel: $phone'),
                                      if ((social ?? '').isNotEmpty) Text('Rede: $social'),

                                      const Spacer(),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _copyContact(email: email, phone: phone, social: social),
                                              child: const Text('Copiar contato'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: coachId.isEmpty ? null : () => _selectCoach(coachId),
                                              child: const Text('Selecionar'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
