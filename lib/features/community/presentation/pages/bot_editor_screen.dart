import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/community_repository.dart';
import '../../domain/community_model.dart';
import '../../../chat/domain/bot_framework.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/config.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wumble/core/utils/media_helper.dart';
import 'dart:io';

class BotEditorScreen extends StatefulWidget {
  final Community community;
  final BotConfig bot;
  final bool isNew;

  BotEditorScreen({
    super.key,
    required this.community,
    required this.bot,
    this.isNew = false,
  });

  @override
  State<BotEditorScreen> createState() => _BotEditorScreenState();
}

class _BotEditorScreenState extends State<BotEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _prefixController;
  late TextEditingController _avatarController;
  late TextEditingController _descriptionController;
  late TextEditingController _statusTextController;
  late TextEditingController _onJoinController;
  late TextEditingController _onLeaveController;
  late TextEditingController _bannerController;
  late TextEditingController _customStatusPrefixController;
  late BotStatusType _statusType;
  late Color _embedColor;
  late Color _profileColor;
  late bool _isGuardian;
  late bool _allowMention;
  late bool _isActive;
  late double _chatModerationSensitivity;
  late double _feedModerationSensitivity;
  late List<BotCommand> _commands;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = di.sl<StorageService>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bot.name);
    _prefixController = TextEditingController(text: widget.bot.prefix);
    _avatarController = TextEditingController(text: widget.bot.avatarUrl);
    _descriptionController = TextEditingController(text: widget.bot.description);
    _statusTextController = TextEditingController(text: widget.bot.statusText);
    _onJoinController = TextEditingController(text: widget.bot.eventTriggers['onJoin'] ?? '');
    _onLeaveController = TextEditingController(text: widget.bot.eventTriggers['onLeave'] ?? '');
    _bannerController = TextEditingController(text: widget.bot.bannerUrl ?? '');
    _customStatusPrefixController = TextEditingController(text: widget.bot.customStatusPrefix ?? '');
    _statusType = widget.bot.statusType;
    _embedColor = Color(widget.bot.embedColorValue);
    _profileColor = Color(widget.bot.backgroundColorValue ?? widget.bot.embedColorValue);
    _isGuardian = widget.bot.isGuardian;
    _allowMention = widget.bot.allowMention;
    _isActive = widget.bot.isActive;
    _chatModerationSensitivity = widget.bot.chatModerationSensitivity;
    _feedModerationSensitivity = widget.bot.feedModerationSensitivity;
    _commands = List.from(widget.bot.commands);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prefixController.dispose();
    _avatarController.dispose();
    _descriptionController.dispose();
    _statusTextController.dispose();
    _bannerController.dispose();
    _customStatusPrefixController.dispose();
    super.dispose();
  }

  Future<void> _saveBot() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('El nombre no puede estar vacío'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedBot = widget.bot.copyWith(
        name: _nameController.text,
        prefix: _prefixController.text,
        avatarUrl: _avatarController.text,
        description: _descriptionController.text,
        statusType: _statusType,
        statusText: _statusTextController.text,
        embedColorValue: _embedColor.toARGB32(),
        backgroundColorValue: _profileColor.toARGB32(),
        isGuardian: _isGuardian,
        allowMention: _allowMention,
        isActive: _isActive,
        chatModerationSensitivity: _chatModerationSensitivity,
        feedModerationSensitivity: _feedModerationSensitivity,
        commands: _commands,
        bannerUrl: _bannerController.text.trim().isNotEmpty ? _bannerController.text.trim() : null,
        customStatusPrefix: _customStatusPrefixController.text.trim().isNotEmpty ? _customStatusPrefixController.text.trim() : null,
        eventTriggers: {
          'onJoin': _onJoinController.text.trim(),
          'onLeave': _onLeaveController.text.trim(),
        },
      );

      if (widget.isNew) {
        final communityRepo = di.sl<CommunityRepository>();
        await communityRepo.createBot(widget.community.id, updatedBot);
      } else {
        final communityRepo = di.sl<CommunityRepository>();
        await communityRepo.updateBot(widget.community.id, updatedBot);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Bot guardado correctamente'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addCommand() {
    setState(() {
      _commands.add(BotCommand(
        trigger: 'nuevo',
        response: 'Escribe aquí la respuesta',
      ));
    });
  }

  void _editCommand(int index) {
    final cmd = _commands[index];
    final triggerController = TextEditingController(text: cmd.trigger);
    final responseController = TextEditingController(text: cmd.response);
    final titleController = TextEditingController(text: cmd.title);
    final footerController = TextEditingController(text: cmd.footerText);
    final mediaController = TextEditingController(text: cmd.mediaUrl);
    final webhookController = TextEditingController(text: cmd.webhookUrl);
    final apiKeyController = TextEditingController(text: cmd.apiKey);
    final aiModelController = TextEditingController(text: cmd.aiModel);
    final promptController = TextEditingController(text: cmd.prompt);
    final responsesController = TextEditingController(text: cmd.responses.join('\n'));
    List<BotButton> buttons = List.from(cmd.buttons);
    bool isEmbed = cmd.isEmbed;
    BotCommandProvider provider = cmd.provider;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          backgroundColor: Wumbleheme.surfaceColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          title: Text(tr('Editar Comando')),
          content: SizedBox(
            width: MediaQuery.of(dialogCtx).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- EDUCATIONAL TIPS SECTION ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Text(tr('Tips de Inteligencia'), style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTipItem('🤖', 'Usa "*" como activador para que el bot responda a cualquier mensaje (Modo Chat).'),
                        _buildTipItem('🧠', 'Selecciona "Groq" o "Gemini" para darle un cerebro de IA real al comando.'),
                        _buildTipItem('👤', 'En "Prompt", define su personalidad. Ejemplo: "Eres un pirata que habla con rimas".'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildModalTextField(triggerController, 'Activador (Palabra clave)', Icons.terminal),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text('Usa "*" para capturar cualquier mensaje no definido.', style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
                  ),
                  SizedBox(height: 12),
                  _buildModalTextField(responseController, 'Respuesta Principal', Icons.chat_bubble),
                  Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text('Variables: {user}, {community}, {time}, {user_id}', style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
                  ),
                  SizedBox(height: 12),
                  _buildModalTextField(responsesController, 'Otras Respuestas (una por línea)', Icons.shuffle, maxLines: 3),
                  SizedBox(height: 16),
                  
                  // --- AI Provider Section ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('PROVEEDOR DE RESPUESTA'), style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BotCommandProvider>(
                            value: provider,
                            isExpanded: true,
                            dropdownColor: Wumbleheme.surfaceColor,
                            items: BotCommandProvider.values.map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p == BotCommandProvider.webhook ? 'WEBHOOK (AVANZADO)' :
                                p == BotCommandProvider.groq ? 'GROQ IA (RÁPIDO)' :
                                p == BotCommandProvider.gemini ? 'GEMINI IA (GOOGLE)' :
                                'LOCAL (TEXTO FIJO)',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            )).toList(),
                            onChanged: (val) => setModalState(() => provider = val!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  if (provider == BotCommandProvider.webhook)
                    _buildModalTextField(webhookController, 'Webhook URL', Icons.api),
                  
                  if (provider == BotCommandProvider.groq || provider == BotCommandProvider.gemini) ...[
                    _buildModalTextField(apiKeyController, 'API Key (Privada)', Icons.key),
                    SizedBox(height: 12),
                    _buildModalTextField(aiModelController, 'Modelo (ej: llama3-8b-8192)', Icons.auto_awesome),
                    SizedBox(height: 12),
                    _buildModalTextField(promptController, 'Instrucciones del Sistema (Prompt)', Icons.psychology, maxLines: 3),
                    Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text(tr('Define la personalidad y reglas de la IA para este comando.'), style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  
                  // --- Media Selection Section ---
                  _buildMediaPickerSection(mediaController, setModalState, modalCtx),
                  const SizedBox(height: 16),

                  // --- Buttons Section ---
                  _buildButtonsSection(buttons, setModalState, modalCtx),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: Text(tr('Formato Embed'), style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(tr('Título, color y pie de página'), style: TextStyle(color: Colors.white54, fontSize: 11)),
                    value: isEmbed,
                    onChanged: (val) => setModalState(() => isEmbed = val),
                    activeThumbColor: _embedColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isEmbed) ...[
                    const SizedBox(height: 8),
                    _buildModalTextField(titleController, 'Título del Embed', Icons.title),
                    const SizedBox(height: 12),
                    _buildModalTextField(footerController, 'Pie de página', Icons.info_outline),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(modalCtx), child: Text(tr('Cancelar'))),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _commands[index] = BotCommand(
                    trigger: triggerController.text,
                    response: responseController.text,
                    responses: responsesController.text.split('\n').where((t) => t.trim().isNotEmpty).toList(),
                    type: mediaController.text.isNotEmpty ? BotResponseType.image : BotResponseType.text,
                    mediaUrl: mediaController.text.isNotEmpty ? mediaController.text : null,
                    isEmbed: isEmbed,
                    title: titleController.text,
                    footerText: footerController.text,
                    webhookUrl: provider == BotCommandProvider.webhook ? webhookController.text.trim() : null,
                    provider: provider,
                    apiKey: apiKeyController.text.trim(),
                    aiModel: aiModelController.text.trim(),
                    prompt: promptController.text.trim(),
                    buttons: buttons,
                  );
                });
                Navigator.pop(modalCtx);
              },
              child: Text(tr('Guardar')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonsSection(List<BotButton> buttons, StateSetter setModalState, BuildContext modalCtx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr('Botones Interactivos'), style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: Wumbleheme.secondaryColor),
              onPressed: () => _addBotButton(buttons, setModalState, modalCtx),
            ),
          ],
        ),
        if (buttons.isEmpty)
          Text(tr('Sin botones añadidos'), style: TextStyle(color: Colors.white24, fontSize: 11)),
        ...buttons.asMap().entries.map((entry) {
          final idx = entry.key;
          final btn = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              dense: true,
              title: Text(btn.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text(btn.trigger, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1),
              trailing: IconButton(
                icon: const Icon(Icons.delete, size: 16, color: Colors.white24),
                onPressed: () => setModalState(() => buttons.removeAt(idx)),
              ),
              onTap: () => _addBotButton(buttons, setModalState, modalCtx, index: idx),
            ),
          );
        }),
      ],
    );
  }

  void _addBotButton(List<BotButton> buttons, StateSetter setModalState, BuildContext modalCtx, {int? index}) {
    final btn = index != null ? buttons[index] : BotButton(label: '', trigger: '');
    final labelCtrl = TextEditingController(text: btn.label);
    final triggerCtrl = TextEditingController(text: btn.trigger);
    bool isUrl = btn.isUrl;

    showDialog(
      context: modalCtx,
      builder: (btnCtx) => StatefulBuilder(
        builder: (btnModalCtx, setSubModalState) => AlertDialog(
          backgroundColor: Wumbleheme.surfaceColor,
          title: Text(index == null ? 'Añadir Botón' : 'Editar Botón'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModalTextField(labelCtrl, 'Etiqueta (Texto)', Icons.label),
              const SizedBox(height: 12),
              _buildModalTextField(triggerCtrl, 'Activador (Comando o URL)', Icons.bolt),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(tr('Es un enlace (URL)'), style: TextStyle(color: Colors.white70, fontSize: 13)),
                value: isUrl,
                onChanged: (v) => setSubModalState(() => isUrl = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(btnModalCtx), child: Text(tr('Cancelar'))),
            ElevatedButton(
              onPressed: () {
                if (labelCtrl.text.isEmpty || triggerCtrl.text.isEmpty) return;
                setModalState(() {
                  final newBtn = BotButton(label: labelCtrl.text, trigger: triggerCtrl.text, isUrl: isUrl);
                  if (index == null) buttons.add(newBtn);
                  else buttons[index] = newBtn;
                });
                Navigator.pop(btnModalCtx);
              },
              child: Text(tr('Aceptar')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPickerSection(TextEditingController controller, StateSetter setModalState, BuildContext modalCtx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr('Imagen / GIF'), style: TextStyle(color: Colors.white70, fontSize: 12)),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library, size: 20, color: Wumbleheme.secondaryColor),
                  onPressed: () => _pickLocalMedia(controller, setModalState),
                  tooltip: tr('Galería Local'),
                ),
                IconButton(
                  icon: const Icon(Icons.gif_box, size: 20, color: Colors.blueAccent),
                  onPressed: () => _pickGiphyMedia(controller, setModalState, modalCtx),
                  tooltip: tr('Giphy Web'),
                ),
              ],
            ),
          ],
        ),
        _buildModalTextField(controller, 'URL Imagen/GIF (o sube una)', Icons.link),
        if (controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.network(
                    controller.text,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.white10,
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                      onPressed: () => setModalState(() => controller.clear()),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickLocalMedia(TextEditingController controller, StateSetter setModalState) async {
    try {
      final XFile? image = await MediaHelper.pickImageWithOptimization(context);
      if (image == null) return;

      setState(() => _isLoading = true);
      final url = await _storageService.uploadChatImage(File(image.path));
      
      setModalState(() {
        controller.text = url;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Medio subido con éxito'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickGiphyMedia(TextEditingController controller, StateSetter setModalState, BuildContext modalCtx) async {
    try {
      if (AppConfig.giphyApiKey == 'PASTE_YOUR_GIPHY_API_KEY_HERE') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, configura la API Key de Giphy en AppConfig')),
        );
        return;
      }

      final gif = await GiphyGet.getGif(
        context: modalCtx,
        apiKey: AppConfig.giphyApiKey,
        lang: GiphyLanguage.spanish,
        tabColor: Wumbleheme.secondaryColor,
      );

      if (gif != null) {
        final url = gif.images?.original?.url;
        if (url != null) {
          setModalState(() {
            controller.text = url;
          });
        }
      }
    } catch (e) {
      debugPrint('Error en Giphy: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir Giphy: $e')),
        );
      }
    }
  }

  Future<void> _pickAvatarImage() async {
    try {
      final XFile? image = await MediaHelper.pickImageWithOptimization(context);
      if (image == null) return;

      setState(() => _isLoading = true);
      final url = await _storageService.uploadPostImage(File(image.path), folder: 'bots/avatars');
      
      setState(() {
        _avatarController.text = url;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Avatar subido con éxito'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir avatar: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickGiphyAvatar() async {
    try {
      if (AppConfig.giphyApiKey == 'PASTE_YOUR_GIPHY_API_KEY_HERE') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, configura la API Key de Giphy en AppConfig')),
        );
        return;
      }

      final gif = await GiphyGet.getGif(
        context: context,
        apiKey: AppConfig.giphyApiKey,
        lang: GiphyLanguage.spanish,
        tabColor: Wumbleheme.secondaryColor,
      );

      if (gif != null) {
        final url = gif.images?.original?.url;
        if (url != null && mounted) {
          setState(() {
            _avatarController.text = url;
          });
        }
      }
    } catch (e) {
      debugPrint('Error en Giphy Avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir Giphy: $e')),
        );
      }
    }
  }

  Widget _buildActiveToggle() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isActive ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: SwitchListTile(
        title: Text(_isActive ? 'BOT ACTIVO' : 'BOT DESACTIVADO', 
          style: TextStyle(color: _isActive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
        subtitle: Text(tr('Si está desactivado, el bot no responderá a ningún comando.'), 
          style: TextStyle(color: Colors.white54, fontSize: 11)),
        value: _isActive,
        onChanged: (val) => setState(() => _isActive = val),
        activeColor: Colors.greenAccent,
        inactiveThumbColor: Colors.redAccent,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBannerPickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Banner del Mini-perfil'), style: TextStyle(color: Colors.white70, fontSize: 12)),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(_bannerController, 'URL del Banner', Icons.image),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library, color: Wumbleheme.secondaryColor),
              onPressed: _pickBannerImage,
              tooltip: tr('Subir Imagen'),
            ),
            IconButton(
              icon: const Icon(Icons.gif_box, color: Colors.blueAccent),
              onPressed: _pickGiphyBanner,
              tooltip: tr('Buscar en Giphy'),
            ),
          ],
        ),
        if (_bannerController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: _bannerController.text,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.white10),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                      onPressed: () => setState(() => _bannerController.clear()),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickBannerImage() async {
    try {
      final XFile? image = await MediaHelper.pickImageWithOptimization(context);
      if (image == null) return;
      setState(() => _isLoading = true);
      final url = await _storageService.uploadPostImage(File(image.path), folder: 'bots/banners');
      setState(() => _bannerController.text = url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir banner: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickGiphyBanner() async {
    try {
      final gif = await GiphyGet.getGif(
        context: context,
        apiKey: AppConfig.giphyApiKey,
        lang: GiphyLanguage.spanish,
        tabColor: Wumbleheme.secondaryColor,
      );
      if (gif != null) {
        final url = gif.images?.original?.url;
        if (url != null) setState(() => _bannerController.text = url);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en Giphy: $e')));
    }
  }

  Widget _buildTipItem(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildModalTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.isNew ? 'Crear Agente AI' : 'Protocolos del Agente'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else
            IconButton(
              icon: const Icon(Icons.check_circle, color: Wumbleheme.secondaryColor, size: 28),
              onPressed: _saveBot,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIdentitySettings(),
            const SizedBox(height: 32),
            _buildAppearanceSettings(),
            
            const SizedBox(height: 32),
            _buildSectionHeader('Presencia y Operación'),
            _buildActiveToggle(),
            const SizedBox(height: 16),
            _buildPrefixAndStatusRow(),

            const SizedBox(height: 32),
            _buildSectionHeader('IA de Moderación (Guardián)'),
            _buildGuardianSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Automatización de Eventos'),
            _buildTriggerSettings(),

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Base de Conocimiento (Comandos)'),
                IconButton(
                  icon: const Icon(Icons.add_box, color: Wumbleheme.secondaryColor),
                  onPressed: _addCommand,
                ),
              ],
            ),
            ...List.generate(_commands.length, (index) {
              final cmd = _commands[index];
              return Dismissible(
                key: Key('cmd_$index'),
                onDismissed: (_) => setState(() => _commands.removeAt(index)),
                child: Card(
                  color: Wumbleheme.surfaceColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cmd.isEmbed ? _embedColor.withValues(alpha: 0.3) : Colors.transparent)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _embedColor.withValues(alpha: 0.1),
                      child: Text(widget.bot.prefix.isNotEmpty ? widget.bot.prefix : '/', style: TextStyle(color: _embedColor, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(cmd.trigger, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(cmd.response, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.edit_note, color: Colors.white54),
                    onTap: () => _editCommand(index),
                  ),
                ),
              );
            }),

            if (!widget.isNew) ...[
              const SizedBox(height: 48),
              Center(
                child: TextButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  label: Text(tr('DESACTIVAR Y ELIMINAR AGENTE'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefixAndStatusRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(_prefixController, 'Prefijo', Icons.terminal),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text('Símbolo para activar comandos (ej: /)', style: TextStyle(color: Colors.white24, fontSize: 9, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildStatusSelector(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Wumbleheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BotStatusType>(
              value: _statusType,
              dropdownColor: Wumbleheme.surfaceColor,
              isExpanded: true,
              items: BotStatusType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getStatusIcon(type), size: 18, color: Colors.white54),
                      const SizedBox(width: 12),
                      Text(_getStatusLabel(type), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _statusType = val!),
            ),
          ),
        ),
        if (_statusType != BotStatusType.none) ...[
          const SizedBox(height: 12),
          if (_statusType == BotStatusType.custom) ...[
            _buildTextField(_customStatusPrefixController, 'Actividad (ej: Durmiendo)', Icons.bolt),
            const SizedBox(height: 8),
          ],
          _buildTextField(_statusTextController, _statusType == BotStatusType.custom ? 'Detalles (opcional)' : 'Texto del estado', Icons.edit_attributes),
        ],
      ],
    );
  }

  IconData _getStatusIcon(BotStatusType type) {
    switch (type) {
      case BotStatusType.playing: return Icons.videogame_asset;
      case BotStatusType.watching: return Icons.remove_red_eye;
      case BotStatusType.listening: return Icons.headset;
      case BotStatusType.competing: return Icons.emoji_events;
      default: return Icons.do_not_disturb_on;
    }
  }

  String _getStatusLabel(BotStatusType type) {
    switch (type) {
      case BotStatusType.playing: return 'Jugando a...';
      case BotStatusType.watching: return 'Viendo...';
      case BotStatusType.listening: return 'Escuchando...';
      case BotStatusType.competing: return 'Compitiendo en...';
      case BotStatusType.custom: return 'Personalizado...';
      default: return 'Sin estado';
    }
  }

  void _pickEmbedColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Color de Mensajes')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _embedColor,
            onColorChanged: (c) => setState(() => _embedColor = c),
            enableAlpha: false,
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cerrar')))],
      ),
    );
  }

  Widget _buildIdentitySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Identidad del Agente'),
        _buildTextField(_nameController, 'Nombre del Bot', Icons.badge),
        SizedBox(height: 16),
        _buildTextField(_descriptionController, 'Descripción / Protocolo Base', Icons.description, maxLines: 3),
        SizedBox(height: 8),
        Text(
          tr('Define el propósito y comportamiento general de este agente.'),
          style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Identidad Visual'),
        _buildAvatarPickerSection(),
        const SizedBox(height: 24),
        _buildBannerPickerSection(),
        const SizedBox(height: 24),
        _buildSectionHeader('Protocolos de Color'),
        Row(
          children: [
            Expanded(child: _buildColorTile('Color de Perfil', _profileColor, _pickProfileColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildColorTile('Color Embed', _embedColor, _pickEmbedColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildColorTile(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Wumbleheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(width: 24, height: 24, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _pickProfileColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Color de Perfil')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _profileColor,
            onColorChanged: (c) => setState(() => _profileColor = c),
            enableAlpha: false,
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cerrar')))],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: Wumbleheme.secondaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54, size: 22),
        filled: true,
        fillColor: Wumbleheme.surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Eliminar Bot')),
        content: Text(tr('¿Estás seguro? Se perderán todos los comandos.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final communityRepo = di.sl<CommunityRepository>();
              final String communityId = widget.community.id;
              final String botId = widget.bot.id;
              final navigator = Navigator.of(context);
              await communityRepo.deleteBot(communityId, botId);
              if (mounted) {
                navigator.pop(); // Close dialog
                navigator.pop(); // Close screen
              }
            },
            child: Text(tr('Eliminar')),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianSettings() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isGuardian ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(tr('Modo Guardián (IA)'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(tr('Detecta y elimina mensajes tóxicos/spam localmente'), style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _isGuardian,
            onChanged: (val) => setState(() => _isGuardian = val),
            activeThumbColor: Colors.greenAccent,
            contentPadding: EdgeInsets.zero,
          ),
          if (_isGuardian) ...[
            const Divider(color: Colors.white10, height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('SENSIBILIDAD POR CANAL'), style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // Chat Sensitivity
                Row(
                  children: [
                    const Icon(Icons.forum_outlined, color: Colors.white54, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chats: ${(_chatModerationSensitivity * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Slider(
                            value: _chatModerationSensitivity,
                            onChanged: (val) => setState(() => _chatModerationSensitivity = val),
                            activeColor: Colors.greenAccent,
                            inactiveColor: Colors.white10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Feed Sensitivity
                Row(
                  children: [
                    const Icon(Icons.article_outlined, color: Colors.white54, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publicaciones/Feed: ${(_feedModerationSensitivity * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Slider(
                            value: _feedModerationSensitivity,
                            onChanged: (val) => setState(() => _feedModerationSensitivity = val),
                            activeColor: Colors.lightBlueAccent,
                            inactiveColor: Colors.white10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarPickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('IMAGEN DE PERFIL DEL BOT', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Wumbleheme.surfaceColor,
                  backgroundImage: _avatarController.text.isNotEmpty 
                      ? NetworkImage(_avatarController.text) 
                      : null,
                  child: _avatarController.text.isEmpty 
                      ? const Icon(Icons.face_retouching_natural, size: 40, color: Colors.white24) 
                      : null,
                ),
                if (_avatarController.text.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _avatarController.clear()),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickAvatarImage,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: Text(tr('SUBIR FOTO')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Wumbleheme.secondaryColor,
                      side: const BorderSide(color: Wumbleheme.secondaryColor),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickGiphyAvatar,
                    icon: const Icon(Icons.gif_box, size: 18),
                    label: Text(tr('ELEGIR GIF')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _buildTextField(_avatarController, 'URL del Avatar (opcional)', Icons.link),
      ],
    );
  }

  Widget _buildTriggerSettings() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(tr('Responder a Menciones'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text(tr('Si lo mencionas con @Nombre, el bot usará la IA (comando *) para conversar.'), style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _allowMention,
            onChanged: (val) => setState(() => _allowMention = val),
            activeThumbColor: Wumbleheme.secondaryColor,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildTextField(_onJoinController, 'Trigger al unirse (onJoin)', Icons.person_add),
          const SizedBox(height: 12),
          _buildTextField(_onLeaveController, 'Trigger al salir (onLeave)', Icons.person_remove),
          const SizedBox(height: 8),
          const Text(
            'Escribe el activador de un comando (ej: bienvenida) que el bot ejecutará automáticamente.',
            style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
