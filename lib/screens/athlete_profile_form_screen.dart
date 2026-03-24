import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_router_screen.dart';
import 'athlete_agenda_screen.dart';
import '../services/edge_functions_service.dart';

class AthleteProfileFormScreen extends StatefulWidget {
  const AthleteProfileFormScreen({super.key});

  @override
  State<AthleteProfileFormScreen> createState() => _AthleteProfileFormScreenState();
}

class _AthleteProfileFormScreenState extends State<AthleteProfileFormScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();
  String? _msg;

  final _nameController = TextEditingController();
  DateTime? _birthDate;

  String _gender = 'male'; // male/female/other
  String _experience = 'intermediate'; // beginner/intermediate/advanced/elite

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _restHrController = TextEditingController();
  final _maxHrController = TextEditingController();
  final _vo2Controller = TextEditingController(); // opcional

  String _fitnessLevel = 'intermediate';
  String? _avatarUrl;
  final _bmrController = TextEditingController(text: '1600');
  final _phaseController = TextEditingController(text: 'base');
  final _dietController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _restHrController.dispose();
    _maxHrController.dispose();
    _vo2Controller.dispose();
    _bmrController.dispose();
    _phaseController.dispose();
    _dietController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _toInt(String s) => int.tryParse(s.trim());
  double? _toDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

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
      final profile = await _client
          .from('profiles')
          .select('full_name,avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final athlete = await _client
          .from('athletes')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      _nameController.text = (profile?['full_name'] ?? '').toString();
      _avatarUrl = (profile?['avatar_url'] ?? '').toString().trim();
      if (_avatarUrl != null && _avatarUrl!.isEmpty) _avatarUrl = null;

      final bd = athlete?['birth_date'];
      if (bd != null) {
        _birthDate = DateTime.tryParse(bd.toString());
      }

      _gender = (athlete?['gender'] ?? _gender).toString();
      _experience = (athlete?['experience_level'] ?? _experience).toString();
      _fitnessLevel = (athlete?['fitness_level'] ?? _fitnessLevel).toString();

      _heightController.text = (athlete?['height_cm'] ?? '').toString();
      _weightController.text = (athlete?['weight_kg'] ?? '').toString();
      _restHrController.text = (athlete?['resting_hr'] ?? '').toString();
      _maxHrController.text = (athlete?['max_hr'] ?? '').toString();
      _vo2Controller.text = (athlete?['vo2_max'] ?? '').toString();

      _bmrController.text =
          (athlete?['basal_metabolic_rate'] ?? 1600).toString();
      _phaseController.text = (athlete?['phase'] ?? 'base').toString();

      final diets = athlete?['dietary_restrictions'];
      if (diets is List) {
        _dietController.text =
            diets.map((e) => e.toString()).join(', ');
      }
    } catch (e) {
      _msg = 'Erro ao carregar dados: $e';
    } finally {
      setState(() => _loading = false);
    }
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

  String? _optionalRangeDouble(String? v, String label, double min, double max) {
    if (v == null || v.trim().isEmpty) return null;
    final x = _toDouble(v);
    if (x == null) return '$label inválido.';
    if (x < min || x > max) return '$label fora do intervalo ($min–$max).';
    return null;
  }

  
  Future<void> _uploadAvatar() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _msg = null);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        throw Exception('Nenhuma imagem selecionada.');
      }

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Falha ao ler a imagem no navegador.');
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
await _client.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', user.id);
setState(() {
        _avatarUrl = publicUrl;
        _msg = 'Foto de perfil enviada ✅';
      });
    } catch (e) {
      final msg = e.toString();
      setState(() => _msg = 'Erro ao enviar foto (provável CORS/origin): $msg');
    }
  }

Future<void> _save() async {
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

    final height = _toDouble(_heightController.text)!;
    final weight = _toDouble(_weightController.text)!;
    final rhr = _toInt(_restHrController.text)!;
    final mhr = _toInt(_maxHrController.text)!;

    if (rhr >= mhr) {
      setState(() => _msg = 'FC repouso deve ser menor que FC máxima.');
      return;
    }

    final vo2 = _vo2Controller.text.trim().isEmpty
        ? null
        : _toDouble(_vo2Controller.text);

    setState(() => _saving = true);

    try {
      await _client.from('profiles').update({
        'full_name': _nameController.text.trim(),
      }).eq('id', user.id);

      await _client.from('athletes').upsert({
        'id': user.id,
        'birth_date': _birthDate!.toIso8601String().substring(0, 10),
        'gender': _gender,
        'height_cm': height,
        'weight_kg': weight,
        'experience_level': _experience,
        'resting_hr': rhr,
        'max_hr': mhr,
        'vo2_max': vo2,
        'fitness_level': _fitnessLevel,
        'basal_metabolic_rate': _toInt(_bmrController.text) ?? 1600,
        'phase': _phaseController.text.trim().isEmpty
            ? 'base'
            : _phaseController.text.trim(),
        'dietary_restrictions': _dietController.text.trim().isEmpty
            ? null
            : _dietController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
      });

      // Defaults auxiliares (não doem se já existirem)
      await _client.from('athlete_capacity').upsert({'athlete_id': user.id});
      await _client.from('athlete_zones').upsert({'athlete_id': user.id});

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AthleteAgendaScreen()),
      );
} catch (e) {
      setState(() => _msg = 'Erro ao salvar: $e');
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
      appBar: AppBar(title: const Text('Perfil do Atleta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    'Complete seus dados para o motor calcular treinos com precisão.\nCampos com validação rígida.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton(
                    onPressed: _saving ? null : _uploadAvatar,
                    child: const Text('Enviar foto de perfil (obrigatório)'),
                  ),
                  if (_avatarUrl != null) ...[
                    const SizedBox(height: 8),
                    Text('Foto OK ✅', textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome (obrigatório)',
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
                    child: Text(
                      _birthDate == null
                          ? 'Selecionar data de nascimento (obrigatório)'
                          : 'Nascimento: ${_birthDate!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gênero (obrigatório)',
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
                      labelText: 'Experiência (obrigatório)',
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
                      labelText: 'Altura em cm (obrigatório) — ex: 178',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _rangeDouble(v, 'Altura', 120, 230),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peso em kg (obrigatório) — ex: 72.5',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _rangeDouble(v, 'Peso', 30, 220),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _restHrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'FC repouso (obrigatório) — ex: 52',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _rangeInt(v, 'FC repouso', 30, 120),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _maxHrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'FC máxima (obrigatório) — ex: 190',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _rangeInt(v, 'FC máxima', 120, 230),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _vo2Controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'VO2max (opcional) — ex: 52.4',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _optionalRangeDouble(v, 'VO2max', 20, 90),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _fitnessLevel,
                    decoration: const InputDecoration(
                      labelText: 'Nível fitness (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'beginner', child: Text('Iniciante')),
                      DropdownMenuItem(value: 'intermediate', child: Text('Intermediário')),
                      DropdownMenuItem(value: 'advanced', child: Text('Avançado')),
                      DropdownMenuItem(value: 'elite', child: Text('Elite')),
                    ],
                    onChanged: (v) => setState(() => _fitnessLevel = v ?? 'intermediate'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _bmrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'BMR (opcional) — ex: 1600',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final x = _toInt(v);
                      if (x == null) return 'BMR inválido.';
                      if (x < 900 || x > 3500) return 'BMR fora do intervalo (900–3500).';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _phaseController,
                    decoration: const InputDecoration(
                      labelText: 'Fase (opcional) — ex: base',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _dietController,
                    decoration: const InputDecoration(
                      labelText: 'Restrições alimentares (opcional, vírgula)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Salvando...' : 'Salvar e continuar'),
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
      ),
    );
  }
}
