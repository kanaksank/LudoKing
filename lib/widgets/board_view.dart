import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../game/board_geometry.dart';
import '../game/ludo_engine.dart';
import '../state/game_controller.dart';
import 'board_painter.dart';
import 'token_widget.dart';

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.ui,
    required this.onTokenTap,
    required this.onConfirmSelection,
    required this.onClearSelection,
  });

  final GameUiState ui;
  final void Function(int player, int token) onTokenTap;
  final VoidCallback onConfirmSelection;
  final VoidCallback onClearSelection;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _TokenEntry {
  _TokenEntry(this.player, this.token, this.progress, this.point);
  final int player;
  final int token;
  final int progress;
  final BoardPoint point;

  String get cellKey => '${(point.x * 10).round()}_${(point.y * 10).round()}';
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    final on = widget.ui.selectedToken != null;
    if (on && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!on && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    final game = ui.game;
    final geo = BoardGeometry.of(game.armCount);
    final surface = SurfaceTokens.of(context);

    final armColors = List<Color?>.filled(geo.arms, null);
    for (final p in game.players) {
      armColors[p.arm] = LudoPalette.of(p.colorIndex);
    }

    final current = game.current;
    final humanTurn = !game.currentPlayer.isBot;
    final movable = humanTurn ? ui.movable.toSet() : <int>{};

    var path = <BoardPoint>[];
    final sel = ui.selectedToken;
    if (sel != null && game.dice != null) {
      final arm = game.players[current].arm;
      path = [
        for (final prog in LudoEngine.pathFor(game, current, sel, game.dice!))
          geo.tokenPoint(arm: arm, progress: prog, token: sel),
      ];
    }
    final destination = path.isEmpty ? null : path.last;

    // Collect tokens, grouping those that share a cell.
    final entries = <_TokenEntry>[];
    for (var p = 0; p < game.players.length; p++) {
      for (var t = 0; t < LudoEngine.tokensPerPlayer; t++) {
        final prog = ui.display[p][t];
        entries.add(_TokenEntry(p, t, prog, geo.tokenPoint(arm: game.players[p].arm, progress: prog, token: t)));
      }
    }
    final groups = <String, List<_TokenEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.cellKey, () => []).add(e);
    }
    // Current player's tokens are painted last so they stay tappable.
    int rank(_TokenEntry e) => e.player != current ? 0 : (movable.contains(e.token) ? 2 : 1);
    entries.sort((a, b) => rank(a).compareTo(rank(b)));

    return LayoutBuilder(
      builder: (context, box) {
        final s = math.min(box.maxWidth / (2 * geo.extentX), box.maxHeight / (2 * geo.extentY));
        final bw = 2 * geo.extentX * s;
        final bh = 2 * geo.extentY * s;
        final baseSize = s * 0.84;

        Offset toPx(BoardPoint p) => Offset((p.x + geo.extentX) * s, (p.y + geo.extentY) * s);

        final children = <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                if (destination == null) return;
                final bx = d.localPosition.dx / s - geo.extentX;
                final by = d.localPosition.dy / s - geo.extentY;
                if (BoardPoint(bx, by).distanceTo(destination) < 0.8) {
                  widget.onConfirmSelection();
                } else {
                  widget.onClearSelection();
                }
              },
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: BoardPainter(
                    geo: geo,
                    armColors: armColors,
                    surface: surface,
                    safeStars: game.rules.safeStars,
                    path: path,
                    pathColor: path.isEmpty ? null : LudoPalette.of(game.currentPlayer.colorIndex),
                    pulse: _pulse.value,
                  ),
                ),
              ),
            ),
          ),
        ];

        final fin = LudoEngine.finishProgress(game.armCount);
        for (final e in entries) {
          final group = groups[e.cellKey]!;
          var size = baseSize;
          var offset = Offset.zero;
          if (group.length > 1) {
            size = baseSize * (group.length > 2 ? 0.62 : 0.72);
            final i = group.indexOf(e);
            final a = -math.pi / 2 + 2 * math.pi * i / group.length;
            offset = Offset(math.cos(a), math.sin(a)) * s * 0.2;
          }
          if (e.progress == fin) size = baseSize * 0.62;

          final px = toPx(e.point) + offset;
          final color = LudoPalette.of(game.players[e.player].colorIndex);
          final isMovable = e.player == current && movable.contains(e.token);
          final onTrack = LudoEngine.isOnTrack(game.armCount, e.progress);
          final safe = onTrack &&
              LudoEngine.isSafeCell(
                LudoEngine.absoluteCell(game.armCount, game.players[e.player].arm, e.progress),
                game.rules,
              );

          children.add(
            AnimatedPositioned(
              key: ValueKey('tok_${e.player}_${e.token}'),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              left: px.dx - size / 2,
              top: px.dy - size / 2 - size * 0.1,
              width: size,
              height: size,
              child: TokenWidget(
                color: color,
                size: size,
                movable: isMovable && ui.selectedToken != e.token,
                selected: e.player == current && ui.selectedToken == e.token,
                safeBadge: safe && group.length == 1,
                onTap: isMovable ? () => widget.onTokenTap(e.player, e.token) : null,
              ),
            ),
          );
        }

        return Center(
          child: Container(
            width: bw,
            height: bh,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(s * 0.9),
              boxShadow: [
                BoxShadow(color: surface.shadowDark, blurRadius: 18, offset: const Offset(6, 8)),
                BoxShadow(color: surface.shadowLight, blurRadius: 14, offset: const Offset(-5, -5)),
              ],
            ),
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        );
      },
    );
  }
}
