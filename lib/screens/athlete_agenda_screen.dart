import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'athlete_recommended_screen.dart';

class AthleteAgendaScreen extends StatefulWidget {
  const AthleteAgendaScreen({super.key});

  @override
  State<AthleteAgendaScreen> createState() => _AthleteAgendaScreenState();
}

class _AthleteAgendaScreenState extends State<AthleteAgendaScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  // A) Weekly Constraints
  // day_of_week: 1..7 (Seg..Dom)
  // time_slot: morning/afternoon/evening
  final Map<String, Map<int, Set<String>>> _availability = {
    'morning': {for (var d = 1; d <= 7; d++) d: <String>{}},
    'afternoon': {for (var d = 1; d <= 7; d++) d: <String>{}},
    'evening': {for (var d = 1; d <= 7; d++) d: <String>{}},
  };

  // B) Standard Week Pattern
  int? _patternId;
  final _patternTitleController = TextEditingController(text: 'Meu padrão semanal');
  final List<_PatternSession> _sessions = [];

  static const Map<int, String> dayLabels = {
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
    7: 'Dom',
  };

  static const Map<String, String> slotLabels = {
    'morning': 'Manhã',
    'afternoon': 'Tarde',
    'evening': 'Noite',
  };

  // activity_type_id (backend)
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

  @override
  void dispose() {
    _patternTitleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _msg = 'Usuário não autenticado.';
        _loading = false;
      });
      return;
    }

    try {
      // Carrega weekly_constraints existentes
      final wc = await _client
          .from('weekly_constraints')
          .select('day_of_week, activity_type_id, time_slot')
          .eq('athlete_id', user.id);

      if (wc is List) {
        for (final row in wc) {
          final d = row['day_of_week'];
          final a = (row['activity_type_id'] ?? '').toString();
          final s = (row['time_slot'] ?? '').toString();
          if (d is int && _availability.containsKey(s) && a.isNotEmpty) {
            _availability[s]![d]!.add(a);
          }
        }
      }

      // Carrega padrão ativo (se existir)
      final pattern = await _client
          .from('standard_week_patterns')
          .select('id,title,is_active')
          .eq('athlete_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .maybeSingle();

      if (pattern != null) {
        _patternId = pattern['id'] as int?;
        _patternTitleController.text = (pattern['title'] ?? 'Meu padrão semanal').toString();

        if (_patternId != null) {
          final sess = await _client
              .from('standard_week_pattern_sessions')
              .select('day_of_week, activity_type_id, duration_minutes, time_slot, session_order')
              .eq('standard_week_pattern_id', _patternId!)
              .order('day_of_week')
              .order('session_order');

          _sessions.clear();
          if (sess is List) {
            for (final r in sess) {
              _sessions.add(_PatternSession(
                dayOfWeek: (r['day_of_week'] ?? 1) as int,
                timeSlot: (r['time_slot'] ?? 'morning').toString(),
                activityTypeId: (r['activity_type_id'] ?? 'run').toString(),
                durationMinutes: (r['duration_minutes'] ?? 45) as int,
                sessionOrder: (r['session_order'] ?? 1) as int,
              ));
            }
          }
        }
      }
    } catch (e) {
      _msg = 'Erro ao carregar agenda: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _hasAnyWeeklyConstraints() {
    for (final slot in _availability.keys) {
      for (var d = 1; d <= 7; d++) {
        if (_availability[slot]![d]!.isNotEmpty) return true;
      }
    }
    return false;
  }

  bool _hasPatternSessions() => _sessions.isNotEmpty;

  Future<void> _saveWeeklyConstraints() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (!_hasAnyWeeklyConstraints()) {
      setState(() => _msg = 'Preencha ao menos 1 disponibilidade em (A) Weekly Constraints.');
      return;
    }

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      // Apaga constraints anteriores do atleta e recria (simples e consistente)
      await _client.from('weekly_constraints').delete().eq('athlete_id', user.id);

      final inserts = <Map<String, dynamic>>[];
      for (final slot in _availability.keys) {
        for (var d = 1; d <= 7; d++) {
          for (final act in _availability[slot]![d]!) {
            inserts.add({
              'athlete_id': user.id,
              'day_of_week': d,
              'activity_type_id': act,
              'time_slot': slot,
              'is_locked': false,
              'notes': null,
            });
          }
        }
      }

      await _client.from('weekly_constraints').insert(inserts);

      setState(() => _msg = 'Disponibilidade (A) salva com sucesso ✅');
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar (A): $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _saveStandardWeekPattern() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (!_hasPatternSessions()) {
      setState(() => _msg = 'Adicione ao menos 1 sessão no padrão (B).');
      return;
    }

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      // Desativa padrões anteriores do atleta
      await _client
          .from('standard_week_patterns')
          .update({'is_active': false})
          .eq('athlete_id', user.id);

      // Cria um novo padrão ativo
      final created = await _client
          .from('standard_week_patterns')
          .insert({
            'athlete_id': user.id,
            'title': _patternTitleController.text.trim().isEmpty
                ? 'Meu padrão semanal'
                : _patternTitleController.text.trim(),
            'is_active': true,
          })
          .select('id')
          .single();

      final patternId = created['id'] as int;
      _patternId = patternId;

      // Insere sessões
      final inserts = _sessions.map((s) => s.toInsert(patternId)).toList();
      await _client.from('standard_week_pattern_sessions').insert(inserts);

      setState(() => _msg = 'Padrão (B) salvo com sucesso ✅');
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar (B): $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _continue() async {
    // Para “fechar cadastro”, vamos exigir:
    // - preencher A OU B (ou ambos)
    final ok = _hasAnyWeeklyConstraints() || _hasPatternSessions();
    if (!ok) {
      setState(() => _msg = 'Para continuar, preencha (A) ou (B). Quanto mais completo, melhor o motor.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AthleteRecommendedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agenda do Atleta (Obrigatório)'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'A) Disponibilidade'),
              Tab(text: 'B) Padrão semanal'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // A) Weekly Constraints
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'A) Weekly Constraints (recomendado)\n'
                    'Informe em quais dias/turnos você consegue treinar e qual modalidade.\n'
                    'Motivo: o Trinium encaixa as sessões na sua agenda real.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _WeeklyConstraintsGrid(
                    availability: _availability,
                    activityLabels: activityLabels,
                    dayLabels: dayLabels,
                    slotLabels: slotLabels,
                    onToggle: (slot, day, activity) {
                      setState(() {
                        final set = _availability[slot]![day]!;
                        if (set.contains(activity)) {
                          set.remove(activity);
                        } else {
                          set.add(activity);
                        }
                      });
                    },
                  )),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _saving ? null : _saveWeeklyConstraints,
                    child: Text(_saving ? 'Salvando...' : 'Salvar (A) Disponibilidade'),
                  ),
                ],
              ),
            ),

            // B) Standard Week Pattern
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'B) Standard Week Pattern (recomendado)\n'
                    'Defina um “padrão de semana” com sessões e duração.\n'
                    'Motivo: o Trinium gera semanas consistentes e ajusta carga com mais precisão.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _patternTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do padrão',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _sessions.isEmpty
                        ? const Center(child: Text('Nenhuma sessão adicionada ainda.'))
                        : ListView.separated(
                            itemCount: _sessions.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final s = _sessions[i];
                              return ListTile(
                                title: Text('${dayLabels[s.dayOfWeek]} • ${slotLabels[s.timeSlot]} • ${activityLabels[s.activityTypeId]}'),
                                subtitle: Text('Duração: ${s.durationMinutes} min  | Ordem: ${s.sessionOrder}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => setState(() => _sessions.removeAt(i)),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final created = await showDialog<_PatternSession>(
                        context: context,
                        builder: (_) => _AddSessionDialog(activityLabels: activityLabels),
                      );
                      if (created != null) {
                        setState(() => _sessions.add(created));
                      }
                    },
                    child: const Text('Adicionar sessão'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _saving ? null : _saveStandardWeekPattern,
                    child: Text(_saving ? 'Salvando...' : 'Salvar (B) Padrão semanal'),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_msg != null) Text(_msg!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _continue,
                child: const Text('Continuar (Recomendados)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyConstraintsGrid extends StatelessWidget {
  final Map<String, Map<int, Set<String>>> availability;
  final Map<String, String> activityLabels;
  final Map<int, String> dayLabels;
  final Map<String, String> slotLabels;
  final void Function(String slot, int day, String activity) onToggle;

  const _WeeklyConstraintsGrid({
    required this.availability,
    required this.activityLabels,
    required this.dayLabels,
    required this.slotLabels,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final slots = availability.keys.toList();

    return ListView(
      children: slots.map((slot) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slotLabels[slot] ?? slot, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...dayLabels.entries.map((d) {
                  final set = availability[slot]![d.key]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.value),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activityLabels.entries.map((a) {
                          final selected = set.contains(a.key);
                          return FilterChip(
                            selected: selected,
                            label: Text(a.value),
                            onSelected: (_) => onToggle(slot, d.key, a.key),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PatternSession {
  final int dayOfWeek;
  final String timeSlot;
  final String activityTypeId;
  final int durationMinutes;
  final int sessionOrder;

  _PatternSession({
    required this.dayOfWeek,
    required this.timeSlot,
    required this.activityTypeId,
    required this.durationMinutes,
    required this.sessionOrder,
  });

  Map<String, dynamic> toInsert(int patternId) => {
        'standard_week_pattern_id': patternId,
        'day_of_week': dayOfWeek,
        'activity_type_id': activityTypeId,
        'duration_minutes': durationMinutes,
        'time_slot': timeSlot,
        'session_order': sessionOrder,
      };
}

class _AddSessionDialog extends StatefulWidget {
  final Map<String, String> activityLabels;

  const _AddSessionDialog({required this.activityLabels});

  @override
  State<_AddSessionDialog> createState() => _AddSessionDialogState();
}

class _AddSessionDialogState extends State<_AddSessionDialog> {
  int _day = 1;
  String _slot = 'morning';
  String _activity = 'running';
  int _duration = 45;
  int _order = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar sessão'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: _day,
              decoration: const InputDecoration(labelText: 'Dia da semana'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Seg')),
                DropdownMenuItem(value: 2, child: Text('Ter')),
                DropdownMenuItem(value: 3, child: Text('Qua')),
                DropdownMenuItem(value: 4, child: Text('Qui')),
                DropdownMenuItem(value: 5, child: Text('Sex')),
                DropdownMenuItem(value: 6, child: Text('Sáb')),
                DropdownMenuItem(value: 7, child: Text('Dom')),
              ],
              onChanged: (v) => setState(() => _day = v ?? 1),
            ),
            DropdownButtonFormField<String>(
              value: _slot,
              decoration: const InputDecoration(labelText: 'Turno'),
              items: const [
                DropdownMenuItem(value: 'morning', child: Text('Manhã')),
                DropdownMenuItem(value: 'afternoon', child: Text('Tarde')),
                DropdownMenuItem(value: 'evening', child: Text('Noite')),
              ],
              onChanged: (v) => setState(() => _slot = v ?? 'morning'),
            ),
            DropdownButtonFormField<String>(
              value: _activity,
              decoration: const InputDecoration(labelText: 'Modalidade'),
              items: widget.activityLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v ?? 'running'),
            ),
            TextFormField(
              initialValue: '45',
              decoration: const InputDecoration(labelText: 'Duração (min)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _duration = int.tryParse(v.trim()) ?? 45,
            ),
            TextFormField(
              initialValue: '1',
              decoration: const InputDecoration(labelText: 'Ordem da sessão'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _order = int.tryParse(v.trim()) ?? 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _PatternSession(
                dayOfWeek: _day,
                timeSlot: _slot,
                activityTypeId: _activity,
                durationMinutes: _duration,
                sessionOrder: _order,
              ),
            );
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
