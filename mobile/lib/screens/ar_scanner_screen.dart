import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class ARScannerScreen extends StatefulWidget {
  const ARScannerScreen({super.key});

  @override
  State<ARScannerScreen> createState() => _ARScannerScreenState();
}

class _ARScannerScreenState extends State<ARScannerScreen>
    with TickerProviderStateMixin {
  int _activeMode = 0; // 0: RF / WiFi, 1: App Sensors, 2: BLE Trackers
  bool _scanning = true;
  late AnimationController _radarCtrl;
  late AnimationController _laserCtrl;
  late AnimationController _pulseCtrl;

  // Track mitigated threats
  final Set<String> _mitigated = {};

  final List<Map<String, dynamic>> _wifiThreats = [
    {
      'id': 'wf_1',
      'title': 'CoffeeShop_Free_Guest',
      'subtitle': 'Open Captive Portal (No Encryption)',
      'bssid': 'E4:95:6E:81:4A:20',
      'channel': 'CH 6 (2.437 GHz)',
      'signal': -42,
      'risk': 'critical',
      'vector': 'Man-in-the-Middle & DNS spoofing vulnerability. Cleartext traffic can be sniffed.',
      'action': 'Disable Auto-Join & Route via WireGuard VPN',
      'icon': Icons.wifi_off,
    },
    {
      'id': 'wf_2',
      'title': 'Airport_Express_Secure?',
      'subtitle': 'Suspected Rogue AP (Evil Twin Attack)',
      'bssid': '70:3A:0E:99:BC:11',
      'channel': 'CH 36 (5.180 GHz)',
      'signal': -68,
      'risk': 'high',
      'vector': 'Cloned SSID with duplicate BSSID beaconing high power to trick phones.',
      'action': 'Isolate Network & Blacklist MAC',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'id': 'wf_3',
      'title': 'Office_Guest_WPA2',
      'subtitle': 'Outdated WPA2-TKIP Protocol',
      'bssid': 'A0:B1:C2:33:44:55',
      'channel': 'CH 11 (2.462 GHz)',
      'signal': -75,
      'risk': 'medium',
      'vector': 'Vulnerable to KRACK key reinstallation exploit. Handshake easily cracked.',
      'action': 'Enforce WPA3-Personal Only',
      'icon': Icons.lock_open,
    },
  ];

  final List<Map<String, dynamic>> _sensorThreats = [
    {
      'id': 'sn_1',
      'title': 'VoiceAssistant_Background',
      'subtitle': 'Continuous Microphone Hook Active',
      'bssid': 'PID: 18402 | 4.2h background',
      'channel': 'AUDIO_RECORD',
      'signal': -30,
      'risk': 'critical',
      'vector': 'Actively polling audio buffer even when screen is locked without foreground service notification.',
      'action': 'Revoke Microphone Permission & Force Stop',
      'icon': Icons.mic_off,
    },
    {
      'id': 'sn_2',
      'title': 'PhotoEditor_Pro',
      'subtitle': 'Background Clipboard & GPS Polling',
      'bssid': 'PID: 9281 | 12 clipboard reads',
      'channel': 'CLIPBOARD_PASTE',
      'signal': -55,
      'risk': 'high',
      'vector': 'Silently reading system pasteboard every 15 seconds. May capture 2FA tokens and passwords.',
      'action': 'Restrict Pasteboard Access & Revoke GPS',
      'icon': Icons.content_paste_off,
    },
    {
      'id': 'sn_3',
      'title': 'SocialFeed_App',
      'subtitle': 'Precise Location Tracking in Background',
      'bssid': 'PID: 3341 | 180 GPS queries/day',
      'channel': 'ACCESS_FINE_LOCATION',
      'signal': -70,
      'risk': 'medium',
      'vector': 'Compiling minute-by-minute movement history shared with advertising exchange brokers.',
      'action': 'Downgrade to Approximate Location Only',
      'icon': Icons.location_off,
    },
  ];

  final List<Map<String, dynamic>> _bleThreats = [
    {
      'id': 'ble_1',
      'title': 'Unknown AirTag / FindMy Beacon',
      'subtitle': 'Following user for > 45 minutes',
      'bssid': 'UUID: 4F2A-88D1 | RSSI: -48 dBm',
      'channel': 'BLE Adv (2.402 GHz)',
      'signal': -48,
      'risk': 'critical',
      'vector': 'Persistent Bluetooth Low Energy advertising beacon detected in 4 separate locations.',
      'action': 'Play Sound & Generate Serial Deactivation Report',
      'icon': Icons.fmd_bad,
    },
    {
      'id': 'ble_2',
      'title': 'Commercial Retail Beacon',
      'subtitle': 'Footfall Profiling & Proximity Ping',
      'bssid': 'Eddystone-UID: B9407F30',
      'channel': 'BLE Ch 37',
      'signal': -62,
      'risk': 'low',
      'vector': 'Storefront scanner recording MAC rotation and duration of dwell time.',
      'action': 'Randomize Bluetooth Address & Silence BLE',
      'icon': Icons.bluetooth_disabled,
    },
  ];

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _laserCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _currentThreats {
    switch (_activeMode) {
      case 1:
        return _sensorThreats;
      case 2:
        return _bleThreats;
      default:
        return _wifiThreats;
    }
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'critical':
        return AppColors.red;
      case 'high':
        return AppColors.orange;
      case 'medium':
        return AppColors.blue;
      case 'low':
        return AppColors.green;
      default:
        return AppColors.cyan;
    }
  }

  void _toggleMitigation(String id) {
    setState(() {
      if (_mitigated.contains(id)) {
        _mitigated.remove(id);
      } else {
        _mitigated.add(id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _mitigated.contains(id) ? AppColors.green : AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              _mitigated.contains(id) ? Icons.shield : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _mitigated.contains(id)
                    ? 'Countermeasure deployed. Vector neutralized!'
                    : 'Mitigation reset.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threats = _currentThreats;
    final pendingCount = threats.where((t) => !_mitigated.contains(t['id'])).length;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A).withAlpha(220),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withAlpha(120),
                    blurRadius: 10,
                  ),
                ],
                gradient: const RadialGradient(
                  colors: [AppColors.cyan, Color(0xFF0E7490)],
                ),
              ),
              child: const Icon(Icons.radar, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'AR PRIVACY RADAR',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _scanning ? AppColors.cyan.withAlpha(30) : AppColors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _scanning ? AppColors.cyan.withAlpha(150) : AppColors.green.withAlpha(150),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _scanning ? AppColors.cyan : AppColors.green,
                    boxShadow: [
                      BoxShadow(
                        color: _scanning ? AppColors.cyan : AppColors.green,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _scanning ? 'SWEEPING' : 'LOCKED',
                  style: TextStyle(
                    color: _scanning ? AppColors.cyan : AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Mode Selector Tabs
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF131D31),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withAlpha(15)),
              ),
              child: Row(
                children: [
                  _modeButton(0, Icons.wifi, 'RF / WiFi'),
                  _modeButton(1, Icons.mic, 'App Sensors'),
                  _modeButton(2, Icons.fmd_bad, 'BLE Trackers'),
                ],
              ),
            ),
          ),

          // Cyber Holographic Viewfinder HUD
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 250,
              decoration: BoxDecoration(
                color: const Color(0xFF060B14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cyan.withAlpha(80), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withAlpha(35),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Canvas HUD Reticle
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_radarCtrl, _laserCtrl, _pulseCtrl]),
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _CyberHUDPainter(
                              radarAngle: _radarCtrl.value * 2 * pi,
                              laserProgress: _laserCtrl.value,
                              pulseValue: _pulseCtrl.value,
                              activeMode: _activeMode,
                            ),
                          );
                        },
                      ),
                    ),

                    // Top Telemetry Header
                    Positioned(
                      top: 12,
                      left: 14,
                      right: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lens, color: AppColors.red, size: 8),
                              const SizedBox(width: 6),
                              Text(
                                _activeMode == 0
                                    ? 'FREQ: 2.4 / 5.8 GHz [HYBRID]'
                                    : _activeMode == 1
                                        ? 'KERNEL PROBES: 4 ACTIVE'
                                        : 'BLE ADV CH: 37, 38, 39',
                                style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.cyan.withAlpha(100)),
                            ),
                            child: Text(
                              'THREATS: $pendingCount',
                              style: TextStyle(
                                color: pendingCount > 0 ? AppColors.red : AppColors.green,
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Telemetry Coordinates
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AZIMUTH: 042° NNE | RSSI: -48 dBm',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            'PROTOCOL: AEAD-256',
                            style: TextStyle(
                              color: AppColors.cyan.withAlpha(180),
                              fontFamily: 'monospace',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center Target Lock Box
                    Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: pendingCount > 0
                                ? AppColors.red.withAlpha(180)
                                : AppColors.cyan.withAlpha(180),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            pendingCount > 0 ? Icons.warning_rounded : Icons.shield_outlined,
                            color: pendingCount > 0 ? AppColors.red : AppColors.cyan,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Live Threat Spectrum Stats Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D31),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withAlpha(15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.red.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_moon, color: AppColors.red, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$pendingCount Active Vectors',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Text(
                                'Immediate exposure risk',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cyan.withAlpha(80)),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() => _mitigated.clear());
                      },
                      child: const Center(
                        child: Text(
                          'RESET',
                          style: TextStyle(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Threat Cards Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _activeMode == 0
                        ? 'DETECTED RADIO ANOMALIES'
                        : _activeMode == 1
                            ? 'ACTIVE SURVEILLANCE HOOKS'
                            : 'DETECTED STALKER BEACONS',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${threats.length} Targets',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Threat Cards List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final t = threats[index];
                final isDone = _mitigated.contains(t['id']);
                final color = isDone ? AppColors.green : _riskColor(t['risk']);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D31),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDone ? AppColors.green.withAlpha(80) : color.withAlpha(90),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDone ? AppColors.green : color).withAlpha(18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color.withAlpha(80)),
                              ),
                              child: Icon(t['icon'] as IconData, color: color, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t['title'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                            color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withAlpha(30),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: color.withAlpha(120)),
                                        ),
                                        child: Text(
                                          isDone ? 'NEUTRALIZED' : t['risk'].toString().toUpperCase(),
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    t['subtitle'],
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Technical Vector Pill
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(100),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withAlpha(10)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.code, color: AppColors.cyan, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${t['bssid']}  |  ${t['channel']}',
                                  style: const TextStyle(
                                    color: AppColors.cyan,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Text(
                                '${t['signal']} dBm',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Risk Vector Explainer
                        const SizedBox(height: 10),
                        Text(
                          t['vector'],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),

                        // Action Button
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _toggleMitigation(t['id']),
                            icon: Icon(
                              isDone ? Icons.check_circle : Icons.shield,
                              size: 16,
                              color: isDone ? Colors.white : Colors.black,
                            ),
                            label: Text(
                              isDone ? 'NEUTRALIZED — TAP TO RESTORE' : t['action'],
                              style: TextStyle(
                                color: isDone ? Colors.white : Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDone ? const Color(0xFF065F46) : color,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: threats.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _modeButton(int index, IconData icon, String label) {
    final active = _activeMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeMode = index;
            _scanning = true;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.cyan.withAlpha(100),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.black : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.black : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cybernetic Reticle HUD Painter
class _CyberHUDPainter extends CustomPainter {
  final double radarAngle;
  final double laserProgress;
  final double pulseValue;
  final int activeMode;

  _CyberHUDPainter({
    required this.radarAngle,
    required this.laserProgress,
    required this.pulseValue,
    required this.activeMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.42;

    // 1. Grid matrix lines
    final gridPaint = Paint()
      ..color = AppColors.cyan.withAlpha(18)
      ..strokeWidth = 1.0;

    const gridStep = 24.0;
    for (double x = 0; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Concentric Radar Rings
    final ringPaint = Paint()
      ..color = AppColors.cyan.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), ringPaint);
    }

    // 3. Compass Azimuth Crosshairs & Ticks
    final crossPaint = Paint()
      ..color = AppColors.cyan.withAlpha(70)
      ..strokeWidth = 1.2;

    canvas.drawLine(Offset(center.dx - maxRadius - 10, center.dy),
        Offset(center.dx + maxRadius + 10, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius - 10),
        Offset(center.dx, center.dy + maxRadius + 10), crossPaint);

    // 4. Rotating Radar Sweep Beam (SweepGradient Shader)
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: pi * 0.6,
        colors: [
          Colors.transparent,
          AppColors.cyan.withAlpha(120),
        ],
        transform: GradientRotation(radarAngle),
      ).createShader(sweepRect);

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // 5. Laser Bar Scanning Top-to-Bottom
    final laserY = size.height * laserProgress;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.cyan.withAlpha(200),
          Colors.white,
          AppColors.cyan.withAlpha(200),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, laserY, size.width, 3))
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(0, laserY), Offset(size.width, laserY), laserPaint);

    // 6. Threat Signal Blips on Radar
    _drawBlip(canvas, center, maxRadius * 0.45, 0.85, AppColors.red);
    _drawBlip(canvas, center, maxRadius * 0.75, 2.4, AppColors.orange);
    _drawBlip(canvas, center, maxRadius * 0.90, 4.1, AppColors.cyan);

    // 7. Corner HUD Reticle Brackets
    _drawCornerHUD(canvas, 14, 14, 24, true, true);
    _drawCornerHUD(canvas, size.width - 14, 14, 24, false, true);
    _drawCornerHUD(canvas, 14, size.height - 14, 24, true, false);
    _drawCornerHUD(canvas, size.width - 14, size.height - 14, 24, false, false);
  }

  void _drawBlip(Canvas canvas, Offset center, double distance, double angle, Color color) {
    final blipPos = Offset(
      center.dx + distance * cos(angle),
      center.dy + distance * sin(angle),
    );

    final blipCore = Paint()..color = color;
    canvas.drawCircle(blipPos, 4, blipCore);

    final blipPulse = Paint()
      ..color = color.withAlpha((180 * (1 - pulseValue)).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(blipPos, 4 + (pulseValue * 10), blipPulse);
  }

  void _drawCornerHUD(Canvas canvas, double x, double y, double len, bool left, bool top) {
    final p = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final dx = left ? len : -len;
    final dy = top ? len : -len;

    path.moveTo(x + dx, y);
    path.lineTo(x, y);
    path.lineTo(x, y + dy);

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CyberHUDPainter oldDelegate) => true;
}
