import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/media_helper.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart';
import '../../community/domain/wiki_model.dart';
import '../../community/domain/wiki_repository.dart';
import '../../chat/domain/moderation_service.dart';
import '../../chat/domain/bot_framework.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/rich_text_controller.dart';

class WikiEditorScreen extends StatefulWidget {
  final String? communityId;
  final WikiPage? wikiToEdit;

  const WikiEditorScreen({super.key, this.communityId, this.wikiToEdit});

  @override
  State<WikiEditorScreen> createState() => _WikiEditorScreenState();
}

class _WikiEditorScreenState extends State<WikiEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _wikiIconPath;
  String? _wikiBackgroundPath;
  bool _isSaving = false;
  
  // Blocks for "Sobre" section
  final List<Map<String, dynamic>> _blocks = [];
  int? _focusedBlockIndex;
  int? _savedCursor;

  final List<Map<String, String>> _infoFields = [
    {'label': 'Lo que me gusta', 'value': ''},
    {'label': 'Lo que no me gusta', 'value': ''},
    {'label': 'Calificación', 'value': '⭐⭐⭐⭐⭐'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.wikiToEdit != null) {
      _nameController.text = widget.wikiToEdit!.title;
      
      // Load labels
      for (var field in _infoFields) {
        if (widget.wikiToEdit!.labels.containsKey(field['label'])) {
          field['value'] = widget.wikiToEdit!.labels[field['label']]!;
        }
      }

      // Load blocks
      if (widget.wikiToEdit!.blocks.isNotEmpty) {
        for (var block in widget.wikiToEdit!.blocks) {
          if (block['type'] == 'text') {
            _addTextBlock(initialText: block['value'], autoFocus: false);
          } else if (block['type'] == 'image') {
            _blocks.add({'type': 'image', 'value': block['value']});
          }
        }
      } else {
        _addTextBlock();
      }
    } else {
      _addTextBlock();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var block in _blocks) {
      if (block['type'] == 'text') {
        (block['controller'] as TextEditingController).dispose();
        (block['focusNode'] as FocusNode).dispose();
      }
    }
    super.dispose();
  }

  void _addTextBlock({String? initialText, bool autoFocus = true}) {
    final controller = RichTextEditingController();
    if (initialText != null) controller.text = initialText;
    final focusNode = FocusNode();

    controller.addListener(() {
      final selection = controller.selection;
      if (selection.baseOffset >= 0) {
        final textBefore = controller.text.substring(0, selection.baseOffset);
        final lineIndex = textBefore.split('\n').length - 1;
        if (controller.cursorLine != lineIndex) {
          setState(() {
            controller.updateCursorLine(lineIndex);
          });
        }
      }
    });

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        setState(() {
          _focusedBlockIndex = _blocks.indexWhere((b) => b['focusNode'] == focusNode);
        });
      }
    });

    setState(() {
      _blocks.add({
        'type': 'text',
        'controller': controller,
        'focusNode': focusNode,
      });
    });

    if (autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.requestFocus();
      });
    }
  }

  Future<void> _addImageBlock() async {
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() {
        _blocks.add({
          'type': 'image',
          'file': File(image.path),
        });
        _addTextBlock(); // Add text block after image
      });
    }
  }

  void _removeBlock(int index) {
    if (_blocks[index]['type'] == 'text') {
      (_blocks[index]['controller'] as TextEditingController).dispose();
      (_blocks[index]['focusNode'] as FocusNode).dispose();
    }
    setState(() {
      _blocks.removeAt(index);
      if (_focusedBlockIndex == index) _focusedBlockIndex = null;
    });
  }

  void _saveCursor() {
    if (_focusedBlockIndex == null) return;
    final block = _blocks[_focusedBlockIndex!];
    if (block['type'] != 'text') return;
    final ctrl = block['controller'] as RichTextEditingController;
    final offset = ctrl.selection.baseOffset;
    if (offset >= 0) _savedCursor = offset;
  }

  void _insertTag(String tag) {
    if (_focusedBlockIndex == null || _focusedBlockIndex! >= _blocks.length) return;
    final block = _blocks[_focusedBlockIndex!];
    if (block['type'] != 'text') return;

    final controller = block['controller'] as RichTextEditingController;
    final text = controller.text;
    int cursor = controller.selection.baseOffset;
    if (cursor < 0) cursor = _savedCursor ?? text.length;
    _savedCursor = null;

    int lineStart = cursor > 0 ? text.lastIndexOf('\n', cursor - 1) + 1 : 0;
    int lineEnd = text.indexOf('\n', cursor);
    if (lineEnd == -1) lineEnd = text.length;

    final String currentLine = text.substring(lineStart, lineEnd);
    final tagMatch = RegExp(r'^\[([^\]]+)\]').firstMatch(currentLine);
    final String lineText = tagMatch != null
        ? currentLine.substring(tagMatch.group(0)!.length)
        : currentLine;
    final String rawTags = tagMatch?.group(1) ?? '';
    final Set<String> tagChars = rawTags.split('').where((s) => s.isNotEmpty).toSet();

    if ('CRJ'.contains(tag)) {
      if (tagChars.contains(tag)) {
        tagChars.remove(tag);
      } else {
        tagChars.removeAll({'C', 'R', 'J'});
        tagChars.add(tag);
      }
    } else {
      if (tagChars.contains(tag)) {
        tagChars.remove(tag);
      } else {
        tagChars.add(tag);
      }
    }

    const String order = 'BICUSLMRJ';
    String finalTags = '';
    for (final c in order.split('')) {
      if (tagChars.contains(c)) finalTags += c;
    }

    final String newLine = finalTags.isEmpty ? lineText : '[$finalTags]$lineText';
    setState(() {
      controller.text = text.replaceRange(lineStart, lineEnd, newLine);
      int newCursor = lineStart + newLine.length;
      controller.selection = TextSelection.collapsed(offset: newCursor);
    });
  }

  Future<void> _pickWikiMedia(bool isIcon) async {
    final image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() {
        if (isIcon) {
          _wikiIconPath = image.path;
        } else {
          _wikiBackgroundPath = image.path;
        }
      });
    }
  }

  Future<void> _saveWiki() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }

    if (widget.communityId == null) {
      // In a real app we might pick a community, here we assume it enters from a community
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: No hay comunidad seleccionada')));
      return;
    }

    setState(() => _isSaving = true);
    final communityId = widget.communityId ?? widget.wikiToEdit?.communityId;

    try {
      // 1. Load Guardian level
      ModerationLevel level = ModerationLevel.medium;
      try {
        if (communityId != null) {
          final botsSnapshot = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('bots')
              .where('isActive', isEqualTo: true)
              .where('isGuardian', isEqualTo: true)
              .limit(1)
              .get();
          
          if (botsSnapshot.docs.isNotEmpty) {
            final bot = BotConfig.fromFirestore(botsSnapshot.docs.first);
            if (bot.feedModerationSensitivity < 0.3) {
              level = ModerationLevel.low;
            } else if (bot.feedModerationSensitivity < 0.7) {
              level = ModerationLevel.medium;
            } else {
              level = ModerationLevel.high;
            }
          }
        }
      } catch (_) {}

      // 2. Check Title
      if (_nameController.text.isNotEmpty) {
        final res = await ModerationService.analyzeText(_nameController.text, level: level);
        if (res.isFlagged && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Título bloqueado: ${res.reason}'), backgroundColor: Colors.red));
           setState(() => _isSaving = false);
           return;
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final wikiId = widget.wikiToEdit?.id ?? const Uuid().v4();
      final labels = {
        for (var field in _infoFields) field['label']!: field['value']!
      };

      final List<Map<String, dynamic>> parsedBlocks = [];
      String plainContentFallback = '';

      for (var block in _blocks) {
        if (block['type'] == 'text') {
          final text = (block['controller'] as TextEditingController).text.trim();
          if (text.isNotEmpty) {
            final res = await ModerationService.analyzeText(text, level: level);
            if (res.isFlagged && mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contenido bloqueado: ${res.reason}'), backgroundColor: Colors.red));
               setState(() => _isSaving = false);
               return;
            }
            parsedBlocks.add({'type': 'text', 'value': text});
            plainContentFallback += '$text\n\n';
          }
        } else if (block['type'] == 'image') {
          if (block['file'] != null) {
            parsedBlocks.add({'type': 'image', 'file': block['file']});
          } else if (block['value'] != null) {
            parsedBlocks.add({'type': 'image', 'value': block['value']});
          }
        }
      }

      // 2.8: Fetch community member profile if inside a community for accurate metadata
      String authorName = user.displayName ?? 'Usuario';
      String authorAvatarUrl = user.photoURL ?? '';
      String? authorAvatarFrameUrl;

      try {
        final profileRef = communityId != null
            ? FirebaseFirestore.instance.collection('communities').doc(communityId).collection('members').doc(user.uid)
            : FirebaseFirestore.instance.collection('users').doc(user.uid);
        final profileDoc = await profileRef.get();
            
        if (profileDoc.exists) {
          final data = profileDoc.data() as Map<String, dynamic>;
          authorName = data['displayName'] ?? data['username'] ?? authorName;
          authorAvatarUrl = data['avatarUrl'] ?? authorAvatarUrl;
          authorAvatarFrameUrl = data['avatarFrameUrl'];
        }
      } catch (_) {}

      final newWiki = WikiPage(
        id: wikiId,
        communityId: communityId ?? widget.wikiToEdit!.communityId,
        authorId: widget.wikiToEdit?.authorId ?? user.uid,
        authorName: widget.wikiToEdit?.authorName ?? authorName,
        authorAvatarUrl: widget.wikiToEdit?.authorAvatarUrl ?? authorAvatarUrl,
        authorAvatarFrameUrl: widget.wikiToEdit?.authorAvatarFrameUrl ?? authorAvatarFrameUrl,
        title: _nameController.text.trim(),
        content: plainContentFallback.trim(),
        blocks: parsedBlocks,
        iconUrl: _wikiIconPath ?? widget.wikiToEdit?.iconUrl,
        coverUrl: _wikiBackgroundPath ?? widget.wikiToEdit?.coverUrl,
        labels: labels,
        createdAt: widget.wikiToEdit?.createdAt ?? DateTime.now(),
        likesCount: widget.wikiToEdit?.likesCount ?? 0,
        commentsCount: widget.wikiToEdit?.commentsCount ?? 0,
        isApproved: widget.wikiToEdit?.isApproved ?? false,
      );

      File? iconFile = _wikiIconPath != null ? File(_wikiIconPath!) : null;
      File? coverFile = _wikiBackgroundPath != null ? File(_wikiBackgroundPath!) : null;

      if (widget.wikiToEdit != null) {
        await sl<WikiRepository>().updateWiki(
          newWiki, 
          iconFile: iconFile, 
          coverFile: coverFile
        );
      } else {
        await sl<WikiRepository>().createWiki(
          newWiki, 
          iconFile: iconFile, 
          coverFile: coverFile
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to trigger refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Wiki guardada con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.wikiToEdit != null ? 'Editar Wiki' : 'Nueva Wiki'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            onPressed: _showPreview,
            tooltip: 'Vista Previa',
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveWiki,
            child: _isSaving 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text(
                  'Guardar',
                  style: TextStyle(
                    color: Wumbleheme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section: Icon and Background
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                GestureDetector(
                  onTap: () => _pickWikiMedia(false),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Wumbleheme.surfaceColor,
                      image: _wikiBackgroundPath != null
                          ? DecorationImage(
                              image: FileImage(File(_wikiBackgroundPath!)),
                              fit: BoxFit.cover,
                            )
                          : (widget.wikiToEdit?.coverUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(widget.wikiToEdit!.coverUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    ),
                    child: _wikiBackgroundPath == null
                        ? const Center(
                            child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.white24),
                          )
                        : null,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, 40),
                  child: GestureDetector(
                    onTap: () => _pickWikiMedia(true),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Wumbleheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.yellow.shade700, width: 2),
                        image: _wikiIconPath != null
                            ? DecorationImage(
                                image: FileImage(File(_wikiIconPath!)),
                                fit: BoxFit.cover,
                              )
                            : (widget.wikiToEdit?.iconUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(widget.wikiToEdit!.iconUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                      ),
                      child: _wikiIconPath == null
                          ? const Icon(Icons.add_a_photo_outlined, color: Colors.white24)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            
            // Name Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Nombre de la Wiki',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
            ),
            const Divider(color: Colors.white10),
            
            // Info Fields (Wumble Style)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: _infoFields.asMap().entries.map((entry) {
                  int idx = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Wumbleheme.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Text(entry.value['label']!, style: const TextStyle(color: Wumbleheme.textSecondary)),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: entry.value['value'], // Use initialValue instead of controller for simplicity here
                            onChanged: (val) => _infoFields[idx]['value'] = val,
                            decoration: InputDecoration(
                              hintText: 'Añadir...',
                              hintStyle: const TextStyle(color: Colors.white10),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.yellow.withOpacity(0.3))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const Divider(color: Colors.white10),
            
            // About Section (Rich Content)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sobre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  
                  // Blocks List
                  ..._blocks.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var block = entry.value;

                    if (block['type'] == 'text') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: block['controller'],
                                focusNode: block['focusNode'],
                                maxLines: null,
                                style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
                                decoration: InputDecoration(
                                  hintText: idx == 0 ? 'Escribe información detallada aquí...' : '',
                                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_blocks.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.white24),
                                onPressed: () => _removeBlock(idx),
                              ),
                          ],
                        ),
                      );
                    } else if (block['type'] == 'image') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: block['file'] != null 
                                ? Image.file(block['file'], fit: BoxFit.cover)
                                : CachedNetworkImage(imageUrl: block['value'], fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _removeBlock(idx),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 20, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox();
                  }),

                  const SizedBox(height: 20),
                  // Formatting Toolbar
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Wumbleheme.surfaceColor,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _toolButton(Icons.format_bold, () => _insertTag('B')),
                        _toolButton(Icons.format_italic, () => _insertTag('I')),
                        _toolButton(Icons.format_align_center, () => _insertTag('C')),
                        _toolButton(Icons.format_underlined, () => _insertTag('U')),
                        const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white10),
                        _toolButton(Icons.text_fields, () => _addTextBlock()),
                        _toolButton(Icons.add_photo_alternate, _addImageBlock),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.97,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: Wumbleheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Vista Previa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(color: Colors.white10),
              
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.all(0),
                  children: [
                    // Header (Cover + Icon + Title)
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Wumbleheme.surfaceColor,
                            image: _wikiBackgroundPath != null
                                ? DecorationImage(image: FileImage(File(_wikiBackgroundPath!)), fit: BoxFit.cover)
                                : (widget.wikiToEdit?.coverUrl != null
                                    ? DecorationImage(image: CachedNetworkImageProvider(widget.wikiToEdit!.coverUrl!), fit: BoxFit.cover)
                                    : null),
                          ),
                        ),
                        Positioned(
                          bottom: -40,
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              color: Wumbleheme.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.yellow.shade700, width: 2),
                              image: _wikiIconPath != null
                                  ? DecorationImage(image: FileImage(File(_wikiIconPath!)), fit: BoxFit.cover)
                                  : (widget.wikiToEdit?.iconUrl != null
                                      ? DecorationImage(image: CachedNetworkImageProvider(widget.wikiToEdit!.iconUrl!), fit: BoxFit.cover)
                                      : null),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Text(
                      _nameController.text.isEmpty ? 'Nombre de la Wiki' : _nameController.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Divider(color: Colors.white10, height: 40),
                    
                    // Labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: _infoFields.map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(field['label']!, style: const TextStyle(color: Wumbleheme.textSecondary)),
                              const Spacer(),
                              Text(field['value']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 40),
                    
                    // Blocks
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sobre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 12),
                          ..._blocks.map((block) {
                            if (block['type'] == 'text') {
                              final text = (block['controller'] as TextEditingController).text;
                              return _buildPreviewRichText(text);
                            } else if (block['type'] == 'image') {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: block['file'] != null 
                                    ? Image.file(block['file'] as File)
                                    : CachedNetworkImage(imageUrl: block['value'] as String),
                                ),
                              );
                            }
                            return const SizedBox();
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRichText(String raw) {
    if (raw.isEmpty) return const SizedBox();
    
    final tagRe   = RegExp(r'^\[([^\]]+)\]');
    final lineWidgets = raw.split('\n').map<Widget>((line) {
      final m = tagRe.firstMatch(line);
      final tags = m?.group(1) ?? '';
      final content = m != null ? line.substring(m.group(0)!.length) : line;

      TextAlign align = TextAlign.start;
      if (tags.contains('C')) align = TextAlign.center;
      else if (tags.contains('R')) align = TextAlign.right;
      else if (tags.contains('J')) align = TextAlign.justify;

      final decs = <TextDecoration>[];
      if (tags.contains('U')) decs.add(TextDecoration.underline);
      if (tags.contains('S')) decs.add(TextDecoration.lineThrough);

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            content,
            textAlign: align,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: tags.contains('B') ? FontWeight.bold : FontWeight.normal,
              fontStyle: tags.contains('I') ? FontStyle.italic : FontStyle.normal,
              decoration: decs.isNotEmpty ? TextDecoration.combine(decs) : null,
              color: Colors.white,
            ),
          ),
        ),
      );
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lineWidgets);
  }

  Widget _toolButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 22),
      onPressed: onTap,
    );
  }
}
