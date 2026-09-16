import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../game/board_geometry.dart';
import '../game/ludo_engine.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../widgets/board_view.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/dice.dart';
import '../widgets/dice_pod.dart';
import '../widgets/effects.dart';
import '../widgets/neo.dart';
import 'victory_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _zoom = TransformationController();
  int _shakeTick = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoom.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(gameControllerProvider.notifier).pause();
    }
  }

  void _quit() {
    _leaving = true;
    ref.read(gameControllerProvider.notifier).leave();
    Navigator.of(context).pop();
  }

  void _restart() {
    final setup = ref.read(lastSetupProvider);
    if (setup == null) return;
    _zoom.value = Matrix4.identity();
    ref.read(gameControllerProvider.notifier).start(setup);
  }

  void _zoomBy(double factor, Size viewport) {
    final current = _zoom.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 3.0).toDouble();
    if (target <= 1.001) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final centre = Offset(viewport.width / 2, viewport.height / 2);
    final scenePoint = _zoom.toScene(centre);
    _zoom.value = Matrix4.diagonal3Values(target, target, 1)
      ..setTranslationRaw(centre.dx - target * scenePoint.dx, centre.dy - target * scenePoint.dy, 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameEvent?>(gameControllerProvider.select((s) => s?.event), (prev, next) {
      if (next == null || next.id == prev?.id) return;
      if (next.type == GameEventType.capture) {
        setState(() => _shakeTick++);
      } else if (next.type == GameEventType.gameOver) {
        final finalState = ref.read(gameControllerProvider)?.game;
        if (finalState == null) return;
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted || _leaving) return;
          _leaving = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => VictoryScreen(result: finalState)),
          );
        });
      }
    });

    final ui = ref.watch(gameControllerProvider);
    if (ui == null) return const Scaffold();
    final controller = ref.read(gameControllerProvider.notifier);
    final g = ui.game;
    final geo = BoardGeometry.of(g.armCount);
    final t = SurfaceTokens.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          Navigator.of(context).pop();
          return;
        }
        if (ui.paused) {
          controller.resumePlay();
        } else {
          controller.pause();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: const ChatDrawer(),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(ui, t),
                  _podRow(ui, geo.topArms, geo),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          Widget board = BoardView(
                            ui: ui,
                            onTokenTap: controller.tapToken,
                            onConfirmSelection: controller.confirmSelection,
                            onClearSelection: controller.clearSelection,
                          );
                          if (!geo.isClassic) {
                            board = InteractiveViewer(
                              transformationController: _zoom,
                              minScale: 1,
                              maxScale: 3,
                              boundaryMargin: const EdgeInsets.all(24),
                              child: board,
                            );
                          }
                          return Stack(
                            children: [
                              Positioned.fill(child: ShakeBox(trigger: _shakeTick, child: board)),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(child: _Banner(text: ui.banner)),
                              ),
                              if (!geo.isClassic)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: _ZoomControls(
                                    onIn: () => _zoomBy(1.4, box.biggest),
                                    onOut: () => _zoomBy(1 / 1.4, box.biggest),
                                    onFit: () => _zoom.value = Matrix4.identity(),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  _podRow(ui, geo.bottomArms, geo),
                  _thumbDock(ui, t),
                ],
              ),
              if (ui.paused)
                Positioned.fill(
                  child: _PauseOverlay(
                    onResume: controller.resumePlay,
                    onRestart: _restart,
                    onQuit: _quit,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(GameUiState ui, SurfaceTokens t) {
    final g = ui.game;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.sm, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Pause',
            onPressed: ref.read(gameControllerProvider.notifier).pause,
            icon: const Icon(Icons.pause_circle_filled_rounded, size: 30),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  g.armCount == 4 ? 'Classic · ${g.players.length} players' : 'Hexagon · ${g.players.length} players',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Turn ${g.turnNumber + 1}',
                  style: TextStyle(fontSize: 12, color: t.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chat & sound',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.forum_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _podRow(GameUiState ui, List<int> arms, BoardGeometry geo) {
    final g = ui.game;
    final controller = ref.read(gameControllerProvider.notifier);
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(124.0, (box.maxWidth - 24) / arms.length);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final arm in arms) _podFor(ui, g, arm, geo, width, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _podFor(
    GameUiState ui,
    LudoState g,
    int arm,
    BoardGeometry geo,
    double width,
    GameController controller,
  ) {
    final index = g.players.indexWhere((p) => p.arm == arm);
    if (index < 0) return SizedBox(width: width);
    final p = g.players[index];
    final isCurrent = index == g.current && !g.isOver;
    final rankIndex = g.finishOrder.indexOf(index);
    return DicePod(
      width: width,
      player: p,
      face: ui.lastFaces[index],
      isCurrent: isCurrent,
      rolling: ui.rolling,
      timerFraction: ui.timerFraction,
      canRoll: isCurrent && !p.isBot && g.awaitingRoll && !ui.busy,
      onRoll: controller.humanRoll,
      reaction: ui.reactions[index],
      rank: rankIndex < 0 ? null : rankIndex + 1,
      mirrored: math.cos(geo.baseAngle(arm)) > 0.1,
    );
  }

  Widget _thumbDock(GameUiState ui, SurfaceTokens t) {
    final g = ui.game;
    final p = g.currentPlayer;
    final color = LudoPalette.of(p.colorIndex);
    final canRoll = !p.isBot && g.awaitingRoll && !ui.busy;
    final String hint;
    if (ui.paused) {
      hint = 'Paused';
    } else if (ui.rolling) {
      hint = 'Rolling…';
    } else if (ui.animating) {
      hint = 'Moving…';
    } else if (p.isBot) {
      hint = '${p.name} is thinking…';
    } else if (g.awaitingRoll) {
      hint = '${p.name}, tap the die to roll';
    } else if (ui.selectedToken != null) {
      hint = 'Tap the token again, or its glowing target, to move';
    } else {
      hint = 'Pick one of your glowing tokens';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.md),
      child: NeoBox(
        radius: Radii.lg,
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.sm),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  hint,
                  key: ValueKey(hint),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Roll the die',
              child: GestureDetector(
                onTap: canRoll ? ref.read(gameControllerProvider.notifier).humanRoll : null,
                child: AnimatedScale(
                  duration: Motion.press,
                  scale: canRoll ? 1 : 0.85,
                  child: TimerRing(
                    size: 76,
                    color: color,
                    fraction: ui.timerFraction,
                    active: !p.isBot && !ui.paused,
                    child: DiceFace(
                      value: ui.lastFaces[g.current],
                      size: 52,
                      accent: color,
                      rolling: ui.rolling,
                      dimmed: !canRoll && !ui.rolling,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final message = text;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: message == null
          ? const SizedBox.shrink()
          : Center(
              key: ValueKey(message),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xE6151923),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onIn, required this.onOut, required this.onFit});
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: NeoButton(
            onPressed: onTap,
            radius: Radii.md,
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, semanticLabel: tip),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.add_rounded, 'Zoom in', onIn),
        btn(Icons.remove_rounded, 'Zoom out', onOut),
        btn(Icons.fit_screen_rounded, 'Fit board', onFit),
      ],
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onRestart, required this.onQuit});
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    Widget action(String label, IconData icon, Color color, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(top: Space.md),
          child: NeoButton(
            onPressed: onTap,
            gradient: glossy(color),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: Space.md),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        );

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Align(
        alignment: const Alignment(0, 0.5),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: NeoBox(
            radius: Radii.lg,
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Paused',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                action('Resume', Icons.play_arrow_rounded, LudoPalette.green, onResume),
                action('Restart', Icons.refresh_rounded, LudoPalette.blue, onRestart),
                action('Save & quit', Icons.logout_rounded, LudoPalette.red, onQuit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
