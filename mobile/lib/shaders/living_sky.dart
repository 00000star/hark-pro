import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

class LivingSkyWidget extends StatefulWidget {
  final Widget child;
  const LivingSkyWidget({super.key, required this.child});

  @override
  State<LivingSkyWidget> createState() => _LivingSkyWidgetState();
}

class _LivingSkyWidgetState extends State<LivingSkyWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderBuilder(
          assetKey: 'shaders/atmosphere.frag',
          (context, shader, child) {
            return CustomPaint(
              painter: AtmospherePainter(
                shader: shader,
                time: _controller.value * 60.0,
              ),
              child: widget.child,
            );
          },
          child: widget.child,
        );
      },
    );
  }
}

class AtmospherePainter extends CustomPainter {
  final FragmentShader shader;
  final double time;

  AtmospherePainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, 0.5); // sun_pos x
    shader.setFloat(4, 0.7); // sun_pos y
    shader.setFloat(5, 0.3); // cloud_cover
    shader.setFloat(6, 0.15); // haze_density

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant AtmospherePainter oldDelegate) => true;
}
