import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_gate.dart';

class AppLogoutButton extends StatefulWidget {
  const AppLogoutButton({super.key});

  @override
  State<AppLogoutButton> createState() => _AppLogoutButtonState();
}

class _AppLogoutButtonState extends State<AppLogoutButton> {
  bool _loading = false;

  Future<void> _logout() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível sair: $error'),
        ),
      );

      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _loading ? null : _logout,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout),
      label: const Text('Sair'),
    );
  }
}
