import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachRequestsScreen extends StatefulWidget {
  const CoachRequestsScreen({super.key});

  @override
  State<CoachRequestsScreen> createState() => _CoachRequestsScreenState();
}

class _CoachRequestsScreenState extends State<CoachRequestsScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  List<Map<String, dynamic>> _rels = [];
  Map<String, Map<String, dynamic>> _athleteProfilesById = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final rels = await _client
          .from('coach_athlete_relation')
          .select('id, athlete_id, status, created_at')
          .eq('coach_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      _rels = (rels as List).cast<Map<String, dynamic>>();

      final athleteIds = _rels
          .map((r) => (r['athlete_id'] ?? '').toString())
          .where((x) => x.isNotEmpty)
          .toList();

      if (athleteIds.isNotEmpty) {
        final inValues = '(${athleteIds.map((e) => '"$e"').join(',')})';

        final profs = await _client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .filter('id', 'in', inValues);

        final map = <String, Map<String, dynamic>>{};
        for (final p in (profs as List).cast<Map<String, dynamic>>()) {
          map[(p['id'] ?? '').toString()] = p;
        }
        _athleteProfilesById = map;
      } else {
        _athleteProfilesById = {};
      }
    } catch (e) {
      _msg = 'Erro ao carregar solicitações: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept(String relationId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('coach_athlete_relation')
          .update({'status': 'active'})
          .eq('id', relationId)
          .eq('coach_id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação aceita ✅')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aceitar: $e')),
      );
    }
  }

  Future<void> _acceptAndGenerate({
    required String relationId,
    required String athleteId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _loading = true);

      await _client
          .from('coach_athlete_relation')
          .update({'status': 'active'})
          .eq('id', relationId)
          .eq('coach_id', user.id);

      final result = await _client.rpc(
        'generate_plan_for_relation',
        params: {'p_athlete_id': athleteId},
      );

      if (!mounted) return;

      final map = (result is Map<String, dynamic>)
          ? result
          : <String, dynamic>{'success': true, 'message': result.toString()};

      final success = map['success'] == true;
      final message = (map['message'] ?? 'Operação concluída.').toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Solicitação aceita e plano gerado ✅ $message'
                : 'Solicitação aceita, mas o plano não foi gerado. $message',
          ),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aceitar/gerar plano: $e')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitações de atletas'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _rels.isEmpty
                  ? const Center(
                      child: Text('Nenhuma solicitação pendente.'),
                    )
                  : ListView.builder(
                      itemCount: _rels.length,
                      itemBuilder: (context, i) {
                        final r = _rels[i];
                        final relationId = (r['id'] ?? '').toString();
                        final athleteId = (r['athlete_id'] ?? '').toString();
                        final prof = _athleteProfilesById[athleteId] ?? {};

                        final name = (prof['full_name'] ?? 'Atleta').toString();
                        final email = (prof['email'] ?? '').toString();
                        final avatar = (prof['avatar_url'] ?? '').toString();

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: avatar.isNotEmpty
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: avatar.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (email.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(email),
                                      ],
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilledButton(
                                            onPressed: relationId.isEmpty
                                                ? null
                                                : () => _accept(relationId),
                                            child: const Text('Aceitar'),
                                          ),
                                          FilledButton.tonal(
                                            onPressed: relationId.isEmpty ||
                                                    athleteId.isEmpty
                                                ? null
                                                : () => _acceptAndGenerate(
                                                      relationId: relationId,
                                                      athleteId: athleteId,
                                                    ),
                                            child: const Text(
                                              'Aceitar + gerar plano',
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
