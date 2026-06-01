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

  DateTime? _raceDate;
  String _activityType = 'running';
  String _priority = 'b';
  String _status = 'planned';

  final List<_RaceSegmentDraft> _segments = [];

  @override
  void initState() {
    super.initState();
    _segments.add(_RaceSegmentDraft());
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _distanceController.dispose();
    _altimetryController.dispose();
    _notesController.dispose();
    for (final s in _segments) {
      s.dispose();
    }
    super.dispose();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

  int? _toInt(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

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
      case 'strength':
        return 'Força';
      case 'other':
        return 'Outro';
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
    _raceDate = null;
    _activityType = 'running';
    _priority = 'b';
    _status = 'planned';

    for (final s in _segments) {
      s.dispose();
    }
    _segments
      ..clear()
      ..add(_RaceSegmentDraft());
  }

  void _addSegment() {
    setState(() {
      _segments.add(_RaceSegmentDraft());
    });
  }

  void _removeSegment(int index) {
    if (_segments.length == 1) return;
    setState(() {
      _segments[index].dispose();
      _segments.removeAt(index);
    });
  }

  List<Map<String, dynamic>> _buildSegmentsPayload() {
    return _segments
        .map((s) => {
              'modality': s.modality,
              'distance_meters': _toInt(s.distanceController.text),
              'elevation_gain_m': _toInt(s.altimetryController.text),
              'notes': s.notesController.text.trim().isEmpty
                  ? null
                  : s.notesController.text.trim(),
            })
        .where((row) {
          final modality = (row['modality'] ?? '').toString().trim();
          final distance = row['distance_meters'];
          final elevation = row['elevation_gain_m'];
          final notes = (row['notes'] ?? '').toString().trim();
          return modality.isNotEmpty ||
              distance != null ||
              elevation != null ||
              notes.isNotEmpty;
        })
        .toList();
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
        'segments_json': _buildSegmentsPayload(),
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

  Widget _buildSegmentCard(int index, _RaceSegmentDraft segment) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF7F7F9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Segmento ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_segments.length > 1)
                IconButton(
                  onPressed: () => _removeSegment(index),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: segment.modality,
            decoration: const InputDecoration(
              labelText: 'Modalidade do segmento',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'running', child: Text('Corrida')),
              DropdownMenuItem(value: 'trail_running', child: Text('Trail Running')),
              DropdownMenuItem(value: 'swimming', child: Text('Natação')),
              DropdownMenuItem(value: 'cycling', child: Text('Ciclismo')),
              DropdownMenuItem(value: 'transition', child: Text('Transição')),
              DropdownMenuItem(value: 'hiking', child: Text('Hiking')),
              DropdownMenuItem(value: 'kayak', child: Text('Caiaque')),
              DropdownMenuItem(value: 'other', child: Text('Outro')),
            ],
            onChanged: (v) {
              setState(() => segment.modality = v ?? 'running');
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: segment.distanceController,
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
                  controller: segment.altimetryController,
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
          TextFormField(
            controller: segment.notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observação do segmento',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
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

    final segmentsRaw = race['segments_json'];
    final segments = segmentsRaw is List
        ? segmentsRaw.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

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
                Text('Modalidade principal: $activity'),
                if (distance.isNotEmpty) Text('Distância total: ${distance}m'),
                if (elevation.isNotEmpty) Text('Altimetria total: ${elevation}m'),
                if (priority.isNotEmpty) Text('Prioridade: $priority'),
                if (status.isNotEmpty) Text('Status: $status'),
              ],
            ),
            if (segments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Segmentos',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...segments.map((seg) {
                final modality = _activityLabel(_s(seg['modality']));
                final segDistance = _s(seg['distance_meters']);
                final segElevation = _s(seg['elevation_gain_m']);
                final segNotes = _s(seg['notes']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '$modality'
                    '${segDistance.isNotEmpty ? ' • ${segDistance}m' : ''}'
                    '${segElevation.isNotEmpty ? ' • ${segElevation}m+' : ''}'
                    '${segNotes.isNotEmpty ? ' • $segNotes' : ''}',
                  ),
                );
              }),
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
                          labelText: 'Modalidade principal',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'running', child: Text('Corrida')),
                          DropdownMenuItem(value: 'trail_running', child: Text('Trail Running')),
                          DropdownMenuItem(value: 'swimming', child: Text('Natação')),
                          DropdownMenuItem(value: 'cycling', child: Text('Ciclismo')),
                          DropdownMenuItem(value: 'triathlon', child: Text('Triathlon')),
                          DropdownMenuItem(value: 'swimrun', child: Text('Swimrun')),
                          DropdownMenuItem(value: 'other', child: Text('Outro')),
                        ],
                        onChanged: (v) => setState(() => _activityType = v ?? 'running'),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Segmentos da prova',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...List.generate(
                        _segments.length,
                        (index) => _buildSegmentCard(index, _segments[index]),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _addSegment,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar segmento'),
                        ),
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
                          labelText: 'Observações gerais',
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

class _RaceSegmentDraft {
  String modality;
  final TextEditingController distanceController;
  final TextEditingController altimetryController;
  final TextEditingController notesController;

  _RaceSegmentDraft({
    this.modality = 'running',
    TextEditingController? distanceController,
    TextEditingController? altimetryController,
    TextEditingController? notesController,
  })  : distanceController = distanceController ?? TextEditingController(),
        altimetryController = altimetryController ?? TextEditingController(),
        notesController = notesController ?? TextEditingController();

  void dispose() {
    distanceController.dispose();
    altimetryController.dispose();
    notesController.dispose();
  }
}
