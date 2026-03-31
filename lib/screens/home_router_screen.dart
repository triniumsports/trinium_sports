import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/verification_service.dart';
import 'auth_gate.dart';
import 'admin_approvals_screen.dart';
import 'professional_profile_form_screen.dart';
import 'athlete_search_professionals_screen.dart';
import 'coach_requests_screen.dart';
import 'athlete_onboarding_screen.dart';
import 'athlete_profile_form_screen.dart';

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
      if (profile == null) throw Exception('Perfil não encontrado.');

      final role = (profile['user_role'] ?? '').toString().trim().toLowerCase();
      final fullName = (profile['full_name'] ?? '').toString();

      if (role.isEmpty) {
        throw Exception('user_role inválido: (vazio)');
      }

      if (role == 'admin') {
        _resolved = const AdminApprovalsScreen();
      } else if (role == 'athlete') {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('Usuário não autenticado.');

        final athlete = await Supabase.instance.client
            .from('athletes')
            .select('birth_date,gender,height_cm,weight_kg,resting_hr,max_hr,experience_level')
            .eq('id', user.id)
            .maybeSingle();

        // Se não existe linha ainda, força onboarding
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

          final isOk =
              bd.isNotEmpty &&
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

          if (!isOk) {
            _resolved = const AthleteProfileFormScreen();
          } else {
            _resolved = AthleteHomeScreen(fullName: fullName);
          }
        }
      } else if (role == 'coach') {  } else if (role == 'coach') {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('Usuário não autenticado.');

        final coach = await Supabase.instance.client
            .from('coaches')
            .select(
                'verification_status, professional_type, cref_number, phone_mobile, address_zip_code, specialties')
            .eq('id', user.id)
            .maybeSingle();

        final status = (coach?['verification_status'] ?? 'pending').toString();
        final profType = (coach?['professional_type'] ?? '').toString().trim();
        final reg = (coach?['cref_number'] ?? '').toString().trim();
        final phone = (coach?['phone_mobile'] ?? '').toString().trim();
        final zip = (coach?['address_zip_code'] ?? '').toString().trim();
        final specs = coach?['specialties'];
        final specsCount = (specs is List) ? specs.length : 0;

        final isComplete = profType.isNotEmpty &&
            reg.isNotEmpty &&
            phone.isNotEmpty &&
            zip.isNotEmpty &&
            specsCount > 0;

        if (!isComplete) {
          _resolved = const ProfessionalProfileFormScreen();
        } else {
          // Novo modelo: sem trava de aprovação (docs são para auditoria).
          _resolved = CoachHomeScreen(fullName: fullName);
        }
      } else {
        throw Exception('user_role inválido: $role');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  final Widget? extra;

  const BaseHomeScaffold({
    super.key,
    required this.title,
    required this.message,
    this.extra,
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
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
Text(message, textAlign: TextAlign.center),
              if (extra != null) ...[
                const SizedBox(height: 16),
                extra!,
              ],
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
    return BaseHomeScaffold(
      title: 'Home do Atleta',
      message: 'Bem-vindo, $fullName\n\nSeu perfil de atleta está ativo.',
      extra: FilledButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AthleteSearchProfessionalsScreen()),
          );
        },
        child: const Text('Buscar profissionais'),
      ),
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
      message: 'Bem-vindo, $fullName\n\nStatus: VERIFIED ✅',
    );
  }
}

class CoachPendingScreen extends StatefulWidget {
  final String fullName;
  final String status;

  const CoachPendingScreen({super.key, required this.fullName, required this.status});

  @override
  State<CoachPendingScreen> createState() => _CoachPendingScreenState();
}

class _CoachPendingScreenState extends State<CoachPendingScreen> {
  bool _uploading = false;
  String? _msg;

  Future<void> _upload(String type, String label) async {
    setState(() {
      _uploading = true;
      _msg = null;
    });

    try {
      await VerificationService().pickAndUpload(docType: type);
      setState(() => _msg = '$label enviado ✅');
    } catch (e) {
      setState(() => _msg = 'Erro ($label): $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseHomeScaffold(
      title: 'Aguardando Aprovação',
      message:
          'Olá, ${widget.fullName}\n\nStatus do cadastro: ${widget.status}\n\n'
          'Envie os 3 itens para auditoria/validação:\n'
          '1) RG/CNH\n2) Documento do Conselho\n3) Print da consulta pública',
      extra: Column(
        children: [
          FilledButton(
            onPressed: _uploading ? null : () => _upload('identity', 'RG/CNH'),
            child: Text(_uploading ? 'Enviando...' : 'Enviar RG/CNH (foto ou PDF)'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _uploading ? null : () => _upload('council', 'Conselho'),
            child: Text(_uploading ? 'Enviando...' : 'Enviar documento do Conselho (CREF/CRN)'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _uploading ? null : () => _upload('lookup_print', 'Print consulta pública'),
            child: Text(_uploading
                ? 'Enviando...'
                : 'Enviar print da consulta pública (ATIVO/BACHAREL)'),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 12),
            Text(_msg!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class CoachRejectedScreen extends StatelessWidget {
  final String fullName;

  const CoachRejectedScreen({super.key, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return BaseHomeScaffold(
      title: 'Cadastro Rejeitado',
      message: 'Olá, $fullName\n\nSeu cadastro foi rejeitado.\nEntre em contato com o suporte.',
    );
  }
}
