import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:wumble/features/chat/domain/bot_framework.dart';
import '../../domain/chat_model.dart';
import '../../domain/chat_repository.dart';
import '../../../../core/theme.dart';
import 'voice_message_bubble.dart';
import '../image_viewer_screen.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/user_list_bottom_sheet.dart';
import '../../../community/presentation/widgets/bot_mini_profile.dart';
import '../../../../core/utils/link_navigator.dart';
import '../../../../core/widgets/linkify_text.dart';
import '../../../../core/utils/media_optimizer.dart';
import '../../../../core/domain/link_preview_data.dart';
import '../../../../core/widgets/link_preview_card.dart';

import 'bubble_shapes.dart';

/// Adapter class for ChatBubble display
class ChatBubbleMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final int? senderLevel;
  final bool isOneOnOne;
  final String? text;
  final String? stickerUrl;
  final String? imageUrl;
  final String? voiceUrl;
  final String? localPath;
  final String? communityId;
  final MessageType type;
  final DateTime timestamp;
  final bool isMe;
  final bool isEdited;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;
  final String? replyToImageUrl;
  final MessageType? replyToType;

  final ChatBubbleStyle? bubbleStyle;
  final bool isBotEmbed;
  final String? embedTitle;
  final String? embedFooter;
  final int? embedColor;
  final List<BotButton> botButtons; 
  final BotConfig? botConfig; // NEW
  final Map<String, List<String>> reactions; // NEW
  final String? senderAvatarFrameUrl; // Avatar frame support
  final String? senderRole; // NEW: Leader, Curator, etc.
  final bool isSeen;
  final bool showReadReceipts;
  final LinkPreviewData? linkPreview; // NEW

  ChatBubbleMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    this.senderLevel,
    this.isOneOnOne = true,
    this.text,
    this.stickerUrl,
    this.imageUrl,
    this.voiceUrl,
    this.localPath,
    required this.type,
    required this.timestamp,
    required this.isMe,
    this.isEdited = false,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
    this.replyToImageUrl,
    this.replyToType,
    this.communityId,
    this.bubbleStyle,
    this.isBotEmbed = false,
    this.embedTitle,
    this.embedFooter,
    this.embedColor,
    this.botButtons = const [], // NEW
    this.botConfig, // NEW
    this.reactions = const {}, // NEW
    this.senderAvatarFrameUrl,
    this.senderRole, // NEW
    this.isSeen = false,
    this.showReadReceipts = true,
    this.linkPreview,
  });
}

class ChatBubble extends StatelessWidget {
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  final ChatBubbleMessage message;
  final bool isHighlighted;
  final Function(BotButton)? onBotButtonAction; // NEW
  final Function(String)? onReact; // NEW
  final VoidCallback? onLongPress; // NEW

  const ChatBubble({
    super.key,
    required this.message,
    this.isHighlighted = false,
    this.onBotButtonAction, // NEW
    this.onReact, // NEW
    this.onLongPress, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final showHighlight = isHighlighted;

    return Container(
      decoration: BoxDecoration(
        color: showHighlight ? Wumbleheme.primaryColor.withOpacity(0.3) : Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar on the LEFT for other user's messages
          if (!message.isMe) _buildAvatar(context),
          if (!message.isMe) const SizedBox(width: 8),

          // The bubble content
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!message.isOneOnOne && !message.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.senderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (message.senderLevel != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37), // Gold color for badge
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Lv${message.senderLevel}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (message.senderRole != null && message.senderRole!.toLowerCase() != 'member') ...[
                          const SizedBox(width: 4),
                          _buildRoleBadge(message.senderRole!),
                        ]
                      ],
                    ),
                  ),
                _buildContent(context),
                if (message.reactions.isNotEmpty) 
                  _buildReactionsDisplay(context),
              ],
            ),
          ),


          // Avatar on the RIGHT for own messages
          if (message.isMe) const SizedBox(width: 8),
          if (message.isMe) _buildAvatar(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    if (message.isOneOnOne) return const SizedBox.shrink();

    return UserAvatar(
      userId: message.senderId,
      avatarUrl: message.senderAvatarUrl,
      displayName: message.senderName,
      communityId: message.communityId,
      radius: 16,
      avatarFrameUrl: message.senderAvatarFrameUrl,
      skipFirestoreSync: false, // 🚀 NOW SAFE with Singleton Manager
      isAnimated: false, // 🛑 DISABLED FOR PERFORMANCE IN CHAT
      isBot: message.botConfig != null || message.senderId.startsWith('BOT_'),
      onTap: message.botConfig != null 
        ? () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => BotMiniProfile(bot: message.botConfig!),
            )
        : null,
    );
  }

  /// Route to the right content builder
  Widget _buildContent(BuildContext context) {
    if (message.type == MessageType.sticker) {
      return _buildSticker(context);
    }
    if (message.type == MessageType.image) {
      return _buildImage(context);
    }
    if (message.type == MessageType.voice) {
      return Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.replyToId != null) _buildReplyPreview(context),
          GestureDetector(
            onLongPress: onLongPress,
            child: VoiceMessageBubble(
              isMe: message.isMe,
              voiceUrl: message.voiceUrl,
              localPath: message.localPath,
            ),
          ),
          _buildStatus(context),
        ],
      );
    }
    return _buildTextBubble(context);
  }

  Widget _buildImage(BuildContext context) {
    if (message.imageUrl == null && message.localPath == null) {
      return const SizedBox.shrink();
    }

    final hasText = message.text != null && message.text!.isNotEmpty;

    return Column(
      crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.replyToId != null) _buildReplyPreview(context),
        if (hasText)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            child: _renderMessageText(context, message.text!, fontSize: 13),
          ),
        GestureDetector(
          onTap: message.imageUrl != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ImageViewerScreen(imageUrl: message.imageUrl!),
                    ),
                  );
                }
              : null,
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
              maxHeight: 200,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: message.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: MediaOptimizer.post(message.imageUrl!),
                      fit: BoxFit.cover,
                      memCacheWidth: 600, // Optimize decoding memory
                      placeholder: (context, url) => Container(
                        padding: const EdgeInsets.all(20),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white38),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(
                          File(message.localPath!),
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.5),
                          colorBlendMode: BlendMode.darken,
                        ),
                        const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ],
                    ),
            ),
          ),
        ),
        if (message.botButtons.isNotEmpty) _buildBotButtons(context),
        _buildStatus(context),
      ],
    );
  }

  Widget _buildSticker(BuildContext context) {
    return Column(
      crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.replyToId != null) _buildReplyPreview(context),
        GestureDetector(
          onTap: () => _showSaveStickerDialog(context),
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.5,
              maxHeight: 150,
            ),
            child: message.stickerUrl != null
                  ? CachedNetworkImage(
                      imageUrl: MediaOptimizer.optimize(message.stickerUrl!, width: 400, height: 400),
                      fit: BoxFit.contain,
                      memCacheWidth: 350, // Stickers don't need HD texture memory
                      placeholder: (context, url) => const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                    )
                  : message.localPath != null
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(
                              File(message.localPath!),
                              fit: BoxFit.contain,
                              opacity: const AlwaysStoppedAnimation(0.5),
                            ),
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            ),
                          ],
                        )
                      : const Center(child: Icon(Icons.error)),
          ),
        ),
        _buildStatus(context),
      ],
    );
  }

  void _showSaveStickerDialog(BuildContext context) {
    if (message.stickerUrl == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                height: 100,
                child: CachedNetworkImage(imageUrl: MediaOptimizer.optimize(message.stickerUrl!, width: 300, height: 300)),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<String>>(
              future: context.read<ChatRepository>().getFavoriteStickers(FirebaseAuth.instance.currentUser?.uid ?? ''),
              builder: (context, snapshot) {
                final favorites = snapshot.data ?? [];
                final isFavorite = favorites.contains(message.stickerUrl);
                
                return ListTile(
                  leading: Icon(
                    isFavorite ? Icons.star : Icons.star_border, 
                    color: isFavorite ? Colors.amber : Wumbleheme.secondaryColor
                  ),
                  title: Text(
                    isFavorite ? 'Quitar de Favoritos' : 'Agregar a Favoritos', 
                    style: const TextStyle(color: Colors.white)
                  ),
                  onTap: () async {
                    final userId = FirebaseAuth.instance.currentUser?.uid;
                    if (userId != null) {
                      try {
                        if (isFavorite) {
                          await context.read<ChatRepository>().removeStickerFromFavorites(userId, message.stickerUrl!);
                        } else {
                          await context.read<ChatRepository>().addStickerToFavorites(userId, message.stickerUrl!);
                        }
                        
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isFavorite ? 'Sticker eliminado de favoritos' : 'Sticker guardado en favoritos')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          String errorMsg = 'Error al procesar sticker';
                          if (e.toString().contains('ALCANZADO_LIMITE_STICKERS')) {
                            errorMsg = '¡Límite alcanzado! Solo puedes tener 100 stickers favoritos.';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(BuildContext context) {
    if (message.isBotEmbed) {
      return _buildEmbedBubble(context);
    }

    if (message.bubbleStyle != null) {
      return _buildDecoratedBubble(context, message.bubbleStyle!);
    }

    // Solid-ish bubbles for readability on any background
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final currentUserDisplayName = FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';
    final isMentioned = message.text != null && message.text!.contains('@$currentUserDisplayName');

    final bubbleColor = isMentioned
        ? Colors.orange.shade900.withOpacity(0.85) // Highlight color for mentions
        : message.isMe
            ? Colors.green.shade800.withOpacity(0.85) // Dark green for own messages
            : Colors.black.withOpacity(0.65); // Dark for others

    return Column(
      crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: message.isMe ? const Radius.circular(18) : const Radius.circular(0),
              bottomRight: message.isMe ? const Radius.circular(0) : const Radius.circular(18),
            ),
            // Removed BoxShadow to save 30% of rasterization time on complex shapes
            border: Border.all(
              color: isMentioned
                  ? Colors.orangeAccent.withOpacity(0.5)
                  : message.isMe
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
              width: isMentioned ? 2 : 1,
            ),
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          child: Column(
            crossAxisAlignment:
                message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.replyToId != null) _buildReplyPreview(context),
              _renderMessageText(context, message.text ?? ''),
              if (message.linkPreview != null && message.linkPreview!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinkPreviewCard(data: message.linkPreview!, isMe: message.isMe),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '(editado)',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    _buildStatus(context),
                  ],
                ),
              ],
            ),
          ),
        if (message.botButtons.isNotEmpty) _buildBotButtons(context),
      ],
    );
  }

  Widget _buildEmbedBubble(BuildContext context) {
    final embedColor = Color(message.embedColor ?? 0xFF2B2D31);
    
    return Column(
      crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2D31),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: embedColor, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.embedTitle != null && message.embedTitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      message.embedTitle!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                if (message.text != null && message.text!.isNotEmpty)
                  _renderMessageText(context, message.text!),
                if (message.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: MediaOptimizer.post(message.imageUrl!),
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                      ),
                    ),
                  ),
                if (message.embedFooter != null && message.embedFooter!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.embedFooter!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          _timeFormat.format(message.timestamp),
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (message.botButtons.isNotEmpty) _buildBotButtons(context),
      ],
    );
  }

  Widget _buildBotButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: message.isMe ? WrapAlignment.end : WrapAlignment.start,
        children: message.botButtons.map((btn) {
          return InkWell(
            onTap: () => onBotButtonAction?.call(btn),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (btn.isUrl)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.open_in_new, size: 14, color: Colors.white70),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.bolt, size: 14, color: Wumbleheme.secondaryColor),
                    ),
                  Text(
                    btn.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDecoratedBubble(BuildContext context, ChatBubbleStyle style) {
    final isMe = message.isMe;
    final backgroundColor = Color(style.backgroundColorValue);
    final secondaryColor = style.secondaryColorValue != null ? Color(style.secondaryColorValue!) : null;
    final textColor = Color(style.textColorValue);
    final config = style.advancedConfig;

    final padding = config != null
        ? EdgeInsets.only(
            top: config.paddingTop,
            bottom: config.paddingBottom,
            left: config.paddingLeft,
            right: config.paddingRight,
          )
        : const EdgeInsets.symmetric(vertical: 10, horizontal: 14);

    DecorationImage? bgImage;
    if (style.backgroundImageUrl != null && style.backgroundImageUrl!.isNotEmpty) {
      Rect? slice;
      if (config != null && (config.sliceLeft > 0 || config.sliceTop > 0 || config.sliceRight > 0 || config.sliceBottom > 0)) {
        slice = Rect.fromLTRB(config.sliceLeft, config.sliceTop, config.sliceRight, config.sliceBottom);
      }
      bgImage = DecorationImage(
        image: _getImageProvider(style.backgroundImageUrl!),
        fit: slice != null ? BoxFit.fill : BoxFit.cover,
        centerSlice: slice,
        opacity: slice != null ? 1.0 : 0.2, 
      );
    }

    List<BoxShadow> shadows = [];
    if (config != null && config.shadowColorValue != null) {
      shadows = [
        BoxShadow(
          color: Color(config.shadowColorValue!),
          blurRadius: config.shadowBlurRadius,
          offset: Offset(config.shadowOffsetX, config.shadowOffsetY),
        )
      ];
    } else {
      if (style.hasGlow) {
        shadows.add(
          BoxShadow(
            color: backgroundColor.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        );
      }
      shadows.add(
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      );
    }

    final decoration = style.shapeId == null || style.shapeId == 'default'
        ? BoxDecoration(
            color: secondaryColor == null ? backgroundColor : null,
            gradient: secondaryColor != null 
                ? LinearGradient(
                    colors: [backgroundColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(0),
              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18),
            ),
            image: bgImage,
            boxShadow: shadows,
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          )
        : ShapeDecoration(
            color: secondaryColor == null ? backgroundColor : null,
            gradient: secondaryColor != null 
                ? LinearGradient(
                    colors: [backgroundColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            shape: BubbleShapeBorder(
              shapeId: style.shapeId,
              isMe: isMe,
              borderColor: Colors.white.withOpacity(0.1),
              borderWidth: 1,
              advancedConfig: config,
            ),
            image: bgImage, // Note: ShapeDecoration supports image too since Flutter 3.0+ (DecorationImage usually goes in image property if supported, else we can wrap)
            shadows: shadows,
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Bubble Container
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background Layer
              Positioned.fill(
                child: Container(decoration: decoration),
              ),
              
              // Custom Layers
              if (config != null)
                Positioned.fill(
                  child: ClipPath(
                    clipper: config != null && config.clipLayers ? BubbleShapeClipper(shapeId: style.shapeId, isMe: isMe, advancedConfig: config) : null,
                    clipBehavior: config != null && config.clipLayers ? Clip.antiAlias : Clip.none,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: config.layers.map((layer) => _buildLayerWidget(layer)).toList(),
                    ),
                  ),
                ),

              // Content Layer
              Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.replyToId != null) _buildReplyPreview(context),
                    _renderMessageText(context, message.text ?? '', textColor: textColor),
                    if (message.isEdited)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '(editado)',
                          style: TextStyle(
                              color: textColor.withOpacity(0.4),
                              fontSize: 10,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Corner ornaments
        if (style.topLeftOrnamentUrl != null && style.topLeftOrnamentUrl!.isNotEmpty)
          _buildCornerOrnament(context, style.topLeftOrnamentUrl!, top: -12, left: -8),
        if (style.topRightOrnamentUrl != null && style.topRightOrnamentUrl!.isNotEmpty)
          _buildCornerOrnament(context, style.topRightOrnamentUrl!, top: -12, right: -8),
        if (style.bottomLeftOrnamentUrl != null && style.bottomLeftOrnamentUrl!.isNotEmpty)
          _buildCornerOrnament(context, style.bottomLeftOrnamentUrl!, bottom: -12, left: -8),
        if (style.bottomRightOrnamentUrl != null && style.bottomRightOrnamentUrl!.isNotEmpty)
          _buildCornerOrnament(context, style.bottomRightOrnamentUrl!, bottom: -12, right: -8),
      ],
    );
  }

  Widget _buildLayerWidget(BubbleLayer layer) {
    Widget content;
    
    if (layer.type == 'box' || (layer.type == 'shape' && (layer.url.isEmpty || layer.url == 'none'))) {
      final color = Color(layer.colorValue ?? 0xFFFFFFFF);
      final secondaryColor = layer.secondaryColorValue != null ? Color(layer.secondaryColorValue!) : null;
      
      content = Container(
        width: 100 * layer.scale, // Base size to scale from
        height: 100 * layer.scale,
        decoration: BoxDecoration(
          color: secondaryColor == null ? color : null,
          gradient: secondaryColor != null 
              ? LinearGradient(colors: [color, secondaryColor]) 
              : null,
          borderRadius: BorderRadius.circular(layer.borderRadius),
        ),
      );
    } else {
      content = Transform.scale(
        scale: layer.scale,
        child: _buildDecorativeImage(layer.url),
      );
    }

    if (layer.blur > 0) {
      content = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: layer.blur, sigmaY: layer.blur),
        child: content,
      );
    }

    if (layer.opacity < 1.0) {
      content = Opacity(opacity: layer.opacity, child: content);
    }

    return Positioned.fill(
      child: Align(
        alignment: Alignment(layer.x, layer.y),
        child: Transform.rotate(
          angle: layer.rotation,
          child: content,
        ),
      ),
    );
  }

  Widget _buildCornerOrnament(BuildContext context, String url, {double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SizedBox(
        width: 32,
        height: 32,
        child: _buildDecorativeImage(url),
      ),
    );
  }

  ImageProvider _getImageProvider(String source) {
    if (source.startsWith('assets/')) {
      return AssetImage(source);
    }
    if (source.startsWith('/') || source.contains(':\\') || source.startsWith('file://')) {
      final cleanPath = source.replaceFirst('file://', '');
      return FileImage(File(cleanPath));
    }
    return CachedNetworkImageProvider(source);
  }

  Widget _buildDecorativeImage(String source) {
    if (source.startsWith('assets/')) {
      return Image.asset(source, fit: BoxFit.contain);
    }
    if (source.startsWith('/') || source.contains(':\\') || source.startsWith('file://')) {
      final cleanPath = source.replaceFirst('file://', '');
      return Image.file(File(cleanPath), fit: BoxFit.contain);
    }
    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.contain,
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return InkWell(
      onTap: () {
        if (message.replyToId != null) {
          // Trigger jump to message - we'll handle this via a callback or notification
          // For now, let's use a notification logic that the screen can listen to.
          // Or we can look for the nearest BuildContext that can handle this.
          // Dispatching a custom event or using a inherited widget would be better,
          // but for simplicity, let's use the ChatBloc if available.
          // Better: just use a callback if we can, or search for the message id in the list.
          
          // Actually, let's use a standard way: dispatch an event that the screen's ScrollController listens to.
          // But since this is a stateless widget, we can use a custom notification.
          _jumpToMessage(context, message.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Wumbleheme.primaryColor, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.replyToSenderName ?? 'Usuario',
                    style: const TextStyle(
                      color: Wumbleheme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (message.replyToType == MessageType.image)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.image, size: 12, color: Colors.white70),
                        ),
                      if (message.replyToType == MessageType.sticker)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.sticky_note_2, size: 12, color: Colors.white70),
                        ),
                      if (message.replyToType == MessageType.voice)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.mic, size: 12, color: Colors.white70),
                        ),
                      Expanded(
                        child: Text(
                          message.replyToText ?? (message.replyToType == MessageType.image ? 'Foto' : message.replyToType == MessageType.sticker ? 'Sticker' : message.replyToType == MessageType.voice ? 'Mensaje de voz' : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (message.replyToImageUrl != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: message.replyToImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.white10),
                    errorWidget: (context, url, error) => const Icon(Icons.error, size: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _jumpToMessage(BuildContext context, String messageId) {
    ScrollToMessageNotification(messageId).dispatch(context);
  }

  TextSpan _buildTextSpanWithMentions(BuildContext context, String text, {Color? textColor}) {
    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    
    int lastMatchEnd = 0;
    
    for (final Match match in mentionRegex.allMatches(text)) {
      // Pre-match text
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: TextStyle(color: textColor)));
      }
      
      // Match (@username)
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: Wumbleheme.primaryColor,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white10,
        ),
      ));
      
      lastMatchEnd = match.end;
    }
    
    // Remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: TextStyle(color: textColor)));
    }
    
    return TextSpan(children: spans);
  }

  Widget _renderMessageText(BuildContext context, String text, {double fontSize = 14, Color? textColor}) {
    if (text.length < 200 && !text.contains('\n') && !text.contains('http') && !text.contains('**') && !text.contains('#')) {
       // Super fast path for plain short messages
       return LinkifyText(
         text,
         style: TextStyle(color: textColor ?? Colors.white, fontSize: fontSize, height: 1.4),
       );
    }

    // Pre-process mentions for markdown compatibility
    final String processedText = text.replaceAllMapped(
      RegExp(r'@(\w+)'), 
      (match) => '**${match.group(0)}**'
    );
    
    return MarkdownBody(
      data: processedText,
      selectable: false,
      onTapLink: (text, href, title) {
        if (href != null) {
          LinkNavigator.handleUrl(context, href);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: textColor ?? Colors.white, fontSize: fontSize, height: 1.4),
        strong: TextStyle(
          color: textColor ?? Wumbleheme.secondaryColor, 
          fontWeight: FontWeight.bold
        ),
        em: TextStyle(color: textColor ?? Colors.white, fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildReactionsDisplay(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: message.isMe ? WrapAlignment.end : WrapAlignment.start,
        children: message.reactions.entries.map((entry) {
          final reaction = entry.key;
          final userIds = entry.value;
          final isStandardEmoji = !reaction.startsWith('http');
          final hasReacted = userIds.contains(FirebaseAuth.instance.currentUser?.uid);

          return GestureDetector(
            onTap: () {
              UserListBottomSheet.show(
                context,
                title: isStandardEmoji ? 'Personas que reaccionaron $reaction' : 'Personas que reaccionaron',
                userIds: userIds,
                communityId: message.communityId,
              );
            },
            onLongPress: () => onReact?.call(reaction),

            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasReacted 
                    ? Wumbleheme.primaryColor.withOpacity(0.2) 
                    : Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasReacted 
                      ? Wumbleheme.primaryColor.withOpacity(0.5) 
                      : Colors.white12,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isStandardEmoji)
                    Text(reaction, style: const TextStyle(fontSize: 12))
                  else
                    CachedNetworkImage(
                      imageUrl: reaction,
                      width: 16,
                      height: 16,
                      memCacheWidth: 32,
                      memCacheHeight: 32,
                      fit: BoxFit.contain,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    '${userIds.length}',
                    style: TextStyle(
                      color: hasReacted ? Wumbleheme.primaryColor : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    if (!message.isMe || !message.showReadReceipts || !message.isOneOnOne) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Icon(
        message.isSeen ? Icons.done_all : Icons.done,
        size: 13,
      ),
    );
  }
  Widget _buildRoleBadge(String role) {
    String label = role;
    Color color = Colors.grey;
    Color textColor = Colors.white;

    final r = role.toLowerCase();
    if (r == 'leader' || r == 'lider') {
      label = 'Líder';
      color = const Color(0xFFFF4136); // Red
    } else if (r == 'curator' || r == 'curador') {
      label = 'Curador';
      color = const Color(0xFF0074D9); // Blue
    } else if (r == 'bot') {
      label = 'BOT';
      color = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ScrollToMessageNotification extends Notification {
  final String messageId;
  ScrollToMessageNotification(this.messageId);
}
