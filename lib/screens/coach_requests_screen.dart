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
  final SupabaseClient _client = Supabase.instance.client;

  late final TabController _tabController;

  bool _loading = true;
  String? _msg;

  List<Map<String, dynamic>> _pendingRelations = [];
  List<Map<String, dynamic>> _activeRelations = [];
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
      final links = await _client
          .from('v_athlete_professional_links')
          .select()
          .eq('professional_id', user.id)
          .order('created_at', ascending: false);

      final allLinks = (links as List).cast<Map<String, dynamic>>();

      _pendingRelations =
          allLinks.where((e) => e['status'] == 'pending').toList();
      _activeRelations =
          allLinks.where((e) => e['status'] == 'active').toList();

      final athleteIds = <String>{
        ..._pendingRelations
            .map((r) => (r['athlete_id'] ?? '').toString())
            .where((x) => x.isNotEmpty),
        ..._activeRelations
            .map((r) => (r['athlete_id'] ?? '').toString())
            .where((x) => x.isNotEmpty),
      }.toList();

      if (athleteIds.isEmpty) {
        _countsByAthleteId = {};
      } else {
        final workouts = await _client
            .from('v_prescribed_workouts_mvp')
            .select('athlete_id, status, validation_status')
            .filter('athlete_id', 'in', '(${athleteIds.map((e) => '"$e"').join(',')})');

        final countMap = <String, Map<String, int>>{};
        for (final row in (workouts as List).cast<Map<String, dynamic>>()) {
          final athleteId = (row['athlete_id'] ?? '').toString();
          final status = (row['status'] ?? '').toString();
          final validationStatus = (row['validation_status'] ?? '').toString();

          countMap.putIfAbsent(athleteId, () => {
                'planned': 0,
                'published': 0,
                'completed': 0,
                'total': 0,
              });

          countMap[athleteId]!['total'] =
              (countMap[athleteId]!['total'] ?? 0) + 1;

          if (status == 'planned' ||
              validationStatus == 'draft' ||
              validationStatus == 'review') {
            countMap[athleteId]!['planned'] =
                (countMap[athleteId]!['planned'] ?? 0) + 1;
          }

          if (status == 'published' || validationStatus == 'published') {
            countMap[athleteId]!['published'] =
                (countMap[athleteId]!['published'] ?? 0) + 1;
          }

          if (status == 'completed') {
            countMap[athleteId]!['completed'] =
                (countMap[athleteId]!['completed'] ?? 0) + 1;
          }
        }

        _countsByAthleteId = countMap;
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
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
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

  Future<void> _reject(String relationId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('coach_athlete_relation')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', relationId)
          .eq('coach_id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação recusada.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao recusar: $e')),
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

    final athleteName = 'Atleta ${athleteId.length >= 8 ? athleteId.substring(0, 8) : athleteId}';
    final counts = _countsByAthleteId[athleteId] ?? {
      'planned': 0,
      'published': 0,
      'completed': 0,
      'total': 0,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    athleteName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vínculo: ${(relation['role_type'] ?? '').toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (!isPending) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _countChip('Planejados', counts['planned'] ?? 0, Colors.orange),
                        _countChip('Publicados', counts['published'] ?? 0, Colors.green),
                        _countChip('Concluídos', counts['completed'] ?? 0, Colors.blue),
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
                            OutlinedButton(
                              onPressed: relationId.isEmpty
                                  ? null
                                  : () => _reject(relationId),
                              child: const Text('Recusar'),
                            ),
                          ]
                        : [
                            FilledButton(
                              onPressed: athleteId.isEmpty
                                  ? null
                                  : () => _openWorkoutReview(athleteId, athleteName),
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
        title: const Text('Solicitações e atletas'),
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
