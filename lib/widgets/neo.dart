import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_tokens.dart';

/// Soft neumorphic surface: one light and one dark shadow.
class NeoBox extends StatelessWidget {
  const NeoBox({
    super.key,
    required this.child,
    this.radius = Radii.md,
    this.padding = const EdgeInsets.all(Space.md),
    this.color,
    this.pressed = false,
    this.depth = 1,
    this.border,
    this.gradient,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool pressed;
  final double depth;
  final BoxBorder? border;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final t = SurfaceTokens.of(context);
    final d = (pressed ? 1.5 : 5.0) * depth;
    return AnimatedContainer(
      duration: Motion.press,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? t.raised) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: [
          BoxShadow(color: t.shadowLight, offset: Offset(-d * 0.7, -d * 0.7), blurRadius: d * 2),
          BoxShadow(color: t.shadowDark, offset: Offset(d, d), blurRadius: d * 2.4),
        ],
      ),
      child: child,
    );
  }
}

/// Pressable neumorphic button with a small scale-down and a haptic tick.
class NeoButton extends StatefulWidget {
  const NeoButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.gradient,
    this.radius = Radii.lg,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.lg),
    this.haptic = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool haptic;

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: enabled ? (_) => _set(false) : null,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: Motion.press,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: NeoBox(
              pressed: _down,
              radius: widget.radius,
              padding: widget.padding,
              color: widget.color,
              gradient: widget.gradient,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glossy gradient for a coloured button.
LinearGradient glossy(Color c) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [LudoPalette.shade(c, 0.12), c, LudoPalette.shade(c, -0.12)],
    );
