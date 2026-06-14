import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wumble/core/utils/media_helper.dart';
import 'package:wumble/features/community/domain/shared_image_model.dart';
import 'package:wumble/features/community/domain/shared_folder_repository.dart';
import 'package:wumble/injection_container.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/features/community/presentation/widgets/shared_image_viewer.dart';

class SharedFolderScreen extends StatefulWidget {
  final String communityId;

  SharedFolderScreen({super.key, required this.communityId});

  @override
  State<SharedFolderScreen> createState() => SharedFolderScreenState();
}

class SharedFolderScreenState extends State<SharedFolderScreen> with AutomaticKeepAliveClientMixin {
  final SharedFolderRepository _repository = sl<SharedFolderRepository>();
  List<SharedImage> _images = [];
  List<SharedFolderCategory> _categories = [];
  String? _selectedCategoryId;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant SharedFolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.communityId != widget.communityId) {
      _selectedCategoryId = null; // Reiniciar filtro
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.getCategories(widget.communityId),
        _repository.getImages(widget.communityId, categoryId: _selectedCategoryId),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<SharedFolderCategory>;
        _images = results[1] as List<SharedImage>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> pickAndUploadImage() async {
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    
    if (image != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      try {
        await _repository.uploadImage(
          communityId: widget.communityId,
          authorId: user.uid,
          imageFile: File(image.path),
          categoryId: _selectedCategoryId,
        );
        if (mounted) {
          Navigator.pop(context); // Close loading
          _loadData(); // Reload
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Imagen subida con éxito'))),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir imagen: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          SizedBox(height: 16),
          _buildHeader(),
          _buildCategorySelector(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.white,
              backgroundColor: const Color(0xFF1E1E2C),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white24))
                  : _buildImageGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tr('Carpeta Compartida'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white70),
            onPressed: pickAndUploadImage,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : _categories[index - 1];
          final isSelected = isAll ? _selectedCategoryId == null : _selectedCategoryId == category?.id;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(
                isAll ? 'Todos' : category!.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategoryId = isAll ? null : category!.id;
                    _loadData();
                  });
                }
              },
              selectedColor: Theme.of(context).colorScheme.secondary,
              backgroundColor: Colors.white.withOpacity(0.05),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.white10,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_images.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text(
                    tr('No hay imágenes aún'),
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final image = _images[index];
        return GestureDetector(
          onTap: () {
            SharedImageViewer.show(
              context,
              image: image,
              communityId: widget.communityId,
              onDelete: _loadData,
            );
          },
          child: Hero(
            tag: 'shared_image_${image.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white10,
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: image.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.white.withOpacity(0.05),
                  child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white12))),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
              ),
            ),
          ),
        );
      },
    );
  }
}
