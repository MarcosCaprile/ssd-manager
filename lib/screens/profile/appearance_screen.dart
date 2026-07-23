import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Darstellung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Farbschema', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Wähle, ob SSD Manager der Systemeinstellung folgt oder immer hell beziehungsweise dunkel angezeigt wird.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest_outlined),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Hell'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dunkel'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              ref
                  .read(themeControllerProvider.notifier)
                  .setMode(selection.first);
            },
          ),
        ],
      ),
    );
  }
}
