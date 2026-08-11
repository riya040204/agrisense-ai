// AgriSense AI - Moisture gauge
// The signature visual: an actual instrument reading, not a plain number.
// Ring color shifts along the same green -> amber -> red language as advisories.

import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

class MoistureGauge extends StatelessWidget {
  final double moisturePercent; // 0-100
  final double threshold; // crop-specific stress threshold, for the marker

  const MoistureGauge({
    super.key,
    required this.moisturePercent,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = moisturePercent.clamp(0, 100).toDouble();
    final color = clamped < threshold - 5
        ? AppColors.alert
        : clamped < threshold
            ? AppColors.watch
            : AppColors.healthy;

    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _GaugePainter(percent: clamped / 100, threshold: threshold / 100, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${clamped.toStringAsFixed(0)}%',
                style: AppTheme.mono(size: 24, weight: FontWeight.w700, color: color),
              ),
              Text('moisture', style: TextStyle(fontSize: 10, color: AppColors.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final double threshold;
  final Color color;

  _GaugePainter({required this.percent, required this.threshold, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = -pi / 2;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.moss.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi * percent,
      false,
      valuePaint,
    );

    // Threshold marker — small tick showing the crop's stress line
    final tickAngle = startAngle + 2 * pi * threshold;
    final tickInner = Offset(
      center.dx + (radius - 8) * cos(tickAngle),
      center.dy + (radius - 8) * sin(tickAngle),
    );
    final tickOuter = Offset(
      center.dx + (radius + 8) * cos(tickAngle),
      center.dy + (radius + 8) * sin(tickAngle),
    );
    final tickPaint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    canvas.drawLine(tickInner, tickOuter, tickPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}