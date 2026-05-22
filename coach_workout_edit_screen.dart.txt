import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachWorkoutEditScreen extends StatefulWidget {
  final int workoutId;

  const CoachWorkoutEditScreen({
    super.key,
    required this.workoutId,
  });

  @override
  State<CoachWorkoutEditScreen> createState() => _CoachWorkoutEditScreenState();
}

class _CoachWorkoutEditScreenState extends State<CoachWorkoutEditScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  Map<String, dynamic>? _workout;
  List<Map<String, dynamic>> _steps = [];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _rpeController = TextEditingController();

  final Map<String, TextEditingController> _stepDurationControllers = {};
  final Map<String, TextEditingController> _stepNotesControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _rpeController.dispose();

    for (final c in _stepDurationControllers.values) {
      c.dispose();
    }
    for (final c in _stepNotesControllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final workout = await _client
          .from('prescribed_workouts')
          .select('*')
          .eq('id', widget.workoutId)
          .maybeSingle();

      if (workout == null) {
        throw Exception('Treino não encontrado.');
      }

      final steps = await _client
          .from('prescribed_workout_steps')
          .select('*')
          .eq('prescribed_workout_id', widget.workoutId)
          .order('step_order', ascending: true);

      _workout = Map<String, dynamic>.from(workout);
      _steps = (steps as List).cast<Map<String, dynamic>>();

      _titleController.text = (_workout?['title'] ?? '').toString();
      _descriptionController.text = (_workout?['description'] ?? '').toString();
      _durationController.text =
          (_workout?['planned_duration_sec'] ?? '').toString();
      _rpeController.text = (_workout?['planned_rpe'] ?? '').toString();

      for (final s in _steps) {
        final id = (s['id'] ?? '').toString();
        _stepDurationControllers[id] =
            TextEditingController(text: (s['duration_value'] ?? '').toString());
        _stepNotesControllers[id] =
            TextEditingController(text: (s['notes'] ?? '').toString());
      }
    } catch (e) {
      _msg = 'Erro ao carregar treino: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num? _toNumOrNull(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return num.tryParse(v);
  }

  Future<void> _saveDraft() async {
    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      await _client.from('prescribed_workouts').update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'planned_duration_sec': _toNumOrNull(_durationController.text),
        'planned_rpe': _toNumOrNull(_rpeController.text),
        'validation_status': 'pending',
      }).eq('id', widget.workoutId);

      for (final s in _steps) {
        final id = (s['id'] ?? '').toString();
        await _client.from('prescribed_workout_steps').update({
          'duration_value': _toNumOrNull(_stepDurationControllers[id]?.text ?? ''),
          'notes': (_stepNotesControllers[id]?.text ?? '').trim().isEmpty
              ? null
              : (_stepNotesControllers[id]?.text ?? '').trim(),
        }).eq('id', s['id']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas ✅')),
      );
      await _load();
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar alterações: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publishWorkout() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      await _client.from('prescribed_workouts').update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'planned_duration_sec': _toNumOrNull(_durationController.text),
        'planned_rpe': _toNumOrNull(_rpeController.text),
      }).eq('id', widget.workoutId);

      for (final s in _steps) {
        final id = (s['id'] ?? '').toString();
        await _client.from('prescribed_workout_steps').update({
          'duration_value': _toNumOrNull(_stepDurationControllers[id]?.text ?? ''),
          'notes': (_stepNotesControllers[id]?.text ?? '').trim().isEmpty
              ? null
              : (_stepNotesControllers[id]?.text ?? '').trim(),
        }).eq('id', s['id']);
      }

      await _client.from('prescribed_workouts').update({
        'validation_status': 'published',
        'approved_at': DateTime.now().toIso8601String(),
        'approved_by_coach_id': user.id,
      }).eq('id', widget.workoutId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino publicado ✅')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _msg = 'Erro ao publicar treino: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateText() {
    final raw = (_workout?['scheduled_date'] ?? '').toString();
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar treino'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_msg != null) ...[
            Text(
              _msg!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Data: ${_dateText()}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duração planejada (seg)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rpeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'RPE planejado',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Steps do treino',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_steps.isEmpty)
            const Text('Este treino não possui steps.')
          else
            ..._steps.map((s) {
              final id = (s['id'] ?? '').toString();
              final order = (s['step_order'] ?? '').toString();
              final stepType = (s['step_type'] ?? '').toString();
              final zone = (s['target_zone'] ?? '').toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step $order ${stepType.isNotEmpty ? "- $stepType" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (zone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Zona alvo: $zone'),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _stepDurationControllers[id],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duração / valor',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _stepNotesControllers[id],
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _saveDraft,
                  child: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _publishWorkout,
                  child: const Text('Publicar para atleta'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
