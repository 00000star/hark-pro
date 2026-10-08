import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SkyPhase {
  dawn,
  midday,
  sunset,
  night,
}

class LivingSkyBackground extends StatefulWidget {
  final Widget child;
  final SkyPhase? forcedPhase; // Allows manual preview/selection if desired

  const LivingSkyBackground({
    super.key,
    required this.child,
    this.forcedPhase,
  });

  static SkyPhase getCurrentPhase([DateTime? time]) {
    final now = time ?? DateTime.now();
    final hour = now.hour;
    if (hour >= 6 && hour < 9) {
      return SkyPhase.dawn;
    } else if (hour >= 9 && hour < 17) {
      return SkyPhase.midday;
    } else if (hour >= 17 && hour < 20) {
      return SkyPhase.sunset;
    } else {
      return SkyPhase.night;
    }
  }

  static String getPhaseDisplayName(SkyPhase phase) {
    switch (phase) {
      case SkyPhase.dawn:
        return 'Dawn Aurora (6-9 AM)';
      case SkyPhase.midday:
        return 'Midday Cerulean (9 AM-5 PM)';
      case SkyPhase.sunset:
        return 'Sunset Twilight (5-8 PM)';
      case SkyPhase.night:
        return 'Obsidian Indigo (8 PM-6 AM)';
    }
  }

  @override
  State<LivingSkyBackground> createState() => _LivingSkyBackgroundState();
}

class _LivingSkyBackgroundState extends State<LivingSkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.forcedPhase ?? LivingSkyBackground.getCurrentPhase();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _LivingAtmospherePainter(
            phase: phase,
            animationValue: _controller.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;

  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });
}

class _LivingAtmospherePainter extends CustomPainter {
  final SkyPhase phase;
  final double animationValue;

  static late final List<_Star> _stars = _generateStars();

  _LivingAtmospherePainter({
    required this.phase,
    required this.animationValue,
  });

  static List<_Star> _generateStars() {
    final rand = math.Random(1337); // Fixed seed for stable star positions
    return List.generate(65, (_) {
      return _Star(
        x: rand.nextDouble(),
        y: rand.nextDouble() * 0.75, // Stars primarily in upper sky
        size: 0.8 + rand.nextDouble() * 1.8,
        phase: rand.nextDouble() * math.pi * 2,
        speed: 1.0 + rand.nextDouble() * 2.5,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base Atmospheric Sky Gradient
    final skyColors = _getSkyColors(phase);
    final skyStops = _getSkyStops(phase);

    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: skyColors,
      stops: skyStops,
    );

    final skyPaint = Paint()..shader = skyGradient.createShader(rect);
    canvas.drawRect(rect, skyPaint);

    final time = animationValue * math.pi * 2;

    // 2. Night Stars (Twinkling with procedural sinusoidal brightness)
    if (phase == SkyPhase.night || phase == SkyPhase.dawn) {
      final starAlphaMultiplier = phase == SkyPhase.night ? 1.0 : 0.35;
      final starPaint = Paint()..style = PaintingStyle.fill;

      for (final star in _stars) {
        final twinkle = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(time * star.speed + star.phase));
        final opacity = (twinkle * starAlphaMultiplier).clamp(0.0, 1.0);

        starPaint.color = Colors.white.withOpacity(opacity);
        final center = Offset(star.x * size.width, star.y * size.height);
        canvas.drawCircle(center, star.size, starPaint);

        // Soft halo on brighter stars
        if (star.size > 1.8 && opacity > 0.6) {
          final haloPaint = Paint()
            ..color = const Color(0xFFB0D0FF).withOpacity(opacity * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
          canvas.drawCircle(center, star.size * 2.2, haloPaint);
        }
      }
    }

    // 3. Ambient Atmospheric Glow (Sun/Moon Orb glow)
    _drawAtmosphericOrb(canvas, size, time);

    // 4. Procedural Drifting Volumetric Cloud Layers
    _drawDriftingClouds(canvas, size, time);

    // 5. Deep Obsidian Scrim Overlay for ultra-crisp UI readability
    final scrimGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.20),
        const Color(0xFF090A0E).withOpacity(0.72),
        const Color(0xFF07080B).withOpacity(0.92),
      ],
      stops: const [0.0, 0.40, 0.75, 1.0],
    );
    final scrimPaint = Paint()..shader = scrimGradient.createShader(rect);
    canvas.drawRect(rect, scrimPaint);
  }

  void _drawAtmosphericOrb(Canvas canvas, Size size, double time) {
    Offset orbCenter;
    Color orbColor;
    double radius;

    switch (phase) {
      case SkyPhase.dawn:
        orbCenter = Offset(size.width * 0.72, size.height * 0.35);
        orbColor = const Color(0xFFFFB37C).withOpacity(0.28);
        radius = size.width * 0.45;
        break;
      case SkyPhase.midday:
        orbCenter = Offset(size.width * 0.50, size.height * 0.18);
        orbColor = const Color(0xFF5AC8FA).withOpacity(0.22);
        radius = size.width * 0.55;
        break;
      case SkyPhase.sunset:
        orbCenter = Offset(size.width * 0.30, size.height * 0.42);
        orbColor = const Color(0xFFFF6432).withOpacity(0.32);
        radius = size.width * 0.50;
        break;
      case SkyPhase.night:
        orbCenter = Offset(size.width * 0.80, size.height * 0.22);
        orbColor = const Color(0xFF4C669F).withOpacity(0.18);
        radius = size.width * 0.40;
        break;
    }

    // Sinusoidal subtle pulsation
    final pulsate = 1.0 + 0.05 * math.sin(time);
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          orbColor,
          orbColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: radius * pulsate));

    canvas.drawCircle(orbCenter, radius * pulsate, orbPaint);
  }

  void _drawDriftingClouds(Canvas canvas, Size size, double time) {
    final cloudColor = _getCloudColor(phase);

    // Layer 1: High altitude, slow drift
    _drawCloudWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.24,
      amplitude: 18.0,
      wavelength: size.width * 0.75,
      horizontalOffset: (animationValue * size.width * 0.6) % size.width,
      color: cloudColor.withOpacity(0.12),
      verticalSway: math.sin(time * 0.8) * 8.0,
    );

    // Layer 2: Mid altitude, moderate drift
    _drawCloudWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.38,
      amplitude: 26.0,
      wavelength: size.width * 0.95,
      horizontalOffset: -(animationValue * size.width * 0.9) % size.width,
      color: cloudColor.withOpacity(0.16),
      verticalSway: math.cos(time * 1.1) * 12.0,
    );

    // Layer 3: Low horizon mist wisp
    _drawCloudWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.55,
      amplitude: 22.0,
      wavelength: size.width * 1.2,
      horizontalOffset: (animationValue * size.width * 1.3) % size.width,
      color: cloudColor.withOpacity(0.10),
      verticalSway: math.sin(time * 0.6) * 10.0,
    );
  }

  void _drawCloudWave({
    required Canvas canvas,
    required Size size,
    required double baseY,
    required double amplitude,
    required double wavelength,
    required double horizontalOffset,
    required Color color,
    required double verticalSway,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    final path = Path();
    final yPos = baseY + verticalSway;
    path.moveTo(-size.width, size.height);
    path.lineTo(-size.width, yPos);

    for (double x = -size.width; x <= size.width * 2; x += 30) {
      final normalizedX = x + horizontalOffset;
      final y = yPos + math.sin(normalizedX / wavelength * math.pi * 2) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width * 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  List<Color> _getSkyColors(SkyPhase phase) {
    switch (phase) {
      case SkyPhase.dawn:
        return const [
          Color(0xFF1E1728), // Deep dawn indigo
          Color(0xFF4A2B48), // Rose violet
          Color(0xFF8F435E), // Muted magenta
          Color(0xFFD9725C), // Soft peach
          Color(0xFFFFB273), // Daylight amber horizon
        ];
      case SkyPhase.midday:
        return const [
          Color(0xFF071424), // Obsidian deep azure
          Color(0xFF0C2A54), // Cerulean depth
          Color(0xFF104E8B), // Crisp sky blue
          Color(0xFF1E75C4), // Bright atmospheric azure
          Color(0xFF389CF2), // Radiant cyan horizon
        ];
      case SkyPhase.sunset:
        return const [
          Color(0xFF140C24), // Twilight obsidian
          Color(0xFF32153D), // Deep royal violet
          Color(0xFF6B224E), // Dusk crimson
          Color(0xFFBA4748), // Burnished amber
          Color(0xFFFF8E43), // Vivid sunset orange horizon
        ];
      case SkyPhase.night:
        return const [
          Color(0xFF04060A), // Obsidian space
          Color(0xFF080D18), // Deep midnight blue
          Color(0xFF0C1426), // Cosmic indigo
          Color(0xFF121B36), // Distant stellar haze
          Color(0xFF1A264D), // Low indigo horizon
        ];
    }
  }

  List<double> _getSkyStops(SkyPhase phase) {
    return const [0.0, 0.25, 0.50, 0.75, 1.0];
  }

  Color _getCloudColor(SkyPhase phase) {
    switch (phase) {
      case SkyPhase.dawn:
        return const Color(0xFFFFD1BA); // Warm peach reflection
      case SkyPhase.midday:
        return const Color(0xFFD2E8FF); // Soft crisp white-blue
      case SkyPhase.sunset:
        return const Color(0xFFFF9E70); // Golden hour wisp
      case SkyPhase.night:
        return const Color(0xFF324066); // Subtle moonlight silver-indigo
    }
  }

  @override
  bool shouldRepaint(covariant _LivingAtmospherePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.phase != phase;
  }
}
