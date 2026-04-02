import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteApprovedWorkoutsScreen extends StatefulWidget {
  const AthleteApprovedWorkoutsScreen({super.key});

  @override
  State<AthleteApprovedWorkoutsScreen> createState() =>
      _AthleteApprovedWorkoutsScreenState();
}

class _AthleteApprovedWorkoutsScreenState
    extends State<AthleteApprovedWorkoutsScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;
  List<Map<String, dynamic>> _workouts = [];
  Map<int, List<Map<String, dynamic>>> _stepsByWorkout = {};

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
      final workouts = await _client
          .from('prescribed_workouts')
          .select('*')
          .eq('athlete_id', user.id)
          .eq('validation_status', 'published')
          .order('scheduled_date', ascending: true);

      _workouts = (workouts as List).cast<Map<String, dynamic>>();

      final ids = _workouts.map((e) => e['id'] as int).toList();
      final map = <int, List<Map<String, dynamic>>>{};

      if (ids.isNotEmpty) {
        final inValues = '(${ids.join(',')})';
        final steps = await _client
            .from('prescribed_workout_steps')
            .select('*')
            .filter('prescribed_workout_id', 'in', inValues)
            .order('prescribed_workout_id', ascending: true)
            .order('step_order', ascending: true);

        for (final row in (steps as List).cast<Map<String, dynamic>>()) {
          final workoutId = row['prescribed_workout_id'] as int;
          map.putIfAbsent(workoutId, () => []);
          map[workoutId]!.add(row);
        }
      }

      _stepsByWorkout = map;
    } catch (e) {
      _msg = 'Erro ao carregar treinos publicados: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateText(String raw) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treinos publicados'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
            child: _workouts.isEmpty
                ? const Center(
                    child: Text('Nenhum treino publicado encontrado.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _workouts.length,
                    itemBuilder: (context, index) {
                      final w = _workouts[index];
                      final workoutId = w['id'] as int;
                      final title = (w['title'] ?? 'Treino').toString();
                      final date =
                          _dateText((w['scheduled_date'] ?? '').toString());
                      final description =
                          (w['description'] ?? '').toString();
                      final steps = _stepsByWorkout[workoutId] ?? [];

                      return Card(
                        child: ExpansionTile(
                          title: Text(title),
                          subtitle: Text(date),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            if (description.isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(description),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (steps.isEmpty)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Sem steps detalhados.'),
                              )
                            else
                              ...steps.map((s) {
                                final order = (s['step_order'] ?? '').toString();
                                final stepType =
                                    (s['step_type'] ?? '').toString();
                                final duration =
                                    (s['duration_value'] ?? '').toString();
                                final zone =
                                    (s['target_zone'] ?? '').toString();
                                final notes =
                                    (s['notes'] ?? '').toString();

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFFF7F7F9),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Step $order ${stepType.isNotEmpty ? "- $stepType" : ""}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (duration.isNotEmpty)
                                        Text('Valor: $duration'),
                                      if (zone.isNotEmpty) Text('Zona: $zone'),
                                      if (notes.isNotEmpty) Text('Obs: $notes'),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
