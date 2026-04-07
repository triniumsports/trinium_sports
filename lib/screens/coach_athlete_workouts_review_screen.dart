import 'dart:convert';

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
  Map<int, List<Map<String, dynamic>>> _segmentsByRaceId = {};
  Map<String, dynamic>? _athlete;
  Map<String, dynamic> _periodizationByCategory = {};

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
        _loadAthlete(),
        _loadTargetRacesAndSegments(),
        _loadWorkouts(),
      ]);
      await _loadPeriodizationKnowledge();
      _applyFilter();
    } catch (e) {
      _msg = 'Erro ao carregar dashboard: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAthlete() async {
    final athlete = await _client
        .from('athletes')
        .select('*')
        .eq('id', widget.athleteId)
        .maybeSingle();

    _athlete = athlete == null ? null : Map<String, dynamic>.from(athlete);
  }

  Future<void> _loadTargetRacesAndSegments() async {
    final races = await _client
        .from('target_races')
        .select('*')
        .eq('athlete_id', widget.athleteId)
        .order('race_date', ascending: true);

    _targetRaces = (races as List).cast<Map<String, dynamic>>();

    _segmentsByRaceId = {};
    final raceIds = _targetRaces
        .map((e) => e['id'])
        .where((e) => e != null)
        .cast<int>()
        .toList();

    if (raceIds.isEmpty) return;

    final inValues = '(${raceIds.join(',')})';

    try {
      final segments = await _client
          .from('race_segments')
          .select('*')
          .filter('target_race_id', 'in', inValues)
          .order('segment_order', ascending: true);

      for (final row in (segments as List).cast<Map<String, dynamic>>()) {
        final raceId = row['target_race_id'];
        if (raceId is int) {
          _segmentsByRaceId.putIfAbsent(raceId, () => []);
          _segmentsByRaceId[raceId]!.add(row);
        }
      }
    } catch (_) {
      _segmentsByRaceId = {};
    }
  }

  Future<void> _loadWorkouts() async {
    final workouts = await _client
        .from('prescribed_workouts')
        .select('*')
        .eq('athlete_id', widget.athleteId)
        .order('scheduled_date', ascending: true);

    _allWorkouts = (workouts as List).cast<Map<String, dynamic>>();
  }

  Future<void> _loadPeriodizationKnowledge() async {
    final fitnessLevel = _string(_athlete?['fitness_level']).isNotEmpty
        ? _string(_athlete?['fitness_level'])
        : _string(_athlete?['experience_level']);

    _periodizationByCategory = {};
    if (fitnessLevel.isEmpty) return;

    final categories = _targetRaces
        .map((r) => _string(r['calculated_race_category_id']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (categories.isEmpty) return;

    final inValues = '(${categories.map((e) => "'$e'").join(',')})';

    try {
      final rows = await _client
          .from('knowledge_base_periodization')
          .select('*')
          .filter('race_category', 'in', inValues)
          .eq('fitness_level', fitnessLevel);

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final category = _string(row['race_category']);
        if (category.isNotEmpty) {
          _periodizationByCategory[category] = row;
        }
      }
    } catch (_) {
      _periodizationByCategory = {};
    }
  }

  void _applyFilter() {
    if (_statusFilter == 'all') {
      _filteredWorkouts = List<Map<String, dynamic>>.from(_allWorkouts);
      return;
    }

    _filteredWorkouts = _allWorkouts
        .where((w) => _string(w['validation_status']) == _statusFilter)
        .toList();
  }

  String _string(dynamic value) => value == null ? '' : value.toString().trim();

  num _num(dynamic value) => value is num ? value : 0;

  String _dateText(String raw) => raw.length >= 10 ? raw.substring(0, 10) : raw;

  DateTime? _parseDate(dynamic raw) {
    final text = _string(raw);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _formatHours(num totalSec) {
    final hours = totalSec / 3600.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  String _activityLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('trail')) return 'Trail';
    if (v.contains('run') || v.contains('corr')) return 'Corrida';
    if (v.contains('swim') || v.contains('nata')) return 'Natação';
    if (v.contains('bike') || v.contains('cicl')) return 'Ciclismo';
    if (v.contains('strength') || v.contains('forca')) return 'Força';
    if (v.contains('rest')) return 'Descanso';
    if (v.contains('swimrun')) return 'Swimrun';
    return raw.isEmpty ? 'Geral' : raw;
  }

  String _workoutActivity(Map<String, dynamic> w) {
    final direct = _string(w['activity_type_id']);
    if (direct.isNotEmpty) return direct;

    final title = _string(w['title']).toLowerCase();
    if (title.contains('swim') || title.contains('nata')) return 'swimming';
    if (title.contains('bike') || title.contains('cicl')) return 'cycling';
    if (title.contains('strength') || title.contains('força')) return 'strength';
    if (title.contains('trail')) return 'trail_running';
    if (title.contains('run') || title.contains('corr')) return 'running';
    return 'geral';
  }

  Map<String, dynamic>? _mainRaceForWorkoutDate(DateTime workoutDate) {
    for (final race in _targetRaces) {
      final raceDate = _parseDate(race['race_date']);
      if (raceDate != null && !workoutDate.isAfter(raceDate)) {
        return race;
      }
    }
    return _targetRaces.isNotEmpty ? _targetRaces.last : null;
  }

  String _phaseOf(Map<String, dynamic> workout) {
    final direct = _string(workout['periodization_phase']);
    if (direct.isNotEmpty) return direct;

    final scheduledDate = _parseDate(workout['scheduled_date']);
    if (scheduledDate == null) return 'sem_fase';

    final race = _mainRaceForWorkoutDate(scheduledDate);
    if (race == null) return 'sem_fase';

    final raceDate = _parseDate(race['race_date']);
    final category = _string(race['calculated_race_category_id']);
    if (raceDate == null || category.isEmpty) return 'sem_fase';

    final row = _periodizationByCategory[category];
    final recommendedWeeks =
        row != null && row['recommended_weeks'] is num ? (row['recommended_weeks'] as num).toInt() : 12;

    final prepStart = raceDate.subtract(Duration(days: recommendedWeeks * 7));
    final prepEnd = raceDate;
    final totalDays = prepEnd.difference(prepStart).inDays;

    if (totalDays <= 0) return 'race';

    final baseEnd = prepStart.add(Duration(days: (totalDays * 0.50).floor()));
    final buildEnd = prepStart.add(Duration(days: (totalDays * 0.80).floor()));
    final peakEnd = prepEnd.subtract(const Duration(days: 14));
    final taperEnd = prepEnd.subtract(const Duration(days: 7));

    if (scheduledDate.isBefore(baseEnd)) return 'base';
    if (scheduledDate.isBefore(buildEnd)) return 'build';
    if (scheduledDate.isBefore(peakEnd)) return 'peak';
    if (scheduledDate.isBefore(taperEnd)) return 'taper';
    return 'race';
  }

  num _durationSec(Map<String, dynamic> workout) {
    final v = workout['planned_duration_sec'];
    return v is num ? v : 0;
  }

  Map<String, dynamic> _globalSummary() {
    int pending = 0;
    int published = 0;
    num totalDuration = 0;
    final Map<String, num> phaseHours = {};

    for (final w in _allWorkouts) {
      final status = _string(w['validation_status']);
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

  Map<int, Map<String, Map<String, num>>> _phaseByRaceByActivity() {
    final Map<int, Map<String, Map<String, num>>> summary = {};

    for (final race in _targetRaces) {
      final raceId = race['id'];
      if (raceId is int) {
        summary[raceId] = {};
      }
    }

    for (final w in _allWorkouts) {
      final scheduledDate = _parseDate(w['scheduled_date']);
      if (scheduledDate == null) continue;

      final race = _mainRaceForWorkoutDate(scheduledDate);
      final raceId = race?['id'];
      if (raceId is! int) continue;

      final phase = _phaseOf(w);
      final activity = _activityLabel(_workoutActivity(w));
      final duration = _durationSec(w);

      summary.putIfAbsent(raceId, () => {});
      summary[raceId]!.putIfAbsent(phase, () => {});
      summary[raceId]![phase]![activity] =
          (summary[raceId]![phase]![activity] ?? 0) + duration;
    }

    return summary;
  }

  List<Map<String, dynamic>> _weeklySummary() {
    final Map<String, Map<String, dynamic>> weekMap = {};

    for (final w in _allWorkouts) {
      final date = _string(w['scheduled_date']);
      final week = _weekKey(date);
      final phase = _phaseOf(w);
      final activity = _activityLabel(_workoutActivity(w));
      final duration = _durationSec(w);

      weekMap.putIfAbsent(week, () {
        return {
          'week': week,
          'phase': phase,
          'total_sessions': 0,
          'total_duration_sec': 0,
          'activity_counts': <String, int>{},
          'activity_duration_sec': <String, num>{},
          'target_races': <String>[],
        };
      });

      weekMap[week]!['phase'] =
          _string(weekMap[week]!['phase']).isEmpty ? phase : weekMap[week]!['phase'];

      weekMap[week]!['total_sessions'] =
          (weekMap[week]!['total_sessions'] as int) + 1;
      weekMap[week]!['total_duration_sec'] =
          (weekMap[week]!['total_duration_sec'] as num) + duration;

      final activityCounts = weekMap[week]!['activity_counts'] as Map<String, int>;
      final activityDurations =
          weekMap[week]!['activity_duration_sec'] as Map<String, num>;

      activityCounts[activity] = (activityCounts[activity] ?? 0) + 1;
      activityDurations[activity] = (activityDurations[activity] ?? 0) + duration;
    }

    for (final race in _targetRaces) {
      final date = _string(race['race_date']);
      final week = _weekKey(date);

      weekMap.putIfAbsent(week, () {
        return {
          'week': week,
          'phase': '',
          'total_sessions': 0,
          'total_duration_sec': 0,
          'activity_counts': <String, int>{},
          'activity_duration_sec': <String, num>{},
          'target_races': <String>[],
        };
      });

      final races = weekMap[week]!['target_races'] as List<String>;
      final raceName = _raceDisplayName(race);
      final priority = _string(race['priority']);
      races.add(priority.isEmpty ? raceName : '$raceName ($priority)');
    }

    final list = weekMap.values.map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => _string(a['week']).compareTo(_string(b['week'])));

    return list;
  }

  String _weekKey(String rawDate) {
    final dt = _parseDate(rawDate);
    if (dt == null) return rawDate;
    final monday = dt.subtract(Duration(days: dt.weekday - 1));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _raceDisplayName(Map<String, dynamic> race) {
    final name = _string(race['name']);
    if (name.isNotEmpty) return name;
    final distance = _string(race['distance_meters']);
    return distance.isEmpty ? 'Prova alvo' : 'Prova ${distance}m';
  }

  List<Map<String, dynamic>> _fallbackSegmentsFromNotes(Map<String, dynamic> race) {
    final notes = race['notes'];
    if (notes == null) return [];

    try {
      final text = notes.toString();
      if (text.trim().isEmpty) return [];
      final decoded = jsonDecode(text);

      if (decoded is Map && decoded['splits'] is List) {
        final splits = decoded['splits'] as List;
        return splits
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}

    return [];
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
      width: 220,
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAthleteContextSection() {
    final weight = _string(_athlete?['weight_kg']);
    final height = _string(_athlete?['height_cm']);
    final level = _string(_athlete?['experience_level']).isNotEmpty
        ? _string(_athlete?['experience_level'])
        : _string(_athlete?['fitness_level']);
    final gender = _string(_athlete?['gender']);
    final maxHr = _string(_athlete?['max_hr']);
    final restHr = _string(_athlete?['resting_hr']);
    final vo2 = _string(_athlete?['vo2_max']);
    final comorbidity = _string(_athlete?['comorbidities']);
    final restrictions = _string(_athlete?['restrictions']);

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
          final raceId = race['id'];
          final raceDate = _dateText(_string(race['race_date']));
          final distance = _string(race['distance_meters']);
          final priority = _string(race['priority']);
          final category = _string(race['calculated_race_category_id']);
          final activity = _string(race['activity_type_id']);
          final status = _string(race['status']);
          final raceName = _raceDisplayName(race);
          final altimetry = _string(race['elevation_gain_m']);

          var segments = <Map<String, dynamic>>[];
          if (raceId is int) {
            segments = _segmentsByRaceId[raceId] ?? [];
          }
          if (segments.isEmpty) {
            segments = _fallbackSegmentsFromNotes(race);
          }

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
                  raceName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text('Data: $raceDate'),
                    Text('Distância total: ${distance}m'),
                    Text('Prioridade: $priority'),
                    Text('Categoria: $category'),
                    Text('Atividade: $activity'),
                    Text('Status: $status'),
                    if (altimetry.isNotEmpty) Text('Altimetria: $altimetry m'),
                  ],
                ),
                if (segments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Distâncias por atividade',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: segments.map((seg) {
                      final segActivity = _activityLabel(
                        _string(seg['activity_type_id']).isNotEmpty
                            ? _string(seg['activity_type_id'])
                            : _string(seg['segment_type']),
                      );
                      final segDistance = _string(seg['distance_meters']).isNotEmpty
                          ? _string(seg['distance_meters'])
                          : _string(seg['distance']);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFFE9EDF5),
                        ),
                        child: Text('$segActivity: ${segDistance}m'),
                      );
                    }).toList(),
                  ),
                ],
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
    final phaseByRace = _phaseByRaceByActivity();

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
              _metricCard(title: 'Carga total', value: _formatHours(_num(s['total_duration_sec'])), icon: Icons.timer),
              _metricCard(title: 'Carga máx. por fase', value: _formatHours(maxPhase), icon: Icons.trending_up),
              _metricCard(title: 'Carga mín. por fase', value: _formatHours(minPhase), icon: Icons.trending_down),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Distribuição de carga horária por fase da periodização',
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
                            Expanded(child: Text(phase, style: const TextStyle(fontWeight: FontWeight.w600))),
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
          const SizedBox(height: 18),
          const Text(
            'Distribuição por fase e atividade dentro de cada prova alvo',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (phaseByRace.isEmpty)
            const Text('Sem dados por prova alvo.')
          else
            ..._targetRaces.map((race) {
              final raceId = race['id'];
              if (raceId is! int) return const SizedBox.shrink();

              final raceName = _raceDisplayName(race);
              final raceDate = _dateText(_string(race['race_date']));
              final phaseMap = phaseByRace[raceId] ?? {};

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF7F7F9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$raceName • $raceDate',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (phaseMap.isEmpty)
                      const Text('Sem carga atribuída a esta prova.')
                    else
                      ...phaseMap.entries.map((phaseEntry) {
                        final phase = phaseEntry.key;
                        final activityMap = phaseEntry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                phase,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: activityMap.entries.map((a) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: const Color(0xFFE9EDF5),
                                    ),
                                    child: Text('${a.key}: ${_formatHours(a.value)}'),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            }).toList(),
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
          final weekKey = _string(week['week']);
          final phase = _string(week['phase']);
          final totalSessions = _string(week['total_sessions']);
          final totalDuration = _formatHours(_num(week['total_duration_sec']));
          final activityCounts = week['activity_counts'] as Map<String, int>;
          final activityDurations = week['activity_duration_sec'] as Map<String, num>;
          final targetRaces = week['target_races'] as List<String>;

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
                Text('Semana de $weekKey', style: const TextStyle(fontWeight: FontWeight.w700)),
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
                if (activityCounts.isNotEmpty) ...[
                  const Text('Sessões por atividade', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
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
                ],
                if (activityDurations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Carga por atividade', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activityDurations.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFFF1F5F9),
                        ),
                        child: Text('${e.key}: ${_formatHours(e.value)}'),
                      );
                    }).toList(),
                  ),
                ],
                if (targetRaces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Provas alvo da semana', style: TextStyle(fontWeight: FontWeight.w600)),
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
              onChanged: (value) {
                setState(() {
                  _statusFilter = value ?? 'pending';
                  _applyFilter();
                });
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
                            final title = _string(w['title']).isEmpty ? 'Treino' : _string(w['title']);
                            final date = _dateText(_string(w['scheduled_date']));
                            final validationStatus = _string(w['validation_status']);
                            final timeSlot = _string(w['time_slot']);
                            final plannedRpe = _string(w['planned_rpe']);
                            final description = _string(w['description']);

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
                                    Text('Fase: ${_phaseOf(w)}'),
                                    if (timeSlot.isNotEmpty) Text('Período: $timeSlot'),
                                    if (plannedRpe.isNotEmpty) Text('RPE: $plannedRpe'),
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
