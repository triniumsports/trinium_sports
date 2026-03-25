import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/edge_functions_service.dart';
import 'home_router_screen.dart';

class AthleteOnboardingScreen extends StatefulWidget {
  const AthleteOnboardingScreen({super.key});

  @override
  State<AthleteOnboardingScreen> createState() => _AthleteOnboardingScreenState();
}

class _AthleteOnboardingScreenState extends State<AthleteOnboardingScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  // --- (1) OBRIGATÓRIOS ---
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'male';
  String _experience = 'intermediate';
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _restHrController = TextEditingController();
  final _maxHrController = TextEditingController();

  String? _avatarUrl; // profiles.avatar_url

  // --- (2) AGENDA (A e B) ---
  // A) weekly_constraints: dia + turno + modalidade (multiselect)
  final Map<String, Map<int, Set<String>>> _availability = {
    'morning': {for (var d = 1; d <= 7; d++) d: <String>{}},
    'afternoon': {for (var d = 1; d <= 7; d++) d: <String>{}},
    'evening': {for (var d = 1; d <= 7; d++) d: <String>{}},
  };

  // B) standard_week_patterns
  final _patternTitleController = TextEditingController(text: 'Meu padrão semanal');
  final List<_PatternSession> _sessions = [];

  // Tipos de atividade carregados do backend (activity_types)
  Map<String, String> _activityLabels = {};


  // --- (3) RECOMENDADOS ---
  String _phase = 'base';
  final _vo2Controller = TextEditingController();
  final _hrMaxController = TextEditingController();
  final _pz1 = TextEditingController();
  final _pz2 = TextEditingController();
  final _pz3 = TextEditingController();
  final _pz4 = TextEditingController();
  final _pz5 = TextEditingController();

  String _raceActivity = 'run';
  final _raceNameController = TextEditingController();
  DateTime? _raceDate;
  final _raceDistanceController = TextEditingController();
  final _raceElevGainController = TextEditingController();
  String _racePriority = 'A';

  // Labels
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
  
  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _restHrController.dispose();
    _maxHrController.dispose();
    _patternTitleController.dispose();
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

  // Pace "mm:ss" -> segundos
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

  String? _requiredText(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label é obrigatório.';
    return null;
  }

  String? _rangeDouble(String? v, String label, double min, double max) {
    if (v == null || v.trim().isEmpty) return '$label é obrigatório.';
    final x = _toDouble(v);
    if (x == null) return '$label inválido.';
    if (x < min || x > max) return '$label fora do intervalo ($min–$max).';
    return null;
  }

  String? _rangeInt(String? v, String label, int min, int max) {
    if (v == null || v.trim().isEmpty) return '$label é obrigatório.';
    final x = _toInt(v);
    if (x == null) return '$label inválido.';
    if (x < min || x > max) return '$label fora do intervalo ($min–$max).';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _msg = 'Usuário não autenticado.';
        _loading = false;
      });
      return;
    }

    try {
      // activity_types (fonte de verdade do backend)
      final types = await _client
          .from('activity_types')
          .select('id,is_active')
          .order('id');

      // Labels PT-BR (UI) para IDs do backend (internacional)
      final labelOverrides = <String, String>{
        'running': 'Corrida (asfalto)',
        'trail_running': 'Trail (trilha)',
        'cycling': 'Ciclismo (road)',
        'mtb': 'MTB',
        'swimming': 'Natação (piscina)',
        'open_water_swimming': 'Natação (águas abertas)',
        'swimrun': 'Swimrun',
        'triathlon': 'Triatlo',
        'strength': 'Força / Musculação',
        'rest': 'Descanso',
      };

      final map = <String, String>{};
      if (types is List) {
        for (final r in types) {
          final id = (r['id'] ?? '').toString();
          if (id.isEmpty) continue;
          final isActive = r['is_active'];
          if (isActive is bool && isActive == false) continue;

          // escondemos "rest" na UI de disponibilidade (não é modalidade de treino)
          if (id == 'rest') continue;

          map[id] = labelOverrides[id] ?? id;
        }
      }

      _activityLabels = map;


      // profiles
      final profile = await _client.from('profiles')
          .select('full_name,avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      _nameController.text = (profile?['full_name'] ?? '').toString();
      _avatarUrl = (profile?['avatar_url'] ?? '').toString().trim();
      if (_avatarUrl != null && _avatarUrl!.isEmpty) _avatarUrl = null;

      // athletes
      final athlete = await _client.from('athletes')
          .select('birth_date,gender,height_cm,weight_kg,resting_hr,max_hr,experience_level,phase,vo2_max')
          .eq('id', user.id)
          .maybeSingle();

      final bd = athlete?['birth_date'];
      if (bd != null) _birthDate = DateTime.tryParse(bd.toString());

      _gender = (athlete?['gender'] ?? _gender).toString();
      _experience = (athlete?['experience_level'] ?? _experience).toString();
      _heightController.text = (athlete?['height_cm'] ?? '').toString();
      _weightController.text = (athlete?['weight_kg'] ?? '').toString();
      _restHrController.text = (athlete?['resting_hr'] ?? '').toString();
      _maxHrController.text = (athlete?['max_hr'] ?? '').toString();

      _phase = (athlete?['phase'] ?? 'base').toString();
      _vo2Controller.text = (athlete?['vo2_max'] ?? '').toString();

      // athlete_zones
      final zones = await _client.from('athlete_zones')
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
        return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
      }

      _pz1.text = secToPace(zones?['pace_z1_sec']);
      _pz2.text = secToPace(zones?['pace_z2_sec']);
      _pz3.text = secToPace(zones?['pace_z3_sec']);
      _pz4.text = secToPace(zones?['pace_z4_sec']);
      _pz5.text = secToPace(zones?['pace_z5_sec']);

      // weekly_constraints (A)
      final wc = await _client.from('weekly_constraints')
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

      // padrão ativo (B)
      final pattern = await _client.from('standard_week_patterns')
          .select('id,title')
          .eq('athlete_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .maybeSingle();

      if (pattern != null) {
        _patternTitleController.text = (pattern['title'] ?? 'Meu padrão semanal').toString();
        final pid = pattern['id'];
        if (pid != null) {
          final sess = await _client.from('standard_week_pattern_sessions')
              .select('day_of_week,activity_type_id,duration_minutes,time_slot,session_order')
              .eq('standard_week_pattern_id', pid)
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
      _msg = 'Erro ao carregar cadastro: $e';
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

  Future<void> _uploadAvatar() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // activity_types (fonte de verdade do backend)
      final types = await _client
          .from('activity_types')
          .select('id,name_pt,name,is_active')
          .order('id');

      final map = <String, String>{};
      if (types is List) {
        for (final r in types) {
          final id = (r['id'] ?? '').toString();
          if (id.isEmpty) continue;
          final isActive = r['is_active'];
          if (isActive is bool && isActive == false) {
            continue;
          }
          final label = ((r['name_pt'] ?? r['name']) ?? id).toString();
          map[id] = label;
        }
      }
      _activityLabels = map;


      // FilePicker web (já existe no projeto)
      // Vamos usar FilePicker.platform diretamente como no seu código atual
      // evitando mexer em dependências.
      // ignore: avoid_dynamic_calls
      final result = await (FilePicker.platform as dynamic).pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files == null || result.files.isEmpty) {
        setState(() => _msg = 'Nenhuma imagem selecionada.');
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _msg = 'Falha ao ler a imagem.');
        return;
      }

      final ext = file.name.split('.').last.toLowerCase();
      final path = '${user.id}/athlete_avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final data = await EdgeFunctionsService.uploadAvatar(
        bucket: 'avatars',
        path: path,
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        base64: base64Encode(bytes),
      );

      final publicUrl = data['publicUrl'] as String;

      await _client.from('profiles').update({'avatar_url': publicUrl}).eq('id', user.id);

      setState(() {
        _avatarUrl = publicUrl;
        _msg = 'Foto enviada ✅';
      });
    } catch (e) {
      setState(() => _msg = 'Erro ao enviar foto: $e');
    }
  }

  Future<void> _saveAll() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _msg = null);

    if (_avatarUrl == null || _avatarUrl!.trim().isEmpty) {
      setState(() => _msg = 'Foto de perfil é obrigatória.');
      return;
    }
    if (_birthDate == null) {
      setState(() => _msg = 'Data de nascimento é obrigatória.');
      return;
    }

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final rhr = _toInt(_restHrController.text)!;
    final mhr = _toInt(_maxHrController.text)!;
    if (rhr >= mhr) {
      setState(() => _msg = 'FC repouso deve ser menor que FC máxima.');
      return;
    }

    // Agenda: exigir A ou B (um dos dois) para o motor gerar semana
    if (!_hasAnyWeeklyConstraints() && _sessions.isEmpty) {
      setState(() => _msg = 'Agenda é obrigatória: preencha (A) Disponibilidade e/ou (B) Padrão semanal.');
      return;
    }

    setState(() => _saving = true);

    try {
      // activity_types (fonte de verdade do backend)
      final types = await _client
          .from('activity_types')
          .select('id,name_pt,name,is_active')
          .order('id');

      final map = <String, String>{};
      if (types is List) {
        for (final r in types) {
          final id = (r['id'] ?? '').toString();
          if (id.isEmpty) continue;
          final isActive = r['is_active'];
          if (isActive is bool && isActive == false) {
            continue;
          }
          final label = ((r['name_pt'] ?? r['name']) ?? id).toString();
          map[id] = label;
        }
      }
      _activityLabels = map;


      // 1) profiles + athletes
      await _client.from('profiles').update({'full_name': _nameController.text.trim()}).eq('id', user.id);

      await _client.from('athletes').upsert({
        'id': user.id,
        'birth_date': _birthDate!.toIso8601String().substring(0, 10),
        'gender': _gender,
        'height_cm': _toDouble(_heightController.text),
        'weight_kg': _toDouble(_weightController.text),
        'experience_level': _experience,
        'resting_hr': rhr,
        'max_hr': mhr,
        'phase': _phase,
        'vo2_max': _vo2Controller.text.trim().isEmpty ? null : _toDouble(_vo2Controller.text),
      });

      // defaults
      await _client.from('athlete_capacity').upsert({'athlete_id': user.id});
      await _client.from('athlete_zones').upsert({'athlete_id': user.id});

      // 2) Agenda A: weekly_constraints (replace)
      await _client.from('weekly_constraints').delete().eq('athlete_id', user.id);

      if (_hasAnyWeeklyConstraints()) {
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
      }

      // 3) Agenda B: padrão semanal (se tiver sessões)
      if (_sessions.isNotEmpty) {
        await _client.from('standard_week_patterns').update({'is_active': false}).eq('athlete_id', user.id);

        final created = await _client.from('standard_week_patterns').insert({
          'athlete_id': user.id,
          'title': _patternTitleController.text.trim().isEmpty ? 'Meu padrão semanal' : _patternTitleController.text.trim(),
          'is_active': true,
        }).select('id').single();

        final pid = created['id'] as int;

        await _client.from('standard_week_pattern_sessions').insert(
          _sessions.map((s) => s.toInsert(pid)).toList(),
        );
      }

      // 4) Recomendados: zones
      await _client.from('athlete_zones').upsert({
        'athlete_id': user.id,
        'hr_max': _hrMaxController.text.trim().isEmpty ? null : _toInt(_hrMaxController.text),
        'pace_z1_sec': _paceToSec(_pz1.text),
        'pace_z2_sec': _paceToSec(_pz2.text),
        'pace_z3_sec': _paceToSec(_pz3.text),
        'pace_z4_sec': _paceToSec(_pz4.text),
        'pace_z5_sec': _paceToSec(_pz5.text),
      });

      // 5) Recomendados: prova alvo (opcional)
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
      setState(() => _msg = 'Erro ao salvar cadastro: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro do Atleta (completo)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const Text(
                  'Trinium Sports é uma inteligência de carga e prescrição.\n'
                  'Preencha os dados abaixo para o motor gerar treinos com precisão.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // --- 1) Obrigatórios
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1) Obrigatórios (motor)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Esses dados permitem o motor gerar treinos com segurança e progressão coerente.'),
                          const SizedBox(height: 12),

                          OutlinedButton(
                            onPressed: _saving ? null : _uploadAvatar,
                            child: const Text('Enviar foto de perfil (obrigatório)'),
                          ),
                          if (_avatarUrl != null) ...[
                            const SizedBox(height: 6),
                            const Text('Foto OK ✅'),
                          ],
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome completo (profiles.full_name)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => _requiredText(v, 'Nome'),
                          ),
                          const SizedBox(height: 12),

                          OutlinedButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _birthDate ?? DateTime(now.year - 30, 1, 1),
                                firstDate: DateTime(1930, 1, 1),
                                lastDate: DateTime(now.year - 10, 12, 31),
                              );
                              if (picked != null) setState(() => _birthDate = picked);
                            },
                            child: Text(_birthDate == null
                                ? 'Selecionar data de nascimento (athletes.birth_date) *'
                                : 'Nascimento: ${_birthDate!.toIso8601String().substring(0, 10)}'),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gênero (athletes.gender) *',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Masculino')),
                              DropdownMenuItem(value: 'female', child: Text('Feminino')),
                              DropdownMenuItem(value: 'other', child: Text('Outro')),
                            ],
                            onChanged: (v) => setState(() => _gender = v ?? 'male'),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _experience,
                            decoration: const InputDecoration(
                              labelText: 'Experiência (athletes.experience_level) *',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'beginner', child: Text('Iniciante')),
                              DropdownMenuItem(value: 'intermediate', child: Text('Intermediário')),
                              DropdownMenuItem(value: 'advanced', child: Text('Avançado')),
                              DropdownMenuItem(value: 'elite', child: Text('Elite')),
                            ],
                            onChanged: (v) => setState(() => _experience = v ?? 'intermediate'),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Altura em cm (athletes.height_cm) *',
                              border: OutlineInputBorder(),
                              helperText: 'Usado para coerência fisiológica e estimativas.',
                            ),
                            validator: (v) => _rangeDouble(v, 'Altura', 120, 230),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Peso em kg (athletes.weight_kg) *',
                              border: OutlineInputBorder(),
                              helperText: 'Impacta carga, energia e tolerância de volume.',
                            ),
                            validator: (v) => _rangeDouble(v, 'Peso', 30, 220),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _restHrController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'FC repouso (athletes.resting_hr) *',
                              border: OutlineInputBorder(),
                              helperText: 'Baseline de recuperação/fadiga.',
                            ),
                            validator: (v) => _rangeInt(v, 'FC repouso', 30, 120),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _maxHrController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'FC máxima (athletes.max_hr) *',
                              border: OutlineInputBorder(),
                              helperText: 'Base para zonas de intensidade.',
                            ),
                            validator: (v) => _rangeInt(v, 'FC máxima', 120, 230),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // --- 2) Agenda
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2) Agenda (obrigatório para o motor)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'O Trinium precisa saber QUANDO você consegue treinar.\n'
                          'Você pode preencher (A) Disponibilidade e/ou (B) Padrão semanal. Quanto mais completo, melhor.',
                        ),
                        const SizedBox(height: 12),

                        const Text('A) Disponibilidade (weekly_constraints)'),
                        const SizedBox(height: 8),
                        _WeeklyConstraintsGrid(
                          availability: _availability,
                          activityLabels: _activityLabels,
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
                        ),

                        const Divider(height: 24),

                        const Text('B) Padrão semanal (standard_week_patterns)'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _patternTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do padrão',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_sessions.isEmpty)
                          const Text('Nenhuma sessão adicionada ainda.')
                        else
                          Column(
                            children: _sessions.map((s) {
                              return ListTile(
                                title: Text('${dayLabels[s.dayOfWeek]} • ${slotLabels[s.timeSlot]} • ${_activityLabels[s.activityTypeId] ?? s.activityTypeId}'),
                                subtitle: Text('Duração: ${s.durationMinutes} min | Ordem: ${s.sessionOrder}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => setState(() => _sessions.remove(s)),
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final created = await showDialog<_PatternSession>(
                              context: context,
                              builder: (_) => _AddSessionDialog(activityLabels: _activityLabels.isEmpty ? {'running':'Corrida (asfalto)'} : _activityLabels),
                            );
                            if (created != null) setState(() => _sessions.add(created));
                          },
                          child: const Text('Adicionar sessão ao padrão'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // --- 3) Recomendados
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('3) Recomendados (aumentam precisão)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Esses dados não são obrigatórios para começar, mas melhoram muito o motor.'),

                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _phase,
                          decoration: const InputDecoration(
                            labelText: 'Fase do ciclo (athletes.phase)',
                            border: OutlineInputBorder(),
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

                        const Divider(height: 24),
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
                        const SizedBox(height: 10),

                        _paceField(_pz1, 'Pace Z1 (pace_z1_sec) — mm:ss'),
                        _paceField(_pz2, 'Pace Z2 (pace_z2_sec) — mm:ss'),
                        _paceField(_pz3, 'Pace Z3 (pace_z3_sec) — mm:ss'),
                        _paceField(_pz4, 'Pace Z4 (pace_z4_sec) — mm:ss'),
                        _paceField(_pz5, 'Pace Z5 (pace_z5_sec) — mm:ss'),

                        const Divider(height: 24),
                        const Text('Prova alvo (target_races) — opcional'),
                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          value: _raceActivity,
                          decoration: const InputDecoration(
                            labelText: 'Modalidade (activity_type_id)',
                            border: OutlineInputBorder(),
                          ),
                          items: _activityLabels.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => setState(() => _raceActivity = v ?? 'run'),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: _raceNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome da prova',
                            border: OutlineInputBorder(),
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
                              ? 'Selecionar data da prova'
                              : 'Data: ${_raceDate!.toIso8601String().substring(0, 10)}'),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: _raceDistanceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Distância (metros) — opcional',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: _raceElevGainController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ganho elevação (m) — opcional',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          value: _racePriority,
                          decoration: const InputDecoration(
                            labelText: 'Prioridade (A/B/C) — opcional',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'A', child: Text('A (principal)')),
                            DropdownMenuItem(value: 'B', child: Text('B')),
                            DropdownMenuItem(value: 'C', child: Text('C')),
                          ],
                          onChanged: (v) => setState(() => _racePriority = v ?? 'A'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                FilledButton(
                  onPressed: _saving ? null : _saveAll,
                  child: Text(_saving ? 'Salvando...' : 'Salvar cadastro completo'),
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
    return Column(
      children: slots.map((slot) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slotLabels[slot] ?? slot,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
              onChanged: (v) => setState(() => _activity = v ?? 'run'),
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
