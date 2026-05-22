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
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  String _statusFilter = 'planned';

  Map<String, dynamic>? _athleteProfile;
  Map<String, dynamic>? _athleteData;
  List<Map<String, dynamic>> _targetRaces = [];
  List<Map<String, dynamic>> _allWorkouts = [];
  List<Map<String, dynamic>> _filteredWorkouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

  DateTime? _d(dynamic v) {
    final s = _s(v);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _dateText(dynamic v) {
    final s = _s(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  num _n(dynamic v) => v is num ? v : 0;

  String _formatHours(num totalSec) => '${(totalSec / 3600).toStringAsFixed(1)}h';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      await Future.wait([
        _loadAthlete(),
        _loadTargetRaces(),
        _loadWorkouts(),
      ]);
      _applyFilter();
    } catch (e) {
      _msg = 'Erro ao carregar treinos do atleta: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadAthlete() async {
    final profile = await _client
        .from('profiles')
        .select('id, full_name, email, avatar_url')
        .eq('id', widget.athleteId)
        .maybeSingle();

    final athlete = await _client
        .from('athletes')
        .select(
          'id, birth_date, gender, height_cm, weight_kg, experience_level, resting_hr, max_hr, vo2_max, fitness_level, phase, garmin_connected',
        )
        .eq('id', widget.athleteId)
        .maybeSingle();

    _athleteProfile =
        profile == null ? null : Map<String, dynamic>.from(profile);
    _athleteData =
        athlete == null ? null : Map<String, dynamic>.from(athlete);
  }

  Future<void> _loadTargetRaces() async {
    final races = await _client
        .from('target_races')
        .select(
          'id, name, race_date, distance_meters, elevation_gain_m, priority, status, activity_type_id, calculated_race_category_id',
        )
        .eq('athlete_id', widget.athleteId)
        .order('race_date', ascending: true);

    _targetRaces = (races as List).cast<Map<String, dynamic>>();
  }

  Future<void> _loadWorkouts() async {
    final workouts = await _client
        .from('v_prescribed_workouts_mvp')
        .select()
        .eq('athlete_id', widget.athleteId)
        .order('scheduled_date', ascending: true)
        .order('created_at', ascending: true);

    _allWorkouts = (workouts as List).cast<Map<String, dynamic>>();
  }

  void _applyFilter() {
    if (_statusFilter == 'all') {
      _filteredWorkouts = List<Map<String, dynamic>>.from(_allWorkouts);
      return;
    }

    _filteredWorkouts = _allWorkouts.where((w) {
      final status = _s(w['status']);
      final validationStatus = _s(w['validation_status']);

      if (_statusFilter == 'planned') {
        return status == 'planned' ||
            validationStatus == 'draft' ||
            validationStatus == 'review' ||
            validationStatus == 'approved';
      }

      if (_statusFilter == 'published') {
        return status == 'published' || validationStatus == 'published';
      }

      if (_statusFilter == 'completed') {
        return status == 'completed';
      }

      return true;
    }).toList();
  }

  String _activityLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('trail')) return 'Trail';
    if (v.contains('run') || v.contains('corr')) return 'Corrida';
    if (v.contains('swim') || v.contains('nata')) return 'Natação';
    if (v.contains('bike') || v.contains('cicl')) return 'Ciclismo';
    if (v.contains('strength') || v.contains('forca')) return 'Força';
    if (v.contains('triathlon')) return 'Triathlon';
    if (v.contains('rest')) return 'Descanso';
    return raw.isEmpty ? 'Geral' : raw;
  }

  Map<String, dynamic> _summary() {
    int planned = 0;
    int published = 0;
    int completed = 0;
    num totalDuration = 0;

    final Map<String, int> byActivity = {};

    for (final w in _allWorkouts) {
      final status = _s(w['status']);
      final validationStatus = _s(w['validation_status']);
      final duration = _n(w['planned_duration_sec']);
      final activity = _activityLabel(_s(w['activity_type_id']));

      if (status == 'planned' ||
          validationStatus == 'draft' ||
          validationStatus == 'review' ||
          validationStatus == 'approved') {
        planned++;
      }

      if (status == 'published' || validationStatus == 'published') {
        published++;
      }

      if (status == 'completed') {
        completed++;
      }

      totalDuration += duration;
      byActivity[activity] = (byActivity[activity] ?? 0) + 1;
    }

    return {
      'planned': planned,
      'published': published,
      'completed': completed,
      'total': _allWorkouts.length,
      'total_duration_sec': totalDuration,
      'by_activity': byActivity,
    };
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
        'status': 'published',
        'validation_status': 'published',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
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
      case 'completed':
        color = Colors.blue;
        break;
      case 'planned':
        color = Colors.orange;
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
    final fullName =
        _s(_athleteProfile?['full_name']).isEmpty ? widget.athleteName : _s(_athleteProfile?['full_name']);
    final email = _s(_athleteProfile?['email']);
    final birthDate = _dateText(_athleteData?['birth_date']);
    final weight = _s(_athleteData?['weight_kg']);
    final height = _s(_athleteData?['height_cm']);
    final level = _s(_athleteData?['experience_level']);
    final fitness = _s(_athleteData?['fitness_level']);
    final vo2 = _s(_athleteData?['vo2_max']);
    final garmin = _athleteData?['garmin_connected'] == true ? 'Sim' : 'Não';

    return _sectionContainer(
      title: 'Contexto do atleta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullName,
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
                title: 'Peso',
                value: weight.isEmpty ? '-' : '$weight kg',
                icon: Icons.monitor_weight,
              ),
              _metricCard(
                title: 'Altura',
                value: height.isEmpty ? '-' : '$height cm',
                icon: Icons.height,
              ),
              _metricCard(
                title: 'Nível',
                value: level.isEmpty ? '-' : level,
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
                title: 'Garmin conectado',
                value: garmin,
                icon: Icons.watch,
              ),
            ],
          ),
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
          final raceName = _s(race['name']).isEmpty
              ? 'Prova alvo'
              : _s(race['name']);
          final raceDate = _dateText(race['race_date']);
          final distance = _s(race['distance_meters']);
          final priority = _s(race['priority']);
          final activity = _activityLabel(_s(race['activity_type_id']));
          final category = _s(race['calculated_race_category_id']);
          final altimetry = _s(race['elevation_gain_m']);

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
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummarySection() {
    final s = _summary();
    final byActivity = (s['by_activity'] as Map<String, int>);

    return _sectionContainer(
      title: 'Resumo dos treinos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                title: 'Planejados',
                value: '${s['planned']}',
                icon: Icons.schedule,
              ),
              _metricCard(
                title: 'Publicados',
                value: '${s['published']}',
                icon: Icons.publish,
              ),
              _metricCard(
                title: 'Concluídos',
                value: '${s['completed']}',
                icon: Icons.check_circle,
              ),
              _metricCard(
                title: 'Total',
                value: '${s['total']}',
                icon: Icons.fitness_center,
              ),
              _metricCard(
                title: 'Carga total',
                value: _formatHours(_n(s['total_duration_sec'])),
                icon: Icons.timer,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Distribuição por atividade',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (byActivity.isEmpty)
            const Text('Sem treinos cadastrados.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byActivity.entries.map((entry) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFE9EDF5),
                  ),
                  child: Text('${entry.key}: ${entry.value}'),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkoutListSection() {
    final total = _filteredWorkouts.length;

    return _sectionContainer(
      title: 'Treinos do filtro ($total)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Filtro dos treinos',
              border: OutlineInputBorder(),
              filled: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'planned',
                child: Text('Planejados'),
              ),
              DropdownMenuItem(
                value: 'published',
                child: Text('Publicados'),
              ),
              DropdownMenuItem(
                value: 'completed',
                child: Text('Concluídos'),
              ),
              DropdownMenuItem(
                value: 'all',
                child: Text('Todos'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value ?? 'planned';
                _applyFilter();
              });
            },
          ),
          const SizedBox(height: 14),
          if (_filteredWorkouts.isEmpty)
            const Text('Nenhum treino encontrado para este filtro.')
          else
            Column(
              children: _filteredWorkouts.map((w) {
                final workoutId = w['id'] as int;
                final title = _s(w['title']).isEmpty ? 'Treino' : _s(w['title']);
                final date = _dateText(w['scheduled_date']);
                final status = _s(w['status']);
                final validationStatus = _s(w['validation_status']);
                final timeSlot = _s(w['time_slot']);
                final plannedRpe = _s(w['planned_rpe']);
                final description = _s(w['description']);
                final activity = _activityLabel(_s(w['activity_type_id']));
                final durationSec = _n(w['planned_duration_sec']);

                final chipStatus =
                    status == 'published' || validationStatus == 'published'
                        ? 'published'
                        : status == 'completed'
                            ? 'completed'
                            : 'planned';

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
                            _statusChip(chipStatus),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Data: $date'),
                        Text('Atividade: $activity'),
                        if (timeSlot.isNotEmpty) Text('Período: $timeSlot'),
                        if (durationSec > 0)
                          Text('Duração planejada: ${_formatHours(durationSec)}'),
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
                            if (chipStatus != 'published' &&
                                chipStatus != 'completed')
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _buildSummarySection(),
                _buildWorkoutListSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
