import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'auth_gate.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  final _client = Supabase.instance.client;

  bool _loading = false;
  String? _message;

  Map<String, dynamic>? _current; // item "claimed"
  final _noteController = TextEditingController();

  // Lists
  bool _listLoading = false;
  String _listFilter = 'pending'; // pending | verified | rejected
  List<Map<String, dynamic>> _list = [];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
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
        _message = decision == 'verified' ? 'Aprovado ✅' : 'Reprovado ❌';
        _current = null;
        _noteController.clear();
      });

      // Atualiza lista automaticamente
      await _loadList();
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

    return await _client.storage.from(bucket).createSignedUrl(path, 60 * 30);
  }

  Future<void> _loadList() async {
    setState(() {
      _listLoading = true;
    });

    try {
      final res = await _client
          .from('coaches')
          .select('id, verification_status, cref_number, verification_documents, assigned_to, assigned_at, reviewed_at')
          .eq('verification_status', _listFilter)
          .limit(100);

      final rows = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _list = rows;
      });
    } catch (e) {
      setState(() {
        _message = 'Erro ao carregar lista: $e';
      });
    } finally {
      setState(() {
        _listLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin • Aprovação de Profissionais'),
          actions: [
            TextButton(
              onPressed: _logout,
              child: const Text('Sair'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fila (aprovar)'),
              Tab(text: 'Listas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: fila
            Center(
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

            // TAB 2: listas
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _listFilter,
                              decoration: const InputDecoration(
                                labelText: 'Filtro',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pendentes (pending)'),
                                ),
                                DropdownMenuItem(
                                  value: 'verified',
                                  child: Text('Aprovados (verified)'),
                                ),
                                DropdownMenuItem(
                                  value: 'rejected',
                                  child: Text('Reprovados (rejected)'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _listFilter = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _listLoading ? null : _loadList,
                            child: Text(_listLoading ? 'Carregando...' : 'Carregar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _list.isEmpty
                            ? const Center(
                                child: Text('Clique em "Carregar" para ver a lista.'),
                              )
                            : ListView.separated(
                                itemCount: _list.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final row = _list[i];
                                  final id = (row['id'] ?? '').toString();
                                  final status = (row['verification_status'] ?? '').toString();
                                  final cref = (row['cref_number'] ?? '').toString();
                                  final docs = row['verification_documents'];

                                  return ListTile(
                                    title: Text('CREF/CRN: $cref'),
                                    subtitle: Text('id: $id\nstatus: $status\nDocs: ${docs == null ? 0 : (docs is List ? docs.length : 1)}'),
                                    isThreeLine: true,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

                      // Abre em nova aba no web (melhor depois, mas aqui mostramos o link)
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
