import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TriniumApp());
}

class TriniumApp extends StatelessWidget {
  const TriniumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Trinium Sports')),
        body: const Center(
          child: Text('APP MINIMO OK'),
        ),
      ),
    );
  }
}
