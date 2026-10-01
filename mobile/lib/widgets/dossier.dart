import 'dart:math';

import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Visual language for PrivacyShield: an intelligence dossier on paper.
/// Ink, signal red, rubber stamps, redaction bars and case-file labels. No gradients, no glow.

/// Small mono label, e.g. "CASE FILE № PS-0042".
class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;

  const Eyebrow(this.text, {super.key, this.color = AppColors.textMuted});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppText.eyebrow(color: color), maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// Case-file section heading: mono code, serif title and a heavy rule.
class CaseHeading extends StatelessWidget {
  final String code;
  final String title;
  final Widget? trailing;

  const CaseHeading({super.key, required this.code, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(code, color: AppColors.red),
                  const SizedBox(height: 4),
                  Text(title, style: AppText.serif(size: 28)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 2, color: AppColors.ink),
      ],
    ),
  );
}

/// A rubber stamp that slams onto the page when it first appears.
class RubberStamp extends StatefulWidget {
  final String text;
  final Color color;
  final double angle;
  final double fontSize;
  final Duration delay;

  const RubberStamp(
    this.text, {
    super.key,
    this.color = AppColors.red,
    this.angle = -0.14,
    this.fontSize = 18,
    this.delay = const Duration(milliseconds: 350),
  });

  @override
  State<RubberStamp> createState() => _RubberStampState();
}

class _RubberStampState extends State<RubberStamp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final t = Curves.easeOutBack.transform(_c.value);
      return Opacity(
        opacity: _c.value.clamp(0.0, 1.0),
        child: Transform.rotate(angle: widget.angle, child: Transform.scale(scale: 2.2 - 1.2 * t, child: child)),
      );
    },
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: widget.fontSize * 0.6, vertical: widget.fontSize * 0.2),
      decoration: BoxDecoration(
        border: Border.all(color: widget.color.withAlpha(215), width: max(2, widget.fontSize / 7)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        widget.text.toUpperCase(),
        style: AppText.mono(size: widget.fontSize, color: widget.color.withAlpha(225), weight: FontWeight.w700)
            .copyWith(letterSpacing: widget.fontSize * 0.14),
      ),
    ),
  );
}

/// Shows [child] under a black redaction bar that wipes away, like a declassified record.
class Redacted extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const Redacted({super.key, required this.child, this.delay = const Duration(milliseconds: 200)});

  @override
  State<Redacted> createState() => _RedactedState();
}

class _RedactedState extends State<Redacted> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Stack(
      children: [
        child!,
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 1 - Curves.easeInOutCubic.transform(_c.value),
              heightFactor: 0.82,
              child: const ColoredBox(color: AppColors.ink),
            ),
          ),
        ),
      ],
    ),
    child: widget.child,
  );
}

/// A black band of mono text that scrolls forever, like a wire-service ticker.
class TickerTape extends StatefulWidget {
  final List<String> items;
  final Color color;

  const TickerTape({super.key, required this.items, this.color = AppColors.ink});

  @override
  State<TickerTape> createState() => _TickerTapeState();
}

class _TickerTapeState extends State<TickerTape> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Duration(seconds: max(12, widget.items.length * 6)))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = '${widget.items.map((e) => e.toUpperCase()).join('   ◼   ')}   ◼   ';
    final style = AppText.mono(size: 12, color: AppColors.background, weight: FontWeight.w600).copyWith(letterSpacing: 1.2);
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    return Container(
      height: 30,
      color: widget.color,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: Transform.translate(
              offset: Offset(-_c.value * painter.width, 0),
              child: Text('$text$text$text', style: style, maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ),
    );
  }
}

/// A paper panel with crop-mark corners, like a document on a light table.
class FilePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color markColor;

  const FilePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppColors.surface,
    this.markColor = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _CropMarks(markColor),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(color: color, border: Border.all(color: AppColors.border)),
      child: child,
    ),
  );
}

class _CropMarks extends CustomPainter {
  final Color color;

  _CropMarks(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    const l = 12.0;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1, 1), (size.width, 0.0, -1, 1), (0.0, size.height, 1, -1), (size.width, size.height, -1, -1)]) {
      canvas.drawLine(Offset(x, y), Offset(x + l * dx, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + l * dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant _CropMarks old) => old.color != color;
}

/// A slow scanning line across its child, as if the page is being read by a machine.
class ScanLine extends StatefulWidget {
  final Widget child;
  final Color color;

  const ScanLine({super.key, required this.child, this.color = AppColors.red});

  @override
  State<ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Align(
              alignment: Alignment(0, -1 + 2 * _c.value),
              child: Container(height: 1.5, color: widget.color.withAlpha(110)),
            ),
          ),
        ),
      ),
    ],
  );
}

/// A gauge dial: 100 ticks, inked up to the score, with the number set in serif.
class ScoreDial extends StatefulWidget {
  final int score;
  final double size;

  const ScoreDial({super.key, required this.score, this.size = 220});

  @override
  State<ScoreDial> createState() => _ScoreDialState();
}

class _ScoreDialState extends State<ScoreDial> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  }

  @override
  void didUpdateWidget(covariant ScoreDial old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final shown = (widget.score * Curves.easeOutCubic.transform(_c.value)).round();
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _DialPainter(shown, scoreColor(widget.score)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$shown', style: AppText.serif(size: widget.size * 0.36)),
                Eyebrow('of 100', color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Color scoreColor(num score) => score >= 80
    ? AppColors.green
    : score >= 60
    ? AppColors.ink
    : score >= 40
    ? AppColors.orange
    : AppColors.red;

class _DialPainter extends CustomPainter {
  final int score;
  final Color color;

  _DialPainter(this.score, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    const start = pi * 0.75, sweep = pi * 1.5;
    for (var i = 0; i <= 100; i++) {
      final a = start + sweep * i / 100;
      final major = i % 10 == 0;
      final inked = i <= score;
      final outer = r - 2, inner = r - (major ? 20 : 12);
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * inner,
        c + Offset(cos(a), sin(a)) * outer,
        Paint()
          ..color = inked ? color : AppColors.border
          ..strokeWidth = major ? 2.4 : 1.4,
      );
    }
    // Needle.
    final a = start + sweep * score / 100;
    canvas.drawLine(
      c + Offset(cos(a), sin(a)) * (r * 0.5),
      c + Offset(cos(a), sin(a)) * (r - 26),
      Paint()
        ..color = AppColors.red
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.score != score || old.color != color;
}
