import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/verification_service.dart';
import 'auth_gate.dart';
import 'admin_approvals_screen.dart';

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

      if (role == 'admin') {
        _resolved = const AdminApprovalsScreen();
      } else if (role == 'athlete') {
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

        // No seu schema: aprovado = verified
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
          ),
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

  const CoachPendingScreen({
    super.key,
    required this.fullName,
    required this.status,
  });

  @override
  State<CoachPendingScreen> createState() => _CoachPendingScreenState();
}

class _CoachPendingScreenState extends State<CoachPendingScreen> {
  bool _uploading = false;
  String? _uploadMsg;

  Future<void> _uploadDoc() async {
    setState(() {
      _uploading = true;
      _uploadMsg = null;
    });

    try {
      await VerificationService().pickAndUpload(docType: 'council');
      setState(() {
        _uploadMsg = 'Documento enviado com sucesso ✅\nAguarde validação.';
      });
    } catch (e) {
      setState(() {
        _uploadMsg = 'Erro ao enviar documento: $e';
      });
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseHomeScaffold(
      title: 'Aguardando Aprovação',
      message:
          'Olá, ${widget.fullName}\n\nStatus do cadastro: ${widget.status}\n\n'
          'Envie uma foto do seu CREF/CRN para validação.',
      extra: Column(
        children: [
          FilledButton(
            onPressed: _uploading ? null : () async {
              setState(() { _uploading = true; _uploadMsg = null; });
              try {
                await VerificationService().pickAndUpload(docType: 'identity');
                setState(() { _uploadMsg = 'RG/CNH enviado ✅'; });
              } catch (e) {
                setState(() { _uploadMsg = 'Erro RG/CNH: $e'; });
              } finally {
                setState(() { _uploading = false; });
              }
            },
            child: Text(_uploading ? 'Enviando...' : 'Enviar RG/CNH (foto ou PDF)'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _uploading ? null : () async {
              setState(() { _uploading = true; _uploadMsg = null; });
              try {
                await VerificationService().pickAndUpload(docType: 'council');
                setState(() { _uploadMsg = 'Documento do Conselho enviado ✅'; });
              } catch (e) {
                setState(() { _uploadMsg = 'Erro Conselho: $e'; });
              } finally {
                setState(() { _uploading = false; });
              }
            },
            child: Text(_uploading ? 'Enviando...' : 'Enviar documento do Conselho (CREF/CRN)'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _uploading ? null : () async {
              setState(() { _uploading = true; _uploadMsg = null; });
              try {
                await VerificationService().pickAndUpload(docType: 'lookup_print');
                setState(() { _uploadMsg = 'Print da consulta pública enviado ✅'; });
              } catch (e) {
                setState(() { _uploadMsg = 'Erro Print: $e'; });
              } finally {
                setState(() { _uploading = false; });
              }
            },
            child: Text(_uploading ? 'Enviando...' : 'Enviar print da consulta pública (ATIVO/BACHAREL)'),
          ),
          if (_uploadMsg != null) ...[
            const SizedBox(height: 12),
            Text(_uploadMsg!, textAlign: TextAlign.center),
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
      message:
          'Olá, $fullName\n\nSeu cadastro foi rejeitado.\nEntre em contato com o suporte.',
    );
  }
}
