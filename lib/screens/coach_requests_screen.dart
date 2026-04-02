import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachRequestsScreen extends StatefulWidget {
  const CoachRequestsScreen({super.key});

  @override
  State<CoachRequestsScreen> createState() => _CoachRequestsScreenState();
}

class _CoachRequestsScreenState extends State<CoachRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;

  late final TabController _tabController;

  bool _loading = true;
  String? _msg;

  List<Map<String, dynamic>> _pendingRelations = [];
  List<Map<String, dynamic>> _activeRelations = [];
  Map<String, Map<String, dynamic>> _athleteProfilesById = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final pending = await _client
          .from('coach_athlete_relation')
          .select('id, athlete_id, status, created_at')
          .eq('coach_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      final active = await _client
          .from('coach_athlete_relation')
          .select('id, athlete_id, status, created_at')
          .eq('coach_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      _pendingRelations = (pending as List).cast<Map<String, dynamic>>();
      _activeRelations = (active as List).cast<Map<String, dynamic>>();

      final athleteIds = <String>{
        ..._pendingRelations
            .map((r) => (r['athlete_id'] ?? '').toString())
            .where((x) => x.isNotEmpty),
        ..._activeRelations
            .map((r) => (r['athlete_id'] ?? '').toString())
            .where((x) => x.isNotEmpty),
      }.toList();

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
      if (mounted) setState(() => _loading = false);
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
      setState(() {
        _loading = true;
        _msg = null;
      });

      await _client
          .from('coach_athlete_relation')
          .update({'status': 'active'})
          .eq('id', relationId)
          .eq('coach_id', user.id);

      final result = await _client.rpc(
        'path_b_generate_plan',
        params: {
          'v_athlete': athleteId,
          'v_coach': user.id,
          'v_target_race_id': null,
        },
      );

      if (!mounted) return;

      final map = result is Map<String, dynamic>
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
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao aceitar e gerar plano: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _generateForActiveAthlete(String athleteId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _loading = true;
        _msg = null;
      });

      final result = await _client.rpc(
        'path_b_generate_plan',
        params: {
          'v_athlete': athleteId,
          'v_coach': user.id,
          'v_target_race_id': null,
        },
      );

      if (!mounted) return;

      final map = result is Map<String, dynamic>
          ? result
          : <String, dynamic>{'success': true, 'message': result.toString()};

      final success = map['success'] == true;
      final message = (map['message'] ?? 'Operação concluída.').toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Plano gerado com sucesso ✅ $message'
                : 'Não foi possível gerar o plano. $message',
          ),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar plano: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Widget _buildRelationCard(
    Map<String, dynamic> relation, {
    required bool isPending,
  }) {
    final athleteId = (relation['athlete_id'] ?? '').toString();
    final relationId = (relation['id'] ?? '').toString();
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
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(email),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: isPending
                        ? [
                            FilledButton(
                              onPressed: relationId.isEmpty
                                  ? null
                                  : () => _accept(relationId),
                              child: const Text('Aceitar'),
                            ),
                            FilledButton.tonal(
                              onPressed: relationId.isEmpty || athleteId.isEmpty
                                  ? null
                                  : () => _acceptAndGenerate(
                                        relationId: relationId,
                                        athleteId: athleteId,
                                      ),
                              child: const Text('Aceitar + gerar plano'),
                            ),
                          ]
                        : [
                            FilledButton(
                              onPressed: athleteId.isEmpty
                                  ? null
                                  : () => _generateForActiveAthlete(athleteId),
                              child: const Text('Gerar plano'),
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
  }

  Widget _buildTabContent(List<Map<String, dynamic>> list, bool isPending) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isPending ? 'Nenhuma solicitação pendente.' : 'Nenhum atleta ativo.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return _buildRelationCard(
            list[index],
            isPending: isPending,
          );
        },
      ),
    );
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pendentes'),
            Tab(text: 'Ativos'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _msg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(_pendingRelations, true),
                _buildTabContent(_activeRelations, false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
