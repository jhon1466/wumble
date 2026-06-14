import 'dart:async';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/chat_model.dart';
import '../../../../core/theme.dart';

class LiveOverlay extends StatefulWidget {
  final LiveSession session;
  final String currentUserId;
  final VoidCallback onLeave;
  final Function(bool) onToggleMic;
  final Function(bool) onToggleSpeaker;
  final bool isSpeakerOn;
  final Function(String) onSendMessage;
  final Widget chatWidget;

  LiveOverlay({
    super.key,
    required this.session,
    required this.currentUserId,
    required this.onLeave,
    required this.onToggleMic,
    required this.onToggleSpeaker,
    required this.isSpeakerOn,
    required this.onSendMessage,
    required this.chatWidget,
  });

  @override
  State<LiveOverlay> createState() => _LiveOverlayState();
}

class _LiveOverlayState extends State<LiveOverlay> {
  Timer? _timer;
  String _elapsedString = '00:00';
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final start = widget.session.startedAt ?? DateTime.now();
      final diff = DateTime.now().difference(start);
      final minutes = diff.inMinutes.toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      setState(() {
        _elapsedString = '$minutes:$seconds';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final currentUserId = widget.currentUserId;
    
    final me = session.participants.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => LiveParticipant(
        userId: currentUserId,
        username: '',
        avatarUrl: '',
        role: 'listener',
      ),
    );

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context),
            
            SizedBox(height: 20),
            
            // Speaker Grid
            _buildSpeakerGrid(),
            
            Spacer(),
            
            // Chat View (Overlaid)
            Expanded(
              flex: 2,
              child: widget.chatWidget,
            ),
            
            // Bottom Controls
            _buildBottomControls(me),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tr('Live en curso'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _elapsedString,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  tr('Proyección de audio'),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onLeave,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerGrid() {
    final speakers = widget.session.participants.where((p) => p.role != 'listener').toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: speakers.map((p) => _buildSpeakerAvatar(p)).toList(),
      ),
    );
  }

  Widget _buildSpeakerAvatar(LiveParticipant p) {
    if (p.isSpeaking) {
      debugPrint('🎨 [UI RENDERING WAVE] for ${p.username} | isSpeaking: ${p.isSpeaking}');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (p.isSpeaking)
                PulseAnimation(
                  key: ValueKey('pulse_${p.userId}'),
                  color: p.role == 'host' ? Colors.orangeAccent : Colors.greenAccent,
                ),
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: p.role == 'host' ? Colors.orangeAccent : Colors.greenAccent,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: p.avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: p.avatarUrl,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.person, color: Colors.white38),
              ),
            ),
            // Mic status
            if (!p.isMicOn)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_off, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            p.role == 'host' 
              ? '${p.username.isNotEmpty ? p.username : 'Anfitrión'} (H)' 
              : (p.username.isNotEmpty ? p.username : 'Usuario'),
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(LiveParticipant me) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('Escribe un mensaje...'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  widget.onSendMessage(text.trim());
                  _msgController.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(
              widget.isSpeakerOn ? Icons.volume_up : Icons.hearing,
              color: widget.isSpeakerOn ? Colors.greenAccent : Colors.white70,
            ),
            onPressed: () => widget.onToggleSpeaker(!widget.isSpeakerOn),
          ),
          IconButton(
            icon: Icon(
              me.isMicOn ? Icons.mic : Icons.mic_off,
              color: me.isMicOn ? Colors.greenAccent : Colors.redAccent,
            ),
            onPressed: () => widget.onToggleMic(!me.isMicOn),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onLeave,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class PulseAnimation extends StatefulWidget {
  final Color color;
  const PulseAnimation({super.key, required this.color});

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildPulse(1.0 + (_controller.value * 1.3), 1.0 - _controller.value, 15.0),
            _buildPulse(1.0 + ((_controller.value + 0.5) % 1.0 * 1.3), 1.0 - ((_controller.value + 0.5) % 1.0), 10.0),
            _buildPulse(1.0 + ((_controller.value + 0.7) % 1.0 * 1.1), 1.0 - ((_controller.value + 0.7) % 1.0), 5.0),
          ],
        );
      },
    );
  }

  Widget _buildPulse(double scale, double opacity, double blur) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(opacity * 0.6),
              blurRadius: blur,
              spreadRadius: blur / 2,
            ),
          ],
          gradient: RadialGradient(
            colors: [
              widget.color.withOpacity(opacity * 0.9),
              widget.color.withOpacity(opacity * 0.4),
              widget.color.withOpacity(0),
            ],
            stops: const [0.3, 0.7, 1.0],
          ),
          border: Border.all(
            color: widget.color.withOpacity(opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

