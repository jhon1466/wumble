import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/domain/link_preview_data.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:wumble/core/utils/link_navigator.dart';

class LinkPreviewCard extends StatefulWidget {
  final LinkPreviewData data;
  final bool isMe;

  const LinkPreviewCard({
    super.key,
    required this.data,
    this.isMe = false,
  });

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  YoutubePlayerController? _controller;
  bool _isPlaying = false;
  bool _isFullScreenOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.youtubeVideoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: widget.data.youtubeVideoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: false,
          useHybridComposition: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pushFullScreen(BuildContext ctx) async {
    if (_controller == null || _isFullScreenOpen) return;
    setState(() => _isFullScreenOpen = true);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!ctx.mounted) {
      setState(() => _isFullScreenOpen = false);
      return;
    }

    await Navigator.of(ctx, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) => _FullScreenVideoPage(
          controller: _controller!,
        ),
      ),
    );

    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) setState(() => _isFullScreenOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _launchURL(context, widget.data.url),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF15181C), // X-style dark background
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias, // Ensures internal content follows border radius
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Media Area (Top)
            _buildMediaArea(context),

            // 2. Info Area (Bottom)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Domain/Site Name (X Style)
                  if (widget.data.siteName != null)
                    Text(
                      widget.data.siteName!.toLowerCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 2),

                  // Title
                  if (widget.data.title != null)
                    Text(
                      widget.data.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (widget.data.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.data.description!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaArea(BuildContext context) {
    // Aspect Ratio 16/9 is standard for modern cards
    const cardAspectRatio = 16 / 9;

    if (_isPlaying && _controller != null) {
      return AspectRatio(
        aspectRatio: cardAspectRatio,
        child: _isFullScreenOpen
            ? const ColoredBox(color: Colors.black)
            : Stack(
                children: [
                  YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFF1D9BF0), 
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _pushFullScreen(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
      );
    }

    if (widget.data.imageUrl != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: cardAspectRatio,
            child: CachedNetworkImage(
              imageUrl: widget.data.imageUrl!,
              fit: BoxFit.cover,
              httpHeaders: const {
                'User-Agent': 'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
              },
              placeholder: (_, __) => Container(
                color: const Color(0xFF202225),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D9BF0)),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.black26,
                child: const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 40)),
              ),
            ),
          ),
          if (widget.data.youtubeVideoId != null)
            GestureDetector(
              onTap: () => setState(() => _isPlaying = true),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _launchURL(BuildContext context, String url) {
    LinkNavigator.handleUrl(context, url);
  }
}

class _FullScreenVideoPage extends StatelessWidget {
  final YoutubePlayerController controller;
  const _FullScreenVideoPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: YoutubePlayer(
              controller: controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFF1D9BF0),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
