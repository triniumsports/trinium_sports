import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'admin_approvals_screen.dart';
import 'athlete_approved_workouts_screen.dart';
import 'athlete_injuries_restrictions_screen.dart';
import 'athlete_medical_documents_screen.dart';
import 'athlete_my_professionals_screen.dart';
import 'athlete_profile_form_screen.dart';
import 'athlete_search_professionals_screen.dart';
import 'athlete_target_races_screen.dart';
import 'athlete_weekly_availability_edit_screen.dart';
import 'auth_gate.dart';
import 'professional_home_dashboard_screen.dart';
import 'professional_profile_form_screen.dart';

class HomeRouterScreen extends StatefulWidget {
  const HomeRouterScreen({super.key});

  @override
  State<HomeRouterScreen> createState() => _HomeRouterScreenState();
}

class _HomeRouterScreenState extends State<HomeRouterScreen> {
  final AuthService _authService = AuthService();
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  Widget? _resolved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _authService.getMyProfile();
      if (profile == null) {
        throw Exception('Perfil não encontrado.');
      }

      final role = (profile['user_role'] ?? '').toString().trim().toLowerCase();
      final fullName = (profile['full_name'] ?? '').toString().trim();

      if (role == 'admin') {
        _resolved = const AdminApprovalsScreen();
      } else if (role == 'athlete') {
        await _resolveAthlete(fullName);
      } else if (role == 'coach') {
        await _resolveProfessional(fullName);
      } else {
        throw Exception('user_role inválido: $role');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resolveAthlete(String fullName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final athlete = await _client
        .from('athletes')
        .select('birth_date, gender, height_cm, weight_kg, experience_level')
        .eq('id', user.id)
        .maybeSingle();

    if (athlete == null) {
      _resolved = const AthleteProfileFormScreen();
      return;
    }

    final birthDate = (athlete['birth_date'] ?? '').toString().trim();
    final gender = (athlete['gender'] ?? '').toString().trim();
    final experience = (athlete['experience_level'] ?? '').toString().trim();

    final height = athlete['height_cm'];
    final weight = athlete['weight_kg'];

    final isComplete = birthDate.isNotEmpty &&
        gender.isNotEmpty &&
        experience.isNotEmpty &&
        height is num &&
        height > 0 &&
        weight is num &&
        weight > 0;

    _resolved = isComplete
        ? AthleteHomeScreen(fullName: fullName.isEmpty ? 'Atleta' : fullName)
        : const AthleteProfileFormScreen();
  }

  Future<void> _resolveProfessional(String fullName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final coach = await _client
        .from('coaches')
        .select(
          'professional_type, cref_number, license_number, phone_mobile, address_zip_code, specialties, verification_status, display_name',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (coach == null) {
      _resolved = const ProfessionalProfileFormScreen();
      return;
    }

    final professionalType =
        (coach['professional_type'] ?? '').toString().trim();
    final cref = (coach['cref_number'] ?? '').toString().trim();
    final license = (coach['license_number'] ?? '').toString().trim();
    final phone = (coach['phone_mobile'] ?? '').toString().trim();
    final zip = (coach['address_zip_code'] ?? '').toString().trim();
    final verificationStatus =
        (coach['verification_status'] ?? '').toString().trim();

    final specialtiesRaw = coach['specialties'];
    final specialtiesCount = specialtiesRaw is List
        ? specialtiesRaw.where((e) => '$e'.trim().isNotEmpty).length
        : 0;

    final hasRegistration = cref.isNotEmpty || license.isNotEmpty;

    final isComplete = professionalType.isNotEmpty &&
        hasRegistration &&
        phone.isNotEmpty &&
        zip.isNotEmpty &&
        specialtiesCount > 0 &&
        verificationStatus.isNotEmpty;

    final displayName = (coach['display_name'] ?? '').toString().trim();

    _resolved = isComplete
        ? ProfessionalHomeDashboardScreen(
            fullName: displayName.isNotEmpty
                ? displayName
                : (fullName.isEmpty ? 'Profissional' : fullName),
          )
        : const ProfessionalProfileFormScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trinium Sports')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText('ERRO PÓS-LOGIN:\n\n$_error'),
        ),
      );
    }

    return _resolved!;
  }
}

class AthleteHomeScreen extends StatefulWidget {
  final String fullName;

  const AthleteHomeScreen({super.key, required this.fullName});

  @override
  State<AthleteHomeScreen> createState() => _AthleteHomeScreenState();
}

class _AthleteHomeScreenState extends State<AthleteHomeScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _athlete;
  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _careTeam = [];
  List<Map<String, dynamic>> _targetRaces = [];
  List<Map<String, dynamic>> _weeklyConstraints = [];
  List<Map<String, dynamic>> _injuries = [];
  List<Map<String, dynamic>> _documents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();
  num _n(dynamic v) => v is num ? v : 0;

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
      final results = await Future.wait([
        _client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .eq('id', user.id)
            .maybeSingle(),
        _client
            .from('athletes')
            .select('*')
            .eq('id', user.id)
            .maybeSingle(),
        _client
            .from('v_prescribed_workouts_mvp')
            .select()
            .eq('athlete_id', user.id)
            .order('scheduled_date', ascending: true),
        _client
            .from('v_athlete_care_team')
            .select()
            .eq('athlete_id', user.id)
            .order('role_type', ascending: true)
            .order('professional_name', ascending: true),
        _client
            .from('target_races')
            .select()
            .eq('athlete_id', user.id)
            .order('race_date', ascending: true),
        _client
            .from('weekly_constraints')
            .select()
            .eq('athlete_id', user.id)
            .order('day_of_week', ascending: true)
            .order('slot_order', ascending: true),
        _client
            .from('athlete_injuries_restrictions')
            .select()
            .eq('athlete_id', user.id)
            .order('created_at', ascending: false),
        _client
            .from('athlete_medical_documents')
            .select()
            .eq('athlete_id', user.id)
            .order('created_at', ascending: false),
      ]);

      _profile = results[0] == null ? null : Map<String, dynamic>.from(results[0] as Map);
      _athlete = results[1] == null ? null : Map<String, dynamic>.from(results[1] as Map);
      _workouts = (results[2] as List).cast<Map<String, dynamic>>();
      _careTeam = (results[3] as List).cast<Map<String, dynamic>>();
      _targetRaces = (results[4] as List).cast<Map<String, dynamic>>();
      _weeklyConstraints = (results[5] as List).cast<Map<String, dynamic>>();
      _injuries = (results[6] as List).cast<Map<String, dynamic>>();
      _documents = (results[7] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar home do atleta: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _activityLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('trail')) return 'Trail';
    if (v.contains('run') || v.contains('corr')) return 'Corrida';
    if (v.contains('swim') || v.contains('nata')) return 'Natação';
    if (v.contains('bike') || v.contains('cicl')) return 'Ciclismo';
    if (v.contains('strength') || v.contains('forca')) return 'Força';
    if (v.contains('triathlon')) return 'Triathlon';
    if (v.contains('swimrun')) return 'Swimrun';
    return raw.isEmpty ? 'Geral' : raw;
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

  String _weekdayLabel(dynamic raw) {
    final n = _n(raw).toInt();
    switch (n) {
      case 1:
        return 'Segunda';
      case 2:
        return 'Terça';
      case 3:
        return 'Quarta';
      case 4:
        return 'Quinta';
      case 5:
        return 'Sexta';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return _s(raw);
    }
  }

  String _dateText(dynamic v) {
    final s = _s(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _feedbackLabel(String raw) {
    switch (raw) {
      case 'weak':
        return 'Fraco';
      case 'normal':
        return 'Normal';
      case 'strong':
        return 'Forte';
      case 'very_strong':
        return 'Muito Forte';
      default:
        return raw;
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

  Map<String, dynamic> _workoutSummary() {
    int published = 0;
    int completed = 0;
    num totalDurationSec = 0;
    final Map<String, int> byActivity = {};

    for (final w in _workouts) {
      final status = _s(w['status']);
      final validationStatus = _s(w['validation_status']);
      final activity = _activityLabel(_s(w['activity_type_id']));
      final duration = _n(w['planned_duration_sec']);

      if (status == 'published' || validationStatus == 'published') {
        published++;
      }
      if (status == 'completed') {
        completed++;
      }

      totalDurationSec += duration;
      byActivity[activity] = (byActivity[activity] ?? 0) + 1;
    }

    return {
      'published': published,
      'completed': completed,
      'total': _workouts.length,
      'duration_sec': totalDurationSec,
      'by_activity': byActivity,
    };
  }

  Widget _section({
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (actions != null) ...actions,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF7F7F9),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFE9EDF5),
      ),
      child: Text(text),
    );
  }

  Widget _buildHeader() {
    final fullName = _s(_profile?['full_name']).isEmpty
        ? widget.fullName
        : _s(_profile?['full_name']);
    final email = _s(_profile?['email']);
    final avatar = _s(_profile?['avatar_url']);

    return _section(
      title: 'Olá, $fullName',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AthleteProfileFormScreen()),
            );
            await _load();
          },
          child: const Text('Editar perfil'),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person, size: 30) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conecte-se com profissionais, acompanhe sua evolução e edite seu contexto esportivo em um só lugar.',
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(email),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSection() {
    final s = _workoutSummary();
    final byActivity = (s['by_activity'] as Map<String, int>);

    return _section(
      title: 'Treinos',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AthleteApprovedWorkoutsScreen()),
            );
            await _load();
          },
          child: const Text('Abrir'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard('Publicados', '${s['published']}', Icons.publish),
              _metricCard('Executados', '${s['completed']}', Icons.check_circle),
              _metricCard('Total', '${s['total']}', Icons.fitness_center),
              _metricCard(
                'Carga total',
                '${(_n(s['duration_sec']) / 3600).toStringAsFixed(1)}h',
                Icons.timer,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (byActivity.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byActivity.entries
                  .map((e) => _tinyChip('${e.key}: ${e.value}'))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProfessionalsSection() {
    return _section(
      title: 'Meus profissionais',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AthleteMyProfessionalsScreen()),
            );
            await _load();
          },
          child: const Text('Abrir'),
        ),
      ],
      child: _careTeam.isEmpty
          ? const Text('Nenhum profissional ativo encontrado.')
          : Column(
              children: _careTeam.take(6).map((row) {
                final name = _s(row['professional_name']).isEmpty
                    ? 'Profissional'
                    : _s(row['professional_name']);
                final role = _roleLabel(_s(row['role_type']));
                final email = _s(row['professional_email']);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(role),
                      if (email.isNotEmpty) Text(email),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRacesSection() {
    return _section(
      title: 'Provas alvo',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AthleteTargetRacesScreen()),
            );
            await _load();
          },
          child: const Text('Editar'),
        ),
      ],
      child: _targetRaces.isEmpty
          ? const Text('Nenhuma prova alvo cadastrada.')
          : Column(
              children: _targetRaces.take(5).map((race) {
                final name = _s(race['name']).isEmpty ? 'Prova' : _s(race['name']);
                final date = _dateText(race['race_date']);
                final activity = _activityLabel(_s(race['activity_type_id']));
                final distance = _s(race['distance_meters']);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Data: $date'),
                      Text('Modalidade: $activity'),
                      if (distance.isNotEmpty) Text('Distância: ${distance}m'),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAvailabilitySection() {
    return _section(
      title: 'Disponibilidade semanal',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AthleteWeeklyAvailabilityEditScreen(),
              ),
            );
            await _load();
          },
          child: const Text('Editar'),
        ),
      ],
      child: _weeklyConstraints.isEmpty
          ? const Text('Nenhuma disponibilidade semanal cadastrada.')
          : Column(
              children: _weeklyConstraints.take(8).map((row) {
                final day = _weekdayLabel(row['day_of_week']);
                final slotOrder = _n(row['slot_order']).toInt();
                final activity = _activityLabel(_s(row['activity_type_id']));
                final timeSlot = _s(row['time_slot']);
                final durationSec = _n(row['max_duration_sec']);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$day • ${slotOrder == 1 ? 'Opção principal' : 'Opção secundária'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('Modalidade: $activity'),
                      if (timeSlot.isNotEmpty) Text('Período: $timeSlot'),
                      if (durationSec > 0)
                        Text('Tempo: ${(durationSec / 60).toStringAsFixed(0)} min'),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildDietSection() {
    final details = _athlete?['dietary_restrictions_details'];
    final allergies = details is Map ? _s(details['allergies']) : '';
    final intolerances = details is Map ? _s(details['intolerances']) : '';
    final preferences = details is Map ? _s(details['preferences']) : '';
    final medical = details is Map ? _s(details['medical']) : '';
    final supplements = details is Map ? _s(details['supplements']) : '';
    final notes = details is Map ? _s(details['notes']) : '';

    return _section(
      title: 'Restrições alimentares',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AthleteProfileFormScreen()),
            );
            await _load();
          },
          child: const Text('Editar'),
        ),
      ],
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metricCard('Alergias', allergies.isEmpty ? '-' : allergies, Icons.warning_amber),
          _metricCard('Intolerâncias', intolerances.isEmpty ? '-' : intolerances, Icons.no_food),
          _metricCard('Preferências', preferences.isEmpty ? '-' : preferences, Icons.restaurant),
          _metricCard('Restrição médica', medical.isEmpty ? '-' : medical, Icons.medical_information),
          _metricCard('Suplementos', supplements.isEmpty ? '-' : supplements, Icons.medication),
          if (notes.isNotEmpty)
            Container(
              width: 460,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFF7F7F9),
              ),
              child: Text('Observações: $notes'),
            ),
        ],
      ),
    );
  }

  Widget _buildInjuriesSection() {
    return _section(
      title: 'Restrições / lesões',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AthleteInjuriesRestrictionsScreen(),
              ),
            );
            await _load();
          },
          child: const Text('Editar'),
        ),
      ],
      child: _injuries.isEmpty
          ? const Text('Nenhuma restrição ou lesão cadastrada.')
          : Column(
              children: _injuries.take(5).map((row) {
                final title = _s(row['title']).isEmpty ? 'Registro' : _s(row['title']);
                final type = _s(row['restriction_type']);
                final region = _s(row['body_region']);
                final status = _s(row['status']);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (type.isNotEmpty) Text('Tipo: $type'),
                      if (region.isNotEmpty) Text('Região: $region'),
                      if (status.isNotEmpty) Text('Status: $status'),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildDocumentsSection() {
    return _section(
      title: 'Exames e documentos',
      actions: [
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AthleteMedicalDocumentsScreen(),
              ),
            );
            await _load();
          },
          child: const Text('Gerenciar'),
        ),
      ],
      child: _documents.isEmpty
          ? const Text('Nenhum documento cadastrado.')
          : Column(
              children: _documents.take(5).map((doc) {
                final title = _s(doc['title']).isEmpty ? 'Documento' : _s(doc['title']);
                final type = _docTypeLabel(_s(doc['document_type']));
                final date = _s(doc['exam_date']);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(type),
                      if (date.isNotEmpty) Text('Data: $date'),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;

    final sections = <Widget>[
      _buildHeader(),
      _buildWorkoutSection(),
      _buildProfessionalsSection(),
      _buildRacesSection(),
      _buildAvailabilitySection(),
      _buildDietSection(),
      _buildInjuriesSection(),
      _buildDocumentsSection(),
    ];

    Widget content;
    if (isDesktop) {
      content = Column(
        children: [
          sections[0],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [sections[1], sections[3], sections[5], sections[7]])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [sections[2], sections[4], sections[6]])),
            ],
          ),
        ],
      );
    } else {
      content = Column(children: sections);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Home do Atleta'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          TextButton(onPressed: _logout, child: const Text('Sair')),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_msg!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    content,
                    const SizedBox(height: 8),
                    _section(
                      title: 'Próxima evolução do dashboard',
                      child: const Text(
                        'Próximo passo: consolidar planejado vs executado, carga por modalidade, carga por grupo muscular e mapa corporal interativo.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AthleteSearchProfessionalsScreen(),
            ),
          );
        },
        label: const Text('Marketplace'),
        icon: const Icon(Icons.search),
      ),
    );
  }
}
