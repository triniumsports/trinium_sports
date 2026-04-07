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

  List<Map<String, dynamic>> _workouts = [];
  Map<String, dynamic>? _mainRace;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _weeklySummary = [];

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
        _loadMainRace(),
        _loadWorkouts(),
      ]);
      _buildSummary();
    } catch (e) {
      _msg = 'Erro ao carregar treinos: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMainRace() async {
    final races = await _client
        .from('target_races')
        .select(
          'id, athlete_id, race_date, status, distance_meters, priority, calculated_race_category_id, activity_type_id'
        )
        .eq('athlete_id', widget.athleteId)
        .eq('status', 'planned')
        .order('race_date', ascending: true)
        .limit(1);

    if ((races as List).isNotEmpty) {
      _mainRace = Map<String, dynamic>.from(races.first);
    } else {
      _mainRace = null;
    }
  }

  Future<void> _loadWorkouts() async {
    var query = _client
        .from('prescribed_workouts')
        .select('*')
        .eq('athlete_id', widget.athleteId);

    if (_statusFilter != 'all') {
      query = query.eq('validation_status', _statusFilter);
    }

    final res = await query.order('scheduled_date', ascending: true);
    _workouts = (res as List).cast<Map<String, dynamic>>();
  }

  void _buildSummary() {
    final total = _workouts.length;
    int pending = 0;
    int published = 0;

    num totalDurationSec = 0;
    final Map<String, int> byTimeSlot = {};
    final Map<String, int> byStatus = {};
    final Map<String, Map<String, dynamic>> weekMap = {};

    for (final w in _workouts) {
      final status = (w['validation_status'] ?? '').toString();
      final timeSlot = (w['time_slot'] ?? 'Sem período').toString();
      final duration = (w['planned_duration_sec'] ?? 0);

      if (status == 'pending') pending++;
      if (status == 'published') published++;

      byStatus[status] = (byStatus[status] ?? 0) + 1;
      byTimeSlot[timeSlot] = (byTimeSlot[timeSlot] ?? 0) + 1;

      if (duration is num) {
        totalDurationSec += duration;
      }

      final date = (w['scheduled_date'] ?? '').toString();
      final weekKey = _weekKey(date);

      weekMap.putIfAbsent(weekKey, () {
        return {
          'week_key': weekKey,
          'total_sessions': 0,
          'pending': 0,
          'published': 0,
          'total_duration_sec': 0,
        };
      });

      weekMap[weekKey]!['total_sessions'] =
          (weekMap[weekKey]!['total_sessions'] as int) + 1;

      if (status == 'pending') {
        weekMap[weekKey]!['pending'] =
            (weekMap[weekKey]!['pending'] as int) + 1;
      }
      if (status == 'published') {
        weekMap[weekKey]!['published'] =
            (weekMap[weekKey]!['published'] as int) + 1;
      }
      if (duration is num) {
        weekMap[weekKey]!['total_duration_sec'] =
            (weekMap[weekKey]!['total_duration_sec'] as num) + duration;
      }
    }

    _summary = {
      'total': total,
      'pending': pending,
      'published': published,
      'total_duration_sec': totalDurationSec,
      'by_status': byStatus,
      'by_time_slot': byTimeSlot,
    };

    _weeklySummary = weekMap.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) =>
          (a['week_key'] ?? '').toString().compareTo((b['week_key'] ?? '').toString()));
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

  String _dateText(String raw) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _formatHours(num totalSec) {
    final hours = totalSec / 3600.0;
    return '${hours.toStringAsFixed(1)}h';
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

  Widget _infoCard({
    required String title,
    required String value,
    IconData? icon,
  }) {
    return Container(
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

  Widget _buildMainRaceSection() {
    final race = _mainRace;
    if (race == null) {
      return const SizedBox.shrink();
    }

    final raceDate = _dateText((race['race_date'] ?? '').toString());
    final distance = (race['distance_meters'] ?? '').toString();
    final priority = (race['priority'] ?? '').toString();
    final category = (race['calculated_race_category_id'] ?? '').toString();
    final activity = (race['activity_type_id'] ?? '').toString();

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
          const Text(
            'Prova alvo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _infoCard(title: 'Data', value: raceDate, icon: Icons.event),
              _infoCard(title: 'Distância', value: '${distance}m', icon: Icons.straighten),
              _infoCard(title: 'Prioridade', value: priority, icon: Icons.flag),
              _infoCard(title: 'Categoria', value: category, icon: Icons.category),
              _infoCard(title: 'Atividade', value: activity, icon: Icons.directions_run),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

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
          const Text(
            'Resumo global do plano',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _infoCard(
                title: 'Total de treinos',
                value: '${s['total']}',
                icon: Icons.fitness_center,
              ),
              _infoCard(
                title: 'Pendentes',
                value: '${s['pending']}',
                icon: Icons.schedule,
              ),
              _infoCard(
                title: 'Publicados',
                value: '${s['published']}',
                icon: Icons.check_circle,
              ),
              _infoCard(
                title: 'Carga planejada',
                value: _formatHours((s['total_duration_sec'] ?? 0) as num),
                icon: Icons.timer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummarySection() {
    if (_weeklySummary.isEmpty) return const SizedBox.shrink();

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
          const Text(
            'Resumo semanal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._weeklySummary.map((week) {
            final weekKey = (week['week_key'] ?? '').toString();
            final totalSessions = (week['total_sessions'] ?? 0).toString();
            final pending = (week['pending'] ?? 0).toString();
            final published = (week['published'] ?? 0).toString();
            final totalDuration = _formatHours(
              (week['total_duration_sec'] ?? 0) as num,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF7F7F9),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Semana de $weekKey',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('Sessões: $totalSessions'),
                  const SizedBox(width: 12),
                  Text('Pend: $pending'),
                  const SizedBox(width: 12),
                  Text('Pub: $published'),
                  const SizedBox(width: 12),
                  Text(totalDuration),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _workouts.length;

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
                labelText: 'Filtro',
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
                await _load();
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
                _buildMainRaceSection(),
                _buildSummarySection(),
                _buildWeeklySummarySection(),
                Container(
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
                        'Treinos do filtro (${total})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_workouts.isEmpty)
                        const Text('Nenhum treino encontrado para este filtro.')
                      else
                        ..._workouts.map((w) {
                          final workoutId = w['id'] as int;
                          final title = (w['title'] ?? 'Treino').toString();
                          final date = _dateText((w['scheduled_date'] ?? '').toString());
                          final validationStatus =
                              (w['validation_status'] ?? '').toString();
                          final timeSlot = (w['time_slot'] ?? '').toString();
                          final plannedRpe = (w['planned_rpe'] ?? '').toString();
                          final description = (w['description'] ?? '').toString();

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
                        }),
                    ],
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
