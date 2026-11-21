import 'package:flutter/material.dart';

import '../settings/theme_preference.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(this.preference, {super.key});
  final ThemePreference preference;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Impostazioni')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Tema', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: preference,
                builder:
                    (context, selected, _) => Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      child: Column(
                        children: [
                          for (final (mode, label, icon) in const [
                            (
                              ThemeMode.system,
                              'Segui il sistema',
                              Icons.brightness_auto_outlined,
                            ),
                            (
                              ThemeMode.light,
                              'Chiaro',
                              Icons.light_mode_outlined,
                            ),
                            (ThemeMode.dark, 'Scuro', Icons.dark_mode_outlined),
                          ])
                            RadioListTile<ThemeMode>(
                              title: Text(label),
                              secondary: Icon(icon),
                              value: mode,
                              groupValue: selected,
                              onChanged: (choice) async {
                                if (choice == null) return;
                                try {
                                  await preference.select(choice);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Impossibile salvare il tema.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
