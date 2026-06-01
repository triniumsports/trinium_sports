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

  DateTime? _raceDate;
  String _activityType = 'running';
  String _priority = 'medium';
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
    super.dispose();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

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
        'distance_meters': int.tryParse(_distanceController.text.trim()),
        'elevation_gain_m': int.tryParse(_altimetryController.text.trim()),
        'priority': _priority,
        'status': _status,
        'activity_type_id': _activityType,
      });

      _nameController.clear();
      _distanceController.clear();
      _altimetryController.clear();
      _raceDate = null;
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
              child: Text(_msg!, style: const TextStyle(color: Colors.red)),
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
                            initialDate: DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
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
                                labelText: 'Distância (m)',
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
                                labelText: 'Altimetria (m)',
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
                                DropdownMenuItem(value: 'low', child: Text('Baixa')),
                                DropdownMenuItem(value: 'medium', child: Text('Média')),
                                DropdownMenuItem(value: 'high', child: Text('Alta')),
                                DropdownMenuItem(value: 'a', child: Text('A')),
                                DropdownMenuItem(value: 'b', child: Text('B')),
                                DropdownMenuItem(value: 'c', child: Text('C')),
                              ],
                              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
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
                  ..._races.map((race) {
                    final id = race['id'] as int;
                    return Card(
                      child: ListTile(
                        title: Text(_s(race['name']).isEmpty ? 'Prova' : _s(race['name'])),
                        subtitle: Text(
                          '${_s(race['race_date'])} • ${_s(race['activity_type_id'])} • ${_s(race['distance_meters'])}m',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteRace(id),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
