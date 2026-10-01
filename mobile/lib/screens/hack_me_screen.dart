import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

/// "Hack Me" attack simulator: pick an account to be compromised and watch the attack spread.
class HackMeScreen extends StatefulWidget {
  /// Account to preselect as the entry point (e.g. from the risk graph).
  final int? entryAccountId;

  const HackMeScreen({super.key, this.entryAccountId});

  @override
  State<HackMeScreen> createState() => _HackMeScreenState();
}

const _viaLabel = {
  'sso': 'SSO sign-in',
  'recovery_email': 'Recovery email',
  'recovery_phone': 'Recovery phone',
  'password_reuse': 'Reused password',
  'device_trust': 'Trusted device',
  'data_sharing': 'Data sharing',
};

const _viaIcon = {
  'sso': Icons.login,
  'recovery_email': Icons.mark_email_read_outlined,
  'recovery_phone': Icons.sms_outlined,
  'password_reuse': Icons.key,
  'device_trust': Icons.devices,
  'data_sharing': Icons.share,
};

const _categoryIcon = {
  'email': Icons.email_outlined,
  'finance': Icons.account_balance,
  'social': Icons.people_outline,
  'cloud': Icons.cloud_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'work': Icons.work_outline,
  'gaming': Icons.sports_esports_outlined,
  'entertainment': Icons.movie_outlined,
};

String _twofaLabel(String? t) => switch (t) {
  'passkey' => 'Passkey',
  'hardware' => 'Security key',
  'totp' => '2FA app',
  'sms' => 'SMS 2FA',
  'none' => 'No 2FA',
  _ => '2FA unknown',
};

String _pct(num p) => '${(p * 100).round()}%';

/// One thing that happens in the animation: a successful hop or a stopped attempt.
class _Event {
  final Map<String, dynamic> data;
  final bool blocked;

  _Event(this.data, this.blocked);

  int get from => data['from_id'];
  int get to => data['to_id'];
  int get hop => data['hop'];
  double get elapsed => (data['elapsed_minutes'] as num).toDouble();
}

String _clock(double minutes) {
  final secs = (minutes * 60).round();
  return 'T+${(secs ~/ 3600).toString().padLeft(2, '0')}:${(secs ~/ 60 % 60).toString().padLeft(2, '0')}:'
      '${(secs % 60).toString().padLeft(2, '0')}';
}

String _duration(double minutes) {
  final secs = (minutes * 60).round();
  if (secs < 60) return '$secs seconds';
  final m = secs ~/ 60, rest = secs % 60;
  return rest == 0 ? '$m min' : '$m min ${rest}s';
}

class _HackMeScreenState extends State<HackMeScreen> with TickerProviderStateMixin {
  final _api = ApiService();
  late final AnimationController _anim;
  // Drives the shake, red flash and stamp each time an account falls.
  late final AnimationController _fx;
  final _graphKey = GlobalKey();
  bool _demo = false;
  int _lastDone = 0;
  _Event? _lastHit;

  List<Map<String, dynamic>> _entryPoints = [];
  int? _suggestedId;
  int? _entryId;
  bool _loadingEntries = true;
  bool _running = false;
  String? _error;

  Map<String, dynamic>? _result;
  bool _showAfter = false;
  Map<int, Offset> _layout = {};

  static const _msPerEvent = 1300;
  static const _entryMinutes = 2.0;

  String get _base => _demo ? '/attack-sim/demo' : '/attack-sim';

  Map<String, dynamic>? get _report => _result?[_showAfter ? 'after' : 'before'];

  List<_Event> get _events {
    final r = _report;
    if (r == null) return [];
    final events = [
      ...(r['steps'] as List).map((s) => _Event(s, false)),
      ...(r['blocked'] as List).map((b) => _Event(b, true)),
    ];
    // Spread outward hop by hop; stopped attempts show at the hop where they happened.
    events.sort((a, b) => a.elapsed != b.elapsed ? a.elapsed.compareTo(b.elapsed) : (a.blocked ? 1 : 0) - (b.blocked ? 1 : 0));
    return events;
  }

  @override
  void initState() {
    super.initState();
    // Created eagerly so dispose() never builds a controller on a deactivated widget.
    _anim = AnimationController(vsync: this)..addListener(_onTick);
    _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..addListener(() => setState(() {}));
    _loadEntryPoints();
  }

  @override
  void dispose() {
    _anim.dispose();
    _fx.dispose();
    super.dispose();
  }

  void _onTick() {
    final (done, _) = _progress;
    if (done > _lastDone) {
      final hit = _events[done - 1];
      _lastHit = hit;
      _fx.forward(from: 0);
      if (hit.blocked) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
    _lastDone = done;
    setState(() {});
  }

  void _switchSource(bool demo) {
    if (demo == _demo) return;
    _anim.stop();
    setState(() {
      _demo = demo;
      _result = null;
      _entryPoints = [];
      _entryId = null;
      _loadingEntries = true;
      _error = null;
    });
    _loadEntryPoints();
  }

  Future<void> _loadEntryPoints() async {
    try {
      final data = await _api.get('$_base/entry-points');
      final points = (data['entry_points'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _entryPoints = points;
        _suggestedId = data['suggested_id'];
        final wanted = widget.entryAccountId;
        _entryId = points.any((p) => p['id'] == wanted) ? wanted : (_suggestedId ?? (points.isEmpty ? null : points.first['id']));
      });
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loadingEntries = false);
    }
  }

  Future<void> _launch() async {
    if (_entryId == null) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final res = await _api.post('$_base/run', body: {'entry_account_id': _entryId, 'compare_fixes': true});
      setState(() {
        _result = res;
        _showAfter = false;
        _layout = {};
      });
      HapticFeedback.heavyImpact();
      _play();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _graphKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.05);
      });
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _play() {
    final n = _events.length;
    _lastDone = 0;
    _lastHit = null;
    // One beat for the entry account falling, then one per event.
    _anim.duration = Duration(milliseconds: (n + 1) * _msPerEvent + 600);
    _anim.forward(from: 0);
  }

  void _skip() => _anim.value = 1;

  void _toggleMode(bool after) {
    if (after == _showAfter) return;
    setState(() => _showAfter = after);
    _play();
  }

  /// Events fully shown, plus how far the current one has travelled (0..1).
  /// The first beat is the entry account being broken into, so events start after it.
  (int, double) get _progress {
    final n = _events.length;
    final ms = _anim.value * (_anim.duration?.inMilliseconds ?? 0) - _msPerEvent;
    if (n == 0 || ms <= 0) return (0, 0);
    final pos = (ms / _msPerEvent).clamp(0.0, n.toDouble());
    return (pos.floor(), pos - pos.floor());
  }

  bool get _entryFallen => _anim.value * (_anim.duration?.inMilliseconds ?? 0) >= _msPerEvent * 0.8;

  bool get _finished => _anim.isCompleted || (_result != null && !_anim.isAnimating && _anim.value == 1);

  /// Attack clock: the entry break-in, then each event's own timestamp.
  double get _clockMinutes {
    final events = _events;
    final ms = _anim.value * (_anim.duration?.inMilliseconds ?? 0);
    if (ms < _msPerEvent) return _entryMinutes * (ms / _msPerEvent);
    final (done, frac) = _progress;
    final prev = done == 0 ? _entryMinutes : events[done - 1].elapsed;
    if (done >= events.length) return prev;
    return prev + (events[done].elapsed - prev) * frac;
  }

  void _pickEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Which account gets hacked first?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Sorted by how far an attack could spread from it.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ..._entryPoints.map((p) {
              final selected = p['id'] == _entryId;
              return Card(
                color: selected ? AppColors.red.withAlpha(20) : AppColors.background,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: selected ? AppColors.red : AppColors.border),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _entryId = p['id']);
                  },
                  leading: Icon(_categoryIcon[p['category']] ?? Icons.apps, color: AppColors.textSecondary),
                  title: Row(
                    children: [
                      Flexible(child: Text(p['service'], overflow: TextOverflow.ellipsis)),
                      if (p['id'] == _suggestedId) ...[
                        const SizedBox(width: 6),
                        _Tag('MOST DANGEROUS', AppColors.red),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${p['category']} · ${_twofaLabel(p['twofa'])}${p['breached'] == true ? ' · breached' : ''}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p['reaches']}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: p['reaches'] > 0 ? AppColors.red : AppColors.green,
                        ),
                      ),
                      const Text('reachable', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hack Me simulator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _intro(),
          const SizedBox(height: 12),
          _sourceToggle(),
          const SizedBox(height: 12),
          if (_loadingEntries)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.red)),
            )
          else if (_entryPoints.isEmpty)
            _emptyState()
          else
            _entryPicker(),
          if (_error != null && _entryPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            if (_result!['after'] != null) _modeToggle(),
            const SizedBox(height: 8),
            KeyedSubtree(key: _graphKey, child: _graphCard()),
            if (_finished) ...[const SizedBox(height: 16), _verdict()],
            const SizedBox(height: 16),
            _damageReport(),
            const SizedBox(height: 16),
            if (_result!['after'] != null) _comparison(),
            _chain(),
          ],
        ],
      ),
    );
  }

  Widget _sourceToggle() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, icon: Icon(Icons.person_outline), label: Text('My accounts')),
      ButtonSegment(value: true, icon: Icon(Icons.science_outlined), label: Text('Sample network')),
    ],
    selected: {_demo},
    onSelectionChanged: (v) => _switchSource(v.first),
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        const Icon(Icons.bug_report_outlined, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(
          _error ?? 'You have no accounts to attack yet. Add a few (or run Smart Import), or try the sample network first.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (!_demo) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _switchSource(true),
            icon: const Icon(Icons.science_outlined),
            label: const Text('Try the sample network'),
          ),
        ],
      ],
    ),
  );

  Widget _intro() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
    child: const Row(
      children: [
        Icon(Icons.bug_report, color: AppColors.red, size: 36),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HACK ME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 3)),
              SizedBox(height: 4),
              Text(
                'Pretend one of your accounts is hacked and see exactly what an attacker could reach from there.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _entryPicker() {
    final entry = _entryPoints.firstWhere((p) => p['id'] == _entryId, orElse: () => _entryPoints.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Attack entry point', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickEntry,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(_categoryIcon[entry['category']] ?? Icons.apps, color: AppColors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry['service'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(
                        'Could reach ${entry['reaches']} other account${entry['reaches'] == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Text('Change', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
          onPressed: _running ? null : _launch,
          icon: _running
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow),
          label: Text(_result == null ? 'Launch attack' : 'Run again'),
        ),
      ],
    );
  }

  Widget _modeToggle() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, icon: Icon(Icons.lock_open), label: Text('Right now')),
      ButtonSegment(value: true, icon: Icon(Icons.verified_user_outlined), label: Text('After fixes')),
    ],
    selected: {_showAfter},
    onSelectionChanged: (s) => _toggleMode(s.first),
  );

  Map<int, Offset> _computeLayout(Size size) {
    // Positions come from the "right now" run so both modes line up for comparison.
    final before = _result!['before'];
    final nodes = (before['nodes'] as List).cast<Map<String, dynamic>>();
    final center = Offset(size.width / 2, size.height / 2);
    final maxHop = nodes.map((n) => (n['hop'] as int?) ?? 0).fold(0, max);
    final rings = maxHop + 1; // last ring holds accounts the attack never reached
    final radiusStep = (min(size.width, size.height) / 2 - 26) / max(1, rings);
    final byRing = <int, List<int>>{};
    for (final n in nodes) {
      final hop = n['hop'] as int?;
      byRing.putIfAbsent(hop ?? rings, () => []).add(n['id']);
    }
    final layout = <int, Offset>{};
    byRing.forEach((ring, ids) {
      final r = ring == 0 ? 0.0 : radiusStep * ring;
      final offset = ring * 0.6; // stagger rings so lines don't overlap
      for (var i = 0; i < ids.length; i++) {
        final angle = offset + 2 * pi * i / ids.length - pi / 2;
        layout[ids[i]] = center + Offset(cos(angle) * r, sin(angle) * r);
      }
    });
    return layout;
  }

  Widget _graphCard() {
    final events = _events;
    final (done, frac) = _progress;
    final finished = _finished;
    final report = _report!;
    final nodes = {for (final n in (report['nodes'] as List)) n['id'] as int: n as Map<String, dynamic>};
    final owned = (_entryFallen ? 1 : 0) + events.take(done).where((e) => !e.blocked).length;
    final blocked = events.take(done).where((e) => e.blocked).length;
    final money =
        events.take(done).where((e) => !e.blocked && nodes[e.to]?['category'] == 'finance').length +
        (_entryFallen && report['entry']['category'] == 'finance' ? 1 : 0);

    // Shake and flash peak right after an account falls, then settle.
    final fx = _fx.isAnimating ? 1 - _fx.value : 0.0;
    final hitWasBlocked = _lastHit?.blocked ?? false;
    final shake = hitWasBlocked ? 0.0 : sin(_fx.value * pi * 10) * 7 * fx;
    const green = Color(0xFF7BD389), red = Color(0xFFE5482F);

    return Transform.translate(
      offset: Offset(shake, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color.lerp(Colors.white12, hitWasBlocked ? green : red, fx)!, width: 1 + 2 * fx),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                _Blink(on: !finished, child: const Icon(Icons.circle, size: 10, color: red)),
                const SizedBox(width: 6),
                Text(
                  finished ? 'SIMULATION COMPLETE' : 'ATTACK IN PROGRESS',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _clock(_clockMinutes),
                  style: const TextStyle(color: red, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Counter('$owned/${nodes.length}', 'OWNED', red),
                _Counter('$money', 'MONEY ACCTS', const Color(0xFFE59A2F)),
                _Counter('$blocked', 'BLOCKED', green),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (_, box) {
                      if (_layout.isEmpty) _layout = _computeLayout(box.biggest);
                      return CustomPaint(
                        painter: _AttackPainter(
                          layout: _layout,
                          nodes: nodes,
                          entryId: report['entry']['id'],
                          entryFallen: _entryFallen,
                          events: events,
                          done: done,
                          frac: frac,
                          pulse: _anim.value,
                        ),
                      );
                    },
                  ),
                ),
                if (fx > 0 && !hitWasBlocked)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.red.withAlpha((70 * fx).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (fx > 0 && _lastHit != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: fx.clamp(0.0, 1.0),
                          child: Transform.rotate(
                            angle: -0.18,
                            child: Transform.scale(
                              scale: 1.3 - 0.3 * fx,
                              child: _Stamp(
                                hitWasBlocked ? 'BLOCKED' : 'ACCESS GRANTED',
                                '${_lastHit!.data['to']}',
                                hitWasBlocked ? green : red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _terminal(events, done, frac, finished),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _play,
                  icon: const Icon(Icons.replay, color: Colors.white70),
                  label: const Text('Replay', style: TextStyle(color: Colors.white70)),
                ),
                const Spacer(),
                const _Legend(color: red, label: 'Owned'),
                const SizedBox(width: 8),
                const _Legend(color: green, label: 'Blocked'),
                if (!finished) const Spacer(),
                if (!finished)
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Skip to the end', style: TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Hacker-console log that types itself out as the attack plays.
  Widget _terminal(List<_Event> events, int done, double frac, bool finished) {
    final report = _report!;
    final entry = report['entry'];
    const dim = Color(0xFF8FA39A), red = Color(0xFFE5482F), green = Color(0xFF7BD389);
    final lines = <(String, Color)>[];
    String t(double m) => _clock(m).substring(2);
    String typed(String text, double fraction) => text.substring(0, (text.length * fraction.clamp(0.0, 1.0)).round());

    final ms = _anim.value * (_anim.duration?.inMilliseconds ?? 0);
    final entryLine =
        '[${t(0)}] > target: ${entry['service']}'
        '${entry['breached'] == true ? ' (password in a public breach)' : ' (phishing link sent)'}';
    lines.add((typed(entryLine, ms / (_msPerEvent * 0.8)), dim));
    if (_entryFallen) lines.add(('        ${entry['service']} :: ACCESS GRANTED', red));

    for (var i = 0; i < events.length && i <= done; i++) {
      final e = events[i];
      final from = e.data['from'], to = e.data['to'];
      final verb = switch (e.data['via']) {
        'sso' => 'pivot via "Sign in with $from" -> $to',
        'recovery_email' => 'reset $to password, code lands in $from',
        'recovery_phone' => 'SIM-swap to catch the $to reset code',
        'password_reuse' => 'replay $from password on $to',
        'device_trust' => 'use trusted $from device on $to',
        'data_sharing' => 'pull data $from shares with $to',
        _ => '$from -> $to',
      };
      lines.add((typed('[${t(e.elapsed)}] > $verb', i < done ? 1 : frac * 1.6), dim));
      if (i < done) {
        lines.add(
          e.blocked
              ? ('        DENIED :: ${e.data['explanation'].toString().split(': ').last}', green)
              : ('        $to :: ACCESS GRANTED (${_pct(e.data['probability'])})', red),
        );
      }
    }
    if (finished) {
      final d = report['damage'];
      lines.add(
        (report['steps'] as List).isEmpty
            ? ('> attack contained. nothing else reachable.', green)
            : (
                '> done. ${d['accounts_reachable'] + 1} accounts owned in '
                    '${_duration((d['time_to_full_takeover_minutes'] as num).toDouble())}.',
                red,
              ),
      );
    }

    final visible = lines.length > 9 ? lines.sublist(lines.length - 9) : lines;
    return Container(
      width: double.infinity,
      height: 172,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final (text, color) in visible)
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11, height: 1.35),
            ),
          if (!finished)
            _Blink(
              on: true,
              child: const Text('_', style: TextStyle(color: green, fontFamily: 'monospace')),
            ),
        ],
      ),
    );
  }

  /// The punchline once the playback ends.
  Widget _verdict() {
    final report = _report!;
    final d = report['damage'];
    final contained = (report['steps'] as List).isEmpty;
    final consequences = (d['consequences'] as List).cast<String>();
    final owned = d['accounts_reachable'] + 1;
    final color = contained ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withAlpha(90), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contained ? 'ATTACK CONTAINED' : "YOU'VE BEEN OWNED",
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            contained
                ? 'Losing ${report['entry']['service']} stays a one-account problem. Nothing else can be reached from it.'
                : 'In ${_duration((d['time_to_full_takeover_minutes'] as num).toDouble())}, one hacked '
                      '${report['entry']['service']} account hands an attacker $owned of your ${d['total_accounts']} accounts.',
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
          ),
          if (!contained) ...[
            const SizedBox(height: 12),
            ...consequences.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✖  ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(c, style: const TextStyle(color: Colors.white))),
                  ],
                ),
              ),
            ),
            if (_result!['after'] != null && !_showAfter) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                onPressed: () => _toggleMode(true),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Replay it with the fixes done'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _damageReport() {
    final d = _report!['damage'];
    final finance = (d['financial_accounts_at_risk'] as List).cast<Map<String, dynamic>>();
    final data = (d['data_exposed'] as List).cast<Map<String, dynamic>>();
    final score = d['damage_score'] as int;
    return _Card(
      title: _showAfter ? 'Damage report · after fixes' : 'Damage report',
      icon: Icons.assessment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Big('${d['accounts_reachable']}', 'of ${d['total_accounts'] - 1} accounts\nreachable', AppColors.red),
              _Big('${finance.length}', 'financial\naccounts at risk', AppColors.orange),
              _Big('${d['attacks_blocked']}', 'attacks\nblocked', AppColors.green),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${d['likely']} likely · ${d['possible']} possible · spreads ${d['max_hops']} hop${d['max_hops'] == 1 ? '' : 's'} deep',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Damage score', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$score / 100', style: TextStyle(fontWeight: FontWeight.bold, color: _damageColor(score))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 10,
              backgroundColor: AppColors.border,
              color: _damageColor(score),
            ),
          ),
          if (finance.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Money at risk', style: TextStyle(fontWeight: FontWeight.w600)),
            ...finance.map(
              (f) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance, color: AppColors.orange),
                title: Text(f['service']),
                trailing: Text('${_pct(f['probability'])} likely'),
              ),
            ),
          ],
          if (data.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Data the attacker gets', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data
                  .map(
                    (x) => Tooltip(
                      message: (x['services'] as List).join(', '),
                      child: _Tag('${x['type']} · ${(x['services'] as List).length}', AppColors.purple),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _damageColor(int score) => score >= 60
      ? AppColors.red
      : score >= 30
      ? AppColors.orange
      : AppColors.green;

  Widget _comparison() {
    final b = _result!['before']['damage'];
    final a = _result!['after']['damage'];
    final fixes = (_result!['fixes_applied'] as List).cast<Map<String, dynamic>>();
    final prev = _result!['previous_run'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _Card(
        title: 'Before / After',
        icon: Icons.compare_arrows,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompareRow('Accounts reachable', b['accounts_reachable'], a['accounts_reachable']),
            _CompareRow(
              'Financial accounts at risk',
              (b['financial_accounts_at_risk'] as List).length,
              (a['financial_accounts_at_risk'] as List).length,
            ),
            _CompareRow('Damage score', b['damage_score'], a['damage_score']),
            const SizedBox(height: 10),
            Text(
              fixes.isEmpty
                  ? 'No recommended fixes left. Your network is already as tight as PrivacyShield can suggest.'
                  : '"After fixes" assumes you complete these ${fixes.length} recommended fix(es):',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            ...fixes.take(8).map(
              (f) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: AppColors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f['label'], style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
            if (fixes.length > 8)
              Text('+ ${fixes.length - 8} more', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            if (fixes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Mark fixes done on the Overview page, then tap "Run again" to see your real attack chain shrink.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            if (prev != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.history, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Last run from this account${_date(prev['at'])}: ${prev['accounts_reachable']} reachable, '
                      'damage ${prev['damage_score']}. Now: ${b['accounts_reachable']} reachable, damage ${b['damage_score']}.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    return t == null ? '' : ' (${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')})';
  }

  Widget _chain() {
    final r = _report!;
    final steps = (r['steps'] as List).cast<Map<String, dynamic>>();
    final blocked = (r['blocked'] as List).cast<Map<String, dynamic>>();
    return _Card(
      title: 'Attack chain',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChainTile(
            icon: Icons.bug_report,
            color: AppColors.red,
            title: '${r['entry']['service']} is compromised',
            subtitle: 'Entry point${r['entry']['breached'] == true ? ' · already in a breach' : ''}',
          ),
          ...steps.map(
            (s) => _ChainTile(
              icon: _viaIcon[s['via']] ?? Icons.arrow_forward,
              color: s['likelihood'] == 'likely' ? AppColors.red : AppColors.orange,
              title: '${s['to']}  ·  ${_viaLabel[s['via']] ?? s['via']}',
              subtitle: '${s['explanation']}. Hop ${s['hop']}, ${_pct(s['probability'])} likely.',
            ),
          ),
          ...blocked.map(
            (b) => _ChainTile(
              icon: Icons.shield,
              color: AppColors.green,
              title: '${b['to']}  ·  blocked',
              subtitle: b['explanation'],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttackPainter extends CustomPainter {
  final Map<int, Offset> layout;
  final Map<int, Map<String, dynamic>> nodes;
  final int entryId;
  final bool entryFallen;
  final List<_Event> events;
  final int done;
  final double frac;
  final double pulse;

  _AttackPainter({
    required this.layout,
    required this.nodes,
    required this.entryId,
    required this.entryFallen,
    required this.events,
    required this.done,
    required this.frac,
    required this.pulse,
  });

  static const _red = Color(0xFFE5482F);
  static const _green = Color(0xFF7BD389);

  @override
  void paint(Canvas canvas, Size size) {
    final center = layout[entryId] ?? size.center(Offset.zero);
    // Hop rings for orientation.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white10;
    final radii = layout.values.map((p) => (p - center).distance).where((d) => d > 1).toSet();
    for (final r in radii) {
      canvas.drawCircle(center, r, ring);
    }

    final taken = <int>{if (entryFallen) entryId};
    final shielded = <int>{};
    for (var i = 0; i < events.length && i <= done; i++) {
      final e = events[i];
      final a = layout[e.from], b = layout[e.to];
      if (a == null || b == null) continue;
      final t = i < done ? 1.0 : frac;
      if (t <= 0) continue;
      final end = Offset.lerp(a, b, e.blocked ? min(t, 0.82) : t)!;
      final paint = Paint()
        ..strokeWidth = e.blocked ? 2 : 3
        ..strokeCap = StrokeCap.round
        ..color = e.blocked ? _green.withAlpha(200) : _red;
      if (e.blocked) {
        _dashed(canvas, a, end, paint);
      } else {
        canvas.drawLine(a, end, paint);
        if (t >= 1) _arrow(canvas, a, b, paint);
      }
      if (t >= 1) (e.blocked ? shielded : taken).add(e.to);
    }

    for (final entry in layout.entries) {
      final id = entry.key, p = entry.value;
      final node = nodes[id];
      if (node == null) continue;
      final isEntry = id == entryId && entryFallen;
      final isTaken = taken.contains(id);
      final isShielded = shielded.contains(id);
      final dataOnly = node['status'] == 'data_exposed';
      final fill = isEntry
          ? _red
          : isTaken
          ? (dataOnly ? const Color(0xFFE59A2F) : _red.withAlpha(220))
          : isShielded
          ? _green.withAlpha(60)
          : Colors.white12;
      if (isEntry || isTaken) {
        final glow = 14 + 6 * sin(pulse * pi * 8).abs();
        canvas.drawCircle(p, glow, Paint()..color = fill.withAlpha(50));
      }
      canvas.drawCircle(p, 11, Paint()..color = fill);
      canvas.drawCircle(
        p,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = isShielded ? _green : Colors.white38,
      );
      if (isShielded) {
        final tp = TextPainter(text: const TextSpan(text: '🛡', style: TextStyle(fontSize: 11)), textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
      final label = TextPainter(
        text: TextSpan(
          text: node['service'],
          style: TextStyle(
            color: isEntry || isTaken ? Colors.white : Colors.white60,
            fontSize: 10,
            fontWeight: isEntry ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 80);
      label.paint(canvas, p + Offset(-label.width / 2, 14));
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (double d = 0; d < total; d += 9) {
      canvas.drawLine(a + dir * d, a + dir * min(d + 5, total), paint);
    }
  }

  void _arrow(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dir = (b - a) / (b - a).distance;
    final tip = b - dir * 13;
    final normal = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - dir * 8 + normal * 5).dx, (tip - dir * 8 + normal * 5).dy)
      ..lineTo((tip - dir * 8 - normal * 5).dx, (tip - dir * 8 - normal * 5).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = paint.color);
  }

  @override
  bool shouldRepaint(covariant _AttackPainter old) => true;
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Big extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Big(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    ),
  );
}

class _CompareRow extends StatelessWidget {
  final String label;
  final int before;
  final int after;

  const _CompareRow(this.label, this.before, this.after);

  @override
  Widget build(BuildContext context) {
    final better = after < before;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$before', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.red)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
          ),
          Text(
            '$after',
            style: TextStyle(fontWeight: FontWeight.bold, color: better ? AppColors.green : AppColors.textSecondary),
          ),
          if (better)
            Text('  −${before - after}', style: const TextStyle(color: AppColors.green, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChainTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ChainTile({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: CircleAvatar(radius: 16, backgroundColor: color.withAlpha(28), child: Icon(icon, size: 16, color: color)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}


class _Counter extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Counter(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.2)),
      ],
    ),
  );
}

class _Stamp extends StatelessWidget {
  final String title;
  final String target;
  final Color color;

  const _Stamp(this.title, this.target, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(170),
      border: Border.all(color: color, width: 3),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
        Text(target.toUpperCase(), style: TextStyle(color: color, fontSize: 12, letterSpacing: 1.5)),
      ],
    ),
  );
}

/// Blinks its child while [on], like a recording light or a terminal cursor.
class _Blink extends StatefulWidget {
  final bool on;
  final Widget child;

  const _Blink({required this.on, required this.child});

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  // Created up front: a lazy controller would first be built inside dispose() when the blink was never on.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.on ? FadeTransition(opacity: _c, child: widget.child) : Opacity(opacity: 0.4, child: widget.child);
}
