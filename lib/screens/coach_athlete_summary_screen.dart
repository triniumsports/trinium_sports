import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachAthleteSummaryScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const CoachAthleteSummaryScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
  });

  @override
  State<CoachAthleteSummaryScreen> createState() =>
      _CoachAthleteSummaryScreenState();
}

class _CoachAthleteSummaryScreenState extends State<CoachAthleteSummaryScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _careTeam = [];
  List<Map<String, dynamic>> _injuries = [];
  List<Map<String, dynamic>> _publishedWorkouts = [];
  List<Map<String, dynamic>> _targetRaces = [];
  List<Map<String, dynamic>> _weeklyConstraints = [];
  List<Map<String, dynamic>> _enduranceSteps = [];
  List<Map<String, dynamic>> _strengthExercises = [];
  List<Map<String, dynamic>> _weeklyLoad = [];
  List<Map<String, dynamic>> _weeklyMuscleLoad = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();
  num _n(dynamic v) => v is num ? v : 0;

  String _dateText(dynamic v) {
    final s = _s(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _formatHours(num totalSec) =>
      '${(totalSec / 3600).toStringAsFixed(1)}h';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final summaryRes = await _client
          .from('v_athlete_global_summary')
          .select()
          .eq('athlete_id', widget.athleteId)
          .maybeSingle();

      final athleteRaw = await _client
          .from('athletes')
          .select('dietary_restrictions_details')
          .eq('id', widget.athleteId)
          .maybeSingle();

      final careTeamRes = await _client
          .from('v_athlete_care_team')
          .select()
          .eq('athlete_id', widget.athleteId)
          .order('role_type', ascending: true)
          .order('professional_name', ascending: true);

      final injuriesRes = await _client
          .from('athlete_injuries_restrictions')
          .select()
          .eq('athlete_id', widget.athleteId)
          .order('created_at', ascending: false);

      final workoutsRes = await _client
          .from('v_prescribed_workouts_mvp')
          .select()
          .eq('athlete_id', widget.athleteId)
          .order('scheduled_date', ascending: true);

      final racesRes = await _client
          .from('target_races')
          .select(
            'id, name, race_date, distance_meters, elevation_gain_m, priority, status, activity_type_id, calculated_race_category_id',
          )
          .eq('athlete_id', widget.athleteId)
          .order('race_date', ascending: true);

      final weeklyRes = await _client
          .from('weekly_constraints')
          .select()
          .eq('athlete_id', widget.athleteId);

      final weeklyLoadRes = await _client
          .from('v_athlete_training_load_weekly')
          .select()
          .eq('athlete_id', widget.athleteId)
          .order('week_start', ascending: false);

      final weeklyMuscleLoadRes = await _client
          .from('v_athlete_muscle_load_weekly')
          .select()
          .eq('athlete_id', widget.athleteId)
          .order('week_start', ascending: false);

      _summary = summaryRes == null
          ? null
          : Map<String, dynamic>.from(summaryRes as Map);

      if (athleteRaw != null && _summary != null) {
        _summary!['dietary_restrictions_details'] =
            athleteRaw['dietary_restrictions_details'];
      }

      _careTeam = (careTeamRes as List).cast<Map<String, dynamic>>();
      _injuries = (injuriesRes as List).cast<Map<String, dynamic>>();
      _publishedWorkouts = (workoutsRes as List).cast<Map<String, dynamic>>();
      _targetRaces = (racesRes as List).cast<Map<String, dynamic>>();
      _weeklyConstraints = (weeklyRes as List).cast<Map<String, dynamic>>();
      _weeklyLoad = (weeklyLoadRes as List).cast<Map<String, dynamic>>();
      _weeklyMuscleLoad =
          (weeklyMuscleLoadRes as List).cast<Map<String, dynamic>>();

      final workoutIds = _publishedWorkouts
          .map((e) => e['id'])
          .whereType<int>()
          .toList();

      if (workoutIds.isNotEmpty) {
        final inValues = '(${workoutIds.join(',')})';

        final enduranceRes = await _client
            .from('prescribed_workout_steps')
            .select(
              'prescribed_workout_id, duration_type, duration_value, duration_unit, step_category',
            )
            .filter('prescribed_workout_id', 'in', inValues);

        final strengthRes = await _client
            .from('v_prescribed_strength_exercises')
            .select(
              'prescribed_workout_id, muscle_group_primary_name, exercise_name, exercise_order',
            )
            .filter('prescribed_workout_id', 'in', inValues);

        _enduranceSteps = (enduranceRes as List).cast<Map<String, dynamic>>();
        _strengthExercises = (strengthRes as List).cast<Map<String, dynamic>>();
      } else {
        _enduranceSteps = [];
        _strengthExercises = [];
      }
    } catch (e) {
      _msg = 'Erro ao carregar resumo do atleta: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleLabel(String raw) {
    switch (raw) {
      case 'running_coach':
        return 'Treinador de Corrida';
      case 'strength_coach':
        return 'Preparador Físico';
      case 'nutritionist':
        return 'Nutricionista';
      case 'physiotherapist':
        return 'Fisioterapeuta';
      case 'swim_coach':
        return 'Treinador de Natação';
      case 'triathlon_coach':
        return 'Treinador de Triathlon';
      case 'trail_coach':
        return 'Treinador de Trail';
      case 'doctor':
        return 'Médico';
      case 'coach':
        return 'Coach';
      default:
        return raw.isEmpty ? 'Profissional' : raw;
    }
  }

  String _activityLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('trail')) return 'Trail';
    if (v.contains('run') || v.contains('corr')) return 'Corrida';
    if (v.contains('swim') || v.contains('nata')) return 'Natação';
    if (v.contains('bike') || v.contains('cicl')) return 'Ciclismo';
    if (v.contains('strength') || v.contains('forca')) return 'Força';
    if (v.contains('triathlon')) return 'Triathlon';
    if (v.contains('swimrun')) return 'Swimrun';
    if (v.contains('rest')) return 'Descanso';
    return raw.isEmpty ? 'Geral' : raw;
  }

  String _weekdayLabel(dynamic raw) {
    final s = _s(raw).toLowerCase();
    switch (s) {
      case '1':
      case 'monday':
        return 'Segunda';
      case '2':
      case 'tuesday':
        return 'Terça';
      case '3':
      case 'wednesday':
        return 'Quarta';
      case '4':
      case 'thursday':
        return 'Quinta';
      case '5':
      case 'friday':
        return 'Sexta';
      case '6':
      case 'saturday':
        return 'Sábado';
      case '7':
      case 'sunday':
        return 'Domingo';
      default:
        return s.isEmpty ? '-' : s;
    }
  }

  Map<String, dynamic> _loadDashboard() {
    int totalPublished = _publishedWorkouts.length;
    int totalCompleted = 0;
    num totalDurationSec = 0;
    num totalDistanceMeters = 0;

    final Map<String, int> byActivitySessions = {};
    final Map<String, int> byMuscleGroup = {};
    final Map<String, Map<String, num>> byWeek = {};
    final Map<String, Map<String, int>> byWeekActivity = {};

    for (final w in _publishedWorkouts) {
      final activity = _activityLabel(_s(w['activity_type_id']));
      byActivitySessions[activity] = (byActivitySessions[activity] ?? 0) + 1;

      final status = _s(w['status']);
      if (status == 'completed') totalCompleted++;

      final duration = _n(w['planned_duration_sec']);
      totalDurationSec += duration;

      final date = _dateText(w['scheduled_date']);
      if (date.isNotEmpty) {
        byWeek.putIfAbsent(date, () => {
              'hours_sec': 0,
              'distance_m': 0,
              'sessions': 0,
            });
        byWeek[date]!['hours_sec'] =
            (byWeek[date]!['hours_sec'] ?? 0) + duration;
        byWeek[date]!['sessions'] =
            (byWeek[date]!['sessions'] ?? 0) + 1;

        byWeekActivity.putIfAbsent(date, () => {});
        byWeekActivity[date]![activity] =
            (byWeekActivity[date]![activity] ?? 0) + 1;
      }
    }

    for (final step in _enduranceSteps) {
      final durationType = _s(step['duration_type']);
      if (durationType == 'distance') {
        final rawValue = _n(step['duration_value']);
        final unit = _s(step['duration_unit']).toLowerCase();
        num meters = rawValue;
        if (unit == 'km') meters = rawValue * 1000;
        totalDistanceMeters += meters;
      }
    }

    for (final row in _strengthExercises) {
      final muscle = _s(row['muscle_group_primary_name']).isEmpty
          ? 'Sem grupo'
          : _s(row['muscle_group_primary_name']);
      byMuscleGroup[muscle] = (byMuscleGroup[muscle] ?? 0) + 1;
    }

    final weekEntries = byWeek.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return {
      'total_published': totalPublished,
      'total_completed': totalCompleted,
      'total_duration_sec': totalDurationSec,
      'total_distance_m': totalDistanceMeters,
      'by_activity_sessions': byActivitySessions,
      'by_muscle_group': byMuscleGroup,
      'by_week': weekEntries,
      'by_week_activity': byWeekActivity,
    };
  }

  Map<String, dynamic> _weeklyLoadSummary() {
    int plannedSessions = 0;
    int executedSessions = 0;
    num plannedDurationSec = 0;
    num executedDurationSec = 0;
    int weakFeedback = 0;
    int strengthExercises = 0;

    for (final row in _weeklyLoad) {
      plannedSessions += _n(row['planned_sessions']).toInt();
      executedSessions += _n(row['executed_sessions']).toInt();
      plannedDurationSec += _n(row['planned_duration_sec']);
      executedDurationSec += _n(row['executed_duration_sec']);
      weakFeedback += _n(row['weak_feedback_count']).toInt();
      strengthExercises += _n(row['strength_exercises_count']).toInt();
    }

    final adherence = plannedSessions == 0
        ? 0.0
        : (executedSessions / plannedSessions) * 100;

    return {
      'planned_sessions': plannedSessions,
      'executed_sessions': executedSessions,
      'planned_duration_sec': plannedDurationSec,
      'executed_duration_sec': executedDurationSec,
      'weak_feedback': weakFeedback,
      'strength_exercises': strengthExercises,
      'adherence_pct': adherence,
    };
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

  Widget _buildAthleteSection() {
    final name = _s(_summary?['athlete_name']).isEmpty
        ? widget.athleteName
        : _s(_summary?['athlete_name']);
    final email = _s(_summary?['athlete_email']);
    final birthDate = _dateText(_summary?['birth_date']);
    final gender = _s(_summary?['gender']);
    final height = _s(_summary?['height_cm']);
    final weight = _s(_summary?['weight_kg']);
    final experience = _s(_summary?['experience_level']);
    final fitness = _s(_summary?['fitness_level']);
    final vo2 = _s(_summary?['vo2_max']);
    final restingHr = _s(_summary?['resting_hr']);
    final maxHr = _s(_summary?['max_hr']);
    final phase = _s(_summary?['phase']);
    final garmin = _summary?['garmin_connected'] == true ? 'Sim' : 'Não';

    final dietDetails = _summary?['dietary_restrictions_details'];
    final allergies =
        dietDetails is Map ? (dietDetails['allergies'] ?? '').toString() : '';
    final intolerances =
        dietDetails is Map ? (dietDetails['intolerances'] ?? '').toString() : '';
    final preferences =
        dietDetails is Map ? (dietDetails['preferences'] ?? '').toString() : '';
    final medical =
        dietDetails is Map ? (dietDetails['medical'] ?? '').toString() : '';
    final supplements =
        dietDetails is Map ? (dietDetails['supplements'] ?? '').toString() : '';
    final dietNotes =
        dietDetails is Map ? (dietDetails['notes'] ?? '').toString() : '';

    return _sectionContainer(
      title: 'Resumo global do atleta',
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                title: 'Nascimento',
                value: birthDate.isEmpty ? '-' : birthDate,
                icon: Icons.cake,
              ),
              _metricCard(
                title: 'Gênero',
                value: gender.isEmpty ? '-' : gender,
                icon: Icons.person,
              ),
              _metricCard(
                title: 'Altura',
                value: height.isEmpty ? '-' : '$height cm',
                icon: Icons.height,
              ),
              _metricCard(
                title: 'Peso',
                value: weight.isEmpty ? '-' : '$weight kg',
                icon: Icons.monitor_weight,
              ),
              _metricCard(
                title: 'Nível',
                value: experience.isEmpty ? '-' : experience,
                icon: Icons.speed,
              ),
              _metricCard(
                title: 'Fitness level',
                value: fitness.isEmpty ? '-' : fitness,
                icon: Icons.insights,
              ),
              _metricCard(
                title: 'VO2 máx',
                value: vo2.isEmpty ? '-' : vo2,
                icon: Icons.favorite,
              ),
              _metricCard(
                title: 'FC repouso',
                value: restingHr.isEmpty ? '-' : restingHr,
                icon: Icons.favorite_border,
              ),
              _metricCard(
                title: 'FC máxima',
                value: maxHr.isEmpty ? '-' : maxHr,
                icon: Icons.monitor_heart,
              ),
              _metricCard(
                title: 'Fase',
                value: phase.isEmpty ? '-' : phase,
                icon: Icons.timeline,
              ),
              _metricCard(
                title: 'Garmin conectado',
                value: garmin,
                icon: Icons.watch,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Restrições alimentares detalhadas',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(title: 'Alergias', value: allergies.isEmpty ? '-' : allergies),
              _metricCard(title: 'Intolerâncias', value: intolerances.isEmpty ? '-' : intolerances),
              _metricCard(title: 'Preferências', value: preferences.isEmpty ? '-' : preferences),
              _metricCard(title: 'Restrição médica', value: medical.isEmpty ? '-' : medical),
              _metricCard(title: 'Suplementos', value: supplements.isEmpty ? '-' : supplements),
            ],
          ),
          if (dietNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Observações: $dietNotes'),
          ],
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
          final raceName =
              _s(race['name']).isEmpty ? 'Prova alvo' : _s(race['name']);
          final raceDate = _dateText(race['race_date']);
          final distance = _s(race['distance_meters']);
          final priority = _s(race['priority']);
          final activity = _activityLabel(_s(race['activity_type_id']));
          final category = _s(race['calculated_race_category_id']);
          final altimetry = _s(race['elevation_gain_m']);
          final status = _s(race['status']);

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
                    if (distance.isNotEmpty) Text('Distância: ${distance}m'),
                    if (priority.isNotEmpty) Text('Prioridade: $priority'),
                    if (activity.isNotEmpty) Text('Atividade: $activity'),
                    if (category.isNotEmpty) Text('Categoria: $category'),
                    if (altimetry.isNotEmpty) Text('Altimetria: ${altimetry}m'),
                    if (status.isNotEmpty) Text('Status: $status'),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyAvailabilitySection() {
    if (_weeklyConstraints.isEmpty) {
      return _sectionContainer(
        title: 'Disponibilidade semanal',
        child: const Text('Nenhuma disponibilidade semanal cadastrada.'),
      );
    }

    final sorted = List<Map<String, dynamic>>.from(_weeklyConstraints)
      ..sort((a, b) {
        final av = _n(a['day_of_week']);
        final bv = _n(b['day_of_week']);
        if (av == bv) {
          return _n(a['slot_order']).compareTo(_n(b['slot_order']));
        }
        return av.compareTo(bv);
      });

    return _sectionContainer(
      title: 'Disponibilidade semanal',
      child: Column(
        children: sorted.map((row) {
          final day = _weekdayLabel(row['day_of_week']);
          final activity = _activityLabel(_s(row['activity_type_id']));
          final slot = _s(row['time_slot']);
          final maxDurationSec = _n(row['max_duration_sec']);
          final notes = _s(row['notes']);
          final slotOrder = _n(row['slot_order']).toInt();

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
                  '$day • ${slotOrder == 1 ? 'Opção principal' : 'Opção secundária'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (activity.isNotEmpty) Text('Modalidade: $activity'),
                    if (slot.isNotEmpty) Text('Período: $slot'),
                    if (maxDurationSec > 0)
                      Text('Tempo disponível: ${(maxDurationSec / 60).toStringAsFixed(0)} min'),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Obs: $notes'),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCareTeamSection() {
    if (_careTeam.isEmpty) {
      return _sectionContainer(
        title: 'Time de cuidado',
        child: const Text('Nenhum profissional ativo encontrado.'),
      );
    }

    return _sectionContainer(
      title: 'Time de cuidado',
      child: Column(
        children: _careTeam.map((row) {
          final name = _s(row['professional_name']).isEmpty
              ? 'Profissional'
              : _s(row['professional_name']);
          final email = _s(row['professional_email']);
          final phone = _s(row['phone_mobile']);
          final role = _roleLabel(_s(row['role_type']));

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
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(role),
                if (email.isNotEmpty) Text('E-mail: $email'),
                if (phone.isNotEmpty) Text('Telefone: $phone'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInjuriesSection() {
    if (_injuries.isEmpty) {
      return _sectionContainer(
        title: 'Restrições físicas / lesões',
        child: const Text('Nenhuma restrição ou lesão cadastrada.'),
      );
    }

    return _sectionContainer(
      title: 'Restrições físicas / lesões',
      child: Column(
        children: _injuries.map((row) {
          final type = _s(row['restriction_type']);
          final title = _s(row['title']).isEmpty ? 'Registro' : _s(row['title']);
          final bodyRegion = _s(row['body_region']);
          final severity = _s(row['severity']);
          final status = _s(row['status']);
          final startDate = _dateText(row['start_date']);
          final expectedEndDate = _dateText(row['expected_end_date']);
          final notes = _s(row['notes']);
          final recommendations = _s(row['recommendations']);

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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (type.isNotEmpty) Text('Tipo: $type'),
                    if (bodyRegion.isNotEmpty) Text('Região: $bodyRegion'),
                    if (severity.isNotEmpty) Text('Severidade: $severity'),
                    if (status.isNotEmpty) Text('Status: $status'),
                    if (startDate.isNotEmpty) Text('Início: $startDate'),
                    if (expectedEndDate.isNotEmpty)
                      Text('Fim previsto: $expectedEndDate'),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Obs: $notes'),
                ],
                if (recommendations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Recomendações: $recommendations'),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDashboardSection() {
    final d = _loadDashboard();
    final byActivitySessions = (d['by_activity_sessions'] as Map<String, int>);
    final byMuscleGroup = (d['by_muscle_group'] as Map<String, int>);
    final byWeek = (d['by_week'] as List<MapEntry<String, Map<String, num>>>);
    final byWeekActivity = (d['by_week_activity'] as Map<String, Map<String, int>>);

    return _sectionContainer(
      title: 'Dashboard de carga',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                title: 'Treinos publicados',
                value: '${d['total_published']}',
                icon: Icons.publish,
              ),
              _metricCard(
                title: 'Treinos concluídos',
                value: '${d['total_completed']}',
                icon: Icons.check_circle,
              ),
              _metricCard(
                title: 'Horas totais',
                value: _formatHours(_n(d['total_duration_sec'])),
                icon: Icons.timer,
              ),
              _metricCard(
                title: 'Distância total',
                value: '${(_n(d['total_distance_m']) / 1000).toStringAsFixed(1)} km',
                icon: Icons.route,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Carga por modalidade',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (byActivitySessions.isEmpty)
            const Text('Sem distribuição por modalidade.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byActivitySessions.entries.map((entry) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFE9EDF5),
                  ),
                  child: Text('${entry.key}: ${entry.value} sessões'),
                );
              }).toList(),
            ),
          const SizedBox(height: 18),
          const Text(
            'Carga de força por grupo muscular',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (byMuscleGroup.isEmpty)
            const Text('Sem dados de força por grupo muscular.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byMuscleGroup.entries.map((entry) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFE9EDF5),
                  ),
                  child: Text('${entry.key}: ${entry.value} exercícios'),
                );
              }).toList(),
            ),
          const SizedBox(height: 18),
          const Text(
            'Horas / distância por semana',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (byWeek.isEmpty)
            const Text('Sem dados semanais.')
          else
            Column(
              children: byWeek.take(8).map((entry) {
                final week = entry.key;
                final data = entry.value;
                final hoursSec = _n(data['hours_sec']);
                final distanceM = _n(data['distance_m']);
                final sessions = _n(data['sessions']);
                final activities = byWeekActivity[week] ?? {};

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
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Semana de $week',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('Sessões: ${sessions.toInt()}'),
                          Text('Horas: ${(hoursSec / 3600).toStringAsFixed(1)}h'),
                          Text('Distância: ${(distanceM / 1000).toStringAsFixed(1)} km'),
                        ],
                      ),
                      if (activities.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activities.entries.map((a) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFFE9EDF5),
                              ),
                              child: Text('${a.key}: ${a.value}'),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyLoadSection() {
    final summary = _weeklyLoadSummary();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in _weeklyLoad) {
      final week = _dateText(row['week_start']);
      grouped.putIfAbsent(week, () => []);
      grouped[week]!.add(row);
    }

    final orderedWeeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return _sectionContainer(
      title: 'Planned vs Executed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                title: 'Sessões planejadas',
                value: '${summary['planned_sessions']}',
                icon: Icons.event_note,
              ),
              _metricCard(
                title: 'Sessões executadas',
                value: '${summary['executed_sessions']}',
                icon: Icons.done_all,
              ),
              _metricCard(
                title: 'Aderência',
                value: '${(summary['adherence_pct'] as double).toStringAsFixed(0)}%',
                icon: Icons.percent,
              ),
              _metricCard(
                title: 'Feedback fraco',
                value: '${summary['weak_feedback']}',
                icon: Icons.warning_amber,
              ),
              _metricCard(
                title: 'Exercícios força',
                value: '${summary['strength_exercises']}',
                icon: Icons.fitness_center,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (orderedWeeks.isEmpty)
            const Text('Sem dados de carga semanal.')
          else
            Column(
              children: orderedWeeks.take(8).map((week) {
                final rows = grouped[week]!;
                int plannedSessions = 0;
                int executedSessions = 0;
                num plannedDurationSec = 0;
                num executedDurationSec = 0;
                int weakFeedback = 0;
                int strengthExercises = 0;

                for (final row in rows) {
                  plannedSessions += _n(row['planned_sessions']).toInt();
                  executedSessions += _n(row['executed_sessions']).toInt();
                  plannedDurationSec += _n(row['planned_duration_sec']);
                  executedDurationSec += _n(row['executed_duration_sec']);
                  weakFeedback += _n(row['weak_feedback_count']).toInt();
                  strengthExercises += _n(row['strength_exercises_count']).toInt();
                }

                final adherence = plannedSessions == 0
                    ? 0.0
                    : (executedSessions / plannedSessions) * 100;

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
                        'Semana de $week',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text('Planejado: $plannedSessions sessões'),
                          Text('Executado: $executedSessions sessões'),
                          Text('Aderência: ${adherence.toStringAsFixed(0)}%'),
                          Text('Horas plan.: ${(plannedDurationSec / 3600).toStringAsFixed(1)}h'),
                          Text('Horas exec.: ${(executedDurationSec / 3600).toStringAsFixed(1)}h'),
                          Text('Feedback fraco: $weakFeedback'),
                          Text('Força: $strengthExercises exercícios'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rows.map((row) {
                          final activity = _activityLabel(_s(row['activity_type_id']));
                          final planned = _n(row['planned_sessions']).toInt();
                          final executed = _n(row['executed_sessions']).toInt();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFFE9EDF5),
                            ),
                            child: Text('$activity: $executed/$planned'),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMuscleLoadSection() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in _weeklyMuscleLoad) {
      final week = _dateText(row['week_start']);
      grouped.putIfAbsent(week, () => []);
      grouped[week]!.add(row);
    }

    final weeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return _sectionContainer(
      title: 'Carga muscular estimada',
      child: weeks.isEmpty
          ? const Text('Sem dados de carga muscular.')
          : Column(
              children: weeks.take(8).map((week) {
                final rows = grouped[week]!
                  ..sort((a, b) =>
                      _n(b['total_load_points']).compareTo(_n(a['total_load_points'])));

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
                        'Semana de $week',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rows.take(12).map((row) {
                          final muscle = _s(row['muscle_group_name']);
                          final total = _n(row['total_load_points']).toStringAsFixed(1);
                          final strength = _n(row['strength_load_points']).toStringAsFixed(1);
                          final modality = _n(row['modality_load_points']).toStringAsFixed(1);

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFFE9EDF5),
                            ),
                            child: Text(
                              '$muscle • total $total • força $strength • modalidade $modality',
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text('Resumo de ${widget.athleteName}'),
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAthleteSection(),
                _buildTargetRacesSection(),
                _buildWeeklyAvailabilitySection(),
                _buildCareTeamSection(),
                _buildInjuriesSection(),
                _buildWeeklyLoadSection(),
                _buildDashboardSection(),
                _buildMuscleLoadSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
