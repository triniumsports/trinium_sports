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
  Map<int, List<Map<String, dynamic>>> _enduranceStepsByWorkout = {};
  Map<int, List<Map<String, dynamic>>> _strengthStepsByWorkout = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

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
      final enduranceMap = <int, List<Map<String, dynamic>>>{};
      final strengthMap = <int, List<Map<String, dynamic>>>{};

      if (ids.isNotEmpty) {
        final inValues = '(${ids.join(',')})';

        final enduranceSteps = await _client
            .from('prescribed_workout_steps')
            .select('*')
            .filter('prescribed_workout_id', 'in', inValues)
            .order('prescribed_workout_id', ascending: true)
            .order('step_order', ascending: true);

        for (final row in (enduranceSteps as List).cast<Map<String, dynamic>>()) {
          final workoutId = row['prescribed_workout_id'] as int;
          enduranceMap.putIfAbsent(workoutId, () => []);
          enduranceMap[workoutId]!.add(row);
        }

        final strengthSteps = await _client
            .from('v_prescribed_strength_exercises')
            .select('*')
            .filter('prescribed_workout_id', 'in', inValues)
            .order('prescribed_workout_id', ascending: true)
            .order('exercise_order', ascending: true);

        for (final row in (strengthSteps as List).cast<Map<String, dynamic>>()) {
          final workoutId = row['prescribed_workout_id'] as int;
          strengthMap.putIfAbsent(workoutId, () => []);
          strengthMap[workoutId]!.add(row);
        }
      }

      _enduranceStepsByWorkout = enduranceMap;
      _strengthStepsByWorkout = strengthMap;
    } catch (e) {
      _msg = 'Erro ao carregar treinos publicados: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateText(String raw) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _activityLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('trail')) return 'Trail';
    if (v.contains('run') || v.contains('corr')) return 'Corrida';
    if (v.contains('swim') || v.contains('nata')) return 'Natação';
    if (v.contains('bike') || v.contains('cicl')) return 'Ciclismo';
    if (v.contains('strength') || v.contains('forca')) return 'Força';
    if (v.contains('triathlon')) return 'Triathlon';
    return raw.isEmpty ? 'Geral' : raw;
  }

  String _modalityLabel(String raw) {
    final v = raw.toLowerCase();
    if (v == 'strength') return 'Força';
    if (v == 'endurance') return 'Endurance';
    if (v == 'mobility') return 'Mobilidade';
    if (v == 'rehab') return 'Reabilitação';
    if (v == 'nutrition') return 'Nutrição';
    return raw.isEmpty ? '-' : raw;
  }

  String _strengthTargetLabel(Map<String, dynamic> row) {
    final type = _s(row['target_type']);
    final value = _s(row['target_value']);
    final unit = _s(row['target_unit']);

    if (type.isEmpty && value.isEmpty) return '-';
    if (value.isEmpty) return type;
    return unit.isEmpty ? '$value' : '$value $unit';
  }

  String _strengthLoadLabel(Map<String, dynamic> row) {
    final loadType = _s(row['load_type']);
    final loadValue = _s(row['load_value']);
    final loadUnit = _s(row['load_unit']);

    if (loadType == 'bodyweight') return 'Peso corporal';
    if (loadType == 'none' || (loadType.isEmpty && loadValue.isEmpty)) return '-';
    if (loadValue.isEmpty) return loadType.isEmpty ? '-' : loadType;
    return loadUnit.isEmpty ? '$loadValue' : '$loadValue $loadUnit';
  }

  Widget _buildEnduranceSteps(List<Map<String, dynamic>> steps) {
    if (steps.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Sem steps detalhados.'),
      );
    }

    return Column(
      children: steps.map((s) {
        final order = _s(s['step_order']);
        final stepType = _s(s['step_type']);
        final duration = _s(s['duration_value']);
        final durationUnit = _s(s['duration_unit']);
        final zone = _s(s['target_zone']);
        final notes = _s(s['notes']);
        final stepNotes = _s(s['step_notes']);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF7F7F9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step $order ${stepType.isNotEmpty ? "- $stepType" : ""}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (duration.isNotEmpty)
                Text(
                  durationUnit.isEmpty
                      ? 'Valor: $duration'
                      : 'Valor: $duration $durationUnit',
                ),
              if (zone.isNotEmpty) Text('Zona: $zone'),
              if (notes.isNotEmpty) Text('Obs: $notes'),
              if (stepNotes.isNotEmpty) Text('Detalhe: $stepNotes'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrengthSteps(List<Map<String, dynamic>> steps) {
    if (steps.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Sem exercícios detalhados.'),
      );
    }

    return Column(
      children: steps.map((s) {
        final order = _s(s['exercise_order']);
        final exerciseName = _s(s['exercise_name']).isNotEmpty
            ? _s(s['exercise_name'])
            : (_s(s['exercise_name_override']).isNotEmpty
                ? _s(s['exercise_name_override'])
                : 'Exercício');
        final muscleGroup = _s(s['muscle_group_primary_name']);
        final equipment = _s(s['equipment_type_name']);
        final target = _strengthTargetLabel(s);
        final load = _strengthLoadLabel(s);
        final restSec = _s(s['rest_sec']);
        final rpe = _s(s['rpe']);
        final notes = _s(s['notes']);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF7F7F9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exercício $order - $exerciseName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (muscleGroup.isNotEmpty) Text('Grupo muscular: $muscleGroup'),
              if (equipment.isNotEmpty) Text('Equipamento: $equipment'),
              Text('Meta: $target'),
              Text('Carga: $load'),
              if (restSec.isNotEmpty) Text('Descanso: $restSec seg'),
              if (rpe.isNotEmpty) Text('RPE: $rpe'),
              if (notes.isNotEmpty) Text('Obs: $notes'),
            ],
          ),
        );
      }).toList(),
    );
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
                      final title = _s(w['title']).isEmpty ? 'Treino' : _s(w['title']);
                      final date = _dateText(_s(w['scheduled_date']));
                      final description = _s(w['description']);
                      final activityType = _activityLabel(_s(w['activity_type_id']));
                      final workoutModality = _modalityLabel(_s(w['workout_modality']));

                      final isStrength =
                          _s(w['activity_type_id']) == 'strength' ||
                          _s(w['workout_modality']) == 'strength';

                      final enduranceSteps =
                          _enduranceStepsByWorkout[workoutId] ?? [];
                      final strengthSteps =
                          _strengthStepsByWorkout[workoutId] ?? [];

                      return Card(
                        child: ExpansionTile(
                          title: Text(title),
                          subtitle: Text('$date • $activityType • $workoutModality'),
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
                            isStrength
                                ? _buildStrengthSteps(strengthSteps)
                                : _buildEnduranceSteps(enduranceSteps),
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
