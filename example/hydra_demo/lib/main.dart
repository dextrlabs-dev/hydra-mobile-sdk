import 'package:flutter/material.dart';

import 'hydra_app_shell.dart';
import 'services/catalyst_init_once.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CatalystInitOnce.ensureInitialized();
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
