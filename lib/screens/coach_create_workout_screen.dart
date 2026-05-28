import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachCreateWorkoutScreen extends StatefulWidget {
  final String? initialAthleteId;
  final String? initialAthleteName;

  const CoachCreateWorkoutScreen({
    super.key,
    this.initialAthleteId,
    this.initialAthleteName,
  });

  @override
  State<CoachCreateWorkoutScreen> createState() =>
      _CoachCreateWorkoutScreenState();
}

class _CoachCreateWorkoutScreenState extends State<CoachCreateWorkoutScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<_AthleteOption> _athletes = [];
  String? _selectedAthleteId;

  DateTime? _scheduledDate;
  String _activityType = 'running';
  String _timeSlot = 'morning';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _rpeController = TextEditingController();
  final TextEditingController _coachNotesController = TextEditingController();

  final List<_WorkoutBlockDraft> _blocks = [];

  static const Map<String, String> _activityLabels = {
    'running': 'Corrida',
    'trail_running': 'Trail',
    'swimming': 'Natação',
    'cycling': 'Ciclismo',
    'strength': 'Força',
    'triathlon': 'Triathlon',
    'swimrun': 'Swimrun',
    'open_water_swimming': 'Águas abertas',
    'mtb': 'MTB',
  };

  static const Map<String, String> _timeSlotLabels = {
    'morning': 'Manhã',
    'afternoon': 'Tarde',
    'evening': 'Noite',
  };

  static const Map<String, String> _stepCategoryLabels = {
    'warmup': 'Aquecimento',
    'main': 'Principal',
    'interval': 'Tiro',
    'recovery': 'Recuperação',
    'cooldown': 'Desaquecimento',
    'rest': 'Descanso',
    'open': 'Livre',
  };

  static const Map<String, String> _durationTypeLabels = {
    'time': 'Tempo',
    'distance': 'Distância',
    'lap_button': 'Botão Lap',
    'open': 'Livre',
  };

  static const Map<String, String> _durationUnitLabels = {
    'sec': 'seg',
    'min': 'min',
    'm': 'm',
    'km': 'km',
    'lap': 'lap',
  };

  static const Map<String, String> _targetTypeLabels = {
    'heart_rate_zone': 'Zona FC',
    'pace_zone': 'Zona de pace',
    'speed_zone': 'Zona de velocidade',
    'power_zone': 'Zona de potência',
    'cadence': 'Cadência',
    'rpe': 'RPE',
    'none': 'Sem alvo',
  };

  static const List<String> _zoneOptions = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];

  @override
  void initState() {
    super.initState();
    _scheduledDate = DateTime.now();
    _blocks.add(
      _WorkoutBlockDraft.single(
        _WorkoutStepDraft.initial(stepCategory: 'warmup'),
      ),
    );
    _blocks.add(
      _WorkoutBlockDraft.repeat(
        repeatCount: 4,
        steps: [
          _WorkoutStepDraft.initial(stepCategory: 'interval'),
          _WorkoutStepDraft.initial(stepCategory: 'recovery'),
        ],
      ),
    );
    _blocks.add(
      _WorkoutBlockDraft.single(
        _WorkoutStepDraft.initial(stepCategory: 'cooldown'),
      ),
    );
    _loadAthletes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _rpeController.dispose();
    _coachNotesController.dispose();

    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

  num? _toNumOrNull(String value) {
    final v = value.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return num.tryParse(v);
  }

  Future<void> _loadAthletes() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _msg = 'Usuário não autenticado.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final rows = await _client
          .from('v_professional_active_athletes')
          .select()
          .eq('professional_id', user.id)
          .order('athlete_name', ascending: true);

      _athletes = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(
            (r) => _AthleteOption(
              id: _s(r['athlete_id']),
              name: _s(r['athlete_name']).isEmpty ? 'Atleta' : _s(r['athlete_name']),
              email: _s(r['athlete_email']),
            ),
          )
          .toList();

      if (widget.initialAthleteId != null &&
          _athletes.any((a) => a.id == widget.initialAthleteId)) {
        _selectedAthleteId = widget.initialAthleteId;
      } else if (_athletes.length == 1) {
        _selectedAthleteId = _athletes.first.id;
      }
    } catch (e) {
      _msg = 'Erro ao carregar atletas ativos: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addSingleStepBlock() {
    setState(() {
      _blocks.add(
        _WorkoutBlockDraft.single(_WorkoutStepDraft.initial()),
      );
    });
  }

  void _addRepeatBlock() {
    setState(() {
      _blocks.add(
        _WorkoutBlockDraft.repeat(
          repeatCount: 4,
          steps: [
            _WorkoutStepDraft.initial(stepCategory: 'interval'),
            _WorkoutStepDraft.initial(stepCategory: 'recovery'),
          ],
        ),
      );
    });
  }

  void _removeBlock(int index) {
    if (_blocks.length == 1) return;
    setState(() {
      _blocks[index].dispose();
      _blocks.removeAt(index);
    });
  }

  void _addStepInsideBlock(int blockIndex) {
    setState(() {
      _blocks[blockIndex].steps.add(_WorkoutStepDraft.initial());
    });
  }

  void _removeStepInsideBlock(int blockIndex, int stepIndex) {
    final block = _blocks[blockIndex];
    if (block.steps.length == 1) return;
    setState(() {
      block.steps[stepIndex].dispose();
      block.steps.removeAt(stepIndex);
    });
  }

  Future<void> _saveWorkout({required bool publishNow}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedAthleteId == null || _selectedAthleteId!.isEmpty) {
      setState(() => _msg = 'Selecione um atleta.');
      return;
    }

    if (_scheduledDate == null) {
      setState(() => _msg = 'Selecione a data do treino.');
      return;
    }

    if (_blocks.isEmpty) {
      setState(() => _msg = 'Adicione pelo menos uma etapa.');
      return;
    }

    for (final block in _blocks) {
      for (final step in block.steps) {
        if (step.durationType != 'open' &&
            step.durationValueController.text.trim().isEmpty) {
          setState(() => _msg = 'Preencha a duração/valor de todas as etapas.');
          return;
        }
      }
    }

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      final scheduledDateText =
          '${_scheduledDate!.year.toString().padLeft(4, '0')}-'
          '${_scheduledDate!.month.toString().padLeft(2, '0')}-'
          '${_scheduledDate!.day.toString().padLeft(2, '0')}';

      final workoutInserted = await _client
          .from('prescribed_workouts')
          .insert({
            'coach_id': user.id,
            'athlete_id': _selectedAthleteId,
            'scheduled_date': scheduledDateText,
            'activity_type_id': _activityType,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            'planned_duration_sec': _toNumOrNull(_durationController.text),
            'planned_rpe': _toNumOrNull(_rpeController.text),
            'time_slot': _timeSlot,
            'session_label': _activityLabels[_activityType],
            'session_order': 1,
            'creation_source': 'coach_manual',
            'status': publishNow ? 'published' : 'planned',
            'validation_status': publishNow ? 'published' : 'review',
            'sync_status': 'not_synced',
            'execution_status': 'not_started',
            'coach_notes': _coachNotesController.text.trim().isEmpty
                ? null
                : _coachNotesController.text.trim(),
            'approved_at':
                publishNow ? DateTime.now().toUtc().toIso8601String() : null,
            'approved_by_coach_id': publishNow ? user.id : null,
          })
          .select('id')
          .single();

      final workoutId = workoutInserted['id'] as int;

      final stepRows = <Map<String, dynamic>>[];
      int globalOrder = 1;

      for (int blockIndex = 0; blockIndex < _blocks.length; blockIndex++) {
        final block = _blocks[blockIndex];
        final repeatGroupId = block.isRepeat ? 'RG${blockIndex + 1}' : null;
        final repeatCount = block.isRepeat ? block.repeatCount : null;

        for (final step in block.steps) {
          stepRows.add({
            'prescribed_workout_id': workoutId,
            'step_order': globalOrder,
            'step_type': step.stepTypeText(),
            'notes': step.notesController.text.trim().isEmpty
                ? null
                : step.notesController.text.trim(),
            'duration_value': _toNumOrNull(step.durationValueController.text),
            'duration_type': step.durationType,
            'duration_unit': step.durationUnit,
            'target_type': step.targetType == 'none' ? null : step.targetType,
            'target_zone': step.targetZone == 'none' ? null : step.targetZone,
            'step_category': step.stepCategory,
            'step_notes': step.stepNotesController.text.trim().isEmpty
                ? null
                : step.stepNotesController.text.trim(),
            'repeat_group_id': repeatGroupId,
            'repeat_count': repeatCount,
            'is_completed': false,
          });
          globalOrder++;
        }
      }

      await _client.from('prescribed_workout_steps').insert(stepRows);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publishNow
                ? 'Treino criado e publicado ✅'
                : 'Treino criado em revisão ✅',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _msg = 'Erro ao criar treino: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Criar treino manual'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Form(
            key: _formKey,
            child: ListView(
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
                _SectionCard(
                  title: 'Cabeçalho do treino',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAthleteId,
                        decoration: const InputDecoration(
                          labelText: 'Atleta',
                          border: OutlineInputBorder(),
                        ),
                        items: _athletes
                            .map(
                              (a) => DropdownMenuItem<String>(
                                value: a.id,
                                child: Text(
                                  a.email.isEmpty
                                      ? a.name
                                      : '${a.name} • ${a.email}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedAthleteId = value);
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Selecione um atleta.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _scheduledDate ?? now,
                                  firstDate: DateTime(now.year - 1, 1, 1),
                                  lastDate: DateTime(now.year + 3, 12, 31),
                                );
                                if (picked != null) {
                                  setState(() => _scheduledDate = picked);
                                }
                              },
                              child: Text(
                                _scheduledDate == null
                                    ? 'Selecionar data'
                                    : 'Data: ${_scheduledDate!.toIso8601String().substring(0, 10)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _activityType,
                              decoration: const InputDecoration(
                                labelText: 'Atividade',
                                border: OutlineInputBorder(),
                              ),
                              items: _activityLabels.entries
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _activityType = value ?? 'running');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Título do treino',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'Informe o título.'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _timeSlot,
                              decoration: const InputDecoration(
                                labelText: 'Período',
                                border: OutlineInputBorder(),
                              ),
                              items: _timeSlotLabels.entries
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _timeSlot = value ?? 'morning');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
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
                            child: TextFormField(
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
                            child: TextFormField(
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _coachNotesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas do treinador',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Builder do treino',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addSingleStepBlock,
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar etapa'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _addRepeatBlock,
                            icon: const Icon(Icons.repeat),
                            label: const Text('Adicionar repetição'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(_blocks.length, (blockIndex) {
                        final block = _blocks[blockIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _WorkoutBlockCard(
                            title: block.isRepeat
                                ? 'Bloco de repetição ${blockIndex + 1}'
                                : 'Etapa ${blockIndex + 1}',
                            block: block,
                            canRemove: _blocks.length > 1,
                            stepCategoryLabels: _stepCategoryLabels,
                            durationTypeLabels: _durationTypeLabels,
                            durationUnitLabels: _durationUnitLabels,
                            targetTypeLabels: _targetTypeLabels,
                            zoneOptions: _zoneOptions,
                            onRemoveBlock: () => _removeBlock(blockIndex),
                            onAddStep: block.isRepeat
                                ? () => _addStepInsideBlock(blockIndex)
                                : null,
                            onRemoveStep: (stepIndex) =>
                                _removeStepInsideBlock(blockIndex, stepIndex),
                            onChanged: () => setState(() {}),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _saveWorkout(publishNow: false),
                        child: Text(
                          _saving ? 'Salvando...' : 'Salvar em revisão',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving
                            ? null
                            : () => _saveWorkout(publishNow: true),
                        child: const Text('Criar e publicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AthleteOption {
  final String id;
  final String name;
  final String email;

  _AthleteOption({
    required this.id,
    required this.name,
    required this.email,
  });
}

class _WorkoutBlockDraft {
  final bool isRepeat;
  int repeatCount;
  final List<_WorkoutStepDraft> steps;

  _WorkoutBlockDraft({
    required this.isRepeat,
    required this.repeatCount,
    required this.steps,
  });

  factory _WorkoutBlockDraft.single(_WorkoutStepDraft step) {
    return _WorkoutBlockDraft(
      isRepeat: false,
      repeatCount: 1,
      steps: [step],
    );
  }

  factory _WorkoutBlockDraft.repeat({
    required int repeatCount,
    required List<_WorkoutStepDraft> steps,
  }) {
    return _WorkoutBlockDraft(
      isRepeat: true,
      repeatCount: repeatCount,
      steps: steps,
    );
  }

  void dispose() {
    for (final step in steps) {
      step.dispose();
    }
  }
}

class _WorkoutStepDraft {
  String stepCategory;
  String durationType;
  String durationUnit;
  String targetType;
  String targetZone;

  final TextEditingController durationValueController;
  final TextEditingController notesController;
  final TextEditingController stepNotesController;

  _WorkoutStepDraft({
    required this.stepCategory,
    required this.durationType,
    required this.durationUnit,
    required this.targetType,
    required this.targetZone,
    required this.durationValueController,
    required this.notesController,
    required this.stepNotesController,
  });

  factory _WorkoutStepDraft.initial({String stepCategory = 'main'}) {
    return _WorkoutStepDraft(
      stepCategory: stepCategory,
      durationType: 'time',
      durationUnit: 'min',
      targetType: 'heart_rate_zone',
      targetZone: 'Z2',
      durationValueController: TextEditingController(),
      notesController: TextEditingController(),
      stepNotesController: TextEditingController(),
    );
  }

  String stepTypeText() {
    switch (stepCategory) {
      case 'warmup':
        return 'warmup';
      case 'interval':
        return 'interval';
      case 'cooldown':
        return 'cooldown';
      case 'recovery':
        return 'recovery';
      case 'rest':
        return 'rest';
      case 'open':
        return 'open';
      default:
        return 'main';
    }
  }

  void dispose() {
    durationValueController.dispose();
    notesController.dispose();
    stepNotesController.dispose();
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class _WorkoutBlockCard extends StatelessWidget {
  final String title;
  final _WorkoutBlockDraft block;
  final bool canRemove;
  final Map<String, String> stepCategoryLabels;
  final Map<String, String> durationTypeLabels;
  final Map<String, String> durationUnitLabels;
  final Map<String, String> targetTypeLabels;
  final List<String> zoneOptions;
  final VoidCallback onRemoveBlock;
  final VoidCallback? onAddStep;
  final void Function(int stepIndex) onRemoveStep;
  final VoidCallback onChanged;

  const _WorkoutBlockCard({
    required this.title,
    required this.block,
    required this.canRemove,
    required this.stepCategoryLabels,
    required this.durationTypeLabels,
    required this.durationUnitLabels,
    required this.targetTypeLabels,
    required this.zoneOptions,
    required this.onRemoveBlock,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9DCE4)),
        color: const Color(0xFFFAFBFD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                if (block.isRepeat)
                  SizedBox(
                    width: 170,
                    child: TextFormField(
                      initialValue: block.repeatCount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Repetir vezes',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        block.repeatCount = int.tryParse(value) ?? 1;
                        onChanged();
                      },
                    ),
                  ),
                if (canRemove) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onRemoveBlock,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(block.steps.length, (stepIndex) {
              final step = block.steps[stepIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StepCard(
                  title: block.isRepeat
                      ? 'Etapa da repetição ${stepIndex + 1}'
                      : 'Etapa',
                  step: step,
                  canRemove: block.isRepeat && block.steps.length > 1,
                  stepCategoryLabels: stepCategoryLabels,
                  durationTypeLabels: durationTypeLabels,
                  durationUnitLabels: durationUnitLabels,
                  targetTypeLabels: targetTypeLabels,
                  zoneOptions: zoneOptions,
                  onRemove: () => onRemoveStep(stepIndex),
                  onChanged: onChanged,
                ),
              );
            }),
            if (block.isRepeat && onAddStep != null)
              OutlinedButton.icon(
                onPressed: onAddStep,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar etapa no bloco'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final _WorkoutStepDraft step;
  final bool canRemove;
  final Map<String, String> stepCategoryLabels;
  final Map<String, String> durationTypeLabels;
  final Map<String, String> durationUnitLabels;
  final Map<String, String> targetTypeLabels;
  final List<String> zoneOptions;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _StepCard({
    required this.title,
    required this.step,
    required this.canRemove,
    required this.stepCategoryLabels,
    required this.durationTypeLabels,
    required this.durationUnitLabels,
    required this.targetTypeLabels,
    required this.zoneOptions,
    required this.onRemove,
    required this.onChanged,
  });

  bool get _showZoneSelector {
    return step.targetType == 'heart_rate_zone' ||
        step.targetType == 'pace_zone' ||
        step.targetType == 'speed_zone' ||
        step.targetType == 'power_zone';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: step.stepCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                    items: stepCategoryLabels.entries
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      step.stepCategory = value ?? 'main';
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: step.durationType,
                    decoration: const InputDecoration(
                      labelText: 'Duração',
                      border: OutlineInputBorder(),
                    ),
                    items: durationTypeLabels.entries
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      step.durationType = value ?? 'time';
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: step.durationValueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (step.durationType == 'open') return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o valor.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: step.durationUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidade',
                      border: OutlineInputBorder(),
                    ),
                    items: durationUnitLabels.entries
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      step.durationUnit = value ?? 'min';
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: step.targetType,
              decoration: const InputDecoration(
                labelText: 'Tipo de alvo',
                border: OutlineInputBorder(),
              ),
              items: targetTypeLabels.entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                step.targetType = value ?? 'heart_rate_zone';
                if (step.targetType == 'none') {
                  step.targetZone = 'none';
                } else if (step.targetZone == 'none') {
                  step.targetZone = 'Z2';
                }
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            if (_showZoneSelector)
              DropdownButtonFormField<String>(
                initialValue: step.targetZone,
                decoration: const InputDecoration(
                  labelText: 'Zona',
                  border: OutlineInputBorder(),
                ),
                items: zoneOptions
                    .map(
                      (z) => DropdownMenuItem<String>(
                        value: z,
                        child: Text(z),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  step.targetZone = value ?? 'Z2';
                  onChanged();
                },
              ),
            if (step.targetType == 'cadence' || step.targetType == 'rpe') ...[
              const SizedBox(height: 12),
              TextField(
                controller: step.notesController,
                decoration: InputDecoration(
                  labelText: step.targetType == 'cadence'
                      ? 'Cadência alvo'
                      : 'RPE alvo',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: step.stepNotesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observações da etapa',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
