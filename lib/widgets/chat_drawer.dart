import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/settings_service.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';

const quickPhrases = [
  'Good luck!',
  'Nice move!',
  'Hurry up!',
  'Oops!',
  'Well played',
  'Not again!',
  'Watch out!',
  'GG',
];

const quickEmojis = ['😀', '😂', '😎', '😡', '😭', '😱', '👍', '👏', '🔥', '🎉', '💪', '🙏'];

/// Collapsible side drawer: table talk, quick reactions and audio controls.
class ChatDrawer extends ConsumerStatefulWidget {
  const ChatDrawer({super.key});

  @override
  ConsumerState<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends ConsumerState<ChatDrawer> {
  int? _sender;

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(gameControllerProvider);
    final settings = ref.watch(settingsProvider);
    final t = SurfaceTokens.of(context);
    if (ui == null) return const Drawer();

    final players = ui.game.players;
    final humans = [
      for (var i = 0; i < players.length; i++)
        if (!players[i].isBot) i,
    ];
    final picked = _sender;
    final int? sender = (picked != null && humans.contains(picked))
        ? picked
        : humans.contains(ui.game.current)
            ? ui.game.current
            : (humans.isEmpty ? null : humans.first);

    void send(String text) {
      final from = sender;
      if (from == null) return;
      ref.read(gameControllerProvider.notifier).sendFromHuman(from, text);
    }

    return Drawer(
      width: 310,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Table talk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Expanded(
                child: ui.chat.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nSend a reaction below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: ui.chat.length,
                        itemBuilder: (context, i) {
                          final line = ui.chat[ui.chat.length - 1 - i];
                          final p = players[line.player];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: LudoPalette.of(p.colorIndex),
                                  child: Text(p.avatar, style: const TextStyle(fontSize: 13)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${p.name}  ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: LudoPalette.of(p.colorIndex),
                                          ),
                                        ),
                                        TextSpan(text: line.text),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              if (humans.length > 1)
                Wrap(
                  spacing: 6,
                  children: [
                    for (final h in humans)
                      ChoiceChip(
                        label: Text(players[h].name),
                        selected: sender == h,
                        onSelected: (_) => setState(() => _sender = h),
                      ),
                  ],
                ),
              if (sender == null)
                Text('Only computer players at this table.', style: TextStyle(color: t.textSecondary))
              else ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final phrase in quickPhrases)
                      ActionChip(label: Text(phrase), onPressed: () => send(phrase)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 2,
                  children: [
                    for (final e in quickEmojis)
                      IconButton(
                        onPressed: () => send(e),
                        icon: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                  ],
                ),
              ],
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Sound'),
                secondary: const Icon(Icons.volume_up_rounded),
                value: settings.sound,
                onChanged: (v) => ref.read(settingsProvider.notifier).apply(settings.copyWith(sound: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Vibration'),
                secondary: const Icon(Icons.vibration_rounded),
                value: settings.haptics,
                onChanged: (v) => ref.read(settingsProvider.notifier).apply(settings.copyWith(haptics: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Fast animations'),
                secondary: const Icon(Icons.speed_rounded),
                value: settings.speed == GameSpeed.fast,
                onChanged: (v) => ref.read(settingsProvider.notifier).apply(
                      settings.copyWith(speed: v ? GameSpeed.fast : GameSpeed.normal),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
