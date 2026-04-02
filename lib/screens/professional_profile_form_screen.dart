import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/edge_functions_service.dart';
import '../services/verification_service.dart';
import 'home_router_screen.dart';

class ProfessionalProfileFormScreen extends StatefulWidget {
  const ProfessionalProfileFormScreen({super.key});

  @override
  State<ProfessionalProfileFormScreen> createState() =>
      _ProfessionalProfileFormScreenState();
}

class _ProfessionalProfileFormScreenState
    extends State<ProfessionalProfileFormScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _msg;

  final _nameController = TextEditingController();
  final _crefOrCrnController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _academicDegreeController = TextEditingController();
  final _universityController = TextEditingController();
  final _graduationYearController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderController = TextEditingController();
  final _instagramController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _bioController = TextEditingController();
  final _crefCrnStateController = TextEditingController();
  final _licenseStateController = TextEditingController();

  String _professionalType = 'coach';
  final Set<String> _specialties = {};
  String? _avatarUrl;
  String _verificationStatus = 'pending';
  final Set<String> _uploadedDocTypes = {};

  static const Map<String, String> specialtyLabels = {
    'run': 'Corrida',
    'swim': 'Natação',
    'bike': 'Ciclismo',
    'strength': 'Força / Musculação',
    'trail': 'Trail',
    'triathlon': 'Triatlo',
  };

  bool get _hasAllDocs =>
      _uploadedDocTypes.contains('identity') &&
      _uploadedDocTypes.contains('council') &&
      _uploadedDocTypes.contains('lookup_print');

  String get _registrationLabel =>
      _professionalType == 'nutritionist' ? 'CRN' : 'CREF';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _crefOrCrnController.dispose();
    _licenseNumberController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _academicDegreeController.dispose();
    _universityController.dispose();
    _graduationYearController.dispose();
    _certificationsController.dispose();
    _yearsExperienceController.dispose();
    _birthDateController.dispose();
    _genderController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _bioController.dispose();
    _crefCrnStateController.dispose();
    _licenseStateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _msg = 'Usuário não autenticado.';
      });
      return;
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('full_name,avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final coach = await _client
          .from('coaches')
          .select(
            'cref_number,cref_state,academic_degree,university_name,graduation_year,'
            'specialties,certifications,years_experience,birth_date,gender,'
            'address_street,address_number,address_neighborhood,address_city,address_state,address_zip_code,'
            'phone_mobile,social_instagram,social_linkedin,bio,professional_type,'
            'license_number,license_state,verification_status,verification_documents',
          )
          .eq('id', user.id)
          .maybeSingle();

      _nameController.text = (profile?['full_name'] ?? '').toString();
      _avatarUrl = (profile?['avatar_url'] ?? '').toString().trim();
      if ((_avatarUrl ?? '').isEmpty) _avatarUrl = null;

      _professionalType =
          (coach?['professional_type'] ?? 'coach').toString().trim();
      if (!['coach', 'nutritionist'].contains(_professionalType)) {
        _professionalType = 'coach';
      }

      _crefOrCrnController.text =
          (coach?['cref_number'] ?? '').toString();
      _crefCrnStateController.text =
          (coach?['cref_state'] ?? '').toString();
      _academicDegreeController.text =
          (coach?['academic_degree'] ?? '').toString();
      _universityController.text =
          (coach?['university_name'] ?? '').toString();
      _graduationYearController.text =
          (coach?['graduation_year'] ?? '').toString();
      _certificationsController.text =
          (coach?['certifications'] ?? '').toString();
      _yearsExperienceController.text =
          (coach?['years_experience'] ?? '').toString();
      _birthDateController.text =
          (coach?['birth_date'] ?? '').toString();
      _genderController.text = (coach?['gender'] ?? '').toString();
      _streetController.text =
          (coach?['address_street'] ?? '').toString();
      _numberController.text =
          (coach?['address_number'] ?? '').toString();
      _neighborhoodController.text =
          (coach?['address_neighborhood'] ?? '').toString();
      _cityController.text = (coach?['address_city'] ?? '').toString();
      _stateController.text = (coach?['address_state'] ?? '').toString();
      _zipController.text = (coach?['address_zip_code'] ?? '').toString();
      _phoneController.text = (coach?['phone_mobile'] ?? '').toString();
      _instagramController.text =
          (coach?['social_instagram'] ?? '').toString();
      _linkedinController.text =
          (coach?['social_linkedin'] ?? '').toString();
      _bioController.text = (coach?['bio'] ?? '').toString();
      _licenseNumberController.text =
          (coach?['license_number'] ?? '').toString();
      _licenseStateController.text =
          (coach?['license_state'] ?? '').toString();
      _verificationStatus =
          (coach?['verification_status'] ?? 'pending').toString();

      _specialties.clear();
      final specs = coach?['specialties'];
      if (specs is List) {
        _specialties.addAll(specs.map((e) => e.toString()));
      }

      _uploadedDocTypes.clear();
      final docs = coach?['verification_documents'];
      if (docs is List) {
        for (final d in docs) {
          if (d is Map && d['type'] != null) {
            _uploadedDocTypes.add(d['type'].toString());
          }
        }
      } else if (docs is Map) {
        for (final entry in docs.entries) {
          final key = entry.key.toString();
          if (key.isNotEmpty) _uploadedDocTypes.add(key);
        }
      }
    } catch (e) {
      _msg = 'Erro ao carregar dados: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Falha ao ler arquivo.');
      }

      final ext = file.name.split('.').last.toLowerCase();
      final path =
          '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

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
        _msg = 'Foto enviada ✅';
      });
    } catch (e) {
      setState(() => _msg = 'Erro ao enviar foto: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadDoc(String docType, String label) async {
    setState(() {
      _uploading = true;
      _msg = null;
    });

    try {
      await VerificationService().pickAndUpload(docType: docType);
      await _load();

      setState(() {
        _msg = _hasAllDocs
            ? '$label enviado ✅ Profissional aprovado automaticamente.'
            : '$label enviado ✅';
      });
    } catch (e) {
      setState(() => _msg = 'Erro ($label): $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool _isValid() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_crefOrCrnController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().isEmpty) return false;
    if (_zipController.text.trim().isEmpty) return false;
    if (_specialties.isEmpty) return false;
    if ((_avatarUrl ?? '').isEmpty) return false;
    if (!_hasAllDocs) return false;
    return true;
  }

  int? _toIntOrNull(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  Future<void> _save() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (!_isValid()) {
      setState(() {
        _msg =
            'Preencha os campos obrigatórios, envie a foto e os 3 documentos.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'avatar_url': _avatarUrl,
      });

      await _client.from('coaches').upsert({
        'id': user.id,
        'cref_number': _crefOrCrnController.text.trim(),
        'cref_state': _crefCrnStateController.text.trim().isEmpty
            ? null
            : _crefCrnStateController.text.trim(),
        'academic_degree': _academicDegreeController.text.trim().isEmpty
            ? null
            : _academicDegreeController.text.trim(),
        'university_name': _universityController.text.trim().isEmpty
            ? null
            : _universityController.text.trim(),
        'graduation_year': _toIntOrNull(_graduationYearController.text),
        'specialties': _specialties.toList(),
        'certifications': _certificationsController.text.trim().isEmpty
            ? null
            : _certificationsController.text.trim(),
        'years_experience': _toIntOrNull(_yearsExperienceController.text),
        'birth_date': _birthDateController.text.trim().isEmpty
            ? null
            : _birthDateController.text.trim(),
        'gender': _genderController.text.trim().isEmpty
            ? null
            : _genderController.text.trim(),
        'address_street': _streetController.text.trim().isEmpty
            ? null
            : _streetController.text.trim(),
        'address_number': _numberController.text.trim().isEmpty
            ? null
            : _numberController.text.trim(),
        'address_neighborhood': _neighborhoodController.text.trim().isEmpty
            ? null
            : _neighborhoodController.text.trim(),
        'address_city': _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        'address_state': _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        'address_zip_code': _zipController.text.trim(),
        'phone_mobile': _phoneController.text.trim(),
        'social_instagram': _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
        'social_linkedin': _linkedinController.text.trim().isEmpty
            ? null
            : _linkedinController.text.trim(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'professional_type': _professionalType,
        'license_number': _licenseNumberController.text.trim().isEmpty
            ? null
            : _licenseNumberController.text.trim(),
        'license_state': _licenseStateController.text.trim().isEmpty
            ? null
            : _licenseStateController.text.trim(),
        'verification_status': _hasAllDocs ? 'approved' : 'pending',
        'verification_submitted_at':
            _hasAllDocs ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeRouterScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _docTile(String title, String type, String buttonLabel) {
    final ok = _uploadedDocTypes.contains(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ok ? const Color(0xFFEAF8EE) : const Color(0xFFFFF4E5),
            border: Border.all(
              color: ok ? const Color(0xFF4CAF50) : const Color(0xFFFFB74D),
            ),
          ),
          child: Text(
            ok ? '$title enviado ✅' : '$title pendente',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _uploading ? null : () => _uploadDoc(type, title),
          child: Text(buttonLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Cadastro do Profissional'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 16,
                        offset: Offset(0, 8),
                        color: Color(0x12000000),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Complete o cadastro para aparecer no marketplace.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _verificationStatus == 'approved'
                              ? const Color(0xFFEAF8EE)
                              : const Color(0xFFFFF4E5),
                        ),
                        child: Text(
                          _verificationStatus == 'approved'
                              ? 'Status atual: aprovado automaticamente ✅'
                              : 'Status atual: pendente. Envie os 3 documentos para aprovação automática.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _uploading ? null : _uploadAvatar,
                        child: Text(
                          (_avatarUrl ?? '').isEmpty
                              ? 'Enviar foto de perfil (obrigatória)'
                              : 'Trocar foto de perfil',
                        ),
                      ),
                      if ((_avatarUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Foto OK ✅',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _professionalType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo profissional',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'coach',
                            child: Text('Treinador'),
                          ),
                          DropdownMenuItem(
                            value: 'nutritionist',
                            child: Text('Nutricionista'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _professionalType = value ?? 'coach';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(_nameController, 'Nome completo *'),
                      _field(_crefOrCrnController, '$_registrationLabel *'),
                      _field(_crefCrnStateController, 'Estado do $_registrationLabel'),
                      _field(_licenseNumberController, 'Número de licença / registro complementar'),
                      _field(_licenseStateController, 'Estado da licença complementar'),
                      _field(_phoneController, 'Celular *', keyboardType: TextInputType.phone),
                      _field(_zipController, 'CEP *'),
                      _field(_streetController, 'Rua'),
                      _field(_numberController, 'Número'),
                      _field(_neighborhoodController, 'Bairro'),
                      _field(_cityController, 'Cidade'),
                      _field(_stateController, 'UF'),
                      _field(_academicDegreeController, 'Grau acadêmico'),
                      _field(_universityController, 'Universidade'),
                      _field(_graduationYearController, 'Ano de formação', keyboardType: TextInputType.number),
                      _field(_certificationsController, 'Certificações'),
                      _field(_yearsExperienceController, 'Anos de experiência', keyboardType: TextInputType.number),
                      _field(_birthDateController, 'Data de nascimento (YYYY-MM-DD)'),
                      _field(_genderController, 'Gênero'),
                      _field(_instagramController, 'Instagram'),
                      _field(_linkedinController, 'LinkedIn'),
                      _field(_bioController, 'Bio', maxLines: 4),
                      const SizedBox(height: 8),
                      const Text(
                        'Especialidades (selecione ao menos 1) *',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: specialtyLabels.entries.map((entry) {
                          final selected = _specialties.contains(entry.key);
                          return FilterChip(
                            selected: selected,
                            label: Text(entry.value),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _specialties.add(entry.key);
                                } else {
                                  _specialties.remove(entry.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Documentos obrigatórios',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _docTile('RG/CNH', 'identity', 'Enviar RG/CNH'),
                      const SizedBox(height: 14),
                      _docTile('Documento do Conselho', 'council',
                          'Enviar documento do Conselho'),
                      const SizedBox(height: 14),
                      _docTile('Print da consulta pública', 'lookup_print',
                          'Enviar print da consulta pública'),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _saving ? 'Salvando...' : 'Salvar e continuar',
                        ),
                      ),
                      if (_msg != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _msg!,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
