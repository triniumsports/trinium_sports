import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteMyProfessionalsScreen extends StatefulWidget {
  const AthleteMyProfessionalsScreen({super.key});

  @override
  State<AthleteMyProfessionalsScreen> createState() =>
      _AthleteMyProfessionalsScreenState();
}

class _AthleteMyProfessionalsScreenState
    extends State<AthleteMyProfessionalsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
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
          .from('v_athlete_care_team')
          .select()
          .eq('athlete_id', user.id)
          .order('role_type', ascending: true)
          .order('professional_name', ascending: true);

      _rows = (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar profissionais: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _roleLabel(String raw) {
    switch (raw) {
      case 'running_coach':
        return 'Treinador de Corrida';
      case 'strength_coach':
        return 'Preparador Físico';
      case 'nutritionist':
        return 'Nutricionista';
      case 'physiotherapist':
        return 'Fisioterapeuta';
      case 'swim_coach':
        return 'Treinador de Natação';
      case 'triathlon_coach':
        return 'Treinador de Triathlon';
      case 'trail_coach':
        return 'Treinador de Trail';
      case 'doctor':
        return 'Médico';
      case 'coach':
        return 'Coach';
      default:
        return raw.isEmpty ? 'Profissional' : raw;
    }
  }

  String _groupKey(String raw) {
    switch (raw) {
      case 'running_coach':
      case 'swim_coach':
      case 'triathlon_coach':
      case 'trail_coach':
      case 'coach':
        return 'Treinadores';
      case 'strength_coach':
        return 'Força';
      case 'nutritionist':
        return 'Nutrição';
      case 'physiotherapist':
        return 'Fisioterapia';
      case 'doctor':
        return 'Médico';
      default:
        return 'Outros';
    }
  }

  List<_ProfessionalGroup> _groupedRows() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final row in _rows) {
      final key = _groupKey(_s(row['role_type']));
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(row);
    }

    const orderedKeys = [
      'Treinadores',
      'Força',
      'Nutrição',
      'Fisioterapia',
      'Médico',
      'Outros',
    ];

    return orderedKeys
        .where((k) => grouped.containsKey(k) && grouped[k]!.isNotEmpty)
        .map((k) => _ProfessionalGroup(title: k, rows: grouped[k]!))
        .toList();
  }

  Widget _buildProfessionalCard(Map<String, dynamic> row) {
    final name = _s(row['professional_name']).isEmpty
        ? 'Profissional'
        : _s(row['professional_name']);
    final email = _s(row['professional_email']);
    final phone = _s(row['phone_mobile']);
    final insta = _s(row['social_instagram']);
    final linkedin = _s(row['social_linkedin']);
    final roleType = _roleLabel(_s(row['role_type']));
    final verification = _s(row['verification_status']);
    final avatar = _s(row['professional_avatar']);

    final specialtiesRaw = row['specialties'];
    final specialties = specialtiesRaw is List
        ? specialtiesRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roleType,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (email.isNotEmpty) Text('E-mail: $email'),
                if (phone.isNotEmpty) Text('Telefone: $phone'),
                if (insta.isNotEmpty) Text('Instagram: $insta'),
                if (linkedin.isNotEmpty) Text('LinkedIn: $linkedin'),
                if (specialties.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: specialties
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFFE9EDF5),
                            ),
                            child: Text(s),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (verification.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: verification == 'approved'
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
              ),
              child: Text(
                verification,
                style: TextStyle(
                  color: verification == 'approved'
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroup(_ProfessionalGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...group.rows.map(_buildProfessionalCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedRows();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Meus profissionais'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _msg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: grouped.isEmpty
                ? const Center(
                    child: Text('Nenhum profissional ativo encontrado.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: grouped.map(_buildGroup).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalGroup {
  final String title;
  final List<Map<String, dynamic>> rows;

  _ProfessionalGroup({
    required this.title,
    required this.rows,
  });
}
