import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/theme.dart';

class VoiceMessageBubble extends StatefulWidget {
  final bool isMe;
  final String? voiceUrl;
  final String? localPath;
  final Duration? duration;

  const VoiceMessageBubble({
    super.key, 
    required this.isMe,
    this.voiceUrl,
    this.localPath,
    this.duration,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = widget.duration ?? const Duration(seconds: 0);
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    final source = widget.voiceUrl != null 
        ? UrlSource(widget.voiceUrl!) 
        : widget.localPath != null 
            ? DeviceFileSource(widget.localPath!) 
            : null;

    if (source == null) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: widget.isMe ? Wumbleheme.primaryColor : Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(widget.isMe ? 16 : 0),
          bottomRight: Radius.circular(widget.isMe ? 0 : 16),
        ),
        border: widget.isMe ? null : Border.all(color: Colors.white10),
      ),
      width: 220,
      child: Row(
        children: [
          widget.voiceUrl == null && widget.localPath != null
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                ),
              )
            : IconButton(
                icon: Icon(
                  _playerState == PlayerState.playing 
                      ? Icons.pause_rounded 
                      : Icons.play_arrow_rounded,
                  color: widget.isMe ? Colors.white : Wumbleheme.secondaryColor,
                  size: 30,
                ),
                onPressed: _playPause,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressBar(),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(_playerState == PlayerState.playing ? _position : _duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildProgressBar() {
    double progress = 0;
    if (_duration.inMilliseconds > 0) {
      progress = _position.inMilliseconds / _duration.inMilliseconds;
    }
    
    return Stack(
      children: [
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}
