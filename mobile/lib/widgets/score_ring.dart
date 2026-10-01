import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class ScoreRing extends StatelessWidget {
  final double score;
  final double size;
  final double strokeWidth;

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 180,
    this.strokeWidth = 6,
  });

  Color get _scoreColor {
    if (score >= 80) return AppColors.textPrimary; // Crisp Bone White
    if (score >= 60) return AppColors.titanium;
    if (score >= 40) return AppColors.orange;
    return AppColors.red;
  }

  String get _label {
    if (score >= 80) return 'OPTIMAL';
    if (score >= 60) return 'ELEVATED';
    if (score >= 40) return 'AT_RISK';
    return 'CRITICAL';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PrecisionDialPainter(
          score: score,
          color: _scoreColor,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PRIVACY_INDEX',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    score.toInt().toString(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      color: _scoreColor,
                    ),
                  ),
                  Text(
                    '/100',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border, width: 1.0),
                ),
                child: Text(
                  _label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrecisionDialPainter extends CustomPainter {
  final double score;
  final Color color;
  final double strokeWidth;

  _PrecisionDialPainter({
    required this.score,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;

    // 1. Draw outer subtle tick marks (60 ticks like a precision mechanical gauge)
    final tickPaint = Paint()
      ..color = AppColors.borderHover
      ..strokeWidth = 1.0;

    final activeTickPaint = Paint()
      ..color = AppColors.titanium
      ..strokeWidth = 1.5;

    const totalTicks = 48;
    const startAngle = -pi / 2;
    final activeTicksCount = ((score / 100) * totalTicks).round();

    for (int i = 0; i < totalTicks; i++) {
      final angle = startAngle + (i / totalTicks) * 2 * pi;
      final isMajor = i % 6 == 0;
      final tickLength = isMajor ? 6.0 : 3.0;

      final startOffset = Offset(
        center.dx + (radius + 6) * cos(angle),
        center.dy + (radius + 6) * sin(angle),
      );
      final endOffset = Offset(
        center.dx + (radius + 6 + tickLength) * cos(angle),
        center.dy + (radius + 6 + tickLength) * sin(angle),
      );

      final paintToUse = i <= activeTicksCount ? activeTickPaint : tickPaint;
      canvas.drawLine(startOffset, endOffset, paintToUse);
    }

    // 2. Track background arc
    final trackPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawCircle(center, radius, trackPaint);

    // 3. Active score arc
    final sweepAngle = (score / 100) * 2 * pi;
    final activeArcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      activeArcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PrecisionDialPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
