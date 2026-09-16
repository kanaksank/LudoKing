import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/settings_service.dart';
import '../state/providers.dart';
import '../widgets/neo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final t = SurfaceTokens.of(context);
    ref.watch(saveVersionProvider);
    final hasSave = ref.read(saveServiceProvider).hasSave;

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: NeoBox(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
                  child: Text(title, style: TextStyle(color: t.textSecondary, fontWeight: FontWeight.w700)),
                ),
                ...children,
              ],
            ),
          ),
        );

    Widget toggle(IconData icon, String title, String? sub, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon),
          title: Text(title),
          subtitle: sub == null ? null : Text(sub, style: TextStyle(fontSize: 12, color: t.textSecondary)),
          value: value,
          onChanged: onChanged,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          section('Feel', [
            toggle(Icons.volume_up_rounded, 'Sound', 'System click and alert sounds', s.sound,
                (v) => n.apply(s.copyWith(sound: v))),
            toggle(Icons.vibration_rounded, 'Vibration', 'Dice roll, token steps and captures', s.haptics,
                (v) => n.apply(s.copyWith(haptics: v))),
            toggle(Icons.dark_mode_rounded, 'Dark mode', null, s.darkMode,
                (v) => n.apply(s.copyWith(darkMode: v))),
          ]),
          section('Gameplay', [
            toggle(Icons.route_rounded, 'Path preview', 'First tap shows the route, second tap moves',
                s.pathPreview, (v) => n.apply(s.copyWith(pathPreview: v))),
            toggle(Icons.auto_mode_rounded, 'Auto-move obvious moves',
                'Moves for you when every choice is the same', s.autoMove,
                (v) => n.apply(s.copyWith(autoMove: v))),
            toggle(Icons.speed_rounded, 'Fast animations', null, s.speed == GameSpeed.fast,
                (v) => n.apply(s.copyWith(speed: v ? GameSpeed.fast : GameSpeed.normal))),
          ]),
          section('Data', [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_rounded),
              title: const Text('Discard saved game'),
              enabled: hasSave,
              onTap: () async {
                await ref.read(saveServiceProvider).clear();
                ref.read(saveVersionProvider.notifier).state++;
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reset statistics'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Reset statistics?'),
                    content: const Text('Games played, wins and captures go back to zero.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                    ],
                  ),
                );
                if (ok ?? false) await ref.read(statsProvider.notifier).reset();
              },
            ),
          ]),
          Center(
            child: Text(
              'Ludo Nova 1.0 · offline, no ads, no account',
              style: TextStyle(color: t.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
