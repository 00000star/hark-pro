import 'dart:math' as math;
import 'package:flutter/material.dart';

class DynamicPanelCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? accentColor;
  final String? badgeText;

  const DynamicPanelCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141620).withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (accentColor ?? Colors.white).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (accentColor ?? const Color(0xFF0A84FF)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: accentColor ?? const Color(0xFF0A84FF),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (accentColor ?? Colors.white).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      color: accentColor ?? Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          child,
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. FLIGHT TRACKER MINI-APP
// -------------------------------------------------------------
class FlightTrackerPanel extends StatelessWidget {
  const FlightTrackerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicPanelCard(
      title: "Delta Flight DL 412",
      icon: Icons.flight_rounded,
      accentColor: const Color(0xFFBF5AF2),
      badgeText: "ON TIME",
      child: Column(
        children: [
          // Route and Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("SFO",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  Text("San Francisco",
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  SizedBox(height: 2),
                  Text("08:15 AM",
                      style: TextStyle(
                          color: Color(0xFFBF5AF2),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      const Text(
                        "5h 30m • 2,586 mi",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Align(
                            alignment: const Alignment(-0.2, 0.0),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFBF5AF2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.flight_rounded,
                                  color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text("JFK",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  Text("New York",
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  SizedBox(height: 2),
                  Text("04:45 PM",
                      style: TextStyle(
                          color: Color(0xFFBF5AF2),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Flight Details Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1017),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem("Gate", "B22"),
                _buildDivider(),
                _buildInfoItem("Terminal", "T2"),
                _buildDivider(),
                _buildInfoItem("Seat", "14A"),
                _buildDivider(),
                _buildInfoItem("Baggage", "Claim 4"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  static Widget _buildDivider() {
    return Container(width: 1, height: 22, color: Colors.white12);
  }
}

// -------------------------------------------------------------
// 2. HEALTH & FITNESS MINI-APP
// -------------------------------------------------------------
class HealthFitnessPanel extends StatefulWidget {
  const HealthFitnessPanel({super.key});

  @override
  State<HealthFitnessPanel> createState() => _HealthFitnessPanelState();
}

class _HealthFitnessPanelState extends State<HealthFitnessPanel> {
  int _hydrationOz = 80;
  final int _hydrationGoal = 100;

  void _adjustHydration(int delta) {
    setState(() {
      _hydrationOz = (_hydrationOz + delta).clamp(0, 160);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicPanelCard(
      title: "Health & Activity",
      icon: Icons.favorite_rounded,
      accentColor: const Color(0xFFFF2D55),
      badgeText: "STREAK 14D",
      child: Column(
        children: [
          Row(
            children: [
              // Concentric Activity Rings
              SizedBox(
                width: 76,
                height: 76,
                child: CustomPaint(
                  painter: _ActivityRingsPainter(
                    moveProgress: 680 / 700,
                    exerciseProgress: 42 / 30,
                    standProgress: 11 / 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Activity Metrics
              Expanded(
                child: Column(
                  children: [
                    _buildMetricRow("Move", "680 / 700 kcal", const Color(0xFFFF2D55)),
                    const SizedBox(height: 6),
                    _buildMetricRow("Exercise", "42 / 30 min", const Color(0xFF30D158)),
                    const SizedBox(height: 6),
                    _buildMetricRow("Stand", "11 / 12 hrs", const Color(0xFF00E5FF)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Interactive Hydration Counter & Mileage Row
          Row(
            children: [
              // Mileage
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1017),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Weekly Distance",
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                      SizedBox(height: 3),
                      Text("24.8 mi",
                          style: TextStyle(
                              color: Color(0xFFFF9F0A),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Interactive Hydration Counter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1017),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Hydration Counter",
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("$_hydrationOz oz",
                              style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _adjustHydration(-8),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.remove,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () => _adjustHydration(8),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.black, size: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String name, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(name,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ActivityRingsPainter extends CustomPainter {
  final double moveProgress;
  final double exerciseProgress;
  final double standProgress;

  _ActivityRingsPainter({
    required this.moveProgress,
    required this.exerciseProgress,
    required this.standProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _drawRing(canvas, center, 32, 6.0, const Color(0xFFFF2D55), moveProgress);
    _drawRing(canvas, center, 23, 6.0, const Color(0xFF30D158), exerciseProgress);
    _drawRing(canvas, center, 14, 6.0, const Color(0xFF00E5FF), standProgress);
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double strokeWidth,
      Color color, double progress) {
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final sweepAngle = (progress * math.pi * 2).clamp(0.0, math.pi * 2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter oldDelegate) => true;
}

// -------------------------------------------------------------
// 3. HOME ENERGY MONITOR MINI-APP
// -------------------------------------------------------------
class HomeEnergyPanel extends StatefulWidget {
  const HomeEnergyPanel({super.key});

  @override
  State<HomeEnergyPanel> createState() => _HomeEnergyPanelState();
}

class _HomeEnergyPanelState extends State<HomeEnergyPanel> {
  int _targetTemp = 68;
  final int _currentTemp = 71;

  void _adjustTemp(int delta) {
    setState(() {
      _targetTemp = (_targetTemp + delta).clamp(60, 85);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicPanelCard(
      title: "Home Energy & Climate",
      icon: Icons.bolt_rounded,
      accentColor: const Color(0xFFFF9F0A),
      badgeText: "SOLAR ACTIVE",
      child: Column(
        children: [
          // Current Load & Solar Net
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1017),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Grid Consumption",
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                      SizedBox(height: 3),
                      Text("2.4 kW",
                          style: TextStyle(
                              color: Color(0xFFFF9F0A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text("Rate: \$0.42/kWh (Peak)",
                          style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1017),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Solar Array",
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                      SizedBox(height: 3),
                      Text("+3.8 kW",
                          style: TextStyle(
                              color: Color(0xFF30D158),
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text("Net Exporting to Grid",
                          style: TextStyle(color: Color(0xFF30D158), fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive Smart Thermostat Dial
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161A26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0A84FF).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A84FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.thermostat_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Nest Eco Thermostat",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        Text("Current Room: $_currentTemp°F",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ],
                ),

                // Interactive target temp adjuster
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _adjustTemp(-1),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.remove,
                            color: Colors.white, size: 14),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "$_targetTemp°F",
                        style: const TextStyle(
                          color: Color(0xFF0A84FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _adjustTemp(1),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A84FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. MEDIA / AUDIO MINI-APP
// -------------------------------------------------------------
class MediaAudioPanel extends StatefulWidget {
  const MediaAudioPanel({super.key});

  @override
  State<MediaAudioPanel> createState() => _MediaAudioPanelState();
}

class _MediaAudioPanelState extends State<MediaAudioPanel>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  double _progress = 0.44;
  late AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _equalizerController.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _equalizerController.repeat(reverse: true);
      } else {
        _equalizerController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicPanelCard(
      title: "Now Playing",
      icon: Icons.music_note_rounded,
      accentColor: const Color(0xFF30D158),
      badgeText: "AIRPLAY",
      child: Column(
        children: [
          Row(
            children: [
              // Vinyl / Album artwork
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF380036), Color(0xFF0CBABA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0CBABA).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.graphic_eq_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 14),

              // Track Info & Equalizer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Synthetic Horizons",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Hark Neural Audio • Ambient Focus",
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Animated Equalizer Bars
              if (_isPlaying)
                AnimatedBuilder(
                  animation: _equalizerController,
                  builder: (context, _) {
                    return Row(
                      children: List.generate(4, (index) {
                        final h = 6.0 +
                            math.sin(_equalizerController.value * math.pi + index) *
                                12.0;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 3,
                          height: h.abs() + 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF30D158),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive Progress Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: const Color(0xFF30D158),
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: _progress,
              onChanged: (v) => setState(() => _progress = v),
            ),
          ),

          // Time & Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("1:39",
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
              Row(
                children: [
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white70),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: _togglePlayback,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF30D158),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white70),
                    onPressed: () {},
                  ),
                ],
              ),
              const Text("3:45",
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
