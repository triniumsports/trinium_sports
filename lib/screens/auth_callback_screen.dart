import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCallbackScreen extends StatefulWidget {
  final Widget child;

  const AuthCallbackScreen({super.key, required this.child});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  bool _handling = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _handleAuthCallbackIfAny();
  }

  bool _hasAuthCallback(Uri uri) {
    final frag = uri.fragment;
    final query = uri.query;
    return frag.contains('access_token=') ||
        frag.contains('code=') ||
        frag.contains('type=') ||
        frag.contains('message=') ||
        query.contains('code=') ||
        query.contains('type=') ||
        query.contains('message=');
  }

  Future<void> _handleAuthCallbackIfAny() async {
    final uri = Uri.base;

    if (!_hasAuthCallback(uri)) {
      setState(() => _handling = false);
      return;
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      setState(() {
        _message = 'E-mail confirmado ✅ Agora você pode fazer login.';
      });
    } catch (e) {
      setState(() {
        _message =
            'Não foi possível processar o link automaticamente.\n'
            'Se você já confirmou o e-mail, volte e faça login.\n\nDetalhe: $e';
      });
    } finally {
      setState(() => _handling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_handling) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Processando confirmação...\n\nAguarde.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_message != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trinium Sports')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_message!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => widget.child),
                      (route) => false,
                    );
                  },
                  child: const Text('Ir para Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
