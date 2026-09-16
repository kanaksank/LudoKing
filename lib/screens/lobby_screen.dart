import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../game/board_geometry.dart';
import '../game/ludo_engine.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../widgets/board_painter.dart';
import '../widgets/neo.dart';
import 'game_screen.dart';

enum LobbyMode { computer, local }

class _Seat {
  _Seat({required this.isBot, required this.avatar});
  bool isBot;
  BotLevel level = BotLevel.medium;
  String avatar;
}

const _botNames = ['Aria', 'Bolt', 'Cleo', 'Dash', 'Echo', 'Fizz'];

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.mode});
  final LobbyMode mode;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  late int _count = widget.mode == LobbyMode.computer ? 4 : 2;
  late final List<_Seat> _seats;
  late final List<TextEditingController> _names;
  GameRules _rules = const GameRules();

  @override
  void initState() {
    super.initState();
    final computer = widget.mode == LobbyMode.computer;
    _seats = List.generate(
      6,
      (i) => _Seat(isBot: computer && i > 0, avatar: avatarChoices[i]),
    );
    _names = List.generate(6, (i) {
      final name = computer ? (i == 0 ? 'You' : 'Bot ${_botNames[i]}') : 'Player ${i + 1}';
      return TextEditingController(text: name);
    });
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  List<LudoPlayer> _players() {
    final arms = LudoEngine.armsForPlayerCount(_count);
    return [
      for (var i = 0; i < _count; i++)
        LudoPlayer(
          name: _names[i].text.trim().isEmpty ? 'Player ${i + 1}' : _names[i].text.trim(),
          arm: arms[i],
          colorIndex: arms[i],
          isBot: _seats[i].isBot,
          botLevel: _seats[i].level,
          avatar: _seats[i].avatar,
        ),
    ];
  }

  void _start() {
    final setup = GameSetup(players: _players(), rules: _rules);
    ref.read(gameControllerProvider.notifier).start(setup);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  void _cycleAvatar(int i) {
    setState(() {
      final idx = avatarChoices.indexOf(_seats[i].avatar);
      _seats[i].avatar = avatarChoices[(idx + 1) % avatarChoices.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SurfaceTokens.of(context);
    final arms = LudoEngine.armsForPlayerCount(_count);
    final boardArms = LudoEngine.boardArmsFor(_count);
    final armColors = List<Color?>.filled(boardArms, null);
    for (final a in arms) {
      armColors[a] = LudoPalette.of(a);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == LobbyMode.computer ? 'Play vs Computer' : 'Pass & Play'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
                children: [
                  NeoBox(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          height: 104,
                          child: CustomPaint(
                            painter: BoardPainter(
                              geo: BoardGeometry.of(boardArms),
                              armColors: armColors,
                              surface: t,
                              safeStars: _rules.safeStars,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                boardArms == 4 ? 'Classic board' : 'Hexagon board',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                boardArms == 4
                                    ? '52-cell cross track, 4 corner bases'
                                    : '78-cell track, 6 radial bases, pinch to zoom',
                                style: TextStyle(color: t.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: Space.md),
                              const Text('Players', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: Space.xs),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (var n = 2; n <= 6; n++)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text('$n'),
                                          selected: _count == n,
                                          onSelected: (_) => setState(() => _count = n),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  for (var i = 0; i < _count; i++) ...[
                    _seatCard(i, arms[i]),
                    const SizedBox(height: Space.md),
                  ],
                  _rulesCard(t),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
              child: SizedBox(
                width: double.infinity,
                child: NeoButton(
                  onPressed: _start,
                  gradient: glossy(LudoPalette.green),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.casino_rounded, color: Colors.white),
                      SizedBox(width: Space.sm),
                      Text(
                        'Start game',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seatCard(int i, int arm) {
    final color = LudoPalette.of(arm);
    final seat = _seats[i];
    return NeoBox(
      padding: const EdgeInsets.all(Space.md),
      border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _cycleAvatar(i),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: glossy(color),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(seat.avatar, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: TextField(
                  controller: _names[i],
                  maxLength: 14,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    labelText: '${LudoPalette.names[arm]} player',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.sm,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.person_rounded), label: Text('Human')),
                  ButtonSegment(value: true, icon: Icon(Icons.smart_toy_rounded), label: Text('Bot')),
                ],
                selected: {seat.isBot},
                onSelectionChanged: (v) => setState(() {
                  seat.isBot = v.first;
                  final text = _names[i].text;
                  if (seat.isBot && (text.isEmpty || text.startsWith('Player'))) {
                    _names[i].text = 'Bot ${_botNames[i]}';
                  } else if (!seat.isBot && text.startsWith('Bot ')) {
                    _names[i].text = 'Player ${i + 1}';
                  }
                }),
              ),
              if (seat.isBot)
                DropdownButton<BotLevel>(
                  value: seat.level,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: BotLevel.easy, child: Text('Easy')),
                    DropdownMenuItem(value: BotLevel.medium, child: Text('Medium')),
                    DropdownMenuItem(value: BotLevel.hard, child: Text('Hard')),
                  ],
                  onChanged: (v) => setState(() => seat.level = v ?? seat.level),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rulesCard(SurfaceTokens t) {
    Widget toggle(String title, String subtitle, bool value, GameRules Function(bool) apply) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(color: t.textSecondary, fontSize: 12)),
        value: value,
        onChanged: (v) => setState(() => _rules = apply(v)),
      );
    }

    return NeoBox(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.rule_rounded),
          title: const Text('House rules', style: TextStyle(fontWeight: FontWeight.w700)),
          children: [
            toggle('Six to leave base', 'Otherwise a 1 or a 6 releases a token', _rules.sixToRelease,
                (v) => _rules.copyWith(sixToRelease: v)),
            toggle('Safe stars', 'Star cells protect tokens from capture', _rules.safeStars,
                (v) => _rules.copyWith(safeStars: v)),
            toggle('Three sixes rule', 'A third six in a row forfeits the turn', _rules.threeSixesForfeit,
                (v) => _rules.copyWith(threeSixesForfeit: v)),
            toggle('Bonus roll on capture', 'Capturing earns another roll', _rules.extraTurnOnCapture,
                (v) => _rules.copyWith(extraTurnOnCapture: v)),
            toggle('Bonus roll on reaching home', 'Getting a token home earns another roll',
                _rules.extraTurnOnFinish, (v) => _rules.copyWith(extraTurnOnFinish: v)),
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Turn timer'),
                  const SizedBox(height: Space.xs),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Off')),
                      ButtonSegment(value: 10, label: Text('10s')),
                      ButtonSegment(value: 15, label: Text('15s')),
                      ButtonSegment(value: 30, label: Text('30s')),
                    ],
                    selected: {_rules.turnSeconds},
                    onSelectionChanged: (v) => setState(() => _rules = _rules.copyWith(turnSeconds: v.first)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
