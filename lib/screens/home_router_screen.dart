import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'admin_approvals_screen.dart';
import 'athlete_approved_workouts_screen.dart';
import 'athlete_profile_form_screen.dart';
import 'athlete_search_professionals_screen.dart';
import 'auth_gate.dart';
import 'coach_requests_screen.dart';
import 'professional_profile_form_screen.dart';
import 'athlete_weekly_availability_edit_screen.dart';

class HomeRouterScreen extends StatefulWidget {
  const HomeRouterScreen({super.key});

  @override
  State<HomeRouterScreen> createState() => _HomeRouterScreenState();
}

class _HomeRouterScreenState extends State<HomeRouterScreen> {
  final _authService = AuthService();

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
      final fullName = (profile['full_name'] ?? '').toString();

      if (role == 'admin') {
        _resolved = const AdminApprovalsScreen();
      } else if (role == 'athlete') {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          throw Exception('Usuário não autenticado.');
        }

        final athlete = await Supabase.instance.client
            .from('athletes')
            .select(
              'birth_date,gender,height_cm,weight_kg,resting_hr,max_hr,experience_level',
            )
            .eq('id', user.id)
            .maybeSingle();

        if (athlete == null) {
          _resolved = const AthleteProfileFormScreen();
        } else {
          final bd = (athlete['birth_date'] ?? '').toString().trim();
          final g = (athlete['gender'] ?? '').toString().trim();
          final exp = (athlete['experience_level'] ?? '').toString().trim();

          final h = athlete['height_cm'];
          final w = athlete['weight_kg'];
          final rhr = athlete['resting_hr'];
          final mhr = athlete['max_hr'];

          final isComplete = bd.isNotEmpty &&
              g.isNotEmpty &&
              exp.isNotEmpty &&
              h != null &&
              w != null &&
              rhr != null &&
              mhr != null &&
              (h is num && h > 0) &&
              (w is num && w > 0) &&
              (rhr is num && rhr > 0) &&
              (mhr is num && mhr > 0);

          _resolved =
              isComplete ? AthleteHomeScreen(fullName: fullName) : const AthleteProfileFormScreen();
        }
      } else if (role == 'coach') {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          throw Exception('Usuário não autenticado.');
        }

        final coach = await Supabase.instance.client
            .from('coaches')
            .select(
              'professional_type,cref_number,license_number,phone_mobile,address_zip_code,specialties,verification_status',
            )
            .eq('id', user.id)
            .maybeSingle();

        if (coach == null) {
          _resolved = const ProfessionalProfileFormScreen();
        } else {
          final professionalType =
              (coach['professional_type'] ?? '').toString().trim();
          final cref = (coach['cref_number'] ?? '').toString().trim();
          final license = (coach['license_number'] ?? '').toString().trim();
          final phone = (coach['phone_mobile'] ?? '').toString().trim();
          final zip = (coach['address_zip_code'] ?? '').toString().trim();
          final specs = coach['specialties'];
          final specsCount = specs is List ? specs.length : 0;

          final hasRegistration = cref.isNotEmpty || license.isNotEmpty;

          final isComplete = professionalType.isNotEmpty &&
              hasRegistration &&
              phone.isNotEmpty &&
              zip.isNotEmpty &&
              specsCount > 0;

          _resolved =
              isComplete ? CoachHomeScreen(fullName: fullName) : const ProfessionalProfileFormScreen();
        }
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
  final String message;
  final List<Widget> actions;

  const BaseHomeScaffold({
    super.key,
    required this.title,
    required this.message,
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
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ),
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
    return BaseHomeScaffold(
      title: 'Home do Atleta',
      message: 'Bem-vindo, $fullName\n\nSeu perfil de atleta está ativo.',
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AthleteSearchProfessionalsScreen(),
              ),
            );
          },
          child: const Text('Buscar profissionais'),
        ),
        FilledButton.tonal(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AthleteApprovedWorkoutsScreen(),
              ),
            );
          },
          child: const Text('Treinos aprovados'),
        ),
      ],
    );
  }
}

class CoachHomeScreen extends StatelessWidget {
  final String fullName;

  const CoachHomeScreen({super.key, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return BaseHomeScaffold(
      title: 'Home do Profissional',
      message: 'Bem-vindo, $fullName\n\nSeu perfil profissional está ativo.',
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CoachRequestsScreen(),
              ),
            );
          },
          child: const Text('Solicitações de atletas'),
        ),
      ],
    );
  }
}
