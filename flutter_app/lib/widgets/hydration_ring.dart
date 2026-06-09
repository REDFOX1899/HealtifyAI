import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Circular progress ring showing oz consumed vs. daily goal.
class HydrationRing extends StatelessWidget {
  const HydrationRing({
    super.key,
    required this.ozConsumed,
    required this.dailyGoal,
    this.size = 220,
  });

  final double ozConsumed;
  final int dailyGoal;
  final double size;

  double get progress =>
      dailyGoal == 0 ? 0 : (ozConsumed / dailyGoal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ozConsumed.round()} oz',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.offwhite,
                ),
              ),
              Text(
                'of $dailyGoal oz',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.offwhite.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    const stroke = 16.0;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.teal.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.teal;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
