import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/verification_service.dart';
import 'home_router_screen.dart';
import '../services/edge_functions_service.dart';

class ProfessionalProfileFormScreen extends StatefulWidget {
  const ProfessionalProfileFormScreen({super.key});

  @override
  State<ProfessionalProfileFormScreen> createState() => _ProfessionalProfileFormScreenState();
}

class _ProfessionalProfileFormScreenState extends State<ProfessionalProfileFormScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _msg;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipController = TextEditingController();
  final _bioController = TextEditingController();
  final _regController = TextEditingController();

  String _professionalType = 'coach'; // coach | nutritionist | hybrid
  final Set<String> _specialties = {};

  String? _avatarUrl;

  static const Map<String, String> specialtyLabels = {
    'run': 'Corrida',
    'swim': 'Natação',
    'bike': 'Ciclismo',
    'strength': 'Força / Musculação',
    'trail': 'Trail',
    'triathlon': 'Triatlo',
  };

  String get _regLabel {
    if (_professionalType == 'nutritionist') return 'CRN (Registro profissional)';
    return 'CREF (Registro profissional)';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _bioController.dispose();
    _regController.dispose();
    super.dispose();
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
      final profile = await _client.from('profiles')
          .select('full_name,email,avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final coach = await _client.from('coaches')
          .select('professional_type,cref_number,phone_mobile,address_zip_code,bio,specialties')
          .eq('id', user.id)
          .maybeSingle();

      _nameController.text = (profile?['full_name'] ?? '').toString();
      _avatarUrl = (profile?['avatar_url'] ?? '').toString().trim();
      if (_avatarUrl != null && _avatarUrl!.isEmpty) _avatarUrl = null;

      _professionalType = (coach?['professional_type'] ?? 'coach').toString();
      _regController.text = (coach?['cref_number'] ?? '').toString();
      _phoneController.text = (coach?['phone_mobile'] ?? '').toString();
      _zipController.text = (coach?['address_zip_code'] ?? '').toString();
      _bioController.text = (coach?['bio'] ?? '').toString();

      final specs = coach?['specialties'];
      if (specs is List) {
        _specialties
          ..clear()
          ..addAll(specs.map((e) => e.toString()));
      }
    } catch (e) {
      _msg = 'Erro ao carregar dados: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _isValid() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().isEmpty) return false;
    if (_zipController.text.trim().isEmpty) return false;
    if (_regController.text.trim().isEmpty) return false;
    if (_specialties.isEmpty) return false;
    if (!['coach', 'nutritionist', 'hybrid'].contains(_professionalType)) return false;
    if (_avatarUrl == null || _avatarUrl!.trim().isEmpty) return false; // foto obrigatória
    return true;
  }

  Future<void> _uploadAvatar() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _uploading = true;
      _msg = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        throw Exception('Nenhum arquivo selecionado.');
      }

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('Falha ao ler arquivo.');

      final ext = file.name.split('.').last.toLowerCase();
      final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

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
      setState(() {
        _msg = 'Erro ao enviar foto: $e';
      });
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _uploadDoc(String docType, String label) async {
    setState(() {
      _uploading = true;
      _msg = null;
    });

    try {
      await VerificationService().pickAndUpload(docType: docType);
      setState(() {
        _msg = '$label enviado ✅';
      });
    } catch (e) {
      setState(() {
        _msg = 'Erro ($label): $e';
      });
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (!_isValid()) {
      setState(() {
        _msg = 'Preencha todos os campos obrigatórios (incluindo foto).';
      });
      return;
    }

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      await _client.from('profiles').update({
        'full_name': _nameController.text.trim(),
      }).eq('id', user.id);

      await _client.from('coaches').update({
        'professional_type': _professionalType,
        'cref_number': _regController.text.trim(),
        'phone_mobile': _phoneController.text.trim(),
        'address_zip_code': _zipController.text.trim(),
        'bio': _bioController.text.trim(),
        'specialties': _specialties.toList(),
      }).eq('id', user.id);

      // evita tela branca: volta para o router (recarrega lógica)
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeRouterScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _msg = 'Erro ao salvar: $e';
      });
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
      appBar: AppBar(title: const Text('Perfil do Profissional')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const Text(
                  'Complete seu perfil para aparecer na busca do atleta.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // FOTO
                OutlinedButton(
                  onPressed: _uploading ? null : _uploadAvatar,
                  child: Text(_uploading ? 'Enviando...' : 'Enviar foto de perfil (obrigatório)'),
                ),
                if (_avatarUrl != null) ...[
                  const SizedBox(height: 8),
                  Text('Foto OK ✅', textAlign: TextAlign.center),
                ],

                const SizedBox(height: 16),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome (obrigatório)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _professionalType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo (obrigatório)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'coach', child: Text('Treinador')),
                    DropdownMenuItem(value: 'nutritionist', child: Text('Nutricionista')),
                    DropdownMenuItem(value: 'hybrid', child: Text('Híbrido')),
                  ],
                  onChanged: (v) => setState(() => _professionalType = v ?? 'coach'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _regController,
                  decoration: InputDecoration(
                    labelText: '$_regLabel (obrigatório)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Celular (obrigatório)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'CEP (obrigatório)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Especialidades (selecione ao menos 1):'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: specialtyLabels.entries.map((e) {
                    final selected = _specialties.contains(e.key);
                    return FilterChip(
                      selected: selected,
                      label: Text(e.value),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _specialties.add(e.key);
                          } else {
                            _specialties.remove(e.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Documentos (obrigatório enviar os 3):'),
                const SizedBox(height: 8),

                FilledButton(
                  onPressed: _uploading ? null : () => _uploadDoc('identity', 'RG/CNH'),
                  child: const Text('Enviar RG/CNH (foto ou PDF)'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _uploading ? null : () => _uploadDoc('council', 'Documento do Conselho'),
                  child: const Text('Enviar documento do Conselho (CREF/CRN)'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _uploading ? null : () => _uploadDoc('lookup_print', 'Print consulta pública'),
                  child: const Text('Enviar print da consulta pública (ATIVO/BACHAREL)'),
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
    );
  }
}
