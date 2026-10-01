import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';
import '../services/api_service.dart';

/// Security-operations layer in the paper palette: ink-black instrument panels with
/// signal red and forest green readouts. Everything shown comes from the user's real data.

const kConsoleGreen = Color(0xFF8BC79B);
const kConsoleRed = Color(0xFFE5583F);
const kConsoleDim = Color(0xFF8E897E);

/// A pulsing status light.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, this.color = AppColors.green, this.size = 9});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size * 2.4,
    height: widget.size * 2.4,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size * (1 + 1.4 * _c.value),
            height: widget.size * (1 + 1.4 * _c.value),
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withAlpha((90 * (1 - _c.value)).round())),
          ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
          ),
        ],
      ),
    ),
  );
}

/// "SHIELD ACTIVE" bar: live session clock and a real round-trip to the user's server.
class ShieldStatus extends StatefulWidget {
  final int accounts;

  const ShieldStatus({super.key, required this.accounts});

  @override
  State<ShieldStatus> createState() => _ShieldStatusState();
}

class _ShieldStatusState extends State<ShieldStatus> {
  static final _sessionStart = DateTime.now();
  Timer? _tick;
  int? _latencyMs;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _ping();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (t.tick % 10 == 0) _ping();
      if (mounted) setState(() {});
    });
  }

  Future<void> _ping() async {
    final sw = Stopwatch()..start();
    try {
      await http.get(Uri.parse('${ApiService().baseUrl}/health')).timeout(const Duration(seconds: 4));
      _online = true;
      _latencyMs = sw.elapsedMilliseconds;
    } catch (_) {
      _online = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = DateTime.now().difference(_sessionStart);
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = '${two(up.inHours)}:${two(up.inMinutes % 60)}:${two(up.inSeconds % 60)}';
    final color = _online ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.ink, width: 1.2)),
      child: Row(
        children: [
          PulseDot(color: color),
          const SizedBox(width: 6),
          Text(
            _online ? 'SHIELD ACTIVE' : 'SERVER OFFLINE',
            style: AppText.mono(size: 11.5, color: color, weight: FontWeight.w700).copyWith(letterSpacing: 1.4),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              '${widget.accounts} WATCHED · ${_latencyMs != null && _online ? '${_latencyMs}MS' : '--'} · $clock',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(size: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Black instrument panel with a mono header, used for radar and console.
class InkPanel extends StatelessWidget {
  final String title;
  final String? meta;
  final Widget child;

  const InkPanel({super.key, required this.title, this.meta, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.ink,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(title.toUpperCase(), style: AppText.mono(size: 11, color: AppColors.background, weight: FontWeight.w700).copyWith(letterSpacing: 1.6)),
            const Spacer(),
            if (meta != null) Text(meta!.toUpperCase(), style: AppText.mono(size: 10.5, color: kConsoleDim)),
          ],
        ),
        Container(height: 1, color: Colors.white24, margin: const EdgeInsets.only(top: 8, bottom: 10)),
        child,
      ],
    ),
  );
}

/// Rotating radar: every account is a blip, riskier ones closer to the centre and in red.
class ThreatRadar extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;

  const ThreatRadar({super.key, required this.accounts});

  @override
  State<ThreatRadar> createState() => _ThreatRadarState();
}

class _ThreatRadarState extends State<ThreatRadar> with SingleTickerProviderStateMixin {
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
  Widget build(BuildContext context) {
    final hot = widget.accounts.where((a) => ((a['risk_score'] ?? 0) as num) >= 50).length;
    return InkPanel(
      title: 'Threat radar',
      meta: '$hot hot · ${widget.accounts.length} contacts',
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _RadarPainter(widget.accounts, _c.value)),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<Map<String, dynamic>> accounts;
  final double t;

  _RadarPainter(this.accounts, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawCircle(c, r * f, line);
    }
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), line);
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), line);
    for (final (f, label) in [(0.25, 'CRIT'), (0.5, 'HIGH'), (0.75, 'MED')]) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(3, -r * f - 10));
    }

    // Sweep: a fading wedge behind the leading edge.
    final sweep = t * 2 * pi - pi / 2;
    for (var i = 0; i < 24; i++) {
      final a = sweep - i * 0.035;
      canvas.drawLine(
        c,
        c + Offset(cos(a), sin(a)) * r,
        Paint()
          ..color = kConsoleRed.withAlpha((120 * (1 - i / 24)).round())
          ..strokeWidth = 2,
      );
    }

    for (var i = 0; i < accounts.length; i++) {
      final a = accounts[i];
      final risk = ((a['risk_score'] ?? 0) as num).toDouble().clamp(0, 100);
      // Spread blips evenly by a stable angle per account; riskier accounts sit closer to the centre.
      final angle = (i * 2.399963) % (2 * pi) - pi / 2;
      final dist = r * (0.12 + 0.85 * (1 - risk / 100));
      final pos = c + Offset(cos(angle), sin(angle)) * dist;
      final since = ((sweep - angle) % (2 * pi)) / (2 * pi); // 0 right after the sweep passes
      final glow = (1 - since * 3).clamp(0.0, 1.0);
      final color = risk >= 50 ? kConsoleRed : risk >= 25 ? const Color(0xFFE0A84A) : kConsoleGreen;
      canvas.drawCircle(pos, 4 + 7 * glow, Paint()..color = color.withAlpha((80 * glow).round()));
      canvas.drawCircle(pos, 3.5, Paint()..color = color.withAlpha(140 + (115 * glow).round()));
      if (glow > 0.05 || risk >= 50) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${a['service_name']}'.toUpperCase(),
            style: TextStyle(color: color.withAlpha(120 + (135 * glow).round()), fontSize: 9, fontFamily: 'monospace'),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 90);
        tp.paint(canvas, pos + const Offset(7, -6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}

/// Terminal that types out real per-account scan results, then keeps a heartbeat going.
class LiveConsole extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;

  const LiveConsole({super.key, required this.accounts});

  @override
  State<LiveConsole> createState() => _LiveConsoleState();
}

class _LiveConsoleState extends State<LiveConsole> {
  final List<(String, Color)> _lines = [];
  Timer? _timer;
  int _next = 0;
  int _beat = 0;

  late final List<(String, Color)> _script = [
    ('> privacyshield monitor --live', kConsoleDim),
    for (final a in widget.accounts) _scanLine(a),
    ('> scan complete · ${widget.accounts.length} targets · ${widget.accounts.where((a) => ((a['risk_score'] ?? 0) as num) >= 50).length} flagged', AppColors.background),
  ];

  (String, Color) _scanLine(Map<String, dynamic> a) {
    final name = (a['service_url'] ?? a['service_name']).toString().toLowerCase().replaceAll(RegExp(r'^https?://(www\.)?'), '');
    final twofa = a['has_2fa'] == true ? 'ON ' : a['has_2fa'] == false ? 'OFF' : '?? ';
    final reuse = (a['password_group'] ?? '').toString().isNotEmpty ? 'YES' : 'NO ';
    final breaches = (a['breach_count'] ?? 0) as int;
    final risk = ((a['risk_score'] ?? 0) as num).round();
    final flagged = risk >= 50 || breaches > 0;
    final shown = name.length > 14 ? '${name.substring(0, 13)}…' : name.padRight(14);
    return (
      'scan $shown 2FA:$twofa REUSE:$reuse BR:$breaches RISK:${risk.toString().padLeft(2)}${flagged ? ' ▲' : ''}',
      flagged ? kConsoleRed : kConsoleGreen,
    );
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) => _step());
  }

  Future<void> _step() async {
    if (_next < _script.length) {
      _lines.add(_script[_next++]);
    } else {
      // After the scan, keep a slow heartbeat against the real server.
      _beat++;
      if (_beat % 7 != 0) return;
      final sw = Stopwatch()..start();
      try {
        await http.get(Uri.parse('${ApiService().baseUrl}/health')).timeout(const Duration(seconds: 4));
        _lines.add(('heartbeat · server ok · ${sw.elapsedMilliseconds}ms', kConsoleDim));
      } catch (_) {
        _lines.add(('heartbeat · server unreachable', kConsoleRed));
      }
    }
    if (_lines.length > 40) _lines.removeAt(0);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _lines.length > 9 ? _lines.sublist(_lines.length - 9) : _lines;
    return InkPanel(
      title: 'Live scan',
      meta: _next < _script.length ? 'running' : 'monitoring',
      child: SizedBox(
        height: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final (text, color) in visible)
              Text(text, maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: AppText.mono(size: 10.5, color: color)),
            const _Cursor(),
          ],
        ),
      ),
    );
  }
}

class _Cursor extends StatefulWidget {
  const _Cursor();

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _c, child: Text('█', style: AppText.mono(size: 10.5, color: kConsoleGreen)));
}

/// Full-screen scan that runs through the user's accounts before the overview appears.
class BootScan extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final VoidCallback onDone;

  const BootScan({super.key, required this.accounts, required this.onDone});

  @override
  State<BootScan> createState() => _BootScanState();
}

class _BootScanState extends State<BootScan> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final n = widget.accounts.length;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: 900 + 180 * n.clamp(3, 14)))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDone,
      child: Container(
        color: AppColors.ink,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final n = widget.accounts.length;
            final shown = (n * (_c.value / 0.85)).clamp(0, n).floor();
            final flagged = widget.accounts.take(shown).where((a) => ((a['risk_score'] ?? 0) as num) >= 50).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRIVACYSHIELD // EXPOSURE SCAN', style: AppText.mono(size: 12, color: kConsoleRed, weight: FontWeight.w700).copyWith(letterSpacing: 1.5)),
                const SizedBox(height: 18),
                Text('${(_c.value * 100).round()}%', style: AppText.serif(size: 96, color: AppColors.background)),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  color: Colors.white12,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: _c.value, child: Container(color: kConsoleRed)),
                ),
                const SizedBox(height: 18),
                Text(
                  '$shown/$n ACCOUNTS CHECKED · $flagged FLAGGED',
                  style: AppText.mono(size: 12, color: AppColors.background).copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final a in widget.accounts.take(shown).toList().reversed.take(12))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '> ${a['service_name']}'.padRight(24) +
                                (((a['risk_score'] ?? 0) as num) >= 50 ? 'FLAGGED' : 'CLEAR'),
                            style: AppText.mono(
                              size: 12,
                              color: ((a['risk_score'] ?? 0) as num) >= 50 ? kConsoleRed : kConsoleGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text('TAP TO SKIP', style: AppText.mono(size: 10.5, color: kConsoleDim).copyWith(letterSpacing: 1.5)),
              ],
            );
          },
        ),
      ),
    );
  }
}
