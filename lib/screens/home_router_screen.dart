import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'auth_gate.dart';

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

      final role = (profile['user_role'] ?? '').toString();
      final fullName = (profile['full_name'] ?? '').toString();

      if (role == 'athlete') {
        _resolved = AthleteHomeScreen(fullName: fullName);
      } else if (role == 'coach') {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('Usuário não autenticado.');

        final coach = await Supabase.instance.client
            .from('coaches')
            .select('verification_status')
            .eq('id', user.id)
            .maybeSingle();

        final status = (coach?['verification_status'] ?? 'pending').toString();

        // No seu schema, aprovado = verified
        if (status == 'verified') {
          _resolved = CoachHomeScreen(fullName: fullName);
        } else if (status == 'rejected') {
          _resolved = CoachRejectedScreen(fullName: fullName);
        } else {
          _resolved = CoachPendingScreen(fullName: fullName, status: status);
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

  const BaseHomeScaffold({super.key, required this.title, required this.message});

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
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
    );
  }
}

class CoachHomeScreen extends StatelessWidget {
  final String fullName;

  const CoachHomeScreen({super.key, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return BaseHomeScaffold(
      title: 'Home do Coach',
      message: 'Bem-vindo, $fullName\n\nSeu perfil está VERIFICADO (verified).',
    );
  }
}

class CoachPendingScreen extends StatelessWidget {
  final String fullName;
  final String status;

  const CoachPendingScreen({super.key, required this.fullName, required this.status});

  @override
  Widget build(BuildContext context) {
    return BaseHomeScaffold(
      title: 'Aguardando Aprovação',
      message: 'Olá, $fullName\n\nStatus do cadastro: $status\n\nAguarde validação.',
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
