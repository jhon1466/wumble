import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme.dart';
import '../../../profile/domain/custom_frame_model.dart';
import '../../../../core/widgets/avatar_frame.dart';
import '../../../../core/utils/media_helper.dart';

// ─────────────────────────────────────────────────────────────
// Data class — one frame entry in the pack
// ─────────────────────────────────────────────────────────────
class _FrameEntry {
  final String id;
  File? file;
  String? networkUrl;
  FrameType type;
  final TextEditingController nameCtrl;

  _FrameEntry({
    this.file,
    this.networkUrl,
    required this.type,
    String? existingId,
  })  : id = existingId ?? Uuid().v4(),
        nameCtrl = TextEditingController();

  void dispose() => nameCtrl.dispose();
}

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class PublishFrameScreen extends StatefulWidget {
  final List<CustomAvatarFrame>? initialFrames;

  PublishFrameScreen({super.key, this.initialFrames});

  @override
  State<PublishFrameScreen> createState() => _PublishFrameScreenState();
}

class _PublishFrameScreenState extends State<PublishFrameScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _packNameController = TextEditingController();
  final _packPriceController = TextEditingController(text: '0'); // Total pack price
  final _priceController = TextEditingController(text: '0');     // Single-frame price
  final _creditsController = TextEditingController();             // Credits/Source controller

  final List<_FrameEntry> _frames = [];
  int _previewIndex = 0;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  int _uploadingIndex = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // User data for preview
  String? _userAvatarUrl;
  String _userDisplayName = '?';
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadCurrentUser();
    if (widget.initialFrames != null && widget.initialFrames!.isNotEmpty) {
      _initFromExisting();
    }
  }

  void _initFromExisting() {
    final first = widget.initialFrames!.first;
    _packNameController.text = first.packName ?? first.name;
    _packPriceController.text = first.packPrice.toString();
    _priceController.text = first.price.toString();
    _creditsController.text = first.credits ?? '';

    for (var f in widget.initialFrames!) {
      final entry = _FrameEntry(
        networkUrl: f.url,
        type: f.type,
        existingId: f.id,
      );
      entry.nameCtrl.text = f.name;
      _frames.add(entry);
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userAvatarUrl = data['avatarUrl'] as String?;
          _userDisplayName = (data['displayName'] as String?)?.isNotEmpty == true
              ? (data['displayName'] as String)[0].toUpperCase()
              : (authUser.displayName?.isNotEmpty == true
                  ? authUser.displayName![0].toUpperCase()
                  : '?');
          _loadingUser = false;
        });
      } else if (mounted) {
        setState(() => _loadingUser = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  @override
  void dispose() {
    _packNameController.dispose();
    _packPriceController.dispose();
    _priceController.dispose();
    _creditsController.dispose();
    _pulseController.dispose();
    for (final f in _frames) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Add frame ──────────────────────────────────────────────

  Future<void> _addFrame(bool isScreenBlend) async {
    final picked = await MediaHelper.pickImageWithOptimization(context);
    if (picked == null) return;

    final entry = _FrameEntry(
      file: File(picked.path),
      type: isScreenBlend ? FrameType.video : FrameType.image,
    );

    setState(() {
      _frames.add(entry);
      _previewIndex = _frames.length - 1;
    });
  }

  void _removeFrame(int index) {
    _frames[index].dispose();
    setState(() {
      _frames.removeAt(index);
      if (_previewIndex >= _frames.length) {
        _previewIndex = _frames.isEmpty ? 0 : _frames.length - 1;
      }
    });
  }

  void _showAddPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                tr('Tipo de Marco'),
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.image_rounded, color: Colors.blueAccent),
              ),
              title: Text(tr('Marco Normal (Clásico)'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('PNG o GIF transparente en tamaño estándar', style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () { Navigator.pop(ctx); _addFrame(false); },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent),
              ),
              title: Text(tr('Efecto Especial (Animado)'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Fondo negro desaparece, tamaño gigante', style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () { Navigator.pop(ctx); _addFrame(true); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Upload ─────────────────────────────────────────────────

  Future<void> _uploadPack() async {
    if (!_formKey.currentState!.validate()) return;
    if (_frames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Agrega al menos un marco al pack')), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() { _isUploading = true; _uploadProgress = 0; _uploadingIndex = 0; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final packName = _packNameController.text.trim();
      final total = _frames.length;
      final isPack = total > 1;

      // Pack pricing
      final packPrice = isPack ? (int.tryParse(_packPriceController.text.trim()) ?? 0) : 0;
      // Individual price: if pack, split evenly (ceiling); if solo, use _priceController
      final singlePrice = isPack
          ? (packPrice / total).ceil()
          : (int.tryParse(_priceController.text.trim()) ?? 0);
      final packId = isPack 
          ? (widget.initialFrames?.first.packId ?? Uuid().v4()) 
          : null;

      // Clean up previous pack associations if editing
      if (packId != null && widget.initialFrames != null) {
        final oldDocs = await FirebaseFirestore.instance
            .collection('avatar_frames')
            .where('packId', isEqualTo: packId)
            .get();
        for (var doc in oldDocs.docs) {
          await doc.reference.update({'packId': null, 'packName': null});
        }
      }

      for (int i = 0; i < total; i++) {
        final entry = _frames[i];
        setState(() { _uploadingIndex = i; _uploadProgress = 0; });

        final frameName = entry.nameCtrl.text.trim().isEmpty
            ? (total == 1 ? packName : '$packName ${i + 1}')
            : entry.nameCtrl.text.trim();

        String? downloadUrl = entry.networkUrl;
        if (entry.file != null) {
          // --- COMPRESIÓN DE SEGURIDAD ---
          final fileToUpload = await MediaHelper.compressFile(entry.file!);

          final ext = 'png';
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('avatar_frames')
              .child(user.uid)
              .child('${entry.id}.$ext');

          final uploadTask = storageRef.putFile(fileToUpload);
          uploadTask.snapshotEvents.listen((snap) {
            if (mounted) {
              setState(() {
                _uploadProgress = snap.bytesTransferred / snap.totalBytes;
              });
            }
          });

          await uploadTask;
          downloadUrl = await storageRef.getDownloadURL();
        }

        final newFrame = CustomAvatarFrame(
          id: entry.id,
          uploaderId: user.uid,
          name: frameName,
          price: singlePrice,
          packPrice: packPrice,
          packSize: isPack ? total : 0,
          type: entry.type,
          url: downloadUrl!,
          createdAt: DateTime.now(),
          packId: packId,
          packName: isPack ? packName : null,
          credits: _creditsController.text.trim().isEmpty ? null : _creditsController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('avatar_frames')
            .doc(entry.id)
            .set(newFrame.toMap());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(total > 1
                ? '¡Pack de $total marcos publicado con éxito!'
                : '¡Marco publicado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          _frames.length > 1 ? 'Crear Pack de Marcos (${_frames.length})' : 'Crear Marco',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Wumbleheme.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── PREVIEW SECTION ───────────────────────────────────
            _buildPreviewSection(),

            // ── FRAMES LIST ───────────────────────────────────────
            _buildFramesList(),

            // ── FORM ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pack name
                    _buildLabel(_frames.length > 1 ? 'Nombre del Pack' : 'Nombre del Marco'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _packNameController,
                      hint: _frames.length > 1 ? 'Ej: Fuego Místico Pack...' : 'Ej: Llamas de Neón...',
                      icon: Icons.label_outline_rounded,
                      validator: (v) => v == null || v.isEmpty ? 'El nombre es requerido' : null,
                    ),

                    const SizedBox(height: 20),

                    // Credits
                    _buildLabel('Créditos / Autor Original (opcional)'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _creditsController,
                      hint: 'Créditos al artista, link de origen, etc.',
                      icon: Icons.attribution_rounded,
                    ),

                    const SizedBox(height: 20),

                    // Price — dynamic based on pack size
                    if (_frames.length <= 1) ...[
                      // Single frame: simple price field
                      _buildLabel('Precio (AC)'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _priceController,
                        hint: '0 = gratis',
                        icon: Icons.monetization_on_outlined,
                        keyboardType: TextInputType.number,
                        textColor: Colors.amber,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (int.tryParse(v) == null) return 'Debe ser un número';
                          return null;
                        },
                      ),
                    ] else ...[
                      // Pack: pack total price field + auto-calculated individual
                      _buildLabel('Precio del Pack Completo (AC)'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _packPriceController,
                        hint: '0 = gratis',
                        icon: Icons.shopping_bag_outlined,
                        keyboardType: TextInputType.number,
                        textColor: Colors.amber,
                        onChanged: (_) => setState(() {}), // Rebuild to show calc
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (int.tryParse(v) == null) return 'Debe ser un número';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      // Auto-calculated individual price
                      Builder(builder: (_) {
                        final packTotal = int.tryParse(_packPriceController.text) ?? 0;
                        final perFrame = _frames.isEmpty ? 0 : (packTotal / _frames.length).ceil();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                tr('Precio individual por marco: '),
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                              ),
                              Text(
                                '$perFrame AC',
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white24, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _frames.length > 1
                                ? 'Los usuarios pueden comprar marcos o el pack completo. Si ya tienen alguno, el precio del pack se descuenta automáticamente.'
                                : 'Precio 0 = disponible gratis para todos',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // Upload progress / button
                    if (_isUploading) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subiendo marco ${_uploadingIndex + 1} de ${_frames.length}...',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          minHeight: 6,
                          color: Wumbleheme.secondaryColor,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ] else
                      ElevatedButton.icon(
                        onPressed: _frames.isEmpty ? null : _uploadPack,
                        icon: Icon(_frames.length > 1 ? Icons.upload_rounded : Icons.cloud_upload_rounded),
                        label: Text(
                          _frames.isEmpty
                              ? 'Agrega al menos un marco'
                              : _frames.length > 1
                                  ? 'Publicar Pack (${_frames.length} marcos)'
                                  : 'Publicar Marco',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _frames.isEmpty ? Colors.white10 : Wumbleheme.primaryColor,
                          disabledBackgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: _frames.isEmpty ? 0 : 6,
                          shadowColor: Wumbleheme.primaryColor.withOpacity(0.4),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview Section ────────────────────────────────────────

  Widget _buildPreviewSection() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Column(
        children: [
          Text(
            tr('VISTA PREVIA'),
            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 24),

          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _frames.isNotEmpty ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: _buildLivePreview(),
          ),

          // Page indicator when multiple frames
          if (_frames.length > 1) ...[
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_frames.length, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _previewIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _previewIndex ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _previewIndex
                          ? Wumbleheme.primaryColor
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 8),
            Text(
              'Marco ${_previewIndex + 1} de ${_frames.length}',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],

          SizedBox(height: 20),

          // Add button
          GestureDetector(
            onTap: _showAddPicker,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Wumbleheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Wumbleheme.primaryColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: Wumbleheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _frames.isEmpty ? 'Seleccionar imagen o gif' : 'Agregar otro marco',
                    style: TextStyle(color: Wumbleheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    double size = 120;

    // Avatar base
    Widget avatarBase = _loadingUser
        ? Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white10,
            ),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : CircleAvatar(
            radius: size / 2,
            backgroundColor: Wumbleheme.surfaceColor,
            backgroundImage: (_userAvatarUrl != null && _userAvatarUrl!.isNotEmpty)
                ? CachedNetworkImageProvider(_userAvatarUrl!)
                : null,
            child: (_userAvatarUrl == null || _userAvatarUrl!.isEmpty)
                ? Text(
                    _userDisplayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.35,
                    ),
                  )
                : null,
          );

    if (_frames.isEmpty) return avatarBase;

    final entry = _frames[_previewIndex];
    final isScreenBlend = entry.type == FrameType.video;
    final canvasSize = isScreenBlend ? size * 1.7 : size * 1.3;

    // For local file preview we use a dummy FramedAvatar without a real frameId,
    // but we overlay the image on top manually
    return SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: SizedBox(
          width: canvasSize,
          height: canvasSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Avatar
              SizedBox(width: size, height: size, child: avatarBase),
              // Frame overlay from local file or network
              IgnorePointer(
                child: isScreenBlend 
                  ? ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
                        blendMode: BlendMode.screen,
                        child: Transform.scale(
                          scale: 1.05,
                          child: entry.file != null 
                            ? Image.file(entry.file!, width: canvasSize, height: canvasSize, fit: BoxFit.cover)
                            : CachedNetworkImage(imageUrl: entry.networkUrl!, width: canvasSize, height: canvasSize, fit: BoxFit.cover),
                        ),
                      ),
                    )
                  : (entry.file != null 
                      ? Image.file(entry.file!, width: canvasSize, height: canvasSize, fit: BoxFit.cover)
                      : CachedNetworkImage(imageUrl: entry.networkUrl!, width: canvasSize, height: canvasSize, fit: BoxFit.cover)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ── Frames List ────────────────────────────────────────────

  Widget _buildFramesList() {
    if (_frames.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Text(
                tr('MARCOS EN EL PACK'),
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              const Spacer(),
              Text(
                '${_frames.length} marco${_frames.length != 1 ? 's' : ''}',
                style: TextStyle(color: Wumbleheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _frames.length + 1, // +1 for add button
            itemBuilder: (context, i) {
              if (i == _frames.length) {
                // Add more button
                return GestureDetector(
                  onTap: _showAddPicker,
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, color: Colors.white38, size: 28),
                        const SizedBox(height: 4),
                        Text(tr('Añadir'), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }

              final entry = _frames[i];
              final isSelected = i == _previewIndex;
              return GestureDetector(
                onTap: () => setState(() => _previewIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Wumbleheme.primaryColor : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: entry.file != null 
                          ? Image.file(entry.file!, width: 80, height: 110, fit: BoxFit.cover)
                          : CachedNetworkImage(imageUrl: entry.networkUrl!, width: 80, height: 110, fit: BoxFit.cover),
                      ),
                      // Delete button (Only if not editing existing pack frames? Or allow deletion too)
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => _removeFrame(i),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                      // Index badge
                      Positioned(
                        bottom: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Wumbleheme.primaryColor : Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Individual name field for each frame if pack has multiple
        if (_frames.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Nombre del Marco ${_previewIndex + 1} (opcional)'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _frames[_previewIndex].nameCtrl,
                  hint: 'Dejar vacío para usar el nombre del pack + número',
                  icon: Icons.label_outline_rounded,
                ),
              ],
            ),
          ),
        const Divider(color: Colors.white10, height: 32),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  Widget _buildLabel(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Color? textColor,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(color: textColor ?? Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Wumbleheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
