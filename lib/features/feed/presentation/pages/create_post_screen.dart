import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/features/feed/domain/post_model.dart';
import 'package:wumble/features/feed/domain/draft_model.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:wumble/features/feed/presentation/bloc/create_post_cubit.dart';
import 'package:wumble/features/feed/presentation/widgets/rich_text_controller.dart';
import 'package:wumble/features/feed/domain/feed_repository.dart';
import 'package:wumble/features/feed/domain/category_model.dart';
import 'package:wumble/features/chat/domain/moderation_service.dart';
import 'package:wumble/features/chat/domain/bot_framework.dart';
import 'package:wumble/features/community/domain/moderation_report_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/core/utils/media_helper.dart';

class CreatePostScreen extends StatefulWidget {
  final String communityId;
  final Post? existingPost;
  final PostDraft? draft;

  CreatePostScreen({super.key, required this.communityId, this.existingPost, this.draft});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  // Customization variables
  File? _backgroundImage;
  String? _backgroundImageUrl; // Added
  String? _backgroundColor;
  bool _showTagsManual = false;
  List<PostCategory> _availableCategories = [];
  String? _selectedCategoryId;
  List<String> _tags = []; // NEW
  final TextEditingController _tagsController = TextEditingController(); // NEW

  // Saved cursor position — captured before dialogs steal focus
  int? _savedCursor;
  
  late final CreatePostCubit _cubit;
  final List<Map<String, dynamic>> _blocks = [];
  int? _focusedBlockIndex;
  bool isLoading = false; 
  bool _isDirty = false;
  late String _draftId;

  @override
  void initState() {
    super.initState();
    _cubit = di.sl<CreatePostCubit>();
    _loadCategories();

    // Usar ID existente del borrador o generar uno nuevo para estra sesión
    _draftId = widget.draft?.id ?? FirebaseFirestore.instance.collection('dummy').doc().id;

    if (widget.existingPost != null) {
      _titleController.text = widget.existingPost!.title ?? '';
      _backgroundColor = widget.existingPost!.backgroundColor;
      _backgroundImageUrl = widget.existingPost!.backgroundImageUrl; // Added
      
      if (widget.existingPost!.blocks.isNotEmpty) {
        for (var block in widget.existingPost!.blocks) {
          _addBlockFromMap(block);
        }
      } else {
        // Fallback for legacy posts
        _addTextBlock(initialText: widget.existingPost!.content);
        if (widget.existingPost!.images.isNotEmpty) {
          for (var url in widget.existingPost!.images) {
             _blocks.add({
              'type': 'image',
              'url': url,
            });
          }
        }
      }
    } else if (widget.draft != null) {
      _titleController.text = widget.draft!.title ?? '';
      _backgroundColor = widget.draft!.backgroundColor;
      _backgroundImageUrl = widget.draft!.backgroundImageUrl; // Added
      for (var block in widget.draft!.blocks) {
        _addBlockFromMap(block);
      }
    } else {
      _addTextBlock();
    }

    _titleController.addListener(_markAsDirty);
    
    // Ensure we start clean after initialization
    _isDirty = false;
  }

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _loadCategories() async {
    try {
      final repo = di.sl<FeedRepository>();
      final cats = await repo.getCategories(widget.communityId);
      if (mounted) {
        setState(() {
          _availableCategories = cats;
          if (widget.existingPost?.categoryId != null) {
            _selectedCategoryId = widget.existingPost!.categoryId;
          }
        });
      }
    } catch (e) {
      print('Error matching categories: $e');
    }
  }

  void _addBlockFromMap(Map<String, dynamic> block) {
    if (block['type'] == 'text') {
      final focusNode = FocusNode();
      final controller = RichTextEditingController();
      controller.text = block['value'] ?? '';
      
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
        _markAsDirty();
      });

      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          setState(() {
            _focusedBlockIndex = _blocks.indexWhere((b) => b['focusNode'] == focusNode);
          });
        }
      });
      
      _blocks.add({
        'type': 'text',
        'controller': controller,
        'focusNode': focusNode,
      });
    } else if (block['type'] == 'image') {
      _blocks.add({
        'type': 'image',
        'url': block['value'],
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_markAsDirty);
    _titleController.dispose();
    for (var block in _blocks) {
      if (block['type'] == 'text') {
         (block['controller'] as TextEditingController).removeListener(_markAsDirty);
         (block['controller'] as TextEditingController).dispose();
         (block['focusNode'] as FocusNode).dispose();
      }
    }
    super.dispose();
    _cubit.close();
  }

  Map<String, dynamic> _createTextBlockData({String? initialText}) {
    final controller = RichTextEditingController();
    if (initialText != null) controller.text = initialText;
    final focusNode = FocusNode();
    
    // Listen to cursor movement to update invisible tags
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
      _markAsDirty();
    });

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        setState(() {
          _focusedBlockIndex = _blocks.indexWhere((b) => b['focusNode'] == focusNode);
        });
      }
    });

    return {
      'type': 'text',
      'controller': controller,
      'focusNode': focusNode,
    };
  }

  void _addTextBlock({String? initialText}) {
    setState(() {
      _blocks.add(_createTextBlockData(initialText: initialText));
      _markAsDirty();
    });
  }

  void _insertTag(String tag, {String? value}) {
    if (_focusedBlockIndex == null || _focusedBlockIndex! >= _blocks.length) return;
    final block = _blocks[_focusedBlockIndex!];
    if (block['type'] != 'text') return;

    final controller = block['controller'] as RichTextEditingController;
    final text = controller.text;
    // Use live cursor, OR fall back to the position saved before a dialog opened
    int cursor = controller.selection.baseOffset;
    if (cursor < 0) cursor = _savedCursor ?? text.length;
    _savedCursor = null; // reset after use
    if (cursor > text.length) cursor = text.length;

    // Find bounds of the line the cursor is on
    int lineStart = cursor > 0 ? text.lastIndexOf('\n', cursor - 1) + 1 : 0;
    if (lineStart < 0) lineStart = 0;
    int lineEnd = text.indexOf('\n', cursor);
    if (lineEnd == -1) lineEnd = text.length;

    final String currentLine = text.substring(lineStart, lineEnd);

    // Parse the existing tag block at the start of the line, e.g. [BIC]
    final tagMatch = RegExp(r'^\[([^\]]+)\]').firstMatch(currentLine);
    final String lineText = tagMatch != null
        ? currentLine.substring(tagMatch.group(0)!.length)
        : currentLine;
    final String rawTags = tagMatch?.group(1) ?? '';

    // Separate param tags (T=, #=, K=, G=) from simple letter tags
    final Map<String, String> paramTags = {};
    final paramRegex = RegExp(r'([T#KG])=([^#TKGJMR ]+)');
    for (final m in paramRegex.allMatches(rawTags)) {
      paramTags[m.group(1)!] = m.group(2)!;
    }
    final Set<String> tagChars = rawTags
        .replaceAll(paramRegex, '')
        .split('')
        .where((s) => s.isNotEmpty)
        .toSet();

    // Apply the toggle
    if (value != null) {
      // Parameterized tag (T=, #=, K=, G=)
      if (paramTags[tag] == value) {
        paramTags.remove(tag);
      } else {
        paramTags[tag] = value;
      }
    } else if ('CRJ'.contains(tag)) {
      // Alignment — mutually exclusive
      if (tagChars.contains(tag)) {
        tagChars.remove(tag);
      } else {
        tagChars.removeAll({'C', 'R', 'J'});
        tagChars.add(tag);
      }
    } else {
      // Simple toggle tags (B, I, U, S, M, ...)
      if (tagChars.contains(tag)) {
        tagChars.remove(tag);
      } else {
        tagChars.add(tag);
      }
    }

    // Rebuild the tag string in a canonical order
    String order = 'BICUSLMRJ';
    String finalTags = '';
    for (final c in order.split('')) {
      if (tagChars.contains(c)) finalTags += c;
    }
    paramTags.forEach((k, v) => finalTags += '$k=$v');

    // Reconstruct the line
    final String newLine = finalTags.isEmpty ? lineText : '[$finalTags]$lineText';

    // Write back the updated text
    setState(() {
      final String newText = text.replaceRange(lineStart, lineEnd, newLine);
      controller.text = newText;
      // Put cursor at end of the clean text part (after the tag prefix)
      int newCursor = lineStart + newLine.length;
      if (newCursor > controller.text.length) newCursor = controller.text.length;
      controller.selection = TextSelection.collapsed(offset: newCursor);
      _markAsDirty();
    });
  }


  /// Save cursor position BEFORE opening a dialog (which steals focus).
  void _saveCursor() {
    if (_focusedBlockIndex == null) return;
    final block = _blocks[_focusedBlockIndex!];
    if (block['type'] != 'text') return;
    final ctrl = block['controller'] as RichTextEditingController;
    final offset = ctrl.selection.baseOffset;
    if (offset >= 0) _savedCursor = offset;
  }

  void _showHighlightPicker() {
    _saveCursor();
    final colors = {
      'Amarillo': 'FFFF00',
      'Verde': '00FF00',
      'Cian': '00FFFF',
      'Magenta': 'FF00FF',
      'Gris': 'CCCCCC',
    };
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Color(0xFF1E1E2C),
        child: ListView(
          shrinkWrap: true,
          children: colors.entries.map((e) => ListTile(
            leading: Container(width: 24, height: 24, color: Color(int.parse('FF${e.value}', radix: 16))),
            title: Text(e.key, style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _insertTag('G', value: e.value);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showAlignmentDialog() {
    _saveCursor();
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Color(0xFF1E1E2C),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.format_align_left, color: Colors.white),
              title: Text(tr('Izquierda'), style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _insertTag('L'); },
            ),
            ListTile(
              leading: Icon(Icons.format_align_center, color: Colors.white),
              title: Text(tr('Centro'), style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _insertTag('C'); },
            ),
            ListTile(
              leading: Icon(Icons.format_align_right, color: Colors.white),
              title: Text(tr('Derecha'), style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _insertTag('R'); },
            ),
            ListTile(
              leading: Icon(Icons.format_align_justify, color: Colors.white),
              title: Text(tr('Justificado'), style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _insertTag('J'); },
            ),
          ],
        ),
      ),
    );
  }

  void _showSizeDialog() {
    _saveCursor();
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        color: Color(0xFF1E1E2C),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(tr('Tamaño de Letra'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sizeOption('Normal', '16'),
                _sizeOption('Grande', '22'),
                _sizeOption('Enorme', '30'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _sizeOption(String label, String value) {
    return TextButton(
      onPressed: () {
        Navigator.pop(context);
        _insertTag('T', value: value);
      },
      child: Text(label, style: TextStyle(color: Colors.blueAccent)),
    );
  }

  void _showColorPicker() {
    _saveCursor();
    final colors = {
      'Blanco': 'FFFFFF',
      'Rojo': 'FF5555',
      'Verde': '55FF55',
      'Azul': '5555FF',
      'Amarillo': 'FFFF55',
      'Naranja': 'FF9955',
      'Rosa': 'FF55AA',
      'Morado': 'AA55FF',
    };
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Color(0xFF1E1E2C),
        child: ListView(
          shrinkWrap: true,
          children: colors.entries.map((e) => ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(int.parse('FF${e.value}', radix: 16)),
              radius: 12,
            ),
            title: Text(e.key, style: TextStyle(color: Color(int.parse('FF${e.value}', radix: 16)), fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _insertTag('#', value: e.value);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showFontDialog() {
    _saveCursor();
    final fonts = ['default', 'serif', 'monospace'];
    final labels = ['Normal', 'Serif', 'Monoespaciado'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Color(0xFF1E1E2C),
        child: ListView(
          shrinkWrap: true,
          children: List.generate(fonts.length, (i) => ListTile(
            title: Text(labels[i], style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _insertTag('K', value: fonts[i]);
            },
          )),
        ),
      ),
    );
  }

  void _showPreview() {
    final bgColor = _getParsedBackgroundColor();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.97,
        builder: (_, sc) => ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor ?? Color(0xFF1A1A2E),
              image: _backgroundImage != null || _backgroundImageUrl != null
                  ? DecorationImage(
                      image: (_backgroundImage != null
                          ? FileImage(_backgroundImage!)
                          : CachedNetworkImageProvider(_backgroundImageUrl!)) as ImageProvider,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.45),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        tr('Vista Previa'),
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView(
                    controller: sc,
                    padding: EdgeInsets.all(20),
                    children: [
                      if (_titleController.text.trim().isNotEmpty) ...[
                        Text(
                          _titleController.text.trim(),
                          style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3,
                          ),
                        ),
                        SizedBox(height: 16),
                        Divider(color: Colors.white24),
                        SizedBox(height: 16),
                      ],
                      ..._blocks.map((block) {
                        if (block['type'] == 'text') {
                          final txt = (block['controller'] as TextEditingController).text;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: _buildPreviewRichText(txt),
                          );
                        } else if (block['type'] == 'image') {
                          final Widget img = block['file'] != null
                              ? Image.file(block['file'], fit: BoxFit.cover)
                              : Image.network(block['url'] ?? '', fit: BoxFit.cover);
                          return Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12), child: img,
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRichText(String raw) {
    final tagRe   = RegExp(r'^\[([^\]]+)\]');
    final sizeRe  = RegExp(r'T=(\d+(?:\.\d+)?)');
    final colorRe = RegExp(r'#=([A-Fa-f0-9]{6})');
    final bgRe    = RegExp(r'G=([A-Fa-f0-9]{6})');
    final fontRe  = RegExp(r'K=([a-zA-Z0-9_-]+)');

    final lineWidgets = raw.split('\n').map<Widget>((line) {
      final m = tagRe.firstMatch(line);
      if (m == null) {
        return Text(line, style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5));
      }
      final tags    = m.group(1)!;
      final content = line.substring(m.group(0)!.length);

      TextAlign align = TextAlign.start;
      if (tags.contains('C')) align = TextAlign.center;
      else if (tags.contains('R')) align = TextAlign.right;
      else if (tags.contains('J')) align = TextAlign.justify;

      double fontSize = tags.contains('M') ? 26 : 16;
      final sm = sizeRe.firstMatch(tags);
      if (sm != null) fontSize = double.tryParse(sm.group(1)!) ?? fontSize;

      Color color = Colors.white;
      final cm = colorRe.firstMatch(tags);
      if (cm != null) color = Color(int.parse('FF${cm.group(1)!.toUpperCase()}', radix: 16));

      Color? bg;
      final bm = bgRe.firstMatch(tags);
      if (bm != null) bg = Color(int.parse('FF${bm.group(1)!.toUpperCase()}', radix: 16));

      String? family;
      final fm = fontRe.firstMatch(tags);
      if (fm != null) {
        final f = fm.group(1)!.toLowerCase();
        if (f == 'serif' || f == 'monospace') family = f;
      }

      final decs = <TextDecoration>[];
      if (tags.contains('U')) decs.add(TextDecoration.underline);
      if (tags.contains('S')) decs.add(TextDecoration.lineThrough);

      return SizedBox(
        width: double.infinity,
        child: Text(
          content,
          textAlign: align,
          style: TextStyle(
            fontWeight:      tags.contains('B') ? FontWeight.bold   : FontWeight.normal,
            fontStyle:       tags.contains('I') ? FontStyle.italic  : FontStyle.normal,
            decoration:      decs.isNotEmpty ? TextDecoration.combine(decs) : null,
            fontSize:        fontSize,
            color:           color,
            backgroundColor: bg,
            fontFamily:      family,
            height:          1.5,
          ),
        ),
      );
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lineWidgets);
  }

  Future<void> _addImageBlock() async {
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      final file = File(image.path);
      
      // --- Phase 12: Image Moderation ---
      ModerationLevel level = ModerationLevel.medium;
      try {
        final botsSnapshot = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('bots')
            .where('isActive', isEqualTo: true)
            .where('isGuardian', isEqualTo: true)
            .limit(1)
            .get();
        if (botsSnapshot.docs.isNotEmpty) {
          final bot = BotConfig.fromFirestore(botsSnapshot.docs.first);
          level = bot.feedModerationSensitivity < 0.3 ? ModerationLevel.low : (bot.feedModerationSensitivity < 0.7 ? ModerationLevel.medium : ModerationLevel.high);
        }
      } catch (_) {}

      final modResult = await ModerationService.analyzeImage(file, level: level);
      if (modResult.isFlagged && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('IMAGEN BLOQUEADA: ${modResult.reason}'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      setState(() {
        _blocks.add({
          'type': 'image',
          'file': file,
        });
        _markAsDirty();
        // Auto-add a text block after an image to keep writing
        _addTextBlock();
      });
    }
  }

  Future<void> _pickBackgroundImage() async {
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() {
        _backgroundImage = File(image.path);
        _backgroundImageUrl = null; // Clear URL
        _backgroundColor = null; // Clear color
        _markAsDirty();
      });
    }
  }

  void _pickBackgroundColor() {
    final colors = ['#1E1E2C', '#2C1E1E', '#1E2C22', '#141414'];
    final currentIdx = colors.indexOf(_backgroundColor ?? '');
    setState(() {
      _backgroundColor = colors[(currentIdx + 1) % colors.length];
      _backgroundImage = null; // Clear image file
      _backgroundImageUrl = null; // Clear image URL
      _markAsDirty();
    });
  }

  void _removeBlock(int index) {
    if (_blocks[index]['type'] == 'text') {
       (_blocks[index]['controller'] as TextEditingController).removeListener(_markAsDirty);
       (_blocks[index]['controller'] as TextEditingController).dispose();
       (_blocks[index]['focusNode'] as FocusNode).dispose();
    }
    setState(() {
      _blocks.removeAt(index);
      if (_focusedBlockIndex == index) _focusedBlockIndex = null;
      _markAsDirty();
    });
  }

  void _submitPost(BuildContext context) {
    final List<Map<String, dynamic>> parsedBlocks = [];
    String legacyContentFallback = '';
    final List<File> legacyImagesFallback = [];

    for (var block in _blocks) {
      if (block['type'] == 'text') {
        final text = (block['controller'] as TextEditingController).text.trim();
        if (text.isNotEmpty) {
          parsedBlocks.add({'type': 'text', 'value': text});
          legacyContentFallback += '$text\n\n';
        }
      } else if (block['type'] == 'image') {
        if (block['file'] != null) {
          parsedBlocks.add({'type': 'image', 'file': block['file']});
          legacyImagesFallback.add(block['file']);
        } else if (block['url'] != null) {
          parsedBlocks.add({'type': 'image', 'value': block['url']});
        }
      }
    }

    if (parsedBlocks.isEmpty && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('El post no puede estar vacío'))),
      );
      return;
    }

    // --- Phase 12: Global Moderation Check ---
    _performGlobalModeration(parsedBlocks, context);
  }

  Future<void> _performGlobalModeration(List<Map<String, dynamic>> parsedBlocks, BuildContext context) async {
    setState(() => isLoading = true);
    
    try {
      // Load Guardian Sensitivity
      ModerationLevel level = ModerationLevel.medium;
      String? guardianBotId;
      try {
        final botsSnapshot = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('bots')
            .where('isActive', isEqualTo: true)
            .where('isGuardian', isEqualTo: true)
            .limit(1)
            .get();
        
        if (botsSnapshot.docs.isNotEmpty) {
          guardianBotId = botsSnapshot.docs.first.id;
          final bot = BotConfig.fromFirestore(botsSnapshot.docs.first);
          if (bot.feedModerationSensitivity < 0.3) {
            level = ModerationLevel.low;
          } else if (bot.feedModerationSensitivity < 0.7) {
            level = ModerationLevel.medium;
          } else {
            level = ModerationLevel.high;
          }
        }
      } catch (e) {
        debugPrint('CreatePost: Error loading moderation: $e');
      }

      // 1. Check Title
      if (_titleController.text.isNotEmpty) {
        final titleResult = await ModerationService.analyzeText(_titleController.text, level: level);
        if (titleResult.isFlagged && mounted) {
          _showModerationError('Título bloqueado: ${titleResult.reason}');
          return;
        } else if (titleResult.confidence > 0.4 && guardianBotId != null) {
          // Yellow Zone: Report but allow
          ModerationService.reportToModerators(
            communityId: widget.communityId,
            reporterId: guardianBotId,
            targetId: 'pending_post_title', // Temporary since post isn't created yet
            targetUserId: FirebaseAuth.instance.currentUser!.uid,
            targetType: ModerationTargetType.post,
            contentPreview: _titleController.text,
            reason: 'TÍTULO SOSPECHOSO: ${titleResult.reason}',
            confidenceScore: titleResult.confidence,
          );
        }
      }

      // 2. Check Blocks
      for (var block in parsedBlocks) {
        if (block['type'] == 'text') {
           final textResult = await ModerationService.analyzeText(block['value'], level: level);
           if (textResult.isFlagged && mounted) {
             _showModerationError('Contenido bloqueado: ${textResult.reason}');
             return;
           } else if (textResult.confidence > 0.4 && guardianBotId != null) {
             // Yellow Zone: Report but allow
             ModerationService.reportToModerators(
               communityId: widget.communityId,
               reporterId: guardianBotId,
               targetId: 'pending_post_content',
               targetUserId: FirebaseAuth.instance.currentUser!.uid,
               targetType: ModerationTargetType.post,
               contentPreview: block['value'],
               reason: 'CONTENIDO SOSPECHOSO: ${textResult.reason}',
               confidenceScore: textResult.confidence,
             );
           }
        }
        // Images are already checked when added, but let's re-verify if they are remote/new
      }

      // If all good, proceed with submission
      _finalizeSubmission(parsedBlocks);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showModerationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.security, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _finalizeSubmission(List<Map<String, dynamic>> parsedBlocks) {
    String legacyContentFallback = '';
    final List<File> legacyImagesFallback = [];

    for (var block in parsedBlocks) {
      if (block['type'] == 'text') {
        legacyContentFallback += '${block['value']}\n\n';
      } else if (block['type'] == 'image') {
        if (block['file'] != null) {
          legacyImagesFallback.add(block['file']);
        }
      }
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null;

    if (widget.existingPost != null) {
      _cubit.editPost(
        postId: widget.existingPost!.id,
        content: legacyContentFallback.trim(),
        title: title,
        backgroundColor: _backgroundColor,
        backgroundImage: _backgroundImage,
        backgroundImageUrl: _backgroundImageUrl,
        blocks: parsedBlocks,
        categoryId: _selectedCategoryId,
        tags: _tags, // NEW
      );
    } else {
      _cubit.createPost(
        communityId: widget.communityId,
        content: legacyContentFallback.trim(),
        userId: userId,
        images: legacyImagesFallback,
        title: title,
        backgroundColor: _backgroundColor,
        backgroundImage: _backgroundImage,
        backgroundImageUrl: _backgroundImageUrl,
        blocks: parsedBlocks,
        categoryId: _selectedCategoryId,
        tags: _tags, // NEW
      );
    }
  }

  Color? _getParsedBackgroundColor() {
    if (_backgroundColor == null) return null;
    try {
      final hex = _backgroundColor!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<bool> _onWillPop() async {
    // Si no hay cambios desde el último guardado o está vacío, salir directamente
    if (!_isDirty) return true;

    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasBlocks = _blocks.any((b) => b['type'] == 'image' || (b['type'] == 'text' && (b['controller'] as TextEditingController).text.trim().isNotEmpty));

    if (!hasTitle && !hasBlocks) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('¿Guardar borrador?'), style: TextStyle(color: Colors.white)),
        content: Text(tr('Puedes terminar de editar este post más tarde.'), style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(tr('DESCARTAR'), style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(tr('CANCELAR'), style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: Text(tr('GUARDAR'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveDraft();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  Future<void> _saveDraft() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final List<Map<String, dynamic>> blocksData = [];
    for (var block in _blocks) {
      if (block['type'] == 'text') {
        blocksData.add({
          'type': 'text',
          'value': (block['controller'] as TextEditingController).text,
        });
      } else if (block['type'] == 'image') {
        if (block['file'] != null) {
          blocksData.add({
            'type': 'image',
            'file': block['file'],
          });
        } else if (block['url'] != null) {
          blocksData.add({
            'type': 'image',
            'value': block['url'],
          });
        }
      }
    }

    final parsedBlocks = blocksData; // Use blocksData as parsedBlocks for draft

    final draft = PostDraft(
      id: _draftId,
      communityId: widget.communityId,
      title: _titleController.text.trim(),
      backgroundColor: _backgroundColor,
      backgroundImageUrl: widget.draft?.backgroundImageUrl,
      backgroundImageFile: _backgroundImage,
      blocks: parsedBlocks,
      categoryId: _selectedCategoryId,
      createdAt: widget.draft?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _cubit.saveDraft(userId, draft);
    setState(() => _isDirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getParsedBackgroundColor() ?? Theme.of(context).scaffoldBackgroundColor;

    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<CreatePostCubit, CreatePostState>(
        listener: (context, state) {
          if (state is CreatePostSuccess) {
            Navigator.pop(context, true); 
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('Blog publicado con éxito'))),
            );
          } else if (state is CreatePostFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.error}')),
            );
          } else if (state is DraftOperationSuccess) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Borrador guardado con éxito'))),
              );
            }
          }
        },
        builder: (context, state) {
          final isPublishing = state is CreatePostLoading;
          final isSavingDraft = state is DraftsLoading;
          final isLoading = isPublishing || isSavingDraft;

          return WillPopScope(
            onWillPop: _onWillPop,
            child: Stack(
              children: [
                Scaffold(
                backgroundColor: bgColor,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(tr('Crear Blog'), style: TextStyle(fontWeight: FontWeight.w600)),
                  actions: [
                    isSavingDraft 
                      ? Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.save_outlined, color: Colors.white70),
                          tooltip: 'Guardar borrador',
                          onPressed: isLoading ? null : () async {
                            await _saveDraft();
                          },
                        ),
                    IconButton(
                      icon: Icon(Icons.remove_red_eye_outlined, color: Colors.white70),
                      tooltip: tr('Vista previa'),
                      onPressed: _showPreview,
                    ),
                    TextButton(
                      onPressed: isLoading ? null : () => _submitPost(context),
                      child: isPublishing
                          ? SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                            )
                          : Text(
                              tr('PUBLICAR'),
                              style: TextStyle(
                                color: Colors.blueAccent, 
                                fontWeight: FontWeight.bold
                              )
                            ),
                    ),
                  ],
                ),
                body: Container(
                  decoration: _backgroundImage != null || _backgroundImageUrl != null
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: (_backgroundImage != null
                              ? FileImage(_backgroundImage!)
                              : CachedNetworkImageProvider(_backgroundImageUrl!)) as ImageProvider,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.4),
                            BlendMode.darken,
                          ),
                        ),
                      ) 
                    : null,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                           color: Colors.black.withOpacity(0.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                             IconButton(
                               icon: Icon(Icons.palette, color: Colors.white70),
                               tooltip: tr('Color de Fondo'),
                               onPressed: _pickBackgroundColor,
                             ),
                             IconButton(
                               icon: Icon(Icons.image, color: Colors.white70),
                               tooltip: tr('Fondo de Portada'),
                               onPressed: _pickBackgroundImage,
                             ),
                             if (_availableCategories.isNotEmpty)
                               IconButton(
                                 icon: Icon(
                                   _selectedCategoryId != null ? Icons.category : Icons.category_outlined,
                                   color: _selectedCategoryId != null ? Colors.blueAccent : Colors.white70,
                                 ),
                                 tooltip: tr('Seleccionar Categoría'),
                                 onPressed: _showCategoryPicker,
                               ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.all(16.0),
                          children: [
                            TextField(
                              controller: _titleController,
                              style: TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white
                              ),
                              decoration: InputDecoration(
                                hintText: tr('Título del Blog...'),
                                hintStyle: TextStyle(fontSize: 24, color: Colors.white54, fontWeight: FontWeight.bold),
                                border: InputBorder.none,
                              ),
                            ),

                            SizedBox(height: 8),
                            TextFormField(
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: tr('Añadir etiquetas (ej: #dibujo, #noticias)'),
                                hintStyle: TextStyle(color: Colors.white24),
                                prefixIcon: Icon(Icons.tag, color: Colors.white24, size: 18),
                                border: InputBorder.none,
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _tags = v.split(RegExp(r'[\s,]+'))
                                    .map((t) => t.trim().toLowerCase()) // Normalized
                                    .where((t) => t.isNotEmpty)
                                    .map((t) => t.startsWith('#') ? t : '#$t')
                                    .toSet() // Remove duplicates
                                    .toList();
                                });
                              },
                            ),

                            Divider(color: Colors.white24, height: 32),
                            
                            ..._blocks.asMap().entries.map((entry) {
                              final index = entry.key;
                              final block = entry.value;

                              if (block['type'] == 'text') {
                                final isFocused = _focusedBlockIndex == index;
                                final controller = block['controller'] as RichTextEditingController;
                                controller.toggleTags(_showTagsManual);
                                controller.isFocused = isFocused;

                                return Column(
                                  children: [
                                    if (isFocused)
                                      Container(
                                        margin: EdgeInsets.only(bottom: 4),
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              _formatButton('B', 'Negrita', () => _insertTag('B')),
                                              _formatButton('I', 'Cursiva', () => _insertTag('I')),
                                              _formatButton('C', 'Centro', () => _insertTag('C')),
                                              _formatButton('U', 'Subrayado', () => _insertTag('U')),
                                              _formatButton('S', 'Tachado', () => _insertTag('S')),
                                              _formatButtonAlign(_showAlignmentDialog),
                                              _formatButtonHighlight(_showHighlightPicker),
                                              _formatButtonTitle(() => _insertTag('M')),
                                              _formatButtonSize('T', 'Tamaño', _showSizeDialog),
                                              _formatButtonColor('A', 'Color', _showColorPicker),
                                              _formatButtonFont('F', 'Fuente', _showFontDialog),
                                              // Toggle Visibility Button
                                              IconButton(
                                                focusNode: FocusNode(canRequestFocus: false),
                                                icon: Icon(
                                                  _showTagsManual ? Icons.visibility : Icons.visibility_off,
                                                  color: Colors.white70,
                                                  size: 20,
                                                ),
                                                onPressed: () => setState(() => _showTagsManual = !_showTagsManual),
                                                tooltip: tr('Mostrar/Ocultar Etiquetas'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: controller,
                                              focusNode: block['focusNode'],
                                              maxLines: null,
                                              keyboardType: TextInputType.multiline,
                                              style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
                                              decoration: InputDecoration(
                                                hintText: tr('Toca aquí para escribir...'),
                                                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                                                border: InputBorder.none,
                                              ),
                                            ),
                                          ),
                                          if (_blocks.length > 1)
                                            IconButton(
                                              icon: const Icon(Icons.close, size: 20, color: Colors.white38),
                                              onPressed: () => _removeBlock(index),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              } else if (block['type'] == 'image') {
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16.0),
                                      width: double.infinity,
                                      constraints: const BoxConstraints(maxHeight: 400),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: block['file'] != null
                                              ? FileImage(block['file']) as ImageProvider
                                              : CachedNetworkImageProvider(block['url']),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => _removeBlock(index),
                                        child: const CircleAvatar(
                                          backgroundColor: Colors.black54,
                                          child: Icon(Icons.close, color: Colors.white),
                                        ),
                                      ),
                                    )
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                            
                            const SizedBox(height: 100), 
                          ],
                        ),
                      ),
                      


                      // Main Toolbar
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom + 8,
                          top: 8,
                          left: 16,
                          right: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton.icon(
                              onPressed: _addTextBlock,
                              icon: const Icon(Icons.text_fields, color: Colors.white),
                              label: Text(tr('Texto'), style: TextStyle(color: Colors.white)),
                            ),
                            TextButton.icon(
                              onPressed: _addImageBlock,
                              icon: const Icon(Icons.add_photo_alternate, color: Colors.blueAccent),
                              label: Text(tr('Imagen'), style: TextStyle(color: Colors.blueAccent)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
            ),
          );
        },
      ),
    );
  }

  Widget _formatButton(String label, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        focusNode: FocusNode(canRequestFocus: false),
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _formatButtonSize(String label, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        focusNode: FocusNode(canRequestFocus: false),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: const Icon(Icons.format_size, color: Colors.blueAccent, size: 24),
        ),
      ),
    );
  }

  Widget _formatButtonColor(String label, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        focusNode: FocusNode(canRequestFocus: false),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: const Icon(Icons.color_lens, color: Colors.orangeAccent, size: 24),
        ),
      ),
    );
  }

  Widget _formatButtonAlign(VoidCallback onTap) {
    return Tooltip(
      message: 'Alineación',
      child: InkWell(
        focusNode: FocusNode(canRequestFocus: false),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: const Icon(Icons.format_align_left, color: Colors.white70, size: 24),
        ),
      ),
    );
  }

  Widget _formatButtonHighlight(VoidCallback onTap) {
    return Tooltip(
      message: 'Resaltado',
      child: InkWell(
        focusNode: FocusNode(canRequestFocus: false),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: const Icon(Icons.border_color, color: Colors.yellowAccent, size: 24),
        ),
      ),
    );
  }

  Widget _formatButtonTitle(VoidCallback onTap) {
    return Tooltip(
      message: 'Título',
      child: InkWell(
        focusNode: FocusNode(canRequestFocus: false),
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 10),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Icon(Icons.title, color: Colors.purpleAccent, size: 24),
        ),
      ),
    );
  }

  Widget _formatButtonFont(String label, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        focusNode: FocusNode(canRequestFocus: false),
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 10),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Icon(Icons.font_download, color: Colors.greenAccent, size: 24),
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Seleccionar Categoría'),
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableCategories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.clear, color: Colors.white54),
                      title: Text(tr('Ninguna'), style: TextStyle(color: Colors.white)),
                      selected: _selectedCategoryId == null,
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        Navigator.pop(context);
                      },
                    );
                  }
                  final cat = _availableCategories[index - 1];
                  return ListTile(
                    leading: Text(cat.icon, style: const TextStyle(fontSize: 24)),
                    title: Text(cat.name, style: const TextStyle(color: Colors.white)),
                    selected: _selectedCategoryId == cat.id,
                    selectedTileColor: Colors.blueAccent.withOpacity(0.1),
                    onTap: () {
                      setState(() => _selectedCategoryId = cat.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
