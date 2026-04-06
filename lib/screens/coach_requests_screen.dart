import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coach_athlete_workouts_review_screen.dart';

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
  Map<String, Map<String, dynamic>> _mainRaceByAthleteId = {};
  Map<String, Map<String, int>> _countsByAthleteId = {};

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

        final profileMap = <String, Map<String, dynamic>>{};
        for (final p in (profs as List).cast<Map<String, dynamic>>()) {
          profileMap[(p['id'] ?? '').toString()] = p;
        }
        _athleteProfilesById = profileMap;

        final races = await _client
            .from('target_races')
            .select(
              'id, athlete_id, race_date, status, distance_meters, priority, race_name, event_name',
            )
            .filter('athlete_id', 'in', inValues)
            .eq('status', 'planned')
            .order('race_date', ascending: true);

        final raceMap = <String, Map<String, dynamic>>{};
        for (final r in (races as List).cast<Map<String, dynamic>>()) {
          final athleteId = (r['athlete_id'] ?? '').toString();
          raceMap.putIfAbsent(athleteId, () => r);
        }
        _mainRaceByAthleteId = raceMap;

        final workouts = await _client
            .from('prescribed_workouts')
            .select('athlete_id, validation_status')
            .filter('athlete_id', 'in', inValues)
            .eq('coach_id', user.id);

        final countMap = <String, Map<String, int>>{};
        for (final row in (workouts as List).cast<Map<String, dynamic>>()) {
          final athleteId = (row['athlete_id'] ?? '').toString();
          final status = (row['validation_status'] ?? '').toString();

          countMap.putIfAbsent(athleteId, () => {
                'pending': 0,
                'published': 0,
                'total': 0,
              });

          countMap[athleteId]!['total'] = (countMap[athleteId]!['total'] ?? 0) + 1;

          if (status == 'pending') {
            countMap[athleteId]!['pending'] =
                (countMap[athleteId]!['pending'] ?? 0) + 1;
          } else if (status == 'published') {
            countMap[athleteId]!['published'] =
                (countMap[athleteId]!['published'] ?? 0) + 1;
          }
        }
        _countsByAthleteId = countMap;
      } else {
        _athleteProfilesById = {};
        _mainRaceByAthleteId = {};
        _countsByAthleteId = {};
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

  void _openWorkoutReview(String athleteId, String athleteName) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => CoachAthleteWorkoutsReviewScreen(
          athleteId: athleteId,
          athleteName: athleteName,
        ),
      ),
    )
        .then((_) async {
      await _load();
    });
  }

  String _displayName(String athleteId) {
    final prof = _athleteProfilesById[athleteId] ?? {};
    final fullName = (prof['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    final email = (prof['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;

    if (athleteId.length >= 8) {
      return 'Atleta ${athleteId.substring(0, 8)}';
    }

    return 'Atleta';
  }

  String _displayEmail(String athleteId) {
    final prof = _athleteProfilesById[athleteId] ?? {};
    return (prof['email'] ?? '').toString().trim();
  }

  String _raceSummary(String athleteId) {
    final race = _mainRaceByAthleteId[athleteId];
    if (race == null) return 'Sem prova alvo planejada';

    final name = (race['race_name'] ?? race['event_name'] ?? 'Prova alvo').toString();
    final date = (race['race_date'] ?? '').toString();
    final distance = (race['distance_meters'] ?? '').toString();
    final priority = (race['priority'] ?? '').toString();

    final dateText = date.length >= 10 ? date.substring(0, 10) : date;
    return '$name • $dateText • ${distance}m${priority.isNotEmpty ? ' • prioridade $priority' : ''}';
  }

  Widget _countChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRelationCard(
    Map<String, dynamic> relation, {
    required bool isPending,
  }) {
    final athleteId = (relation['athlete_id'] ?? '').toString();
    final relationId = (relation['id'] ?? '').toString();
    final prof = _athleteProfilesById[athleteId] ?? {};
    final avatar = (prof['avatar_url'] ?? '').toString();

    final name = _displayName(athleteId);
    final email = _displayEmail(athleteId);
    final counts = _countsByAthleteId[athleteId] ?? {
      'pending': 0,
      'published': 0,
      'total': 0,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(email),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${athleteId.length >= 8 ? athleteId.substring(0, 8) : athleteId}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _raceSummary(athleteId),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (!isPending) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _countChip('Pendentes', counts['pending'] ?? 0, Colors.orange),
                        _countChip('Publicados', counts['published'] ?? 0, Colors.green),
                        _countChip('Total', counts['total'] ?? 0, Colors.blueGrey),
                      ],
                    ),
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
                            FilledButton.tonal(
                              onPressed: athleteId.isEmpty
                                  ? null
                                  : () => _generateForActiveAthlete(athleteId),
                              child: const Text('Gerar plano'),
                            ),
                            FilledButton(
                              onPressed: athleteId.isEmpty
                                  ? null
                                  : () => _openWorkoutReview(athleteId, name),
                              child: const Text('Ver treinos'),
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
