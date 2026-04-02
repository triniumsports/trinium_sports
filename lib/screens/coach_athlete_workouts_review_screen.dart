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
      var query = _client
          .from('prescribed_workouts')
          .select('*')
          .eq('athlete_id', widget.athleteId)
          .eq('coach_id', user.id);

      if (_statusFilter != 'all') {
        query = query.eq('validation_status', _statusFilter);
      }

      final res = await query.order('scheduled_date', ascending: true);
      _workouts = (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar treinos: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateText(String raw) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
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

  @override
  Widget build(BuildContext context) {
    final total = _workouts.length;

    return Scaffold(
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
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filtro',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$total treino(s) encontrado(s)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
            child: _workouts.isEmpty
                ? const Center(
                    child: Text('Nenhum treino encontrado para este filtro.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _workouts.length,
                    itemBuilder: (context, index) {
                      final w = _workouts[index];
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
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
