import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/chat/domain/bot_framework.dart';
import 'package:wumble/features/chat/presentation/image_viewer_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class BotMiniProfile extends StatefulWidget {
  final BotConfig? bot;
  final String? botId;
  final String? communityId;

  const BotMiniProfile({
    super.key, 
    this.bot,
    this.botId,
    this.communityId,
  });

  @override
  State<BotMiniProfile> createState() => _BotMiniProfileState();
}

class _BotMiniProfileState extends State<BotMiniProfile> {
  BotConfig? _loadedBot;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.bot != null) {
      _loadedBot = widget.bot;
    } else if (widget.botId != null) {
      _loadBot();
    }
  }

  Future<void> _loadBot() async {
    if (widget.botId == 'Assistant') return; // Handle system assistant later
    
    setState(() => _isLoading = true);
    try {
      final String cleanId = widget.botId!.replaceFirst('BOT_', '');
      DocumentSnapshot doc;
      
      if (widget.communityId != null) {
        doc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('bots')
            .doc(cleanId)
            .get();
      } else {
        // Search globally if community unknown? (Might be slow/expensive)
        // For now, assume community bots only or assistant
        setState(() => _isLoading = false);
        return;
      }

      if (doc.exists) {
        setState(() {
          _loadedBot = BotConfig.fromFirestore(doc);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading bot config: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Color(0xFF0F1115),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final bot = _loadedBot;
    
    // Fallback if bot not found or system assistant
    if (bot == null) {
      return _buildAssistantProfile();
    }

    final accentColor = Color(bot.backgroundColorValue ?? bot.embedColorValue);
    
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: accentColor.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section with Banner & Avatar
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Banner with Top Corners
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  image: bot.bannerUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(bot.bannerUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: bot.bannerUrl == null
                    ? Center(
                        child: Icon(Icons.smart_toy_outlined,
                            color: accentColor.withValues(alpha: 0.1), size: 60),
                      )
                    : Container(color: Colors.black.withValues(alpha: 0.3)), // Overlay
              ),
              
              // Drag handle inside the banner
              Positioned(
                top: 12,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Avatar with Neon Ring (Overlapping)
              Positioned(
                bottom: -46,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFF1A1D23),
                    backgroundImage: bot.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(bot.avatarUrl)
                        : null,
                    child: bot.avatarUrl.isEmpty
                        ? const Icon(Icons.smart_toy, size: 40, color: Colors.white24)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 56),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Name & Type
                Column(
                  children: [
                    Text(
                      bot.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 10, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'AI AGENT',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Status Text
                if (bot.statusType != BotStatusType.none)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(bot.statusType), size: 14, color: accentColor.withValues(alpha: 0.8)),
                        const SizedBox(width: 8),
                        Text(
                          '${_getStatusPrefix(bot)} ${bot.statusText}'.trim(),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Stats/Info Row
                Row(
                  children: [
                    _buildInfoTile('Comandos', bot.commands.length.toString(), Icons.terminal, accentColor),
                    const SizedBox(width: 12),
                    _buildInfoTile('Prefijo', bot.prefix.isEmpty ? '/' : bot.prefix, Icons.bolt, accentColor),
                  ],
                ),

                const SizedBox(height: 20),

                // Description Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: accentColor),
                          const SizedBox(width: 10),
                          const Text(
                            'Protocolos y Funciones',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        bot.description.isNotEmpty ? bot.description : 'Un agente inteligente diseñado para servir a esta comunidad. No se han definido protocolos específicos.',
                        style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, size: 14, color: accentColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    const Text(
                      'SISTEMA VERIFICADO POR WUMBLE',
                      style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
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

  Widget _buildAssistantProfile() {
    const accentColor = Colors.blueAccent;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1115),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 46,
            backgroundColor: Color(0xFF1A1D23),
            child: Icon(Icons.shield_outlined, size: 40, color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          const Text(
            'System Assistant',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'PROTOCOL: SECURE_GUARD_V1',
            style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Este es un asistente del sistema encargado de la moderación y el soporte técnico. Sus funciones están predefinidas por el núcleo de Wumble.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(BotStatusType type) {
    switch (type) {
      case BotStatusType.playing: return Icons.videogame_asset;
      case BotStatusType.watching: return Icons.remove_red_eye;
      case BotStatusType.listening: return Icons.headset;
      case BotStatusType.competing: return Icons.emoji_events;
      case BotStatusType.custom: return Icons.star_outline;
      default: return Icons.radio_button_checked;
    }
  }

  String _getStatusPrefix(BotConfig bot) {
    switch (bot.statusType) {
      case BotStatusType.playing: return 'Jugando a';
      case BotStatusType.watching: return 'Viendo';
      case BotStatusType.listening: return 'Escuchando a';
      case BotStatusType.competing: return 'Compitiendo en';
      case BotStatusType.custom: return bot.customStatusPrefix ?? '';
      default: return '';
    }
  }
}
