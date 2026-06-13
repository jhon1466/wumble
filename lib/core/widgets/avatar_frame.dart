import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/profile/domain/custom_frame_model.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────
// Color filter matrix to remove black backgrounds (Amino style)
// ─────────────────────────────────────────────────────────────
const ColorFilter _blackToAlphaMatrix = ColorFilter.matrix(<double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  1.2, 1.2, 1.2, 0, 0, // Calculates Alpha directly from RGB brightness
]);

// ─────────────────────────────────────────────────────────────
// Frame Catalog
// ─────────────────────────────────────────────────────────────

enum FrameType { painted, video, image }

class AvatarFrame {
  final String id;
  final String name;
  final List<Color> colors;
  final int price;
  final FrameType type;
  // videoAsset has been removed in favor of image assets (gif/webp)
  final String? imageAsset; // path to local PNG asset, e.g. 'assets/frames/4227.png'
  final String? networkUrl; // URL for custom uploaded frames (Firebase Storage)
  final String? packId;     // ID of the pack this frame belongs to
  final String? packName;   // Name of the pack
  final int packPrice;      // Total price of the pack
  final int packSize;       // Number of frames in the pack
  final String? uploaderId; // The ID of the user who uploaded this frame
  final DateTime? createdAt; // Date when the frame was created
  final String? credits;    // Credits/Source of the original artist/author

  const AvatarFrame({
    required this.id,
    required this.name,
    required this.colors,
    required this.price,
    this.type = FrameType.painted,

    this.imageAsset,
    this.networkUrl,
    this.packId,
    this.packName,
    this.packPrice = 0,
    this.packSize = 0,
    this.uploaderId,
    this.createdAt,
    this.credits,
  });

  Color get primaryColor => colors.isNotEmpty ? colors.first : const Color(0xFF00D4FF);

  static const List<AvatarFrame> catalog = [
    AvatarFrame(
      id: 'fire',
      name: 'Fuego Infernal',
      colors: [Color(0xFFFF6B00), Color(0xFFFFD700), Color(0xFFFF3D00)],
      price: 0,
    ),
    AvatarFrame(
      id: 'galaxy',
      name: 'Galaxia Neón',
      colors: [Color(0xFF6A0572), Color(0xFF00D4FF), Color(0xFF7B2FBE)],
      price: 0,
    ),
    AvatarFrame(
      id: 'ice',
      name: 'Nieve Mística',
      colors: [Color(0xFFADD8E6), Color(0xFFFFFFFF), Color(0xFF0072FF)],
      price: 0,
    ),
    AvatarFrame(
      id: 'gold',
      name: 'Oro Real',
      colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFDAA520)],
      price: 0,
    ),
    AvatarFrame(
      id: 'emerald',
      name: 'Esmeralda',
      colors: [Color(0xFF00C851), Color(0xFF00695C), Color(0xFF69F0AE)],
      price: 0,
    ),
    AvatarFrame(
      id: 'rainbow',
      name: 'Arcoíris',
      colors: [
        Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFFF00),
        Color(0xFF00FF00), Color(0xFF0000FF), Color(0xFF8B00FF),
      ],
      price: 0,
    ),
    // ── GIF Animated Frames (Screen Blend) ──
    AvatarFrame(
      id: 'flamingo',
      name: 'Flamingo',
      colors: [Color(0xFFFF69B4), Color(0xFFFF1493), Color(0xFFFFB6C1)],
      price: 0,
      type: FrameType.video,
      imageAsset: 'assets/frames/flamingo.gif',
    ),
    AvatarFrame(
      id: 'water',
      name: 'Poder del Agua',
      colors: [Color(0xFF00BFFF), Color(0xFF1E90FF), Color(0xFF00CED1)],
      price: 0,
      type: FrameType.video,
      imageAsset: 'assets/frames/water.gif',
    ),
    // ── Image Frames (PNG) ──
    AvatarFrame(
      id: 'genshin_amber',
      name: 'Amber',
      colors: [Color(0xFFFF6B00), Color(0xFFFFD700), Color(0xFFFF8C00)],
      price: 0,
      type: FrameType.image,
      imageAsset: 'assets/frames/Genshin-amber.png',
    ),
    AvatarFrame(
      id: 'genshin_furina',
      name: 'Furina',
      colors: [Color(0xFF4FC3F7), Color(0xFF0288D1), Color(0xFFB3E5FC)],
      price: 0,
      type: FrameType.image,
      imageAsset: 'assets/frames/Genshin-furina.png',
    ),
    AvatarFrame(
      id: 'genshin_hutao',
      name: 'Hu Tao',
      colors: [Color(0xFFFF4444), Color(0xFFFF8C00), Color(0xFF8B0000)],
      price: 0,
      type: FrameType.image,
      imageAsset: 'assets/frames/Genshin-hutao.png',
    ),
  ];

  static final Map<String, AvatarFrame> dynamicFrames = {};

  static AvatarFrame? findById(String id) {
    try {
      return catalog.firstWhere((f) => f.id == id);
    } catch (_) {
      return dynamicFrames[id];
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Main Framed Avatar Widget
// ─────────────────────────────────────────────────────────────

class FramedAvatar extends StatefulWidget {
  final Widget child;
  final String? frameId;
  final double size;
  final bool isAnimated;

  const FramedAvatar({
    super.key,
    required this.child,
    required this.size,
    this.frameId,
    this.isAnimated = true,
  });

  @override
  State<FramedAvatar> createState() => _FramedAvatarState();
}

class _FramedAvatarState extends State<FramedAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  AvatarFrame? _frame;

  @override
  void initState() {
    super.initState();
    _initControllerIfNeeded();
    _resolveFrame();
  }

  void _initControllerIfNeeded() {
    if (widget.isAnimated && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      );
      _controller!.repeat();
    }
  }

  @override
  void didUpdateWidget(FramedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameId != widget.frameId) {
      _resolveFrame();
    }
    if (oldWidget.isAnimated != widget.isAnimated) {
      if (widget.isAnimated) {
        _initControllerIfNeeded();
        if (_controller != null && !_controller!.isAnimating) _controller!.repeat();
      } else {
        _controller?.stop();
        _controller?.value = 0.0;
      }
    }
  }

  Future<void> _resolveFrame() async {
    final id = widget.frameId;
    if (id == null) {
      if (mounted) setState(() => _frame = null);
      return;
    }

    var frame = AvatarFrame.findById(id);
    if (frame != null) {
      if (mounted) setState(() => _frame = frame);
      return;
    }

    // Check if it's already in the dynamic cache to avoid a network call
    if (AvatarFrame.dynamicFrames.containsKey(id)) {
      if (mounted) setState(() => _frame = AvatarFrame.dynamicFrames[id]);
      return;
    }

    // Attempt to fetch custom frame from Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('avatar_frames').doc(id).get();
      if (doc.exists) {
        final customFrame = CustomAvatarFrame.fromMap(doc.data()!, doc.id);
        final uiFrame = customFrame.toAvatarFrame();
        AvatarFrame.dynamicFrames[id] = uiFrame;
        if (mounted && widget.frameId == id) {
          setState(() => _frame = uiFrame);
        }
      } else {
        if (mounted && widget.frameId == id) {
          setState(() => _frame = null);
        }
      }
    } catch (e) {
      debugPrint('Error fetching custom frame $id: $e');
      if (mounted && widget.frameId == id) {
        setState(() => _frame = null);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frame == null) {
      return SizedBox(width: widget.size, height: widget.size, child: widget.child);
    }

    if (_frame!.type == FrameType.video && (_frame!.imageAsset != null || _frame!.networkUrl != null)) {
      return _ImageFrameAvatar(
        frame: _frame!,
        size: widget.size,
        isGif: true,
        isAnimated: widget.isAnimated,
        child: widget.child,
      );
    }

    if (_frame!.type == FrameType.image && (_frame!.imageAsset != null || _frame!.networkUrl != null)) {
      return _ImageFrameAvatar(
        frame: _frame!,
        size: widget.size,
        isAnimated: widget.isAnimated,
        child: widget.child,
      );
    }

    // Painted frame — layout is EXACTLY `size×size`.
    // OPTIMIZATION: When not animated, render the real frame design frozen at t=0
    // with isStatic=true to skip ALL MaskFilter.blur operations.
    if (!widget.isAnimated) {
      final canvasSize = widget.size * 1.3;
      final overflow = (canvasSize - widget.size) / 2;

      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: -overflow,
              top: -overflow,
              width: canvasSize,
              height: canvasSize,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(canvasSize, canvasSize),
                    painter: _BackgroundDecorationPainter(
                      frame: _frame!,
                      t: 0.0,
                      avatarRadius: widget.size / 2,
                      isStatic: true, // Skip ALL blur operations
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: widget.size, height: widget.size, child: widget.child),
            Positioned(
              left: -overflow,
              top: -overflow,
              width: canvasSize,
              height: canvasSize,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(canvasSize, canvasSize),
                    painter: _ForegroundDecorationPainter(
                      frame: _frame!,
                      t: 0.0,
                      avatarRadius: widget.size / 2,
                      isStatic: true, // Skip ALL blur operations
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Animated mode: full decorative painters.
    final canvasSize = widget.size * 1.3; // Reduced from 2.5x
    final overflow = (canvasSize - widget.size) / 2;

    return AnimatedBuilder(
      animation: _controller!,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Background effects
            Positioned(
              left: -overflow,
              top: -overflow,
              width: canvasSize,
              height: canvasSize,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(canvasSize, canvasSize),
                    painter: _BackgroundDecorationPainter(
                      frame: _frame!,
                      t: _controller!.value,
                      avatarRadius: widget.size / 2,
                    ),
                  ),
                ),
              ),
            ),
            // The Avatar Base
            SizedBox(width: widget.size, height: widget.size, child: widget.child),
            // Foreground effects
            Positioned(
              left: -overflow,
              top: -overflow,
              width: canvasSize,
              height: canvasSize,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(canvasSize, canvasSize),
                    painter: _ForegroundDecorationPainter(
                      frame: _frame!,
                      t: _controller!.value,
                      avatarRadius: widget.size / 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




// ─────────────────────────────────────────────────────────────
// PNG Image Frame Widget
// ─────────────────────────────────────────────────────────────

class _ImageFrameAvatar extends StatelessWidget {
  final AvatarFrame frame;
  final double size;
  final Widget child;
  final bool isGif;
  final bool isAnimated;

  const _ImageFrameAvatar({
    required this.frame,
    required this.size,
    required this.child,
    this.isGif = false,
    this.isAnimated = true,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = frame.networkUrl != null
        ? CachedNetworkImage(
            imageUrl: frame.networkUrl!,
            fit: BoxFit.cover,
            memCacheWidth: (size * 2).toInt(),
            memCacheHeight: (size * 2).toInt(),
            errorWidget: (context, url, error) => const SizedBox(),
          )
        : Image.asset(
            frame.imageAsset!,
            fit: BoxFit.cover,
          );

    if (isGif) {
      // ── GIF / animated frame ───────────────────────────────
      // The GIF assets typically have a lot of internal padding/empty space.
      // Scaling them up by 2.15x makes the glowing ring fit perfectly around the avatar.
      final canvasSize = size * 2.15;
      final overflow = (canvasSize - size) / 2;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox(width: size, height: size, child: child),
            Positioned(
              left: -overflow,
              top: -overflow,
              width: canvasSize,
              height: canvasSize,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: SizedBox(
                    width: canvasSize,
                    height: canvasSize,
                    child: ColorFiltered(
                      colorFilter: _blackToAlphaMatrix,
                      child: imageWidget,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Static image frame (Optimization: avoid ColorFiltered if possible) ──
    final canvasSize = size * 1.3;
    final overflow = (canvasSize - size) / 2;
    
    // Simplar layout for non-animated static frames
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child,
          Positioned(
            left: -overflow, top: -overflow,
            width: canvasSize, height: canvasSize,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: imageWidget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// Painters and Helpers
// ─────────────────────────────────────────────────────────────

class _GlowRingPainter extends CustomPainter {
  final List<Color> colors;
  final double avatarRadius;

  _GlowRingPainter({required this.colors, required this.avatarRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final primary = colors.isNotEmpty ? colors.first : const Color(0xFF00D4FF);

    canvas.drawCircle(
      center,
      avatarRadius + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..shader = SweepGradient(
          colors: colors.isEmpty ? [primary, primary] : [...colors, colors.first],
        ).createShader(Rect.fromCircle(center: center, radius: avatarRadius + 3)),
    );
    // Glow
    canvas.drawCircle(
      center,
      avatarRadius + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = primary.withOpacity(0.6),
    );
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// Background Painter (glow ring, base effects)
// ─────────────────────────────────────────────────────────────

class _BackgroundDecorationPainter extends CustomPainter {
  final AvatarFrame frame;
  final double t;
  final double avatarRadius;
  final bool isStatic;

  _BackgroundDecorationPainter({
    required this.frame,
    required this.t,
    required this.avatarRadius,
    this.isStatic = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0.0) {
      // debugPrint call removed
    }
    final center = Offset(size.width / 2, size.height / 2);

    switch (frame.id) {
      case 'fire':
        _paintFireBackground(canvas, center, size);
        break;
      case 'galaxy':
        _paintGalaxyBackground(canvas, center, size);
        break;
      case 'gold':
        _paintGoldBackground(canvas, center, size);
        break;
      case 'ice':
        _paintIceBackground(canvas, center, size);
        break;
      case 'emerald':
        _paintEmeraldBackground(canvas, center, size);
        break;
      case 'rainbow':
        _paintRainbowBackground(canvas, center, size);
        break;
    }
  }

  void _paintFireBackground(Canvas canvas, Offset center, Size size) {
    if (!isStatic) _paintGlowRing(canvas, center, avatarRadius + 8, frame.colors[0].withOpacity(0.5), 24);
    final rand = math.Random(1);
    for (int i = 0; i < 8; i++) {
      final angle = math.pi * 0.3 + (i / 7) * math.pi * 0.4;
      final flameAngle = angle + math.sin(t * 2 * math.pi + i) * 0.15;
      final base = Offset(
        center.dx + (avatarRadius - 4) * math.cos(flameAngle),
        center.dy + (avatarRadius - 4) * math.sin(flameAngle),
      );
      final flameH = (20 + rand.nextDouble() * 15) *
          (0.7 + 0.3 * math.sin(t * 2 * math.pi + i));
      final tip = Offset(
        base.dx + math.cos(flameAngle) * flameH * 0.3,
        base.dy + math.sin(flameAngle) * flameH,
      );
      final path = Path()
        ..moveTo(base.dx - 6, base.dy)
        ..quadraticBezierTo(tip.dx, tip.dy, base.dx + 6, base.dy)
        ..close();
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.yellow, frame.colors[0].withOpacity(0)],
        ).createShader(Rect.fromCircle(center: base, radius: flameH));
      if (!isStatic) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, paint);
    }
  }

  void _paintGalaxyBackground(Canvas canvas, Offset center, Size size) {
    if (!isStatic) _paintGlowRing(canvas, center, avatarRadius + 10, frame.colors[0].withOpacity(0.6), 30);
    final rand = math.Random(42);
    for (int i = 0; i < 18; i++) {
      final baseAngle = (i / 18) * 2 * math.pi;
      final orbitRadius = avatarRadius * (0.9 + rand.nextDouble() * 0.5);
      final wobble = math.sin(t * 2 * math.pi + i) * 6;
      final angle = baseAngle + t * 2 * math.pi * (i.isEven ? 1.0 : -1.0);
      final x = center.dx + (orbitRadius + wobble) * math.cos(angle);
      final y = center.dy + (orbitRadius + wobble) * math.sin(angle);
      final brightness = (0.5 + 0.5 * math.sin(t * 2 * math.pi + i)).clamp(0.0, 1.0);
      final starSize = 1.5 + rand.nextDouble() * 2.5;
      canvas.drawCircle(
        Offset(x, y), starSize * brightness,
        Paint()..color = frame.colors[i.isEven ? 1 : 2].withOpacity(brightness.toDouble()),
      );
    }
  }

  void _paintGoldBackground(Canvas canvas, Offset center, Size size) {
    if (!isStatic) _paintGlowRing(canvas, center, avatarRadius + 8, Colors.amber.withOpacity(0.7), 28);
    final rand = math.Random(7);
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi + t * 2 * math.pi;
      final r = avatarRadius * (1.05 + rand.nextDouble() * 0.35);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final glitter = (math.sin(t * 2 * math.pi * 2 + i * 1.3) + 1) / 2;
      canvas.drawCircle(Offset(x, y), 2.5 * glitter,
          Paint()..color = Colors.white.withOpacity(glitter.toDouble()));
    }
  }

  void _paintIceBackground(Canvas canvas, Offset center, Size size) {
    if (!isStatic) _paintGlowRing(canvas, center, avatarRadius + 8, frame.colors[0].withOpacity(0.5), 24);
    final rand = math.Random(13);
    for (int i = 0; i < 8; i++) {
      final baseAngle = (i / 8) * 2 * math.pi;
      final drift = t * 2 * math.pi + i * 0.7;
      final r = avatarRadius * (1.1 + rand.nextDouble() * 0.3) + math.sin(drift) * 6;
      final angle = baseAngle + math.sin(t * 2 * math.pi + i) * 0.08;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final alpha = (0.4 + 0.6 * math.sin(drift + 1.2)).clamp(0.3, 1.0);
      _drawSnowflakeSimple(canvas, Offset(x, y), 5, Colors.white.withOpacity(alpha));
    }
  }

  void _paintEmeraldBackground(Canvas canvas, Offset center, Size size) {
    if (!isStatic) _paintGlowRing(canvas, center, avatarRadius + 8, frame.colors[0].withOpacity(0.5), 24);
    final rand = math.Random(21);
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * math.pi + t * 2 * math.pi;
      final r = avatarRadius * (1.05 + rand.nextDouble() * 0.4);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final glow = (math.sin(t * 2 * math.pi + i * 2) + 1) / 2;
      final paint = Paint()..color = frame.colors[i % 3].withOpacity(glow.toDouble());
      if (!isStatic) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), 3 * glow, paint);
    }
  }

  void _paintRainbowBackground(Canvas canvas, Offset center, Size size) {
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..shader = SweepGradient(
        colors: frame.colors.isEmpty ? [frame.primaryColor, frame.primaryColor] : [...frame.colors, frame.colors.first],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: avatarRadius + 6));
    canvas.drawCircle(center, avatarRadius + 6, sweepPaint);
    final rand = math.Random(99);
    for (int i = 0; i < 14; i++) {
      final angle = (i / 14) * 2 * math.pi + t * 2 * math.pi;
      final r = avatarRadius * (1.15 + rand.nextDouble() * 0.25);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final pop = (math.sin(t * 2 * math.pi * 3 + i * 1.8) + 1) / 2;
      _drawStar(canvas, Offset(x, y), 4 * pop,
          frame.colors[i % frame.colors.length].withOpacity(pop.toDouble()));
    }
  }

  void _paintGlowRing(Canvas canvas, Offset center, double radius, Color color, double sigma) {
    canvas.drawCircle(
      center, radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sigma * 0.6
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
        ..color = color,
    );
  }

  void _drawSnowflakeSimple(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final angle = (i / 3) * math.pi;
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * size, center.dy + math.sin(angle) * size),
        Offset(center.dx - math.cos(angle) * size, center.dy - math.sin(angle) * size),
        paint,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi;
      final x = center.dx + math.cos(angle) * size;
      final y = center.dy + math.sin(angle) * size;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BackgroundDecorationPainter old) =>
      old.t != t || old.frame.id != frame.id;
}

// ─────────────────────────────────────────────────────────────
// Foreground Painter
// ─────────────────────────────────────────────────────────────

class _ForegroundDecorationPainter extends CustomPainter {
  final AvatarFrame frame;
  final double t;
  final double avatarRadius;
  final bool isStatic;

  _ForegroundDecorationPainter({
    required this.frame,
    required this.t,
    required this.avatarRadius,
    this.isStatic = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _paintCoreRing(canvas, center);

    switch (frame.id) {
      case 'fire':
        _paintFireForeground(canvas, center, size);
        break;
      case 'galaxy':
        _paintGalaxyForeground(canvas, center, size);
        break;
      case 'gold':
        _paintGoldCrown(canvas, center, size);
        break;
      case 'ice':
        _paintIceForeground(canvas, center, size);
        break;
      case 'emerald':
        _paintEmeraldForeground(canvas, center, size);
        break;
    }
  }

  void _paintCoreRing(Canvas canvas, Offset center) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = SweepGradient(
        colors: frame.colors.isEmpty ? [frame.primaryColor, frame.primaryColor] : [...frame.colors, frame.colors.first],
        transform: GradientRotation(-math.pi / 2 + t * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: avatarRadius));
    canvas.drawCircle(center, avatarRadius + 2, ringPaint);
  }

  void _paintFireForeground(Canvas canvas, Offset center, Size size) {
    final rand = math.Random(3);
    for (int i = 0; i < 5; i++) {
      final angle = -math.pi * 0.3 - (i / 4) * math.pi * 0.4;
      final baseX = center.dx + avatarRadius * math.cos(angle);
      final baseY = center.dy + avatarRadius * math.sin(angle);
      final flameH = (25 + rand.nextDouble() * 18) *
          (0.7 + 0.3 * math.sin(t * 2 * math.pi + i));
      final tipX = baseX + math.cos(angle) * flameH * 0.4;
      final tipY = baseY + math.sin(angle) * flameH;
      final path = Path()
        ..moveTo(baseX - 5, baseY)
        ..quadraticBezierTo(tipX - 3, (baseY + tipY) / 2, tipX, tipY)
        ..quadraticBezierTo(tipX + 3, (baseY + tipY) / 2, baseX + 5, baseY)
        ..close();
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.yellow.withOpacity(0.9), frame.colors[0].withOpacity(0.0)],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromPoints(Offset(baseX, baseY), Offset(tipX, tipY)));
      if (!isStatic) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, paint);
    }
  }

  void _paintGalaxyForeground(Canvas canvas, Offset center, Size size) {
    for (int i = 0; i < 4; i++) {
      final progress = ((t + i * 0.25) % 1.0);
      final angle = (i / 4) * 2 * math.pi - math.pi / 2;
      final r = avatarRadius * 0.85 + progress * avatarRadius * 0.7;
      final x = center.dx + r * math.cos(angle + progress * 0.8);
      final y = center.dy + r * math.sin(angle + progress * 0.8);
      final alpha = math.sin(progress * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, y), 2.5 * alpha,
          Paint()..color = frame.colors[1].withOpacity(alpha.toDouble()));
    }
  }

  void _paintGoldCrown(Canvas canvas, Offset center, Size size) {
    final crownBottom = center.dy - avatarRadius - 2;
    final crownW = avatarRadius * 0.7;
    final crownH = avatarRadius * 0.35;
    final crownLeft = center.dx - crownW / 2;
    final glow = (math.sin(t * 2 * math.pi) + 1) / 2;

    final path = Path()
      ..moveTo(crownLeft, crownBottom)
      ..lineTo(crownLeft, crownBottom - crownH * 0.7)
      ..lineTo(center.dx - crownW * 0.25, crownBottom - crownH * 0.35)
      ..lineTo(center.dx, crownBottom - crownH)
      ..lineTo(center.dx + crownW * 0.25, crownBottom - crownH * 0.35)
      ..lineTo(crownLeft + crownW, crownBottom - crownH * 0.7)
      ..lineTo(crownLeft + crownW, crownBottom)
      ..close();

    final crownPaint = Paint()
      ..shader = LinearGradient(
        colors: [frame.colors[0], frame.colors[1], frame.colors[2]],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(crownLeft, crownBottom - crownH, crownW, crownH));
    if (!isStatic) crownPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + glow * 3);
    canvas.drawPath(path, crownPaint);

    for (int i = 0; i < 3; i++) {
      final jewX = crownLeft + crownW * (0.2 + i * 0.3);
      final jewY = crownBottom - crownH * 0.15;
      canvas.drawCircle(Offset(jewX, jewY), 3.5,
          Paint()..color = [Colors.red, Colors.blue, Colors.green][i].withOpacity(0.9));
      canvas.drawCircle(Offset(jewX, jewY), 2,
          Paint()..color = Colors.white.withOpacity(0.6));
    }
  }

  void _paintIceForeground(Canvas canvas, Offset center, Size size) {
    final topY = center.dy - avatarRadius - 14;
    _drawDetailedSnowflake(canvas, Offset(center.dx, topY), 12,
        Colors.white.withOpacity(0.85 + 0.15 * math.sin(t * 2 * math.pi)));
  }

  void _paintEmeraldForeground(Canvas canvas, Offset center, Size size) {
    _drawGem(canvas, Offset(center.dx, center.dy - avatarRadius - 12), 9, frame.colors[0]);
  }

  void _drawDetailedSnowflake(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi;
      final endX = center.dx + math.cos(angle) * size;
      final endY = center.dy + math.sin(angle) * size;
      canvas.drawLine(center, Offset(endX, endY), paint);
      final branchL = size * 0.45;
      for (int b = -1; b <= 1; b += 2) {
        final bAngle = angle + b * math.pi / 3;
        final bx = center.dx + math.cos(angle) * branchL;
        final by = center.dy + math.sin(angle) * branchL;
        canvas.drawLine(Offset(bx, by),
            Offset(bx + math.cos(bAngle) * 5, by + math.sin(bAngle) * 5), paint);
      }
    }
  }

  void _drawGem(Canvas canvas, Offset center, double size, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.7, center.dy - size * 0.3)
      ..lineTo(center.dx + size * 0.7, center.dy + size * 0.3)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size * 0.7, center.dy + size * 0.3)
      ..lineTo(center.dx - size * 0.7, center.dy - size * 0.3)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, color, color.withOpacity(0.6)],
          radius: 0.8,
        ).createShader(Rect.fromCircle(center: center, radius: size)),
    );
    canvas.drawPath(path,
        Paint()..style = PaintingStyle.stroke..color = Colors.white38..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_ForegroundDecorationPainter old) =>
      old.t != t || old.frame.id != frame.id;
}
