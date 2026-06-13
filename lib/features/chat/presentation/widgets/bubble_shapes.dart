import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../domain/chat_model.dart';

class BubbleShapeBorder extends ShapeBorder {
  final String? shapeId;
  final bool isMe;
  final double borderWidth;
  final Color borderColor;
  final AdvancedBubbleConfig? advancedConfig;

  const BubbleShapeBorder({
    this.shapeId,
    required this.isMe,
    this.borderWidth = 1.0,
    this.borderColor = Colors.transparent,
    this.advancedConfig,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderWidth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect.deflate(borderWidth), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return getBubblePath(rect, shapeId, isMe, advancedConfig);
  }

  static Path getBubblePath(Rect rect, String? shapeId, bool isMe, [AdvancedBubbleConfig? config]) {
    final path = Path();
    final w = rect.width;
    final h = rect.height;
    final l = rect.left;
    final t = rect.top;

    switch (shapeId) {
      case 'sharp':
        path.addRect(rect);
        break;
      case 'wavy':
        path.moveTo(l + w * 0.1, t);
        path.quadraticBezierTo(l + w * 0.5, t - h * 0.1, l + w * 0.9, t);
        path.quadraticBezierTo(l + w * 1.05, t + h * 0.5, l + w * 0.9, t + h);
        path.quadraticBezierTo(l + w * 0.5, t + h * 1.1, l + w * 0.1, t + h);
        path.quadraticBezierTo(l - w * 0.05, t + h * 0.5, l + w * 0.1, t);
        path.close();
        break;
      case 'polygon':
        path.moveTo(l + w * 0.2, t);
        path.lineTo(l + w * 0.8, t);
        path.lineTo(l + w, t + h * 0.5);
        path.lineTo(l + w * 0.8, t + h);
        path.lineTo(l + w * 0.2, t + h);
        path.lineTo(l, t + h * 0.5);
        path.close();
        break;
      case 'star':
        final centerX = l + w / 2;
        final centerY = t + h / 2;
        const points = 5;
        final innerRadius = math.min(w, h) / 4;
        final outerRadius = math.min(w, h) / 2;
        for (int i = 0; i < points * 2; i++) {
          final radius = i.isEven ? outerRadius : innerRadius;
          final angle = (i * math.pi) / points - math.pi / 2;
          final x = centerX + radius * math.cos(angle);
          final y = centerY + radius * math.sin(angle);
          if (i == 0) path.moveTo(x, y);
          else path.lineTo(x, y);
        }
        path.close();
        break;
      case 'diamond':
        path.moveTo(l + w / 2, t);
        path.lineTo(l + w, t + h / 2);
        path.lineTo(l + w / 2, t + h);
        path.lineTo(l, t + h / 2);
        path.close();
        break;
      case 'heart':
        path.moveTo(l + w / 2, t + h * 0.35);
        path.cubicTo(l + w * 0.1, t - h * 0.1, l - w * 0.1, t + h * 0.6, l + w / 2, t + h);
        path.cubicTo(l + w * 1.1, t + h * 0.6, l + w * 0.9, t - h * 0.1, l + w / 2, t + h * 0.35);
        path.close();
        break;
      case 'jagged':
        final steps = 10;
        final stepW = w / steps;
        final stepH = h / steps;
        final amp = math.min(w, h) * 0.05;
        
        path.moveTo(l, t);
        // Top
        for (int i = 0; i < steps; i++) {
          path.lineTo(l + (i + 0.5) * stepW, t - amp);
          path.lineTo(l + (i + 1) * stepW, t);
        }
        // Right
        for (int i = 0; i < steps; i++) {
          path.lineTo(l + w + amp, t + (i + 0.5) * stepH);
          path.lineTo(l + w, t + (i + 1) * stepH);
        }
        // Bottom
        for (int i = steps; i > 0; i--) {
          path.lineTo(l + (i - 0.5) * stepW, t + h + amp);
          path.lineTo(l + (i - 1) * stepW, t + h);
        }
        // Left
        for (int i = steps; i > 0; i--) {
          path.lineTo(l - amp, t + (i - 0.5) * stepH);
          path.lineTo(l, t + (i - 1) * stepH);
        }
        path.close();
        break;
      case 'custom':
        if (config != null && config.customPathPoints != null && config.customPathPoints!.isNotEmpty) {
          final points = config.customPathPoints!;
          path.moveTo(l + points[0].dx * w, t + points[0].dy * h);
          for (int i = 1; i < points.length; i++) {
            path.lineTo(l + points[i].dx * w, t + points[i].dy * h);
          }
          path.close();
        } else {
          path.addRect(rect);
        }
        break;
      default:
        final radius = Radius.circular(18);
        path.addRRect(RRect.fromLTRBAndCorners(
          l, t, l + w, t + h,
          topLeft: radius,
          topRight: radius,
          bottomLeft: isMe ? radius : Radius.zero,
          bottomRight: isMe ? Radius.zero : radius,
        ));
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (borderWidth > 0) {
      final paint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

class BubbleShapeClipper extends CustomClipper<Path> {
  final String? shapeId;
  final bool isMe;
  final AdvancedBubbleConfig? advancedConfig;

  BubbleShapeClipper({this.shapeId, required this.isMe, this.advancedConfig});

  @override
  Path getClip(Size size) {
    return BubbleShapeBorder.getBubblePath(Offset.zero & size, shapeId, isMe, advancedConfig);
  }

  @override
  bool shouldReclip(covariant BubbleShapeClipper oldClipper) {
    return oldClipper.shapeId != shapeId || oldClipper.isMe != isMe || oldClipper.advancedConfig != advancedConfig;
  }
}
