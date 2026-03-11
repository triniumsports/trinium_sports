import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'screens/auth_gate.dart';
import 'screens/auth_callback_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    startupError = e.toString();
  }

  runApp(TriniumApp(startupError: startupError));
}

class TriniumApp extends StatelessWidget {
  final String? startupError;

  const TriniumApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: startupError != null
          ? Scaffold(
              appBar: AppBar(title: const Text('Trinium Sports')),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('ERRO SUPABASE:\n\n$startupError'),
              ),
            )
          : const AuthCallbackScreen(child: AuthGate()),
    );
  }
}
