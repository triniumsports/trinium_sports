import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'athlete_approved_workouts_screen.dart';
import 'athlete_my_professionals_screen.dart';
import 'athlete_search_professionals_screen.dart';

class AthleteAgendaScreen extends StatefulWidget {
  const AthleteAgendaScreen({super.key});

  @override
  State<AthleteAgendaScreen> createState() => _AthleteAgendaScreenState();
}

class _AthleteAgendaScreenState extends State<AthleteAgendaScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  String _filter = 'all';

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _athlete;
  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _filteredWorkouts = [];

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
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _msg = 'Usuário não autenticado.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final profile = await _client
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final athlete = await _client
          .from('athletes')
          .select(
            'id, weight_kg, height_cm, experience_level, resting_hr, max_hr, vo2_max, fitness_level, garmin_connected',
          )
          .eq('id', user.id)
          .maybeSingle();

      final workouts = await _client
          .from('v_prescribed_workouts_mvp')
          .select()
          .eq('athlete_id', user.id)
          .order('scheduled_date', ascending: true)
          .order('created_at', ascending: true);

      _profile = profile == null ? null : Map<String, dynamic>.from(profile);
      _athlete = athlete == null ? null : Map<String, dynamic>.from(athlete);
      _workouts = (workouts as List).cast<Map<String, dynamic>>();

      _applyFilter();
    } catch (e) {
      _msg = 'Erro ao carregar agenda: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter() {
    if (_filter == 'all') {
      _filteredWorkouts = List<Map<String, dynamic>>.from(_workouts);
      return;
    }

    _filteredWorkouts = _workouts.where((w) {
      final status = _s(w['status']);
      final validationStatus = _s(w['validation_status']);

      if (_filter == 'planned') {
        return status == 'planned' ||
            validationStatus == 'draft' ||
            validationStatus == 'review' ||
            validationStatus == 'approved';
      }

      if (_filter == 'published') {
        return status == 'published' || validationStatus == 'published';
      }

      if (_filter == 'completed') {
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

    for (final w in _workouts) {
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
      'total': _workouts.length,
      'total_duration_sec': totalDuration,
      'by_activity': byActivity,
    };
  }

  Future<void> _markCompleted(int workoutId) async {
    try {
      await _client.from('prescribed_workouts').update({
        'status': 'completed',
      }).eq('id', workoutId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino marcado como concluído ✅')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao concluir treino: $e')),
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

  Widget _buildQuickActionsSection() {
    return _sectionContainer(
      title: 'Ações rápidas',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 260,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AthleteSearchProfessionalsScreen(),
                  ),
                );
              },
              child: const Text('Marketplace'),
            ),
          ),
          SizedBox(
            width: 260,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AthleteApprovedWorkoutsScreen(),
                  ),
                );
              },
              child: const Text('Treinos publicados'),
            ),
          ),
          SizedBox(
            width: 260,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AthleteMyProfessionalsScreen(),
                  ),
                );
              },
              child: const Text('Meus profissionais'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteSummarySection() {
    final fullName = _s(_profile?['full_name']).isEmpty
        ? 'Atleta'
        : _s(_profile?['full_name']);
    final email = _s(_profile?['email']);
    final weight = _s(_athlete?['weight_kg']);
    final height = _s(_athlete?['height_cm']);
    final level = _s(_athlete?['experience_level']);
    final fitness = _s(_athlete?['fitness_level']);
    final vo2 = _s(_athlete?['vo2_max']);
    final garmin = _athlete?['garmin_connected'] == true ? 'Sim' : 'Não';

    return _sectionContainer(
      title: 'Resumo do atleta',
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

  Widget _buildWorkoutSummarySection() {
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
            const Text('Sem treinos disponíveis.')
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

  Widget _buildAgendaSection() {
    return _sectionContainer(
      title: 'Minha agenda de treinos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _filter,
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
                _filter = value ?? 'all';
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
                final timeSlot = _s(w['time_slot']);
                final plannedRpe = _s(w['planned_rpe']);
                final description = _s(w['description']);
                final durationSec = _n(w['planned_duration_sec']);
                final activity = _activityLabel(_s(w['activity_type_id']));
                final professionalName = _s(w['professional_name']);

                final status = _s(w['status']);
                final validationStatus = _s(w['validation_status']);

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
                        if (professionalName.isNotEmpty)
                          Text('Profissional: $professionalName'),
                        if (timeSlot.isNotEmpty) Text('Período: $timeSlot'),
                        if (durationSec > 0)
                          Text('Duração planejada: ${_formatHours(durationSec)}'),
                        if (plannedRpe.isNotEmpty) Text('RPE: $plannedRpe'),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description),
                        ],
                        const SizedBox(height: 12),
                        if (chipStatus == 'published')
                          FilledButton(
                            onPressed: () => _markCompleted(workoutId),
                            child: const Text('Marcar como concluído'),
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
        title: const Text('Agenda do Atleta'),
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
                _buildQuickActionsSection(),
                _buildAthleteSummarySection(),
                _buildWorkoutSummarySection(),
                _buildAgendaSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
