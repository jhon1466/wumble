import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:giphy_get/giphy_get.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils/media_helper.dart';
import '../../../../core/utils/config.dart';
import '../../domain/chat_repository.dart';
import './sticker_creator_screen.dart';

class StickerSelector extends StatefulWidget {
  final Function(String) onStickerSelected;
  final Function(File) onCustomStickerCreated;

  const StickerSelector({
    super.key, 
    required this.onStickerSelected,
    required this.onCustomStickerCreated,
  });

  @override
  State<StickerSelector> createState() => _StickerSelectorState();
}

class _StickerSelectorState extends State<StickerSelector> {
  int _activeTab = 0; // 0: Favorites, 1: All, 2: History
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final List<String> _allStickers = [];
  List<String> _recentStickers = [];

  @override
  void initState() {
    super.initState();
    _loadRecentStickers();
  }

  Future<void> _loadRecentStickers() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('sticker_history_$_currentUserId');
    if (history != null && mounted) {
      setState(() {
        _recentStickers = history;
      });
    }
  }

  Future<void> _saveToHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = List.from(_recentStickers);
    current.remove(url);
    current.insert(0, url);
    
    // Limit to 20 recent stickers
    if (current.length > 20) current.removeLast();
    
    await prefs.setStringList('sticker_history_$_currentUserId', current);
    if (mounted) {
      setState(() {
        _recentStickers = current;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: FutureBuilder<List<String>>(
        future: context.read<ChatRepository>().getFavoriteStickers(_currentUserId),
        builder: (context, snapshot) {
          final favorites = snapshot.data ?? [];
          return Column(
            children: [
              _buildTabs(),
              Expanded(
                child: _activeTab == 0 // Favorites
                  ? _buildFavoritesTab(favorites)
                  : _activeTab == 1 // All
                    ? _buildStickerGrid(_allStickers, favorites: favorites)
                    : _buildStickerGrid(_recentStickers, favorites: favorites), // History
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildFavoritesTab(List<String> favorites) {
    if (_currentUserId.isEmpty) return _buildEmptyState();
    if (favorites.isEmpty) return _buildEmptyState();
    return _buildStickerGrid(favorites, favorites: favorites, isFavoriteTab: true);
  }

  Widget _buildStickerGrid(List<String> stickers, {required List<String> favorites, bool isFavoriteTab = false}) {
    if (stickers.isEmpty) return _buildEmptyState();
    
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final url = stickers[index];
        final isFavorite = favorites.contains(url);

        return InkResponse(
          onTap: () {
            _saveToHistory(url);
            widget.onStickerSelected(url);
          },
          onLongPress: () => isFavorite ? _confirmRemoveFavorite(url) : _confirmAddFavorite(url),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white24),
                ),
              ),
              if (isFavorite && !isFavoriteTab)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.star, color: Colors.amber, size: 14),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmAddFavorite(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Agregar a favoritos'), style: TextStyle(color: Colors.white)),
        content: Text(tr('¿Deseas guardar este sticker en tus favoritos?'), style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<ChatRepository>().addStickerToFavorites(_currentUserId, url);
                if (mounted) setState(() {}); // Trigger FutureBuilder rebuild
              } catch (e) {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            }, 
            child: Text(tr('Agregar'), style: TextStyle(color: Wumbleheme.secondaryColor))
          ),
        ],
      ),
    );
  }

  void _confirmRemoveFavorite(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Quitar de favoritos'), style: TextStyle(color: Colors.white)),
        content: Text(tr('¿Deseas eliminar este sticker de tus favoritos?'), style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ChatRepository>().removeStickerFromFavorites(_currentUserId, url);
              if (mounted) setState(() {}); // Trigger FutureBuilder rebuild
            }, 
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 12),
        Text(
          tr('No hay pegatinas aquí aún'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF1C2128),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          _buildTabIcon(Icons.star_border, 0),
          _buildTabIcon(Icons.emoji_emotions, 1),
          _buildTabIcon(Icons.history, 2),
          const Spacer(),
          _buildActionButton(Icons.gif_box, () async {
            try {
              final gif = await GiphyGet.getGif(
                context: context,
                apiKey: AppConfig.giphyApiKey,
                lang: GiphyLanguage.spanish,
                tabColor: Wumbleheme.secondaryColor,
              );

              if (gif != null && gif.images?.original?.url != null) {
                widget.onStickerSelected(gif.images!.original!.url!);
              }
            } catch (e) {
              debugPrint('Error en Giphy Chat: $e');
            }
          }),
          _buildActionButton(Icons.add_photo_alternate, () async {
            final xfile = await MediaHelper.pickImageWithOptimization(context);
            if (xfile == null || !mounted) return;

            final stickerFile = await Navigator.push<File>(
              context,
              MaterialPageRoute(
                builder: (context) => StickerCreatorScreen(imageFile: xfile),
              ),
            );

            if (stickerFile != null && mounted) {
              widget.onCustomStickerCreated(stickerFile);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildTabIcon(IconData icon, int index) {
    bool isActive = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        width: 60,
        height: double.infinity,
        decoration: BoxDecoration(
          border: isActive 
              ? const Border(bottom: BorderSide(color: Wumbleheme.secondaryColor, width: 2))
              : null,
        ),
        child: Icon(
          icon,
          color: isActive ? Wumbleheme.secondaryColor : Wumbleheme.textSecondary,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: double.infinity,
        child: Icon(
          icon,
          color: Wumbleheme.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}
