import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PurchaseCelebrationOverlay extends StatefulWidget {
  final VoidCallback onFinished;

  const PurchaseCelebrationOverlay({super.key, required this.onFinished});

  @override
  State<PurchaseCelebrationOverlay> createState() => _PurchaseCelebrationOverlayState();
}

class _PurchaseCelebrationOverlayState extends State<PurchaseCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Create particles (Coins, Stars, Confetti)
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        type: i % 3 == 0 ? _ParticleType.coin : (i % 3 == 1 ? _ParticleType.star : _ParticleType.confetti),
        color: i % 3 == 2 
            ? [Colors.blue, Colors.pink, Colors.green, Colors.yellow, Colors.purple][_random.nextInt(5)]
            : Colors.amber,
        angle: _random.nextDouble() * 2 * math.pi,
        speed: 2 + _random.nextDouble() * 4,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
        size: 8 + _random.nextDouble() * 12,
      ));
    }

    _controller.forward().then((_) => widget.onFinished());
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
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _CelebrationPainter(
            particles: _particles,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

enum _ParticleType { coin, star, confetti }

class _Particle {
  final _ParticleType type;
  final Color color;
  final double angle;
  final double speed;
  final double rotationSpeed;
  final double size;
  double x = 0;
  double y = 0;
  double rotation = 0;

  _Particle({
    required this.type,
    required this.color,
    required this.angle,
    required this.speed,
    required this.rotationSpeed,
    required this.size,
  });

  void update(double progress, Size canvasSize) {
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    
    // Spread from center
    double distance = progress * speed * 200;
    // Gravity effect after initial burst
    double gravity = progress * progress * 500;
    
    x = centerX + math.cos(angle) * distance;
    y = centerY + math.sin(angle) * distance + gravity;
    rotation += rotationSpeed;
  }
}

class _CelebrationPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _CelebrationPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Fade out at the end
    double opacity = 1.0;
    if (progress > 0.8) {
      opacity = (1.0 - progress) / 0.2;
    }

    for (var p in particles) {
      p.update(progress, size);
      paint.color = p.color.withOpacity(opacity);
      
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation + progress * 10);

      switch (p.type) {
        case _ParticleType.coin:
          _drawCoin(canvas, paint, p.size);
          break;
        case _ParticleType.star:
          _drawStar(canvas, paint, p.size);
          break;
        case _ParticleType.confetti:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.4),
              const Radius.circular(2),
            ),
            paint,
          );
          break;
      }
      canvas.restore();
    }
  }

  void _drawCoin(Canvas canvas, Paint paint, double size) {
    // Outer glow
    final glowPaint = Paint()
      ..color = Colors.amber.withOpacity(paint.color.opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset.zero, size / 2 + 2, glowPaint);
    
    // Coin base
    canvas.drawCircle(Offset.zero, size / 2, paint);
    
    // Inner detail
    final detailPaint = Paint()
      ..color = Colors.white.withOpacity(paint.color.opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, size / 3, detailPaint);
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    int points = 5;
    double innerRadius = size / 2.5;
    double outerRadius = size / 2;
    double step = math.pi / points;

    for (int i = 0; i < 2 * points; i++) {
        double r = (i % 2 == 0) ? outerRadius : innerRadius;
        double angle = i * step;
        double x = r * math.cos(angle);
        double y = r * math.sin(angle);
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
