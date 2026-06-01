import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'admin_approvals_screen.dart';
import 'athlete_approved_workouts_screen.dart';
import 'athlete_my_professionals_screen.dart';
import 'athlete_profile_form_screen.dart';
import 'athlete_search_professionals_screen.dart';
import 'athlete_target_races_screen.dart';
import 'athlete_weekly_availability_edit_screen.dart';
import 'auth_gate.dart';
import 'coach_create_workout_screen.dart';
import 'coach_requests_screen.dart';
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
        .select(
          'birth_date, gender, height_cm, weight_kg, resting_hr, max_hr, experience_level',
        )
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
    final restingHr = athlete['resting_hr'];
    final maxHr = athlete['max_hr'];

    final isComplete = birthDate.isNotEmpty &&
        gender.isNotEmpty &&
        experience.isNotEmpty &&
        height is num &&
        height > 0 &&
        weight is num &&
        weight > 0 &&
        restingHr is num &&
        restingHr > 0 &&
        maxHr is num &&
        maxHr > 0;

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
        ? ProfessionalHomeScreen(
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

class BaseHomeScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const BaseHomeScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => _logout(context),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
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
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AthleteHomeScreen extends StatelessWidget {
  final String fullName;

  const AthleteHomeScreen({super.key, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Home do Atleta'),
        actions: [
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate()),
                (route) => false,
              );
            },
            child: const Text('Sair'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HomeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $fullName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Conecte-se com profissionais, organize seus treinos e acompanhe sua evolução esportiva em um só lugar.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _HomeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Disponibilidade semanal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Atualize sua rotina semanal para facilitar a organização dos treinos e o acompanhamento pelos profissionais.',
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const AthleteWeeklyAvailabilityEditScreen(),
                      ),
                    );
                  },
                  child: const Text('Editar disponibilidade semanal'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 320,
                child: _HomeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Marketplace',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Busque treinadores, nutricionistas, fisioterapeutas, médicos e outros profissionais.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AthleteSearchProfessionalsScreen(),
                            ),
                          );
                        },
                        child: const Text('Buscar profissionais'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: _HomeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Treinos publicados',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Visualize os treinos aprovados e publicados para você.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AthleteApprovedWorkoutsScreen(),
                            ),
                          );
                        },
                        child: const Text('Ver treinos'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: _HomeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meus profissionais',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Veja todos os profissionais ativos que acompanham sua jornada.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AthleteMyProfessionalsScreen(),
                            ),
                          );
                        },
                        child: const Text('Ver profissionais'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: _HomeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provas alvo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cadastre, revise e atualize seu calendário de provas.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AthleteTargetRacesScreen(),
                            ),
                          );
                        },
                        child: const Text('Gerenciar provas'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfessionalHomeScreen extends StatelessWidget {
  final String fullName;

  const ProfessionalHomeScreen({super.key, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return BaseHomeScaffold(
      title: 'Home do Profissional',
      subtitle:
          'Bem-vindo, $fullName.\n\nSeu ambiente profissional está focado em vínculo com atletas, criação manual de treinos, revisão e publicação.',
      actions: [
        SizedBox(
          width: 260,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CoachRequestsScreen(),
                ),
              );
            },
            child: const Text('Solicitações e atletas'),
          ),
        ),
        SizedBox(
          width: 260,
          child: FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CoachCreateWorkoutScreen(),
                ),
              );
            },
            child: const Text('Criar treino manual'),
          ),
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  final Widget child;

  const _HomeCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: child,
    );
  }
}
