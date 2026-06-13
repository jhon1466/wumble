import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../chat/domain/chat_model.dart';
import '../../chat/presentation/widgets/chat_bubble.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:get_it/get_it.dart';
import '../domain/profile_repository.dart';
import '../../chat/domain/bubble_pack_model.dart';
import '../../../core/utils/media_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdvancedBubbleEditorScreen extends StatefulWidget {
  final ChatBubbleStyle? initialStyle;

  const AdvancedBubbleEditorScreen({super.key, this.initialStyle});

  @override
  State<AdvancedBubbleEditorScreen> createState() => _AdvancedBubbleEditorScreenState();
}

class _AdvancedBubbleEditorScreenState extends State<AdvancedBubbleEditorScreen> with SingleTickerProviderStateMixin {
  late ChatBubbleStyle _currentStyle;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentStyle = widget.initialStyle ?? const ChatBubbleStyle(
      id: 'custom_draft',
      name: 'Mi Burbuja',
      backgroundColorValue: 0xFF2E7D32,
      textColorValue: 0xFFFFFFFF,
    );
    _tabController = TabController(length: 4, vsync: this);
  }

  int _selectedLayerIndex = -1;

  AdvancedBubbleConfig get _config => _currentStyle.advancedConfig ?? const AdvancedBubbleConfig();

  void _updateConfig(AdvancedBubbleConfig newConfig) {
    _updateStyle(_currentStyle.copyWith(advancedConfig: newConfig));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateStyle(ChatBubbleStyle newStyle) {
    setState(() {
      _currentStyle = newStyle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Workshop de Burbujas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => _showPublishDialog(),
            child: const Text('PUBLICAR', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, _currentStyle);
            },
            child: const Text('GUARDAR', style: TextStyle(color: Wumbleheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Real-time Preview Area (Interactive Canvas)
          Container(
            height: 250,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.black26,
              border: const Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Center(
              child: _buildInteractivePreview(),
            ),
          ),

          // 2. Editor Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: Wumbleheme.primaryColor,
            labelColor: Wumbleheme.primaryColor,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(icon: Icon(Icons.palette), text: 'Estilo'),
              Tab(icon: Icon(Icons.layers), text: 'Capas'),
              Tab(icon: Icon(Icons.straighten), text: 'Márgenes'),
              Tab(icon: Icon(Icons.view_quilt), text: '9-Slice'),
            ],
          ),

          // 3. Editor Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicEditor(),
                _buildLayerEditor(),
                _buildPaddingEditor(),
                _build9SliceEditor(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewMessage({required String text, required bool isMe}) {
    final fakeMessage = ChatBubbleMessage(
      id: 'preview',
      senderId: isMe ? 'me' : 'other',
      senderName: isMe ? 'Usuario' : 'Amigo',
      senderAvatarUrl: '',
      type: MessageType.text,
      text: text,
      timestamp: DateTime.now(),
      isMe: isMe,
      bubbleStyle: _currentStyle,
    );

    return ChatBubble(
      message: fakeMessage,
    );
  }

  Widget _buildInteractivePreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final customPoints = _config.customPathPoints;
        final hasCustomPoints = _currentStyle.shapeId == 'custom' && customPoints != null;

        return GestureDetector(
          onPanUpdate: (details) {
            if (_selectedLayerIndex != -1) {
              final layers = _config.layers;
              final layer = layers[_selectedLayerIndex];
              final deltaX = details.delta.dx / (constraints.maxWidth / 2);
              final deltaY = details.delta.dy / (constraints.maxHeight / 2);
              
              final updatedLayer = layer.copyWith(
                x: (layer.x + deltaX).clamp(-1.0, 1.0),
                y: (layer.y + deltaY).clamp(-1.0, 1.0),
              );
              
              final newLayers = List<BubbleLayer>.from(layers);
              newLayers[_selectedLayerIndex] = updatedLayer;
              _updateConfig(_config.copyWith(layers: newLayers));
            }
          },
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                   _buildPreviewMessage(text: 'Previsualiza y arrastra aquí', isMe: true),
                   if (_selectedLayerIndex != -1)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(_config.layers[_selectedLayerIndex].x, _config.layers[_selectedLayerIndex].y),
                      child: Container(
                        width: 100 * _config.layers[_selectedLayerIndex].scale + 4,
                        height: 100 * _config.layers[_selectedLayerIndex].scale + 4,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.amber, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                
                // Custom Points Handles
                if (hasCustomPoints)
                  ...List.generate(customPoints.length, (index) {
                    final p = customPoints[index];
                    return Positioned(
                      // Message bubble is roughly at center. We need to be careful with coordinate conversion.
                      // Relative 0-1 mapped to the bubble's area in preview.
                      // For now, let's keep it simple: the points editor in the tab is safer, 
                      // but let's at least show them in the preview for visual feedback.
                      left: p.dx * constraints.maxWidth,
                      top: p.dy * constraints.maxHeight,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          final newPoints = List<Offset>.from(customPoints);
                          final deltaX = details.delta.dx / constraints.maxWidth;
                          final deltaY = details.delta.dy / constraints.maxHeight;
                          newPoints[index] = Offset(
                            (p.dx + deltaX).clamp(0.0, 1.0),
                            (p.dy + deltaY).clamp(0.0, 1.0),
                          );
                          _updateConfig(_config.copyWith(customPathPoints: newPoints));
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    );
                  }),

                if (_selectedLayerIndex != -1)
                  const Positioned(
                    top: 0,
                    child: Text('ARRASTRA PARA MOVER CAPA', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                if (hasCustomPoints)
                  const Positioned(
                    bottom: 0,
                    child: Text('ARRASTRA PUNTOS PARA AJUSTAR GEOMETRÍA', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBasicEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('CONFIGURACIÓN BASE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildColorPickerTile('Fondo Principal', _currentStyle.backgroundColorValue, (color) {
          _updateStyle(_currentStyle.copyWith(backgroundColorValue: color.value));
        }),
        _buildColorPickerTile('Gradiente (Opcional)', _currentStyle.secondaryColorValue ?? _currentStyle.backgroundColorValue, (color) {
          _updateStyle(_currentStyle.copyWith(secondaryColorValue: color.value));
        }),
        ListTile(
          title: const Text('Eliminar Gradiente', style: TextStyle(color: Colors.redAccent)),
          leading: const Icon(Icons.format_color_reset, color: Colors.redAccent),
          onTap: () {
            _updateStyle(_currentStyle.copyWith(secondaryColorValue: null));
          },
        ),
        _buildColorPickerTile('Color de Texto', _currentStyle.textColorValue, (color) {
          _updateStyle(_currentStyle.copyWith(textColorValue: color.value));
        }),
        const Divider(color: Colors.white12),
        const Text('GEOMETRÍA', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(height: 100, child: _buildShapeSelector()),
        if (_currentStyle.shapeId == 'custom') ...[
          const SizedBox(height: 16),
          _buildCustomPathEditor(),
        ],
        const Divider(color: Colors.white12),
        const Text('FONDO PERSONALIZADO', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildBackgroundSelector(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildShapeSelector() {
    final shapes = ['default', 'sharp', 'wavy', 'polygon', 'jagged', 'custom'];
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: shapes.length,
      itemBuilder: (context, index) {
        final shape = shapes[index];
        final isSelected = (_currentStyle.shapeId == shape && shape != 'default') || 
                          (_currentStyle.shapeId == null && shape == 'default');
        return GestureDetector(
          onTap: () => _updateStyle(_currentStyle.copyWith(shapeId: shape)),
          child: Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Wumbleheme.primaryColor : Colors.white24, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(shape == 'cloud' ? Icons.cloud : Icons.auto_awesome_mosaic, color: isSelected ? Wumbleheme.primaryColor : Colors.white54),
                const SizedBox(height: 8),
                Text(shape.toUpperCase(), style: TextStyle(color: isSelected ? Wumbleheme.primaryColor : Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundSelector() {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () async {
              final XFile? image = await MediaHelper.pickImageWithOptimization(context);
              if (image != null) _updateStyle(_currentStyle.copyWith(backgroundImageUrl: image.path));
            },
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, style: BorderStyle.solid),
              ),
              child: _currentStyle.backgroundImageUrl != null && _currentStyle.backgroundImageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _currentStyle.backgroundImageUrl!.startsWith('http')
                      ? Image.network(_currentStyle.backgroundImageUrl!, fit: BoxFit.cover)
                      : (_currentStyle.backgroundImageUrl!.startsWith('assets/')
                        ? Image.asset(_currentStyle.backgroundImageUrl!, fit: BoxFit.cover)
                        : Image.file(File(_currentStyle.backgroundImageUrl!), fit: BoxFit.cover)),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 40, color: Colors.white38),
                      SizedBox(height: 8),
                      Text('Subir Imagen de Fondo / Textura', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
            ),
          ),
          if (_currentStyle.backgroundImageUrl != null && _currentStyle.backgroundImageUrl!.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => _updateStyle(_currentStyle.copyWith(backgroundImageUrl: '')),
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLayerEditor() {
    final layers = _config.layers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CAPAS (${layers.length}/10)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Colors.blueAccent),
                    tooltip: 'Añadir Contenedor',
                    onPressed: () {
                      final newLayer = BubbleLayer(
                        id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
                        type: 'box',
                        url: '',
                        x: 0,
                        y: 0,
                        scale: 1,
                        colorValue: Wumbleheme.primaryColor.value,
                        borderRadius: 12,
                      );
                      _updateConfig(_config.copyWith(layers: [...layers, newLayer]));
                      setState(() => _selectedLayerIndex = layers.length);
                    },
                  ),
                  IconButton(
                    onPressed: () async {
                      final XFile? image = await MediaHelper.pickImageWithOptimization(context);
                      if (image != null) {
                        final newLayer = BubbleLayer(
                          id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
                          type: 'image',
                          url: image.path,
                          x: 0,
                          y: 0,
                          scale: 1,
                        );
                        _updateConfig(_config.copyWith(layers: [...layers, newLayer]));
                        setState(() => _selectedLayerIndex = layers.length);
                      }
                    },
                    icon: const Icon(Icons.add_circle, color: Wumbleheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SwitchListTile(
            title: const Text('Recortar Capas (Clipping)', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Mantiene las capas dentro de la forma de la burbuja', style: TextStyle(color: Colors.white54, fontSize: 10)),
            value: _config.clipLayers,
            activeColor: Wumbleheme.primaryColor,
            onChanged: (val) => _updateConfig(_config.copyWith(clipLayers: val)),
          ),
        ),
        const Divider(color: Colors.white12),
        Expanded(
          child: layers.isEmpty
            ? const Center(child: Text('No hay capas adicionales.', style: TextStyle(color: Colors.white38)))
            : ReorderableListView.builder(
                itemCount: layers.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final newLayers = List<BubbleLayer>.from(layers);
                    final item = newLayers.removeAt(oldIndex);
                    newLayers.insert(newIndex, item);
                    _updateConfig(_config.copyWith(layers: newLayers));
                    _selectedLayerIndex = newIndex;
                  });
                },
                itemBuilder: (context, index) {
                  final layer = layers[index];
                  final isSelected = _selectedLayerIndex == index;
                  return _buildLayerTile(index, layer, isSelected, key: ValueKey(layer.id));
                },
              ),
        ),
      ],
    );
  }

  Widget _buildLayerTile(int index, BubbleLayer layer, bool isSelected, {required Key key}) {
    return Column(
      key: key,
      children: [
        ListTile(
          selected: isSelected,
          selectedTileColor: Wumbleheme.primaryColor.withOpacity(0.1),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: layer.type == 'box' ? Color(layer.colorValue ?? 0xFFFFFFFF) : null,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(4),
            ),
            child: layer.type == 'box' 
              ? const Icon(Icons.crop_square, color: Colors.white54)
              : (layer.url.startsWith('http')
                ? Image.network(layer.url, fit: BoxFit.contain)
                : (layer.url.startsWith('assets/')
                  ? Image.asset(layer.url, fit: BoxFit.contain)
                  : Image.file(File(layer.url), fit: BoxFit.contain))),
          ),
          title: Text(layer.type == 'box' ? 'Contenedor ${index + 1}' : 'Imagen ${index + 1}', style: const TextStyle(color: Colors.white)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  final newLayers = [..._config.layers];
                  newLayers.removeAt(index);
                  _updateConfig(_config.copyWith(layers: newLayers));
                  setState(() => _selectedLayerIndex = -1);
                },
                icon: const Icon(Icons.delete, color: Colors.white54, size: 20),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: Colors.white54),
              ),
              Icon(isSelected ? Icons.expand_less : Icons.expand_more, color: Colors.white54),
            ],
          ),
          onTap: () => setState(() => _selectedLayerIndex = isSelected ? -1 : index),
        ),
        if (isSelected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.black12,
            child: Column(
              children: [
                _buildSlider('Posición X (Alignment)', layer.x, -1.0, 1.0, (val) {
                  final newLayers = [..._config.layers];
                  newLayers[index] = layer.copyWith(x: val);
                  _updateConfig(_config.copyWith(layers: newLayers));
                }),
                _buildSlider('Posición Y (Alignment)', layer.y, -1.0, 1.0, (val) {
                  final newLayers = [..._config.layers];
                  newLayers[index] = layer.copyWith(y: val);
                  _updateConfig(_config.copyWith(layers: newLayers));
                }),
                _buildSlider('Escala', layer.scale, 0.1, 3.0, (val) {
                  final newLayers = [..._config.layers];
                  newLayers[index] = layer.copyWith(scale: val);
                  _updateConfig(_config.copyWith(layers: newLayers));
                }),
                _buildSlider('Rotación', layer.rotation, -3.14, 3.14, (val) {
                  final newLayers = [..._config.layers];
                  newLayers[index] = layer.copyWith(rotation: val);
                  _updateConfig(_config.copyWith(layers: newLayers));
                }),
                _buildSlider('Opacidad', layer.opacity, 0.0, 1.0, (val) {
                  final newLayers = [..._config.layers];
                  newLayers[index] = layer.copyWith(opacity: val);
                  _updateConfig(_config.copyWith(layers: newLayers));
                }),
                _buildSlider('Desenfoque', layer.blur, 0.0, 10.0, (val) {
                  final newLayers = [..._config.layers];
                  newLayers[index] = layer.copyWith(blur: val);
                  _updateConfig(_config.copyWith(layers: newLayers));
                }),
                if (layer.type == 'box') ...[
                  _buildSlider('Redondeado', layer.borderRadius, 0.0, 100.0, (val) {
                    final newLayers = [..._config.layers];
                    newLayers[index] = layer.copyWith(borderRadius: val);
                    _updateConfig(_config.copyWith(layers: newLayers));
                  }),
                  _buildColorPickerTile('Color Contenedor', layer.colorValue ?? 0xFFFFFFFF, (color) {
                    final newLayers = [..._config.layers];
                    newLayers[index] = layer.copyWith(colorValue: color.value);
                    _updateConfig(_config.copyWith(layers: newLayers));
                  }),
                  _buildColorPickerTile('Gradiente Contenedor', layer.secondaryColorValue ?? 0x00000000, (color) {
                    final newLayers = [..._config.layers];
                    newLayers[index] = layer.copyWith(secondaryColorValue: color.value == 0 ? null : color.value);
                    _updateConfig(_config.copyWith(layers: newLayers));
                  }),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaddingEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('MARGENES DEL TEXTO (INTERNO)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const Text('Controla dónde aparece el texto dentro de la burbuja.', style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 16),
        _buildSlider('Superior', _config.paddingTop, 0, 50, (val) => _updateConfig(_config.copyWith(paddingTop: val))),
        _buildSlider('Inferior', _config.paddingBottom, 0, 50, (val) => _updateConfig(_config.copyWith(paddingBottom: val))),
        _buildSlider('Izquierda', _config.paddingLeft, 0, 50, (val) => _updateConfig(_config.copyWith(paddingLeft: val))),
        _buildSlider('Derecha', _config.paddingRight, 0, 50, (val) => _updateConfig(_config.copyWith(paddingRight: val))),
        const Divider(color: Colors.white12),
        const Text('ESTILO DE TEXTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildFontSelector(),
        const SizedBox(height: 16),
        _buildColorPickerTile('Color de Sombra', _config.shadowColorValue ?? 0x00000000, (color) => _updateConfig(_config.copyWith(shadowColorValue: color.value))),
        _buildSlider('Desenfoque Sombra', _config.shadowBlurRadius, 0, 20, (val) => _updateConfig(_config.copyWith(shadowBlurRadius: val))),
        _buildSlider('Offset X Sombra', _config.shadowOffsetX, -10, 10, (val) => _updateConfig(_config.copyWith(shadowOffsetX: val))),
        _buildSlider('Offset Y Sombra', _config.shadowOffsetY, -10, 10, (val) => _updateConfig(_config.copyWith(shadowOffsetY: val))),
      ],
    );
  }

  Widget _buildFontSelector() {
    final fonts = ['Default', 'Roboto', 'Inter', 'monospace', 'serif', 'cursive'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipografía', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: fonts.length,
            itemBuilder: (context, index) {
              final font = fonts[index];
              final isSelected = _config.fontStyle == font || (_config.fontStyle == null && font == 'Default');
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(font, style: TextStyle(fontFamily: font == 'Default' ? null : font)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) _updateConfig(_config.copyWith(fontStyle: font == 'Default' ? null : font));
                  },
                  selectedColor: Wumbleheme.primaryColor,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12),
                  backgroundColor: Colors.white10,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _build9SliceEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('9-SLICE (ESTIRAMIENTO DEL FONDO)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const Text('Define los bordes fijos que no deben deformarse al estirar la imagen.', style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 20),
        _buildSlider('Guía Superior', _config.sliceTop, 0, 100, (val) => _updateConfig(_config.copyWith(sliceTop: val))),
        _buildSlider('Guía Inferior', _config.sliceBottom, 0, 100, (val) => _updateConfig(_config.copyWith(sliceBottom: val))),
        _buildSlider('Guía Izquierda', _config.sliceLeft, 0, 100, (val) => _updateConfig(_config.copyWith(sliceLeft: val))),
        _buildSlider('Guía Derecha', _config.sliceRight, 0, 100, (val) => _updateConfig(_config.copyWith(sliceRight: val))),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent),
              SizedBox(width: 12),
              Expanded(child: Text('Asegúrate de que la imagen de fondo sea lo suficientemente grande para estas guías.', style: TextStyle(color: Colors.white70, fontSize: 11))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: Wumbleheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: Wumbleheme.primaryColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildColorPickerTile(String title, int currentColorValue, Function(Color) onColorChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(currentColorValue),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54),
        ),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Seleccionar $title'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: Color(currentColorValue),
                onColorChanged: onColorChanged,
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPublishDialog() {
    final nameCtrl = TextEditingController(text: _currentStyle.name);
    final descCtrl = TextEditingController();
    String selectedCategory = 'General';
    final categories = ['General', 'Aesthetic', 'Anime', 'Gótico', 'Tech', 'Nature'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          return AlertDialog(
            backgroundColor: Wumbleheme.surfaceColor,
            title: const Text('Publicar en Workshop', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nombre del Pack', labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Descripción Corta', labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: Wumbleheme.surfaceColor,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Categoría', labelStyle: TextStyle(color: Colors.white54)),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateBuilder(() => selectedCategory = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Wumbleheme.primaryColor, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(context); // Close dialog
                  await _publishPack(nameCtrl.text, descCtrl.text, selectedCategory);
                },
                child: const Text('PUBLICAR'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _publishPack(String name, String desc, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Show loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final styleId = 'workshop_${DateTime.now().millisecondsSinceEpoch}';
      final finalStyle = _currentStyle.copyWith(id: styleId, name: name);
      
      final pack = BubblePack(
        id: 'pack_$styleId',
        name: name,
        description: desc.isEmpty ? 'Burbuja creada en el Workshop.' : desc,
        category: category,
        creatorId: user.uid,
        isPublic: true,
        styles: [finalStyle],
      );

      await GetIt.I<ProfileRepository>().publishWorkshopPack(pack);
      
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Publicado en el Workshop! 🎉')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
      }
    }
  }

  Widget _buildShapeEditor() {
    final shapes = ['default', 'sharp', 'wavy', 'cloud', 'polygon', 'jagged'];
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: shapes.length,
      itemBuilder: (context, index) {
        final shape = shapes[index];
        final isSelected = _currentStyle.shapeId == shape && shape != 'default' || (_currentStyle.shapeId == null && shape == 'default') || (_currentStyle.shapeId == 'default' && shape == 'default');
        return GestureDetector(
          onTap: () {
             // For shape, since copyWith doesn't clear, we can set it to 'default' if it's default
             _updateStyle(_currentStyle.copyWith(shapeId: shape));
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Wumbleheme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    shape == 'default' ? Icons.rectangle_rounded : 
                    shape == 'cloud' ? Icons.cloud : 
                    Icons.dashboard_customize,
                    color: isSelected ? Wumbleheme.primaryColor : Colors.white54,
                  ),
                  const SizedBox(height: 8),
                  Text(shape.toUpperCase(), style: TextStyle(color: isSelected ? Wumbleheme.primaryColor : Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Fondo de la Burbuja (Imagen o Animación)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 120, // Make background selector larger
            height: 80,
            child: _buildOrnamentSelector(Alignment.center, 'background', _currentStyle.backgroundImageUrl),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Ornamentos (Esquinas)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOrnamentSelector(Alignment.topLeft, 'top_left', _currentStyle.topLeftOrnamentUrl),
            _buildOrnamentSelector(Alignment.topRight, 'top_right', _currentStyle.topRightOrnamentUrl),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOrnamentSelector(Alignment.bottomLeft, 'bottom_left', _currentStyle.bottomLeftOrnamentUrl),
            _buildOrnamentSelector(Alignment.bottomRight, 'bottom_right', _currentStyle.bottomRightOrnamentUrl),
          ],
        ),
      ],
    );
  }

  Widget _buildOrnamentSelector(Alignment alignment, String corner, String? url) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _pickMediaForCorner(corner),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: (url != null && url.isNotEmpty)
              ? url.startsWith('http') || url.startsWith('assets/') 
                  ? Image.network(url, fit: BoxFit.contain, errorBuilder: (_,__,___) => Image.asset(url, fit: BoxFit.contain))
                  : Image.file(File(url), fit: BoxFit.contain)
              : const Icon(Icons.add_photo_alternate, color: Colors.white38),
          ),
        ),
        if (url != null && url.isNotEmpty)
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () {
                if (corner == 'background') _updateStyle(_currentStyle.copyWith(backgroundImageUrl: ''));
                if (corner == 'top_left') _updateStyle(_currentStyle.copyWith(topLeftOrnamentUrl: ''));
                if (corner == 'top_right') _updateStyle(_currentStyle.copyWith(topRightOrnamentUrl: ''));
                if (corner == 'bottom_left') _updateStyle(_currentStyle.copyWith(bottomLeftOrnamentUrl: ''));
                if (corner == 'bottom_right') _updateStyle(_currentStyle.copyWith(bottomRightOrnamentUrl: ''));
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickMediaForCorner(String corner) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (corner == 'background') _updateStyle(_currentStyle.copyWith(backgroundImageUrl: image.path));
      if (corner == 'top_left') _updateStyle(_currentStyle.copyWith(topLeftOrnamentUrl: image.path));
      if (corner == 'top_right') _updateStyle(_currentStyle.copyWith(topRightOrnamentUrl: image.path));
      if (corner == 'bottom_left') _updateStyle(_currentStyle.copyWith(bottomLeftOrnamentUrl: image.path));
      if (corner == 'bottom_right') _updateStyle(_currentStyle.copyWith(bottomRightOrnamentUrl: image.path));
    }
  }
  Widget _buildCustomPathEditor() {
    final points = _config.customPathPoints ?? [
      const Offset(0.1, 0.1),
      const Offset(0.9, 0.1),
      const Offset(0.9, 0.9),
      const Offset(0.1, 0.9),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PUNTOS DE RUTA (Relativos 0-1)', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 20),
                onPressed: () {
                  final newPoints = List<Offset>.from(points);
                  newPoints.add(const Offset(0.5, 0.5));
                  _updateConfig(_config.copyWith(customPathPoints: newPoints));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(points.length, (index) {
            final point = points[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(radius: 10, backgroundColor: Colors.amber, child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('X:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Slider(
                                value: point.dx,
                                min: 0,
                                max: 1,
                                onChanged: (val) {
                                  final newPoints = List<Offset>.from(points);
                                  newPoints[index] = Offset(val, point.dy);
                                  _updateConfig(_config.copyWith(customPathPoints: newPoints));
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Y:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Slider(
                                value: point.dy,
                                min: 0,
                                max: 1,
                                onChanged: (val) {
                                  final newPoints = List<Offset>.from(points);
                                  newPoints[index] = Offset(point.dx, val);
                                  _updateConfig(_config.copyWith(customPathPoints: newPoints));
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                    onPressed: points.length > 3 ? () {
                      final newPoints = List<Offset>.from(points);
                      newPoints.removeAt(index);
                      _updateConfig(_config.copyWith(customPathPoints: newPoints));
                    } : null,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
