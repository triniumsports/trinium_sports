import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  final _client = Supabase.instance.client;

  bool _loading = false;
  String? _message;

  Map<String, dynamic>? _current; // coach row
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _claimNext() async {
    setState(() {
      _loading = true;
      _message = null;
      _current = null;
    });

    try {
      final res = await _client.rpc('claim_next_pending_coach', params: {
        'p_timeout_minutes': 30,
      });

      if (res == null) {
        setState(() {
          _message = 'Nenhum profissional pendente na fila.';
        });
        return;
      }

      // rpc pode retornar lista com 1 item dependendo do driver
      if (res is List && res.isNotEmpty) {
        _current = Map<String, dynamic>.from(res.first);
      } else if (res is Map) {
        _current = Map<String, dynamic>.from(res);
      } else {
        _message = 'Resposta inesperada do servidor.';
      }
    } catch (e) {
      setState(() {
        _message = 'Erro ao pegar próximo: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _review(String decision) async {
    final current = _current;
    if (current == null) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await _client.rpc('review_coach', params: {
        'p_coach_id': current['id'],
        'p_decision': decision,
        'p_note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      });

      setState(() {
        _message = decision == 'verified'
            ? 'Aprovado ✅'
            : 'Reprovado ❌';
        _current = null;
        _noteController.clear();
      });
    } catch (e) {
      setState(() {
        _message = 'Erro ao salvar decisão: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _docsFromRow(Map<String, dynamic> row) async {
    final raw = row['verification_documents'];
    if (raw == null) return [];

    // pode vir jsonb como List<dynamic> ou String
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  Future<String?> _signedUrlForDoc(Map<String, dynamic> doc) async {
    final bucket = (doc['bucket'] ?? '').toString();
    final path = (doc['path'] ?? '').toString();
    if (bucket.isEmpty || path.isEmpty) return null;

    final res = await _client.storage.from(bucket).createSignedUrl(path, 60 * 30);
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Aprovação de Profissionais'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _loading ? null : _claimNext,
                  child: Text(_loading ? 'Carregando...' : 'Pegar próximo da fila'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                if (current == null)
                  const Text(
                    'Nenhum item selecionado. Clique em "Pegar próximo da fila".',
                    textAlign: TextAlign.center,
                  )
                else
                  Expanded(
                    child: _ApprovalCard(
                      row: current,
                      noteController: _noteController,
                      docsLoader: () => _docsFromRow(current),
                      signedUrlLoader: _signedUrlForDoc,
                      onApprove: _loading ? null : () => _review('verified'),
                      onReject: _loading ? null : () => _review('rejected'),
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

class _ApprovalCard extends StatefulWidget {
  final Map<String, dynamic> row;
  final TextEditingController noteController;
  final Future<List<Map<String, dynamic>>> Function() docsLoader;
  final Future<String?> Function(Map<String, dynamic>) signedUrlLoader;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ApprovalCard({
    required this.row,
    required this.noteController,
    required this.docsLoader,
    required this.signedUrlLoader,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _loadingDocs = true;
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    final docs = await widget.docsLoader();
    setState(() {
      _docs = docs;
      _loadingDocs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.row['id']?.toString() ?? '';
    final cref = widget.row['cref_number']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Coach ID: $id'),
            const SizedBox(height: 8),
            Text('CREF/CRN: $cref'),
            const SizedBox(height: 16),
            TextField(
              controller: widget.noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Documentos enviados:'),
            const SizedBox(height: 8),
            if (_loadingDocs)
              const CircularProgressIndicator()
            else if (_docs.isEmpty)
              const Text('Nenhum documento encontrado.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _docs.map((d) {
                  final filename = (d['filename'] ?? 'arquivo').toString();
                  return OutlinedButton(
                    onPressed: () async {
                      final url = await widget.signedUrlLoader(d);
                      if (url == null) return;
                      // Abre em nova aba no web (melhor UX)
                      // ignore: use_build_context_synchronously
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(filename),
                          content: SelectableText(url),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text('Gerar link: $filename'),
                  );
                }).toList(),
              ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onApprove,
                    child: const Text('Aprovar (verified)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    child: const Text('Reprovar (rejected)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
