import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteWeeklyAvailabilityEditScreen extends StatefulWidget {
  const AthleteWeeklyAvailabilityEditScreen({super.key});

  @override
  State<AthleteWeeklyAvailabilityEditScreen> createState() =>
      _AthleteWeeklyAvailabilityEditScreenState();
}

class _AthleteWeeklyAvailabilityEditScreenState
    extends State<AthleteWeeklyAvailabilityEditScreen> {
  final _client = Supabase.instance.client;

  final List<Map<String, dynamic>> _days = [
    {'day': 1, 'label': 'Segunda'},
    {'day': 2, 'label': 'Terça'},
    {'day': 3, 'label': 'Quarta'},
    {'day': 4, 'label': 'Quinta'},
    {'day': 5, 'label': 'Sexta'},
    {'day': 6, 'label': 'Sábado'},
    {'day': 7, 'label': 'Domingo'},
  ];

  final List<String> _activityOptions = const [
    'running',
    'trail_running',
    'swimming',
    'open_water_swimming',
    'cycling',
    'strength',
    'swimrun',
    'triathlon',
    'rest',
  ];

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  final Map<int, Map<String, dynamic>> _slot1 = {};
  final Map<int, Map<String, dynamic>> _slot2 = {};
  final Map<int, bool> _canPair = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _emptySlot({required int day, required int slot}) {
    return {
      'id': null,
      'day_of_week': day,
      'slot_order': slot,
      'activity_type_id': null,
      'time_slot': slot == 1 ? 'morning' : 'evening',
      'max_duration_sec': null,
      'is_primary': slot == 1,
      'can_pair_same_day': false,
      'is_locked': true,
      'notes': null,
    };
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
          .from('weekly_constraints')
          .select('*')
          .eq('athlete_id', user.id)
          .order('day_of_week')
          .order('slot_order');

      for (final d in _days) {
        final day = d['day'] as int;
        _slot1[day] = _emptySlot(day: day, slot: 1);
        _slot2[day] = _emptySlot(day: day, slot: 2);
        _canPair[day] = false;
      }

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final day = row['day_of_week'] as int?;
        final slot = row['slot_order'] as int?;
        if (day == null || slot == null) continue;

        if (slot == 1) {
          _slot1[day] = Map<String, dynamic>.from(row);
        } else if (slot == 2) {
          _slot2[day] = Map<String, dynamic>.from(row);
        }

        if (row['can_pair_same_day'] == true) {
          _canPair[day] = true;
        }
      }
    } catch (e) {
      _msg = 'Erro ao carregar disponibilidade: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDuration(int? sec) {
    if (sec == null || sec <= 0) return '';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  int? _parseDuration(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return null;

    final numbers = RegExp(r'\d+').allMatches(text).map((e) => int.parse(e.group(0)!)).toList();
    if (numbers.isEmpty) return null;

    if (text.contains('h') && text.contains('min') && numbers.length >= 2) {
      return numbers[0] * 3600 + numbers[1] * 60;
    }
    if (text.contains('h')) {
      return numbers[0] * 3600;
    }
    return numbers[0] * 60;
  }

  Widget _slotCard({
    required int day,
    required int slot,
    required Map<String, dynamic> data,
    required bool enabled,
    required ValueChanged<Map<String, dynamic>> onChanged,
  }) {
    final durationController = TextEditingController(
      text: _formatDuration(data['max_duration_sec'] as int?),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF7F7F9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot == 1 ? 'Opção principal' : 'Opção secundária',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: data['activity_type_id'] as String?,
                decoration: const InputDecoration(
                  labelText: 'Modalidade',
                  border: OutlineInputBorder(),
                ),
                items: _activityOptions
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (value) {
                  final updated = Map<String, dynamic>.from(data);
                  updated['activity_type_id'] = value;
                  onChanged(updated);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: (data['time_slot'] ?? 'morning').toString(),
                decoration: const InputDecoration(
                  labelText: 'Período',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'morning', child: Text('Manhã')),
                  DropdownMenuItem(value: 'afternoon', child: Text('Tarde')),
                  DropdownMenuItem(value: 'evening', child: Text('Noite')),
                ],
                onChanged: (value) {
                  final updated = Map<String, dynamic>.from(data);
                  updated['time_slot'] = value;
                  onChanged(updated);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Tempo disponível (ex: 1h 30min ou 90min)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final updated = Map<String, dynamic>.from(data);
                  updated['max_duration_sec'] = _parseDuration(value);
                  onChanged(updated);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: (data['notes'] ?? '').toString(),
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final updated = Map<String, dynamic>.from(data);
                  updated['notes'] = value.trim().isEmpty ? null : value.trim();
                  onChanged(updated);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      await _client.from('weekly_constraints').delete().eq('athlete_id', user.id);

      final List<Map<String, dynamic>> payload = [];

      for (final d in _days) {
        final day = d['day'] as int;
        final canPair = _canPair[day] ?? false;

        final s1 = Map<String, dynamic>.from(_slot1[day]!);
        if ((s1['activity_type_id'] ?? '').toString().isNotEmpty) {
          payload.add({
            'athlete_id': user.id,
            'day_of_week': day,
            'slot_order': 1,
            'activity_type_id': s1['activity_type_id'],
            'time_slot': s1['time_slot'] ?? 'morning',
            'max_duration_sec': s1['max_duration_sec'],
            'is_primary': true,
            'can_pair_same_day': canPair,
            'is_locked': true,
            'notes': s1['notes'],
          });
        }

        final s2 = Map<String, dynamic>.from(_slot2[day]!);
        if (canPair && (s2['activity_type_id'] ?? '').toString().isNotEmpty) {
          payload.add({
            'athlete_id': user.id,
            'day_of_week': day,
            'slot_order': 2,
            'activity_type_id': s2['activity_type_id'],
            'time_slot': s2['time_slot'] ?? 'evening',
            'max_duration_sec': s2['max_duration_sec'],
            'is_primary': false,
            'can_pair_same_day': true,
            'is_locked': true,
            'notes': s2['notes'],
          });
        }
      }

      if (payload.isNotEmpty) {
        await _client.from('weekly_constraints').insert(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disponibilidade salva com sucesso ✅')),
      );
      await _load();
    } catch (e) {
      _msg = 'Erro ao salvar disponibilidade: $e';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar disponibilidade semanal'),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading || _saving) const LinearProgressIndicator(),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _msg!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _loading
                ? const SizedBox.shrink()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _days.length,
                    itemBuilder: (context, index) {
                      final day = _days[index]['day'] as int;
                      final label = _days[index]['label'] as String;
                      final canPair = _canPair[day] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Permitir 2 sessões no dia'),
                              value: canPair,
                              onChanged: (value) {
                                setState(() {
                                  _canPair[day] = value;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            _slotCard(
                              day: day,
                              slot: 1,
                              data: _slot1[day]!,
                              enabled: true,
                              onChanged: (value) {
                                setState(() {
                                  _slot1[day] = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _slotCard(
                              day: day,
                              slot: 2,
                              data: _slot2[day]!,
                              enabled: canPair,
                              onChanged: (value) {
                                setState(() {
                                  _slot2[day] = value;
                                });
                              },
                            ),
                          ],
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
