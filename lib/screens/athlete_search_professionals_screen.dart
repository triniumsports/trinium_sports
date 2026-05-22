import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteSearchProfessionalsScreen extends StatefulWidget {
  const AthleteSearchProfessionalsScreen({super.key});

  @override
  State<AthleteSearchProfessionalsScreen> createState() =>
      _AthleteSearchProfessionalsScreenState();
}

class _AthleteSearchProfessionalsScreenState
    extends State<AthleteSearchProfessionalsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'all';

  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final res = await _client
          .from('v_professionals_marketplace')
          .select()
          .order('display_name', ascending: true);

      _rows = (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar profissionais: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();

    bool containsText(String text) => text.toLowerCase().contains(q);

    return _rows.where((r) {
      final name =
          (r['display_name'] ?? r['full_name'] ?? '').toString().trim();
      final email = (r['email'] ?? '').toString().trim();
      final type = (r['professional_type'] ?? '').toString().trim();
      final phone = (r['phone_mobile'] ?? '').toString().trim();
      final city = (r['address_city'] ?? '').toString().trim();
      final state = (r['address_state'] ?? '').toString().trim();
      final social = _socialRaw(r);
      final specialties = _specialtiesList(r['specialties']).join(' ');

      final typeOk =
          _typeFilter == 'all' ? true : type.toLowerCase() == _typeFilter;

      final searchOk = q.isEmpty
          ? true
          : containsText(name) ||
              containsText(email) ||
              containsText(type) ||
              containsText(phone) ||
              containsText(city) ||
              containsText(state) ||
              containsText(social) ||
              containsText(specialties);

      return typeOk && searchOk;
    }).toList();
  }

  Future<void> _selectProfessional({
    required String professionalId,
    required String professionalName,
    required String professionalType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final existing = await _client
          .from('coach_athlete_relation')
          .select('id, status, role_type')
          .eq('coach_id', professionalId)
          .eq('athlete_id', user.id)
          .maybeSingle();

      if (existing != null) {
        final status = (existing['status'] ?? '').toString();
        if (!mounted) return;

        final msg = status == 'active'
            ? 'Você já está vinculado a $professionalName ✅'
            : 'Você já possui uma solicitação com $professionalName (status: $status).';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }

      await _client.from('coach_athlete_relation').insert({
        'coach_id': professionalId,
        'athlete_id': user.id,
        'status': 'pending',
        'role_type': professionalType,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solicitação enviada para $professionalName ✅ Aguarde a aceitação do profissional.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível enviar a solicitação. Detalhe: $e'),
        ),
      );
    }
  }

  Future<void> _copyContact({
    required String email,
    required String phone,
    String? social,
  }) async {
    final parts = <String>[];
    if (email.trim().isNotEmpty) parts.add('Email: $email');
    if (phone.trim().isNotEmpty) parts.add('Telefone: $phone');
    if ((social ?? '').trim().isNotEmpty) parts.add('Rede social: $social');

    final text = parts.join(' | ');

    await Clipboard.setData(
      ClipboardData(
        text: text.isEmpty ? 'Sem contato disponível' : text,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(text.isEmpty ? 'Sem contato disponível' : 'Contato copiado ✅'),
      ),
    );
  }

  List<String> _specialtiesList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return [];

    return text
        .replaceAll('{', '')
        .replaceAll('}', '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _typeLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'coach':
        return 'Coach esportivo';
      case 'running_coach':
        return 'Treinador de corrida';
      case 'nutritionist':
        return 'Nutricionista';
      case 'strength_coach':
        return 'Preparador físico';
      case 'physiotherapist':
        return 'Fisioterapeuta';
      case 'swim_coach':
        return 'Treinador de natação';
      case 'triathlon_coach':
        return 'Treinador de triathlon';
      case 'trail_coach':
        return 'Treinador de trail';
      default:
        return value.isEmpty ? 'Profissional' : value;
    }
  }

  String _socialRaw(Map<String, dynamic> r) {
    final ig = (r['social_instagram'] ?? '').toString().trim();
    final li = (r['social_linkedin'] ?? '').toString().trim();

    if (ig.isNotEmpty) return ig;
    if (li.isNotEmpty) return li;
    return '';
  }

  String _socialLabel(Map<String, dynamic> r) {
    final ig = (r['social_instagram'] ?? '').toString().trim();
    final li = (r['social_linkedin'] ?? '').toString().trim();

    if (ig.isNotEmpty) {
      return ig.startsWith('@') ? ig : '@$ig';
    }
    if (li.isNotEmpty) return li;
    return 'Não informado';
  }

  String _cityState(Map<String, dynamic> r) {
    final city = (r['address_city'] ?? '').toString().trim();
    final state = (r['address_state'] ?? '').toString().trim();

    if (city.isEmpty && state.isEmpty) return 'Local não informado';
    if (city.isNotEmpty && state.isNotEmpty) return '$city - $state';
    return city.isNotEmpty ? city : state;
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _applyFilters();
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    if (width >= 1200) {
      crossAxisCount = 3;
    } else if (width >= 760) {
      crossAxisCount = 2;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar profissionais'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    offset: Offset(0, 8),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Marketplace de Profissionais',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Encontre treinadores, nutricionistas, fisioterapeutas e outros profissionais.\nO contato e a contratação acontecem fora do app. Depois, selecione o profissional aqui para formalizar o vínculo esportivo no Trinium.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText:
                                'Buscar por nome, especialidade, e-mail, telefone ou cidade',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          initialValue: _typeFilter,
                          decoration: InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'coach',
                              child: Text('Coach esportivo'),
                            ),
                            DropdownMenuItem(
                              value: 'running_coach',
                              child: Text('Treinador de corrida'),
                            ),
                            DropdownMenuItem(
                              value: 'nutritionist',
                              child: Text('Nutricionista'),
                            ),
                            DropdownMenuItem(
                              value: 'strength_coach',
                              child: Text('Preparador físico'),
                            ),
                            DropdownMenuItem(
                              value: 'physiotherapist',
                              child: Text('Fisioterapeuta'),
                            ),
                            DropdownMenuItem(
                              value: 'swim_coach',
                              child: Text('Treinador de natação'),
                            ),
                            DropdownMenuItem(
                              value: 'triathlon_coach',
                              child: Text('Treinador de triathlon'),
                            ),
                            DropdownMenuItem(
                              value: 'trail_coach',
                              child: Text('Treinador de trail'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _typeFilter = value ?? 'all');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_loading) const LinearProgressIndicator(),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _msg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${list.length} profissional(is) encontrado(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!_loading && list.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 16,
                      offset: Offset(0, 8),
                      color: Color(0x12000000),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Nenhum profissional encontrado.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              GridView.builder(
                itemCount: list.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 380,
                ),
                itemBuilder: (context, index) {
                  final r = list[index];

                  final name = (r['display_name'] ?? r['full_name'] ?? 'Profissional')
                      .toString();
                  final email = (r['email'] ?? '').toString();
                  final avatar = (r['avatar_url'] ?? '').toString();
                  final phone = (r['phone_mobile'] ?? '').toString();
                  final type = (r['professional_type'] ?? '').toString().trim();
                  final verificationStatus =
                      (r['verification_status'] ?? '').toString().trim();
                  final specialties = _specialtiesList(r['specialties']);

                  return _ProfessionalCard(
                    name: name,
                    email: email,
                    phone: phone,
                    avatarUrl: avatar,
                    typeLabel: _typeLabel(type),
                    locationLabel: _cityState(r),
                    socialLabel: _socialLabel(r),
                    specialties: specialties,
                    statusLabel:
                        verificationStatus.isEmpty ? 'Sem status' : verificationStatus,
                    statusColor: _statusColor(verificationStatus),
                    onCopyContact: () => _copyContact(
                      email: email,
                      phone: phone,
                      social: _socialRaw(r),
                    ),
                    onSelect: () => _selectProfessional(
                      professionalId: r['id'].toString(),
                      professionalName: name,
                      professionalType: type.isEmpty ? 'coach' : type,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final String typeLabel;
  final String locationLabel;
  final String socialLabel;
  final List<String> specialties;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onCopyContact;
  final VoidCallback onSelect;

  const _ProfessionalCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.typeLabel,
    required this.locationLabel,
    required this.socialLabel,
    required this.specialties,
    required this.statusLabel,
    required this.statusColor,
    required this.onCopyContact,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (specialties.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: specialties
                    .take(5)
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F1FF),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            else
              const Text(
                'Especialidades não informadas',
                style: TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: locationLabel,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.email_outlined,
              text: email.isEmpty ? 'E-mail não informado' : email,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone_outlined,
              text: phone.isEmpty ? 'Telefone não informado' : phone,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.public,
              text: socialLabel,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopyContact,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Contato'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Selecionar'),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}
