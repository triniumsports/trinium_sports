import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_router_screen.dart';

class AthleteRecommendedScreen extends StatefulWidget {
  const AthleteRecommendedScreen({super.key});

  @override
  State<AthleteRecommendedScreen> createState() => _AthleteRecommendedScreenState();
}

class _AthleteRecommendedScreenState extends State<AthleteRecommendedScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  // athletes
  String _phase = 'base';
  final _vo2Controller = TextEditingController();

  // athlete_zones
  final _hrMaxController = TextEditingController();
  final _pz1 = TextEditingController();
  final _pz2 = TextEditingController();
  final _pz3 = TextEditingController();
  final _pz4 = TextEditingController();
  final _pz5 = TextEditingController();

  // ✅ IDs REAIS do backend
  static const Map<String, String> activityLabels = {
    'running': 'Corrida (asfalto)',
    'trail_running': 'Trail (trilha)',
    'cycling': 'Ciclismo (road)',
    'mtb': 'MTB',
    'swimming': 'Natação (piscina)',
    'open_water_swimming': 'Natação (águas abertas)',
    'swimrun': 'Swimrun',
    'triathlon': 'Triatlo',
    'strength': 'Força / Musculação',
  };

  // target_races (múltiplas provas)
  final List<RaceDraft> _races = [];

  @override
  void dispose() {
    _vo2Controller.dispose();
    _hrMaxController.dispose();
    _pz1.dispose();
    _pz2.dispose();
    _pz3.dispose();
    _pz4.dispose();
    _pz5.dispose();
    super.dispose();
  }

  double? _toDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
  int? _toInt(String s) => int.tryParse(s.trim());

  double? _paceToSec(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    final parts = v.split(':');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0]);
    final sec = int.tryParse(parts[1]);
    if (m == null || sec == null) return null;
    return (m * 60 + sec).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _msg = 'Usuário não autenticado.';
        _loading = false;
      });
      return;
    }

    try {
      final athlete = await _client
          .from('athletes')
          .select('phase,vo2_max')
          .eq('id', user.id)
          .maybeSingle();

      _phase = (athlete?['phase'] ?? 'base').toString();
      _vo2Controller.text = (athlete?['vo2_max'] ?? '').toString();

      final zones = await _client
          .from('athlete_zones')
          .select('hr_max,pace_z1_sec,pace_z2_sec,pace_z3_sec,pace_z4_sec,pace_z5_sec')
          .eq('athlete_id', user.id)
          .maybeSingle();

      _hrMaxController.text = (zones?['hr_max'] ?? '').toString();

      String secToPace(dynamic v) {
        if (v == null) return '';
        final sec = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
        if (sec <= 0) return '';
        final m = sec ~/ 60;
        final s = sec % 60;
        return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }

      _pz1.text = secToPace(zones?['pace_z1_sec']);
      _pz2.text = secToPace(zones?['pace_z2_sec']);
      _pz3.text = secToPace(zones?['pace_z3_sec']);
      _pz4.text = secToPace(zones?['pace_z4_sec']);
      _pz5.text = secToPace(zones?['pace_z5_sec']);
    } catch (e) {
      _msg = 'Erro ao carregar recomendados: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addRace() async {
    final created = await showDialog<RaceDraft>(
      context: context,
      builder: (_) => AddRaceDialog(activityLabels: activityLabels),
    );
    if (created != null) {
      setState(() => _races.add(created));
    }
  }

  Future<void> _saveAndFinish() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      // athletes
      await _client.from('athletes').update({
        'phase': _phase,
        'vo2_max': _vo2Controller.text.trim().isEmpty ? null : _toDouble(_vo2Controller.text),
      }).eq('id', user.id);

      // athlete_zones
      await _client.from('athlete_zones').upsert({
        'athlete_id': user.id,
        'hr_max': _hrMaxController.text.trim().isEmpty ? null : _toInt(_hrMaxController.text),
        'pace_z1_sec': _paceToSec(_pz1.text),
        'pace_z2_sec': _paceToSec(_pz2.text),
        'pace_z3_sec': _paceToSec(_pz3.text),
        'pace_z4_sec': _paceToSec(_pz4.text),
        'pace_z5_sec': _paceToSec(_pz5.text),
      });

      // target_races: inserir TODAS as provas do calendário (sem apagar as antigas)
      if (_races.isNotEmpty) {
        final inserts = _races.map((r) => {
              'athlete_id': user.id,
              'activity_type_id': r.activityTypeId, // ✅ id real (trail_running etc)
              'name': r.name.trim(),
              'race_date': r.raceDate.toIso8601String().substring(0, 10),
              'distance_meters': r.distanceMeters,
              'elevation_gain_m': r.elevationGainM ?? 0,
              'priority': r.priority,
              'status': 'planned',
            }).toList();

        try {
          await _client.from('target_races').insert(inserts);
        } catch (e) {
          // Mensagem amigável caso seu backend valide com race_definitions
          setState(() {
            _msg =
                'Erro ao salvar provas. Isso pode acontecer se o backend exigir um race_definition compatível.\n'
                'Dica: confirme se existe race_definitions para activity_type_id e faixa de distância.\n\n'
                'Erro: $e';
          });
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeRouterScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar recomendados: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recomendados (melhoram o motor)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const Text(
                  'Esses dados não são obrigatórios para começar, mas aumentam muito a precisão do Trinium.\n'
                  'Aqui você também pode cadastrar seu calendário anual de provas.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Phase
                DropdownButtonFormField<String>(
                  value: _phase,
                  decoration: const InputDecoration(
                    labelText: 'Fase atual do ciclo (athletes.phase)',
                    border: OutlineInputBorder(),
                    helperText: 'Guia periodização e volume do plano.',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'base', child: Text('Base')),
                    DropdownMenuItem(value: 'build', child: Text('Build')),
                    DropdownMenuItem(value: 'peak', child: Text('Peak')),
                    DropdownMenuItem(value: 'recovery', child: Text('Recovery')),
                  ],
                  onChanged: (v) => setState(() => _phase = v ?? 'base'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _vo2Controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'VO2max (athletes.vo2_max) — opcional',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                const Text('Zonas (athlete_zones) — recomendado para corrida'),
                const SizedBox(height: 8),

                TextField(
                  controller: _hrMaxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'FC máxima para zonas (athlete_zones.hr_max) — opcional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                _paceField(_pz1, 'Pace Z1 (pace_z1_sec) — mm:ss'),
                _paceField(_pz2, 'Pace Z2 (pace_z2_sec) — mm:ss'),
                _paceField(_pz3, 'Pace Z3 (pace_z3_sec) — mm:ss'),
                _paceField(_pz4, 'Pace Z4 (pace_z4_sec) — mm:ss'),
                _paceField(_pz5, 'Pace Z5 (pace_z5_sec) — mm:ss'),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // ✅ Multi-race
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calendário anual de provas (target_races)'),
                    OutlinedButton.icon(
                      onPressed: _addRace,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar prova'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você pode cadastrar várias provas. O motor usa isso para priorizar picos e periodização.',
                ),
                const SizedBox(height: 12),

                if (_races.isEmpty)
                  const Text('Nenhuma prova adicionada ainda.')
                else
                  Column(
                    children: _races.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text('${activityLabels[r.activityTypeId] ?? r.activityTypeId} • ${r.name}'),
                          subtitle: Text(
                            'Data: ${r.raceDate.toIso8601String().substring(0, 10)}'
                            ' | Distância: ${r.distanceMeters ?? '-'}'
                            ' | Elevação: ${r.elevationGainM ?? 0}'
                            ' | Prioridade: ${r.priority}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => setState(() => _races.removeAt(i)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : _saveAndFinish,
                  child: Text(_saving ? 'Salvando...' : 'Concluir cadastro do atleta'),
                ),

                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  Text(_msg!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paceField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: 'Formato: mm:ss (ex.: 05:10).',
        ),
      ),
    );
  }
}

class RaceDraft {
  final String activityTypeId;
  final String name;
  final DateTime raceDate;
  final double? distanceMeters;
  final double? elevationGainM;
  final String priority;

  RaceDraft({
    required this.activityTypeId,
    required this.name,
    required this.raceDate,
    required this.distanceMeters,
    required this.elevationGainM,
    required this.priority,
  });
}

class AddRaceDialog extends StatefulWidget {
  final Map<String, String> activityLabels;
  const AddRaceDialog({super.key, required this.activityLabels});

  @override
  State<AddRaceDialog> createState() => _AddRaceDialogState();
}

class _AddRaceDialogState extends State<AddRaceDialog> {
  String _activity = 'trail_running';
  final _nameController = TextEditingController();
  DateTime? _date;
  final _distanceController = TextEditingController();
  final _elevController = TextEditingController();
  String _priority = 'A';

  double? _toDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _nameController.dispose();
    _distanceController.dispose();
    _elevController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar prova'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _activity,
              decoration: const InputDecoration(
                labelText: 'Modalidade (activity_type_id)',
                border: OutlineInputBorder(),
              ),
              items: widget.activityLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v ?? 'trail_running'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome da prova (obrigatório)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now.add(const Duration(days: 60)),
                  firstDate: now.subtract(const Duration(days: 1)),
                  lastDate: now.add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Text(_date == null ? 'Selecionar data (obrigatório)' : 'Data: ${_date!.toIso8601String().substring(0, 10)}'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _distanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Distância em metros (opcional)',
                border: OutlineInputBorder(),
                helperText: 'Ex.: 21000 para 21K',
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _elevController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ganho elevação em metros (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Prioridade (A/B/C)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'A', child: Text('A (principal)')),
                DropdownMenuItem(value: 'B', child: Text('B')),
                DropdownMenuItem(value: 'C', child: Text('C')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 'A'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty || _date == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nome e data são obrigatórios.')),
              );
              return;
            }

            Navigator.pop(
              context,
              RaceDraft(
                activityTypeId: _activity,
                name: name,
                raceDate: _date!,
                distanceMeters: _distanceController.text.trim().isEmpty ? null : _toDouble(_distanceController.text),
                elevationGainM: _elevController.text.trim().isEmpty ? null : _toDouble(_elevController.text),
                priority: _priority,
              ),
            );
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
