import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coach_workout_edit_screen.dart';

class CoachAthleteWorkoutsReviewScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const CoachAthleteWorkoutsReviewScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
  });

  @override
  State<CoachAthleteWorkoutsReviewScreen> createState() =>
      _CoachAthleteWorkoutsReviewScreenState();
}

class _CoachAthleteWorkoutsReviewScreenState
    extends State<CoachAthleteWorkoutsReviewScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;
  String _statusFilter = 'pending';

  List<Map<String, dynamic>> _allWorkouts = [];
  List<Map<String, dynamic>> _filteredWorkouts = [];
  List<Map<String, dynamic>> _targetRaces = [];
  Map<String, dynamic>? _athlete;
  Map<String, dynamic>? _anamnesis;
  Map<String, dynamic>? _latestMetrics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      await Future.wait([
        _loadAthleteContext(),
        _loadTargetRaces(),
        _loadWorkouts(),
      ]);
      _applyFilter();
    } catch (e) {
      _msg = 'Erro ao carregar dashboard: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAthleteContext() async {
    try {
      final athlete = await _client
          .from('athletes')
          .select('*')
          .eq('id', widget.athleteId)
          .maybeSingle();

      if (athlete != null) {
        _athlete = Map<String, dynamic>.from(athlete);
      } else {
        _athlete = null;
      }
    } catch (_) {
      _athlete = null;
    }

    try {
      final anamnesis = await _client
          .from('athlete_anamnesis')
          .select('*')
          .eq('athlete_id', widget.athleteId)
          .maybeSingle();

      if (anamnesis != null) {
        _anamnesis = Map<String, dynamic>.from(anamnesis);
      } else {
        _anamnesis = null;
      }
    } catch (_) {
      _anamnesis = null;
    }

    try {
      final metrics = await _client
          .from('athlete_metrics_log')
          .select('*')
          .eq('athlete_id', widget.athleteId)
          .order('created_at', ascending: false)
          .limit(1);

      if ((metrics as List).isNotEmpty) {
        _latestMetrics = Map<String, dynamic>.from(metrics.first);
      } else {
        _latestMetrics = null;
      }
    } catch (_) {
      _latestMetrics = null;
    }
  }

  Future<void> _loadTargetRaces() async {
    final res = await _client
        .from('target_races')
        .select('*')
        .eq('athlete_id', widget.athleteId)
        .order('race_date', ascending: true);

    _targetRaces = (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _loadWorkouts() async {
    final res = await _client
        .from('prescribed_workouts')
        .select('*')
        .eq('athlete_id', widget.athleteId)
        .order('scheduled_date', ascending: true);

    _allWorkouts = (res as List).cast<Map<String, dynamic>>();
  }

  void _applyFilter() {
    if (_statusFilter == 'all') {
      _filteredWorkouts = List<Map<String, dynamic>>.from(_allWorkouts);
      return;
    }

    _filteredWorkouts = _allWorkouts
        .where((w) => (w['validation_status'] ?? '').toString() == _statusFilter)
        .toList();
  }

  dynamic _pickValue(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        final value = map[key];
        if (value is String && value.trim().isEmpty) continue;
        return value;
      }
    }
    return null;
  }

  String _pickString(Map<String, dynamic>? map, List<String> keys) {
    final value = _pickValue(map, keys);
    return value == null ? '' : value.toString();
  }

  String _dateText(String raw) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _weekKey(String rawDate) {
    if (rawDate.length < 10) return rawDate;
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;
    final monday = dt.subtract(Duration(days: dt.weekday - 1));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  num _durationSec(Map<String, dynamic> w) {
    final value = w['planned_duration_sec'];
    return value is num ? value : 0;
  }

  String _formatHours(num totalSec) {
    final hours = totalSec / 3600.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  String _phaseOf(Map<String, dynamic> w) {
    final candidates = [
      'periodization_phase',
      'training_phase',
      'phase',
      'macro_phase',
    ];
    for (final key in candidates) {
      final v = (w[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }

    final title = (w['title'] ?? '').toString().toLowerCase();
    if (title.contains('base')) return 'base';
    if (title.contains('build')) return 'build';
    if (title.contains('peak')) return 'peak';
    if (title.contains('taper')) return 'taper';
    if (title.contains('race')) return 'race';

    return 'sem_fase';
  }

  String _activityOf(Map<String, dynamic> w) {
    final candidates = [
      'activity_type_id',
      'activity_type',
      'sport',
      'modality',
    ];
    for (final key in candidates) {
      final v = (w[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }

    final title = (w['title'] ?? '').toString().toLowerCase();
    if (title.contains('swim') || title.contains('nata')) return 'swim';
    if (title.contains('bike') || title.contains('cicl')) return 'bike';
    if (title.contains('strength') || title.contains('força')) return 'strength';
    if (title.contains('trail')) return 'trail';
    if (title.contains('run') || title.contains('corr')) return 'run';

    return 'geral';
  }

  Map<String, dynamic> _globalSummary() {
    int pending = 0;
    int published = 0;
    num totalDuration = 0;

    final Map<String, num> phaseHours = {};

    for (final w in _allWorkouts) {
      final status = (w['validation_status'] ?? '').toString();
      final duration = _durationSec(w);
      final phase = _phaseOf(w);

      if (status == 'pending') pending++;
      if (status == 'published') published++;
      totalDuration += duration;

      phaseHours[phase] = (phaseHours[phase] ?? 0) + duration;
    }

    num maxPhase = 0;
    num minPhase = 0;
    if (phaseHours.isNotEmpty) {
      final values = phaseHours.values.toList();
      maxPhase = values.reduce((a, b) => a > b ? a : b);
      minPhase = values.reduce((a, b) => a < b ? a : b);
    }

    return {
      'total': _allWorkouts.length,
      'pending': pending,
      'published': published,
      'total_duration_sec': totalDuration,
      'phase_hours': phaseHours,
      'max_phase': maxPhase,
      'min_phase': minPhase,
    };
  }

  List<Map<String, dynamic>> _weeklySummary() {
    final Map<String, Map<String, dynamic>> weekMap = {};

    for (final w in _allWorkouts) {
      final date = (w['scheduled_date'] ?? '').toString();
      final week = _weekKey(date);
      final phase = _phaseOf(w);
      final activity = _activityOf(w);
      final duration = _durationSec(w);

      weekMap.putIfAbsent(week, () {
        return {
          'week': week,
          'phase': phase,
          'total_sessions': 0,
          'total_duration_sec': 0,
          'activity_counts': <String, int>{},
          'target_races': <String>[],
        };
      });

      weekMap[week]!['total_sessions'] =
          (weekMap[week]!['total_sessions'] as int) + 1;
      weekMap[week]!['total_duration_sec'] =
          (weekMap[week]!['total_duration_sec'] as num) + duration;

      final activityCounts =
          weekMap[week]!['activity_counts'] as Map<String, int>;
      activityCounts[activity] = (activityCounts[activity] ?? 0) + 1;
    }

    for (final race in _targetRaces) {
      final date = (race['race_date'] ?? '').toString();
      final week = _weekKey(date);

      weekMap.putIfAbsent(week, () {
        return {
          'week': week,
          'phase': '',
          'total_sessions': 0,
          'total_duration_sec': 0,
          'activity_counts': <String, int>{},
          'target_races': <String>[],
        };
      });

      final races = weekMap[week]!['target_races'] as List<String>;
      final distance = (race['distance_meters'] ?? '').toString();
      final priority = (race['priority'] ?? '').toString();
      races.add('Prova ${distance}m${priority.isNotEmpty ? ' (${priority})' : ''}');
    }

    final list = weekMap.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) =>
          (a['week'] ?? '').toString().compareTo((b['week'] ?? '').toString()));

    return list;
  }

  Future<void> _openWorkout(int workoutId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CoachWorkoutEditScreen(workoutId: workoutId),
      ),
    );

    await _load();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino atualizado ✅')),
      );
    }
  }

  Future<void> _publishDirect(int workoutId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('prescribed_workouts').update({
        'validation_status': 'published',
        'approved_at': DateTime.now().toIso8601String(),
        'approved_by_coach_id': user.id,
      }).eq('id', workoutId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino publicado para o atleta ✅')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao publicar: $e')),
      );
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'published':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    IconData? icon,
  }) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer({
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAthleteContextSection() {
    final weight = _pickString(_athlete, ['weight_kg', 'weight']);
    final height = _pickString(_athlete, ['height_cm', 'height']);
    final level = _pickString(_athlete, ['experience_level', 'fitness_level', 'level']);
    final gender = _pickString(_athlete, ['gender']);
    final maxHr = _pickString(_athlete, ['max_hr', 'hr_max']);
    final restHr = _pickString(_athlete, ['resting_hr', 'rest_hr']);
    final vo2 = _pickString(
      _latestMetrics,
      ['vo2max', 'vo2_max', 'vo2_estimated', 'vo2max_estimated'],
    );
    final comorbidity = _pickString(
      _anamnesis,
      ['comorbidities', 'comorbidity', 'medical_conditions', 'health_conditions'],
    );
    final restrictions = _pickString(
      _anamnesis,
      ['restrictions', 'limitations', 'injury_history', 'notes'],
    );

    return _sectionContainer(
      title: 'Contexto do atleta',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metricCard(title: 'Peso', value: weight.isEmpty ? '-' : '$weight kg', icon: Icons.monitor_weight),
          _metricCard(title: 'Altura', value: height.isEmpty ? '-' : '$height cm', icon: Icons.height),
          _metricCard(title: 'Nível', value: level.isEmpty ? '-' : level, icon: Icons.speed),
          _metricCard(title: 'VO2', value: vo2.isEmpty ? '-' : vo2, icon: Icons.favorite),
          _metricCard(title: 'FC repouso', value: restHr.isEmpty ? '-' : restHr, icon: Icons.monitor_heart),
          _metricCard(title: 'FC máxima', value: maxHr.isEmpty ? '-' : maxHr, icon: Icons.bolt),
          _metricCard(title: 'Gênero', value: gender.isEmpty ? '-' : gender, icon: Icons.person),
          _metricCard(title: 'Comorbidades', value: comorbidity.isEmpty ? '-' : comorbidity, icon: Icons.medical_information),
          _metricCard(title: 'Restrições', value: restrictions.isEmpty ? '-' : restrictions, icon: Icons.warning_amber),
        ],
      ),
    );
  }

  Widget _buildTargetRacesSection() {
    if (_targetRaces.isEmpty) {
      return _sectionContainer(
        title: 'Calendário de provas alvo',
        child: const Text('Nenhuma prova alvo encontrada.'),
      );
    }

    return _sectionContainer(
      title: 'Calendário de provas alvo',
      child: Column(
        children: _targetRaces.map((race) {
          final raceDate = _dateText((race['race_date'] ?? '').toString());
          final distance = (race['distance_meters'] ?? '').toString();
          final priority = (race['priority'] ?? '').toString();
          final category =
              (race['calculated_race_category_id'] ?? '').toString();
          final activity = (race['activity_type_id'] ?? '').toString();
          final status = (race['status'] ?? '').toString();

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF7F7F9),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Data: $raceDate'),
                Text('Distância: ${distance}m'),
                Text('Prioridade: $priority'),
                Text('Categoria: $category'),
                Text('Atividade: $activity'),
                Text('Status: $status'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGlobalSummarySection() {
    final s = _globalSummary();
    final phaseHours = (s['phase_hours'] as Map<String, num>);
    final maxPhase = (s['max_phase'] ?? 0) as num;
    final minPhase = (s['min_phase'] ?? 0) as num;

    return _sectionContainer(
      title: 'Resumo global de treinos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(title: 'Total de treinos', value: '${s['total']}', icon: Icons.fitness_center),
              _metricCard(title: 'Pendentes', value: '${s['pending']}', icon: Icons.schedule),
              _metricCard(title: 'Publicados', value: '${s['published']}', icon: Icons.check_circle),
              _metricCard(title: 'Carga total', value: _formatHours((s['total_duration_sec'] ?? 0) as num), icon: Icons.timer),
              _metricCard(title: 'Carga máx. por fase', value: _formatHours(maxPhase), icon: Icons.trending_up),
              _metricCard(title: 'Carga mín. por fase', value: _formatHours(minPhase), icon: Icons.trending_down),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Distribuição de carga horária por fase',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (phaseHours.isEmpty)
            const Text('Sem dados de fase disponíveis.')
          else
            ...phaseHours.entries.map((entry) {
              final phase = entry.key;
              final value = entry.value;
              final ratio = maxPhase > 0 ? (value / maxPhase) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth * ratio.clamp(0, 1);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                phase,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(_formatHours(value)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Stack(
                          children: [
                            Container(
                              height: 14,
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9EDF5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            Container(
                              height: 14,
                              width: barWidth,
                              decoration: BoxDecoration(
                                color: const Color(0xFF607D8B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildWeeklySummarySection() {
    final weeks = _weeklySummary();
    if (weeks.isEmpty) {
      return _sectionContainer(
        title: 'Resumo semanal',
        child: const Text('Sem dados semanais.'),
      );
    }

    return _sectionContainer(
      title: 'Resumo semanal',
      child: Column(
        children: weeks.map((week) {
          final weekKey = (week['week'] ?? '').toString();
          final phase = (week['phase'] ?? '').toString();
          final totalSessions = (week['total_sessions'] ?? 0).toString();
          final totalDuration = _formatHours((week['total_duration_sec'] ?? 0) as num);
          final activityCounts =
              (week['activity_counts'] as Map<String, int>);
          final targetRaces = (week['target_races'] as List<String>);

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF7F7F9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semana de $weekKey',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text('Fase: ${phase.isEmpty ? '-' : phase}'),
                    Text('Sessões: $totalSessions'),
                    Text('Carga: $totalDuration'),
                  ],
                ),
                const SizedBox(height: 8),
                if (activityCounts.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activityCounts.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFFE9EDF5),
                        ),
                        child: Text('${e.key}: ${e.value}'),
                      );
                    }).toList(),
                  ),
                if (targetRaces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Provas alvo da semana:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ...targetRaces.map((r) => Text('• $r')),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _filteredWorkouts.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text('Treinos de ${widget.athleteName}'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Filtro dos treinos na lista',
                border: OutlineInputBorder(),
                filled: true,
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pendentes')),
                DropdownMenuItem(value: 'published', child: Text('Publicados')),
                DropdownMenuItem(value: 'all', child: Text('Todos')),
              ],
              onChanged: (value) async {
                setState(() => _statusFilter = value ?? 'pending');
                _applyFilter();
                setState(() {});
              },
            ),
          ),
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAthleteContextSection(),
                _buildTargetRacesSection(),
                _buildGlobalSummarySection(),
                _buildWeeklySummarySection(),
                _sectionContainer(
                  title: 'Treinos do filtro ($total)',
                  child: _filteredWorkouts.isEmpty
                      ? const Text('Nenhum treino encontrado para este filtro.')
                      : Column(
                          children: _filteredWorkouts.map((w) {
                            final workoutId = w['id'] as int;
                            final title = (w['title'] ?? 'Treino').toString();
                            final date = _dateText((w['scheduled_date'] ?? '').toString());
                            final validationStatus =
                                (w['validation_status'] ?? '').toString();
                            final timeSlot = (w['time_slot'] ?? '').toString();
                            final plannedRpe =
                                (w['planned_rpe'] ?? '').toString();
                            final description =
                                (w['description'] ?? '').toString();

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        _statusChip(validationStatus),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Data: $date'),
                                    if (timeSlot.isNotEmpty)
                                      Text('Período: $timeSlot'),
                                    if (plannedRpe.isNotEmpty)
                                      Text('RPE: $plannedRpe'),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(description),
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.tonal(
                                          onPressed: () => _openWorkout(workoutId),
                                          child: const Text('Revisar / editar'),
                                        ),
                                        if (validationStatus != 'published')
                                          FilledButton(
                                            onPressed: () => _publishDirect(workoutId),
                                            child: const Text('Publicar para atleta'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
