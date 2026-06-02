import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteInjuriesRestrictionsScreen extends StatefulWidget {
  const AthleteInjuriesRestrictionsScreen({super.key});

  @override
  State<AthleteInjuriesRestrictionsScreen> createState() =>
      _AthleteInjuriesRestrictionsScreenState();
}

class _AthleteInjuriesRestrictionsScreenState
    extends State<AthleteInjuriesRestrictionsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _msg;

  List<Map<String, dynamic>> _items = [];

  final _formKey = GlobalKey<FormState>();

  int? _editingId;
  String _restrictionType = 'injury';
  String _severity = 'moderate';
  String _status = 'active';

  final _titleController = TextEditingController();
  final _bodyRegionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _expectedEndDateController = TextEditingController();
  final _notesController = TextEditingController();
  final _recommendationsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyRegionController.dispose();
    _startDateController.dispose();
    _expectedEndDateController.dispose();
    _notesController.dispose();
    _recommendationsController.dispose();
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
          .from('athlete_injuries_restrictions')
          .select()
          .eq('athlete_id', user.id)
          .order('created_at', ascending: false);

      _items = (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar restrições/lesões: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _editingId = null;
    _restrictionType = 'injury';
    _severity = 'moderate';
    _status = 'active';
    _titleController.clear();
    _bodyRegionController.clear();
    _startDateController.clear();
    _expectedEndDateController.clear();
    _notesController.clear();
    _recommendationsController.clear();
    setState(() {});
  }

  void _editItem(Map<String, dynamic> item) {
    _editingId = item['id'] as int?;
    _restrictionType = _s(item['restriction_type']).isEmpty
        ? 'injury'
        : _s(item['restriction_type']);
    _severity =
        _s(item['severity']).isEmpty ? 'moderate' : _s(item['severity']);
    _status = _s(item['status']).isEmpty ? 'active' : _s(item['status']);
    _titleController.text = _s(item['title']);
    _bodyRegionController.text = _s(item['body_region']);
    _startDateController.text = _s(item['start_date']);
    _expectedEndDateController.text = _s(item['expected_end_date']);
    _notesController.text = _s(item['notes']);
    _recommendationsController.text = _s(item['recommendations']);
    setState(() {});
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

  Future<void> _save() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _msg = null;
    });

    try {
      final payload = {
        'athlete_id': user.id,
        'restriction_type': _restrictionType,
        'title': _titleController.text.trim(),
        'body_region': _bodyRegionController.text.trim().isEmpty
            ? null
            : _bodyRegionController.text.trim(),
        'severity': _severity,
        'status': _status,
        'start_date': _startDateController.text.trim().isEmpty
            ? null
            : _startDateController.text.trim(),
        'expected_end_date': _expectedEndDateController.text.trim().isEmpty
            ? null
            : _expectedEndDateController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'recommendations': _recommendationsController.text.trim().isEmpty
            ? null
            : _recommendationsController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (_editingId == null) {
        await _client.from('athlete_injuries_restrictions').insert(payload);
      } else {
        await _client
            .from('athlete_injuries_restrictions')
            .update(payload)
            .eq('id', _editingId!);
      }

      _resetForm();
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingId == null
                ? 'Registro salvo ✅'
                : 'Registro atualizado ✅',
          ),
        ),
      );
    } catch (e) {
      setState(() => _msg = 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _client
          .from('athlete_injuries_restrictions')
          .delete()
          .eq('id', id);

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro excluído.')),
      );
    } catch (e) {
      setState(() => _msg = 'Erro ao excluir: $e');
    }
  }

  String _typeLabel(String raw) {
    switch (raw) {
      case 'injury':
        return 'Lesão';
      case 'physical_restriction':
        return 'Restrição física';
      case 'medical_restriction':
        return 'Restrição médica';
      case 'post_surgery':
        return 'Pós-cirúrgico';
      case 'pain_report':
        return 'Relato de dor';
      case 'other':
        return 'Outro';
      default:
        return raw;
    }
  }

  String _severityLabel(String raw) {
    switch (raw) {
      case 'low':
        return 'Baixa';
      case 'moderate':
        return 'Moderada';
      case 'high':
        return 'Alta';
      case 'critical':
        return 'Crítica';
      default:
        return raw;
    }
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'active':
        return 'Ativa';
      case 'monitoring':
        return 'Em monitoramento';
      case 'resolved':
        return 'Resolvida';
      case 'inactive':
        return 'Inativa';
      default:
        return raw;
    }
  }

  Widget _sectionCard({required Widget child}) {
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
        title: const Text('Restrições / lesões'),
        actions: [
          if (_editingId != null)
            TextButton(
              onPressed: _saving ? null : _resetForm,
              child: const Text('Novo'),
            ),
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
              child: Text(
                _msg!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingId == null
                              ? 'Novo registro'
                              : 'Editar registro',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _restrictionType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'injury',
                              child: Text('Lesão'),
                            ),
                            DropdownMenuItem(
                              value: 'physical_restriction',
                              child: Text('Restrição física'),
                            ),
                            DropdownMenuItem(
                              value: 'medical_restriction',
                              child: Text('Restrição médica'),
                            ),
                            DropdownMenuItem(
                              value: 'post_surgery',
                              child: Text('Pós-cirúrgico'),
                            ),
                            DropdownMenuItem(
                              value: 'pain_report',
                              child: Text('Relato de dor'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Outro'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _restrictionType = v ?? 'injury';
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Título é obrigatório.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bodyRegionController,
                          decoration: const InputDecoration(
                            labelText: 'Região do corpo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _severity,
                                decoration: const InputDecoration(
                                  labelText: 'Severidade',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'low',
                                    child: Text('Baixa'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'moderate',
                                    child: Text('Moderada'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'high',
                                    child: Text('Alta'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'critical',
                                    child: Text('Crítica'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _severity = v ?? 'moderate';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'active',
                                    child: Text('Ativa'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monitoring',
                                    child: Text('Em monitoramento'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'resolved',
                                    child: Text('Resolvida'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'inactive',
                                    child: Text('Inativa'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _status = v ?? 'active';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _startDateController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Data de início',
                                  border: OutlineInputBorder(),
                                ),
                                onTap: () => _pickDate(_startDateController),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _expectedEndDateController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Fim previsto',
                                  border: OutlineInputBorder(),
                                ),
                                onTap: () =>
                                    _pickDate(_expectedEndDateController),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _recommendationsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Recomendações',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(
                                _editingId == null ? 'Salvar' : 'Atualizar',
                              ),
                            ),
                            if (_editingId != null) ...[
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: _saving ? null : _resetForm,
                                child: const Text('Cancelar'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registros cadastrados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        const Text('Nenhuma restrição ou lesão cadastrada.')
                      else
                        ..._items.map((item) {
                          final id = item['id'] as int;
                          final title = _s(item['title']).isEmpty
                              ? 'Registro'
                              : _s(item['title']);
                          final region = _s(item['body_region']);
                          final notes = _s(item['notes']);
                          final recommendations = _s(item['recommendations']);

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
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
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _editItem(item),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteItem(id),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                Text('Tipo: ${_typeLabel(_s(item['restriction_type']))}'),
                                Text('Severidade: ${_severityLabel(_s(item['severity']))}'),
                                Text('Status: ${_statusLabel(_s(item['status']))}'),
                                if (region.isNotEmpty) Text('Região: $region'),
                                if (_s(item['start_date']).isNotEmpty)
                                  Text('Início: ${_s(item['start_date'])}'),
                                if (_s(item['expected_end_date']).isNotEmpty)
                                  Text('Fim previsto: ${_s(item['expected_end_date'])}'),
                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Observações: $notes'),
                                ],
                                if (recommendations.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Recomendações: $recommendations'),
                                ],
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
