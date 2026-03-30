import 'package:flutter/material.dart';
import 'package:hydra_client/hydra_client.dart';

import 'connection_tab.dart';
import 'dice_game_tab.dart';
import 'snake_game_tab.dart';

class HydraAppShell extends StatefulWidget {
  const HydraAppShell({super.key});

  @override
  State<HydraAppShell> createState() => _HydraAppShellState();
}

class _HydraAppShellState extends State<HydraAppShell> {
  int _tab = 0;
  int? _currentSlot;
  HydraClientConfig? _hydraConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          ConnectionTab(
            onGreetingsSlot: (s) => setState(() => _currentSlot = s),
            onHydraConfig: (c) => setState(() => _hydraConfig = c),
          ),
          DiceGameTab(
            currentSlot: _currentSlot,
            hydraConfig: _hydraConfig,
          ),
          SnakeGameTab(
            currentSlot: _currentSlot,
            hydraConfig: _hydraConfig,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Hydra',
          ),
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: 'Dice game',
          ),
          NavigationDestination(
            icon: Icon(Icons.videogame_asset_outlined),
            selectedIcon: Icon(Icons.videogame_asset),
            label: 'Snake',
          ),
        ],
      ),
    );
  }
}
