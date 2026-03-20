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

  // target_race (opcional)
  String _raceActivity = 'run';
  final _raceNameController = TextEditingController();
  DateTime? _raceDate;
  final _raceDistanceController = TextEditingController();
  final _raceElevGainController = TextEditingController();
  String _racePriority = 'A';

  static const Map<String, String> activityLabels = {
    'run': 'Corrida',
    'swim': 'Natação',
    'bike': 'Ciclismo',
    'strength': 'Força / Musculação',
    'trail': 'Trail',
    'triathlon': 'Triatlo',
  };

  @override
  void dispose() {
    _vo2Controller.dispose();
    _hrMaxController.dispose();
    _pz1.dispose();
    _pz2.dispose();
    _pz3.dispose();
    _pz4.dispose();
    _pz5.dispose();
    _raceNameController.dispose();
    _raceDistanceController.dispose();
    _raceElevGainController.dispose();
    super.dispose();
  }

  double? _toDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
  int? _toInt(String s) => int.tryParse(s.trim());

  // Pace input: "mm:ss" -> segundos por km
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

      // Converter seg -> mm:ss para mostrar (opcional)
      String secToPace(dynamic v) {
        if (v == null) return '';
        final sec = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
        if (sec <= 0) return '';
        final m = sec ~/ 60;
        final s = sec % 60;
        return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
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

  Future<void> _saveAndFinish() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      // athletes (recomendados)
      await _client.from('athletes').update({
        'phase': _phase,
        'vo2_max': _vo2Controller.text.trim().isEmpty ? null : _toDouble(_vo2Controller.text),
      }).eq('id', user.id);

      // athlete_zones (recomendados)
      await _client.from('athlete_zones').upsert({
        'athlete_id': user.id,
        'hr_max': _hrMaxController.text.trim().isEmpty ? null : _toInt(_hrMaxController.text),
        'pace_z1_sec': _paceToSec(_pz1.text),
        'pace_z2_sec': _paceToSec(_pz2.text),
        'pace_z3_sec': _paceToSec(_pz3.text),
        'pace_z4_sec': _paceToSec(_pz4.text),
        'pace_z5_sec': _paceToSec(_pz5.text),
      });

      // target_races (opcional)
      final hasRace = _raceNameController.text.trim().isNotEmpty && _raceDate != null;
      if (hasRace) {
        await _client.from('target_races').insert({
          'athlete_id': user.id,
          'activity_type_id': _raceActivity,
          'name': _raceNameController.text.trim(),
          'race_date': _raceDate!.toIso8601String().substring(0, 10),
          'distance_meters': _raceDistanceController.text.trim().isEmpty ? null : _toDouble(_raceDistanceController.text),
          'elevation_gain_m': _raceElevGainController.text.trim().isEmpty ? 0 : (_toDouble(_raceElevGainController.text) ?? 0),
          'priority': _racePriority,
          'status': 'planned',
        });
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
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const Text(
                  'Esses dados NÃO são obrigatórios para começar, mas aumentam muito a precisão do Trinium.\n'
                  'Quanto mais completo, melhor a recomendação e a prescrição automática.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Phase
                DropdownButtonFormField<String>(
                  value: _phase,
                  decoration: const InputDecoration(
                    labelText: 'Fase atual do ciclo (athletes.phase)',
                    border: OutlineInputBorder(),
                    helperText: 'A fase guia a periodização e o volume do plano.',
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
                    helperText: 'Ajuda o motor quando zonas não estão calibradas.',
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Zones
                const Text('Zonas (athlete_zones) — altamente recomendado para corrida'),
                const SizedBox(height: 8),

                TextField(
                  controller: _hrMaxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'FC máxima (athlete_zones.hr_max) — opcional',
                    border: OutlineInputBorder(),
                    helperText: 'Usado para prescrição por zonas de FC.',
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

                // Target race
                const Text('Prova/objetivo (target_races) — recomendado'),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _raceActivity,
                  decoration: const InputDecoration(
                    labelText: 'Modalidade (activity_type_id)',
                    border: OutlineInputBorder(),
                  ),
                  items: activityLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _raceActivity = v ?? 'run'),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _raceNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da prova (target_races.name) — opcional',
                    border: OutlineInputBorder(),
                    helperText: 'Se informar prova, o motor periodiza para uma data-alvo.',
                  ),
                ),
                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _raceDate ?? now.add(const Duration(days: 60)),
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => _raceDate = picked);
                  },
                  child: Text(_raceDate == null
                      ? 'Selecionar data da prova (target_races.race_date)'
                      : 'Data: ${_raceDate!.toIso8601String().substring(0, 10)}'),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _raceDistanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Distância (metros) (target_races.distance_meters) — opcional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _raceElevGainController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ganho elevação (m) (target_races.elevation_gain_m) — opcional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: _racePriority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridade (target_races.priority) — opcional',
                    border: OutlineInputBorder(),
                    helperText: 'A/B/C: ajuda o motor a priorizar o pico.',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A (principal)')),
                    DropdownMenuItem(value: 'B', child: Text('B')),
                    DropdownMenuItem(value: 'C', child: Text('C')),
                  ],
                  onChanged: (v) => setState(() => _racePriority = v ?? 'A'),
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
