import 'package:catalyst_key_derivation/catalyst_key_derivation.dart';
import 'package:flutter/material.dart';

import 'hydra_app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CatalystKeyDerivation.init();
  runApp(const HydraDemoApp());
}

class HydraDemoApp extends StatelessWidget {
  const HydraDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydra demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HydraAppShell(),
    );
  }
}
