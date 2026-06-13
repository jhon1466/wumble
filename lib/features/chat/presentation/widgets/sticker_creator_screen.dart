import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme.dart';

class StickerCreatorScreen extends StatefulWidget {
  final XFile imageFile;

  const StickerCreatorScreen({super.key, required this.imageFile});

  @override
  State<StickerCreatorScreen> createState() => _StickerCreatorScreenState();
}

class _StickerCreatorScreenState extends State<StickerCreatorScreen> {
  bool _isMagicMode = true;
  bool _isProcessing = false;
  File? _processedFile;
  bool _isGif = false;

  final _segmenter = SelfieSegmenter(
    mode: SegmenterMode.single,
    enableRawSizeMask: true,
  );

  @override
  void initState() {
    super.initState();
    // Detect if it's a GIF
    final path = widget.imageFile.path.toLowerCase();
    _isGif = path.endsWith('.gif') || path.endsWith('.webp');
    
    if (_isGif) {
      _isMagicMode = false;
    }
    
    _processImage();
  }

  @override
  void dispose() {
    _segmenter.close();
    super.dispose();
  }

  Future<void> _processImage() async {
    setState(() => _isProcessing = true);
    
    try {
      if (!_isMagicMode) {
        // Optimization: Resize to max 512px even in full mode if it's not a GIF
        if (_isGif) {
          _processedFile = File(widget.imageFile.path);
        } else {
          final bytes = await File(widget.imageFile.path).readAsBytes();
          final originalImage = img.decodeImage(bytes);
          if (originalImage != null) {
            // Resize if too large
            img.Image finalImage = originalImage;
            if (originalImage.width > 512 || originalImage.height > 512) {
              finalImage = img.copyResize(
                originalImage, 
                width: originalImage.width >= originalImage.height ? 512 : null,
                height: originalImage.height > originalImage.width ? 512 : null,
              );
            }
            final tempDir = await getTemporaryDirectory();
            final outputPath = '${tempDir.path}/full_sticker_${DateTime.now().millisecondsSinceEpoch}.jpg';
            // Use JPG for full mode to save space (80% quality)
            final jpgBytes = img.encodeJpg(finalImage, quality: 80);
            _processedFile = await File(outputPath).writeAsBytes(jpgBytes);
          } else {
            _processedFile = File(widget.imageFile.path);
          }
        }
        setState(() => _isProcessing = false);
        return;
      }

      // MAGIC MODE (Background removal)
      final inputImage = InputImage.fromFilePath(widget.imageFile.path);
      final mask = await _segmenter.processImage(inputImage);
      
      if (mask == null) {
        setState(() {
          _isMagicMode = false;
          _processedFile = File(widget.imageFile.path);
          _isProcessing = false;
        });
        return;
      }

      final bytes = await File(widget.imageFile.path).readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("Failed to decode image");

      // Apply mask and Resize to 512 standard simultaneously
      final confidences = mask.confidences;
      final mWidth = mask.width;
      final mHeight = mask.height;

      // Create a result image based on the mask size first
      final extracted = img.Image(width: mWidth, height: mHeight, numChannels: 4);
      final resizedOrig = img.copyResize(originalImage, width: mWidth, height: mHeight);

      for (int y = 0; y < mHeight; y++) {
        for (int x = 0; x < mWidth; x++) {
          final confidence = confidences![y * mWidth + x];
          if (confidence > 0.5) {
            extracted.setPixel(x, y, resizedOrig.getPixel(x, y));
          } else {
            extracted.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }

      // Now Resize the extracted subject to max 512px before adding border
      final double scale = 512 / (mWidth > mHeight ? mWidth : mHeight);
      img.Image processed;
      if (scale < 1.0) {
        processed = img.copyResize(extracted, 
          width: mWidth >= mHeight ? 512 : null,
          height: mHeight > mWidth ? 512 : null,
        );
      } else {
        processed = extracted;
      }

      // Add refined border
      final finalized = _addStickerBorder(processed);

      // Save as optimized PNG (for transparency)
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/magia_${DateTime.now().millisecondsSinceEpoch}.png';
      final pngBytes = img.encodePng(finalized);
      _processedFile = await File(outputPath).writeAsBytes(pngBytes);

    } catch (e) {
      debugPrint('Error processing sticker: $e');
      _processedFile = File(widget.imageFile.path);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  img.Image _addStickerBorder(img.Image source) {
    // Thinner, smoother border implementation
    final borderSize = 4; // Reduced from 10 to 4
    final out = img.Image.from(source);
    
    // We create a temporary alpha mask for dilation
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final p = source.getPixel(x, y);
        if (p.a > 0) continue; 

        bool nearForeground = false;
        for (int dy = -borderSize; dy <= borderSize; dy++) {
          for (int dx = -borderSize; dx <= borderSize; dx++) {
            if (dx * dx + dy * dy <= borderSize * borderSize) {
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < source.width && ny >= 0 && ny < source.height) {
                if (source.getPixel(nx, ny).a > 0) {
                  nearForeground = true;
                  break;
                }
              }
            }
          }
          if (nearForeground) break;
        }

        if (nearForeground) {
          out.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
        }
      }
    }
    
    img.compositeImage(out, source);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Creador de Sticker', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isProcessing 
                ? const CircularProgressIndicator()
                : _processedFile != null
                  ? Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Image.file(_processedFile!),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Vista Previa',
                            style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1),
                          ),
                        ],
                      ),
                    )
                  : const Text('Error al cargar imagen', style: TextStyle(color: Colors.white70)),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      icon: Icons.auto_awesome,
                      label: 'Magia',
                      active: _isMagicMode,
                      disabled: _isGif,
                      onTap: () {
                        if (!_isMagicMode && !_isGif) {
                          setState(() => _isMagicMode = true);
                          _processImage();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildModeButton(
                      icon: Icons.fullscreen,
                      label: 'Completo',
                      active: !_isMagicMode,
                      onTap: () {
                        if (_isMagicMode) {
                          setState(() => _isMagicMode = false);
                          _processImage();
                        }
                      },
                    ),
                  ],
                ),
                if (_isGif)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Magia no disponible para GIFs o WebP animados',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                if (!_isProcessing)
                  BoxShadow(
                    color: Wumbleheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: ElevatedButton(
              onPressed: (_isProcessing || _processedFile == null) 
                ? null 
                : () => Navigator.pop(context, _processedFile),
              style: ElevatedButton.styleFrom(
                backgroundColor: Wumbleheme.secondaryColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: const Text('LISTO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active 
            ? Wumbleheme.secondaryColor 
            : (disabled ? Colors.white.withOpacity(0.05) : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          boxShadow: (active && !disabled) ? [
            BoxShadow(
              color: Wumbleheme.secondaryColor.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: active 
                ? Colors.black 
                : (disabled ? Colors.white10 : Colors.white38), 
              size: 20
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active 
                  ? Colors.black 
                  : (disabled ? Colors.white10 : Colors.white38),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
