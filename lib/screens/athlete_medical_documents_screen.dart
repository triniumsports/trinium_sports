import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/edge_functions_service.dart';

class AthleteMedicalDocumentsScreen extends StatefulWidget {
  const AthleteMedicalDocumentsScreen({super.key});

  @override
  State<AthleteMedicalDocumentsScreen> createState() =>
      _AthleteMedicalDocumentsScreenState();
}

class _AthleteMedicalDocumentsScreenState
    extends State<AthleteMedicalDocumentsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  List<Map<String, dynamic>> _docs = [];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _issuerController = TextEditingController();
  final _examDateController = TextEditingController();
  final _expiresAtController = TextEditingController();
  final _tagsController = TextEditingController();

  String _documentType = 'lab_exam';

  String? _selectedFileName;
  String? _selectedMimeType;
  Uint8List? _selectedBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _issuerController.dispose();
    _examDateController.dispose();
    _expiresAtController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _msg = 'Usuário não autenticado.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final rows = await _client
          .from('athlete_medical_documents')
          .select()
          .eq('athlete_id', user.id)
          .order('created_at', ascending: false);

      _docs = (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar documentos: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.trim().isNotEmpty) {
      initialDate = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (picked != null) {
      controller.text = picked.toIso8601String().substring(0, 10);
      setState(() {});
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) {
        throw Exception('Não foi possível ler o arquivo.');
      }

      final ext = file.name.split('.').last.toLowerCase();
      String mimeType = 'application/octet-stream';
      if (ext == 'pdf') mimeType = 'application/pdf';
      if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
      if (ext == 'png') mimeType = 'image/png';

      setState(() {
        _selectedFileName = file.name;
        _selectedMimeType = mimeType;
        _selectedBytes = file.bytes!;
      });
    } catch (e) {
      setState(() => _msg = 'Erro ao selecionar arquivo: $e');
    }
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (_titleController.text.trim().isEmpty) {
      setState(() => _msg = 'Título é obrigatório.');
      return;
    }

    if (_selectedBytes == null ||
        _selectedFileName == null ||
        _selectedMimeType == null) {
      setState(() => _msg = 'Selecione um arquivo antes de salvar.');
      return;
    }

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final safeName = _selectedFileName!.replaceAll(' ', '_');
      final path = '${user.id}/medical_docs/${now}_$safeName';

      await EdgeFunctionsService.uploadAvatar(
        bucket: 'medical-documents',
        path: path,
        contentType: _selectedMimeType!,
        base64: base64Encode(_selectedBytes!),
      );

      await _client.from('athlete_medical_documents').insert({
        'athlete_id': user.id,
        'uploaded_by_user_id': user.id,
        'uploaded_by_role': 'athlete',
        'document_type': _documentType,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'file_path': path,
        'file_name': _selectedFileName,
        'mime_type': _selectedMimeType,
        'exam_date': _examDateController.text.trim().isEmpty
            ? null
            : _examDateController.text.trim(),
        'expires_at': _expiresAtController.text.trim().isEmpty
            ? null
            : _expiresAtController.text.trim(),
        'issuer_name': _issuerController.text.trim().isEmpty
            ? null
            : _issuerController.text.trim(),
        'tags': _parseTags(_tagsController.text),
        'is_sensitive': true,
      });

      _titleController.clear();
      _descriptionController.clear();
      _issuerController.clear();
      _examDateController.clear();
      _expiresAtController.clear();
      _tagsController.clear();

      setState(() {
        _documentType = 'lab_exam';
        _selectedFileName = null;
        _selectedMimeType = null;
        _selectedBytes = null;
      });

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento enviado com sucesso ✅')),
      );
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar documento: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDoc(int id) async {
    try {
      await _client.from('athlete_medical_documents').delete().eq('id', id);
      await _load();
    } catch (e) {
      setState(() => _msg = 'Erro ao excluir documento: $e');
    }
  }

  String _docTypeLabel(String raw) {
    switch (raw) {
      case 'lab_exam':
        return 'Exame laboratorial';
      case 'cardiology_exam':
        return 'Exame cardiológico';
      case 'imaging_exam':
        return 'Exame de imagem';
      case 'medical_report':
        return 'Laudo médico';
      case 'sports_clearance':
        return 'Liberação esportiva';
      case 'body_composition':
        return 'Composição corporal';
      case 'prescription':
        return 'Prescrição';
      case 'nutrition_exam':
        return 'Exame nutricional';
      case 'physiotherapy_report':
        return 'Relatório de fisioterapia';
      case 'other':
        return 'Outro';
      default:
        return raw;
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Exames e documentos'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading || _saving) const LinearProgressIndicator(),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_msg!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Novo documento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _documentType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo do documento',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'lab_exam',
                            child: Text('Exame laboratorial'),
                          ),
                          DropdownMenuItem(
                            value: 'cardiology_exam',
                            child: Text('Exame cardiológico'),
                          ),
                          DropdownMenuItem(
                            value: 'imaging_exam',
                            child: Text('Exame de imagem'),
                          ),
                          DropdownMenuItem(
                            value: 'medical_report',
                            child: Text('Laudo médico'),
                          ),
                          DropdownMenuItem(
                            value: 'sports_clearance',
                            child: Text('Liberação esportiva'),
                          ),
                          DropdownMenuItem(
                            value: 'body_composition',
                            child: Text('Composição corporal'),
                          ),
                          DropdownMenuItem(
                            value: 'prescription',
                            child: Text('Prescrição'),
                          ),
                          DropdownMenuItem(
                            value: 'nutrition_exam',
                            child: Text('Exame nutricional'),
                          ),
                          DropdownMenuItem(
                            value: 'physiotherapy_report',
                            child: Text('Relatório de fisioterapia'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Outro'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _documentType = v ?? 'lab_exam');
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _issuerController,
                        decoration: const InputDecoration(
                          labelText: 'Emitido por',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _examDateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Data do exame',
                                border: OutlineInputBorder(),
                              ),
                              onTap: () => _pickDate(_examDateController),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _expiresAtController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Validade',
                                border: OutlineInputBorder(),
                              ),
                              onTap: () => _pickDate(_expiresAtController),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (separadas por vírgula)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          _selectedFileName == null
                              ? 'Selecionar arquivo'
                              : 'Arquivo: $_selectedFileName',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Enviando...' : 'Salvar documento'),
                      ),
                    ],
                  ),
                ),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documentos cadastrados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_docs.isEmpty)
                        const Text('Nenhum documento cadastrado.')
                      else
                        ..._docs.map((doc) {
                          final id = doc['id'] as int;
                          final title =
                              _s(doc['title']).isEmpty ? 'Documento' : _s(doc['title']);
                          final docType = _docTypeLabel(_s(doc['document_type']));
                          final examDate = _s(doc['exam_date']);
                          final issuer = _s(doc['issuer_name']);
                          final fileName = _s(doc['file_name']);

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFF7F7F9),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.description_outlined),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(docType),
                                      if (examDate.isNotEmpty)
                                        Text('Data: $examDate'),
                                      if (issuer.isNotEmpty)
                                        Text('Emitido por: $issuer'),
                                      if (fileName.isNotEmpty)
                                        Text('Arquivo: $fileName'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteDoc(id),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
