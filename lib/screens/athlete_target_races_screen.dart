import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteTargetRacesScreen extends StatefulWidget {
  const AthleteTargetRacesScreen({super.key});

  @override
  State<AthleteTargetRacesScreen> createState() =>
      _AthleteTargetRacesScreenState();
}

class _AthleteTargetRacesScreenState extends State<AthleteTargetRacesScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;
  List<Map<String, dynamic>> _races = [];

  final _nameController = TextEditingController();
  final _distanceController = TextEditingController();
  final _altimetryController = TextEditingController();
  final _notesController = TextEditingController();

  final _swimDistanceController = TextEditingController();
  final _bikeDistanceController = TextEditingController();
  final _bikeAltimetryController = TextEditingController();
  final _runDistanceController = TextEditingController();
  final _runAltimetryController = TextEditingController();

  DateTime? _raceDate;
  String _activityType = 'running';
  String _priority = 'b';
  String _status = 'planned';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _distanceController.dispose();
    _altimetryController.dispose();
    _notesController.dispose();
    _swimDistanceController.dispose();
    _bikeDistanceController.dispose();
    _bikeAltimetryController.dispose();
    _runDistanceController.dispose();
    _runAltimetryController.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

  int? _toInt(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  bool get _isMultisport =>
      _activityType == 'triathlon' || _activityType == 'swimrun';

  String _activityLabel(String raw) {
    switch (raw) {
      case 'running':
        return 'Corrida';
      case 'trail_running':
        return 'Trail Running';
      case 'swimming':
        return 'Natação';
      case 'cycling':
        return 'Ciclismo';
      case 'triathlon':
        return 'Triathlon';
      case 'swimrun':
        return 'Swimrun';
      default:
        return raw;
    }
  }

  String _priorityLabel(String raw) {
    switch (raw) {
      case 'a':
        return 'Alta (A)';
      case 'b':
        return 'Média (B)';
      case 'c':
        return 'Baixa (C)';
      default:
        return raw;
    }
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'planned':
        return 'Planejada';
      case 'confirmed':
        return 'Confirmada';
      case 'done':
        return 'Concluída';
      default:
        return raw;
    }
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final rows = await _client
          .from('target_races')
          .select()
          .eq('athlete_id', user.id)
          .order('race_date', ascending: true);

      _races = (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar provas: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _distanceController.clear();
    _altimetryController.clear();
    _notesController.clear();
    _swimDistanceController.clear();
    _bikeDistanceController.clear();
    _bikeAltimetryController.clear();
    _runDistanceController.clear();
    _runAltimetryController.clear();
    _raceDate = null;
    _activityType = 'running';
    _priority = 'b';
    _status = 'planned';
  }

  Future<void> _createRace() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty || _raceDate == null) {
      setState(() => _msg = 'Nome e data da prova são obrigatórios.');
      return;
    }

    try {
      await _client.from('target_races').insert({
        'athlete_id': user.id,
        'name': _nameController.text.trim(),
        'race_date': _raceDate!.toIso8601String().substring(0, 10),
        'distance_meters': _toInt(_distanceController.text),
        'elevation_gain_m': _toInt(_altimetryController.text),
        'priority': _priority,
        'status': _status,
        'activity_type_id': _activityType,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'swim_distance_meters': _toInt(_swimDistanceController.text),
        'bike_distance_meters': _toInt(_bikeDistanceController.text),
        'bike_elevation_gain_m': _toInt(_bikeAltimetryController.text),
        'run_distance_meters': _toInt(_runDistanceController.text),
        'run_elevation_gain_m': _toInt(_runAltimetryController.text),
      });

      _clearForm();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prova alvo salva ✅')),
      );
      setState(() {});
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar prova: $e');
    }
  }

  Future<void> _deleteRace(int id) async {
    try {
      await _client.from('target_races').delete().eq('id', id);
      await _load();
    } catch (e) {
      setState(() => _msg = 'Erro ao excluir prova: $e');
    }
  }

  Widget _buildMultisportFields() {
    if (!_isMultisport) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 10),
        if (_activityType == 'triathlon') ...[
          TextFormField(
            controller: _swimDistanceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Natação - distância (m)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bikeDistanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _activityType == 'swimrun'
                      ? 'Bloco complementar - distância bike/outro (m)'
                      : 'Ciclismo - distância (m)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _bikeAltimetryController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _activityType == 'swimrun'
                      ? 'Bloco complementar - altimetria (m)'
                      : 'Ciclismo - altimetria (m)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _runDistanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Corrida - distância (m)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _runAltimetryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Corrida - altimetria (m)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRaceCard(Map<String, dynamic> race) {
    final id = race['id'] as int;
    final name = _s(race['name']).isEmpty ? 'Prova' : _s(race['name']);
    final date = _s(race['race_date']);
    final activity = _activityLabel(_s(race['activity_type_id']));
    final distance = _s(race['distance_meters']);
    final elevation = _s(race['elevation_gain_m']);
    final priority = _priorityLabel(_s(race['priority']));
    final status = _statusLabel(_s(race['status']));
    final notes = _s(race['notes']);

    final swimDistance = _s(race['swim_distance_meters']);
    final bikeDistance = _s(race['bike_distance_meters']);
    final bikeElevation = _s(race['bike_elevation_gain_m']);
    final runDistance = _s(race['run_distance_meters']);
    final runElevation = _s(race['run_elevation_gain_m']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRace(id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Data: $date'),
                Text('Modalidade: $activity'),
                if (distance.isNotEmpty) Text('Distância total: ${distance}m'),
                if (elevation.isNotEmpty) Text('Altimetria total: ${elevation}m'),
                if (priority.isNotEmpty) Text('Prioridade: $priority'),
                if (status.isNotEmpty) Text('Status: $status'),
              ],
            ),
            if (swimDistance.isNotEmpty ||
                bikeDistance.isNotEmpty ||
                bikeElevation.isNotEmpty ||
                runDistance.isNotEmpty ||
                runElevation.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Segmentos',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (swimDistance.isNotEmpty) Text('Natação: ${swimDistance}m'),
              if (bikeDistance.isNotEmpty || bikeElevation.isNotEmpty)
                Text(
                  'Ciclismo/Complementar: ${bikeDistance.isEmpty ? "-" : "${bikeDistance}m"}'
                  ' • Altimetria: ${bikeElevation.isEmpty ? "-" : "${bikeElevation}m"}',
                ),
              if (runDistance.isNotEmpty || runElevation.isNotEmpty)
                Text(
                  'Corrida: ${runDistance.isEmpty ? "-" : "${runDistance}m"}'
                  ' • Altimetria: ${runElevation.isEmpty ? "-" : "${runElevation}m"}',
                ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Observações: $notes'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Provas alvo')),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _msg!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 10,
                        offset: Offset(0, 4),
                        color: Color(0x12000000),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da prova',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate:
                                DateTime.now().subtract(const Duration(days: 30)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setState(() => _raceDate = picked);
                          }
                        },
                        child: Text(
                          _raceDate == null
                              ? 'Selecionar data'
                              : 'Data: ${_raceDate!.toIso8601String().substring(0, 10)}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _distanceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Distância total (m)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _altimetryController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Altimetria total (m)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _activityType,
                        decoration: const InputDecoration(
                          labelText: 'Modalidade',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'running', child: Text('Corrida')),
                          DropdownMenuItem(value: 'trail_running', child: Text('Trail Running')),
                          DropdownMenuItem(value: 'swimming', child: Text('Natação')),
                          DropdownMenuItem(value: 'cycling', child: Text('Ciclismo')),
                          DropdownMenuItem(value: 'triathlon', child: Text('Triathlon')),
                          DropdownMenuItem(value: 'swimrun', child: Text('Swimrun')),
                        ],
                        onChanged: (v) => setState(() => _activityType = v ?? 'running'),
                      ),
                      _buildMultisportFields(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _priority,
                              decoration: const InputDecoration(
                                labelText: 'Prioridade',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'a', child: Text('Alta (A)')),
                                DropdownMenuItem(value: 'b', child: Text('Média (B)')),
                                DropdownMenuItem(value: 'c', child: Text('Baixa (C)')),
                              ],
                              onChanged: (v) => setState(() => _priority = v ?? 'b'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'planned', child: Text('Planejada')),
                                DropdownMenuItem(value: 'confirmed', child: Text('Confirmada')),
                                DropdownMenuItem(value: 'done', child: Text('Concluída')),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? 'planned'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _createRace,
                        child: const Text('Salvar prova alvo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_races.isEmpty)
                  const Center(child: Text('Nenhuma prova alvo cadastrada.'))
                else
                  ..._races.map(_buildRaceCard),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
