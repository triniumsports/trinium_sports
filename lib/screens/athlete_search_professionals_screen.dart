import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteSearchProfessionalsScreen extends StatefulWidget {
  const AthleteSearchProfessionalsScreen({super.key});

  @override
  State<AthleteSearchProfessionalsScreen> createState() => _AthleteSearchProfessionalsScreenState();
}

class _AthleteSearchProfessionalsScreenState extends State<AthleteSearchProfessionalsScreen> {
  final _client = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _zipController = TextEditingController();
  String? _specialty; // run/swim/bike/strength/trail/triathlon

  bool _loading = false;
  String? _msg;
  List<Map<String, dynamic>> _results = [];

  static const Map<String, String> specialtyLabels = {
    'run': 'Corrida',
    'swim': 'Natação',
    'bike': 'Ciclismo',
    'strength': 'Força / Musculação',
    'trail': 'Trail',
    'triathlon': 'Triatlo',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _msg = null;
      _results = [];
    });

    try {
      final res = await _client.rpc('search_professionals', params: {
        'p_name': _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        'p_specialty': _specialty,
        'p_zip': _zipController.text.trim().isEmpty ? null : _zipController.text.trim(),
        'p_limit': 50,
        'p_offset': 0,
      });

      final rows = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      setState(() {
        _results = rows;
        if (rows.isEmpty) _msg = 'Nenhum profissional encontrado.';
      });
    } catch (e) {
      setState(() {
        _msg = 'Erro na busca: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar Profissionais')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String?>(
                  value: _specialty,
                  decoration: const InputDecoration(
                    labelText: 'Especialidade (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Qualquer')),
                    ...specialtyLabels.entries.map(
                      (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _specialty = v),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'CEP (opcional — prefixo)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: Text(_loading ? 'Buscando...' : 'Buscar'),
                ),

                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  Text(_msg!, textAlign: TextAlign.center),
                ],

                const SizedBox(height: 12),
                Expanded(
                  child: _results.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _results[i];
                            final name = (r['full_name'] ?? '').toString();
                            final type = (r['professional_type'] ?? '').toString();
                            final reg = (r['registration_number'] ?? '').toString();
                            final zip = (r['zip_code'] ?? '').toString();
                            final specs = (r['specialties'] ?? []) as List<dynamic>;
                            final specsLabel = specs.map((s) => specialtyLabels[s] ?? s.toString()).join(', ');

                            return ListTile(
                              title: Text(name),
                              subtitle: Text(
                                'Tipo: $type | Registro: $reg\nEspecialidades: $specsLabel\nCEP: $zip',
                              ),
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
    );
  }
}
