import 'package:flutter/material.dart';
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
      // Fonte principal: coaches + join em profiles
      final res = await _client
          .from('coaches')
          .select('id, phone_mobile, professional_type, specialties, bio, profiles(id, full_name, email, avatar_url, user_role)')
          .order('updated_at', ascending: false);

      final list = (res as List).cast<Map<String, dynamic>>();

      // filtra apenas coaches (opcional — depende do seu backend)
      final filtered = list.where((r) {
        final prof = r['profiles'] as Map<String, dynamic>?;
        final role = (prof?['user_role'] ?? '').toString();
        return role == 'coach' || role == 'professional' || role.isEmpty;
      }).toList();

      setState(() => _rows = filtered);
    } catch (e) {
      setState(() => _msg = 'Erro ao carregar profissionais: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> data) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return data;

    bool match(String? s) => (s ?? '').toLowerCase().contains(q);

    return data.where((r) {
      final prof = (r['profiles'] as Map<String, dynamic>?) ?? {};
      final name = (prof['full_name'] ?? '').toString();
      final email = (prof['email'] ?? '').toString();
      final type = (r['professional_type'] ?? '').toString();
      final specs = (r['specialties'] ?? '').toString();
      return match(name) || match(email) || match(type) || match(specs);
    }).toList();
  }

  Future<void> _selectCoach(String coachId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // cria vínculo pending (se já existir, pode dar erro de duplicidade dependendo do constraint)
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
      // Se já existir (duplicado), apenas informar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar (talvez já exista). Detalhe: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _applySearch(_rows);

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
              'Contato e contrato são fechados fora do app.\n'
              'Depois, selecione o coach aqui para ele ter acesso aos seus dados e gerar treinos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nome, especialidade ou email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            if (_loading) const LinearProgressIndicator(),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
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

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(fullName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (type.isNotEmpty) Text('Tipo: $type'),
                          if (specs.isNotEmpty) Text('Especialidades: $specs'),
                          if (email.isNotEmpty) Text('Email: $email'),
                          if (phone.isNotEmpty) Text('Telefone: $phone'),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: coachId.isEmpty ? null : () => _selectCoach(coachId),
                        child: const Text('Selecionar'),
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
