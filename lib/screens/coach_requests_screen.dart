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

      final athleteIds = _rels.map((r) => (r['athlete_id'] ?? '').toString()).where((x) => x.isNotEmpty).toList();

      if (athleteIds.isNotEmpty) {
        final profs = await _client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .in_('id', athleteIds);

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
      setState(() => _loading = false);
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitações de atletas'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
                  ? const Center(child: Text('Nenhuma solicitação pendente.'))
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
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                              child: avatar.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            title: Text(name),
                            subtitle: email.isNotEmpty ? Text(email) : null,
                            trailing: FilledButton(
                              onPressed: relationId.isEmpty ? null : () => _accept(relationId),
                              child: const Text('Aceitar'),
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
