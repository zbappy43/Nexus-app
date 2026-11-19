import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

/// Animated illustration: pulsing rings around a large icon badge.
class StatusIllustration extends StatefulWidget {
  const StatusIllustration({
    required this.icon,
    super.key,
    this.color = AppColors.primary,
    this.accent = AppColors.accent,
    this.size = 200,
  });

  final IconData icon;
  final Color color;
  final Color accent;
  final double size;

  @override
  State<StatusIllustration> createState() => _StatusIllustrationState();
}

class _StatusIllustrationState extends State<StatusIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: _RingsPainter(
            progress: _controller.value,
            color: widget.color,
            accent: widget.accent,
          ),
          child: child,
        ),
        child: Center(
          child: Container(
            width: widget.size * 0.42,
            height: widget.size * 0.42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[widget.color, Color.lerp(widget.color, Colors.black, 0.25)!],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.2),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.progress, required this.color, required this.accent});

  final double progress;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double maxRadius = size.shortestSide / 2;
    for (int i = 0; i < 3; i++) {
      final double t = (progress + i / 3) % 1.0;
      final double radius = maxRadius * (0.3 + 0.7 * t);
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * 0.35);
      canvas.drawCircle(center, radius, paint);
    }
    // Orbiting accent dots.
    final Paint dot = Paint()..color = accent;
    for (int i = 0; i < 3; i++) {
      final double angle = 2 * math.pi * (progress + i / 3);
      final double r = maxRadius * 0.62;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * r, math.sin(angle) * r),
        i == 0 ? 6 : 4,
        dot..color = accent.withValues(alpha: i == 0 ? 1 : 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => oldDelegate.progress != progress;
}
