import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../../core/utils/media_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme.dart';
import '../../domain/community_model.dart';
import '../../domain/community_member_model.dart';
import '../../domain/reputation_service.dart';
import '../../domain/community_repository.dart';
import '../bloc/community_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bloc/community_context_bloc.dart';
import 'community_management_screen.dart';
import 'member_management_screen.dart';
import 'join_requests_screen.dart';
import 'banned_users_screen.dart';
import '../wiki_approval_screen.dart';
import 'bot_management_screen.dart';
import 'moderation_center_screen.dart';
import '../../../../injection_container.dart' as di;

class CommunitySettingsScreen extends StatefulWidget {
  final Community community;
  final CommunityMember? member;

  CommunitySettingsScreen({
    super.key, 
    required this.community,
    this.member,
  });

  @override
  State<CommunitySettingsScreen> createState() => _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  // Admin Data
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _category;
  late String _privacy;
  late Color _themeColor;
  late TextEditingController _welcomeMessageController;
  late bool _isWelcomeMessageEnabled;
  
  // Admin Files
  File? _iconFile;
  File? _bannerFile;
  File? _backgroundFile;
  
  final ImagePicker _picker = ImagePicker();

  bool get _isAdmin => widget.member?.role == 'leader' || widget.member?.role == 'curator';
  bool get _isOwner => widget.community.creatorId == FirebaseAuth.instance.currentUser?.uid;

  final List<String> _categories = Community.categories;

  @override
  void initState() {
    super.initState();
    // Initialize Admin fields
    _nameController = TextEditingController(text: widget.community.name);
    _descriptionController = TextEditingController(text: widget.community.description);
    _category = widget.community.category;
    _privacy = widget.community.privacy;
    _themeColor = widget.community.themeColor;
    _welcomeMessageController = TextEditingController(text: widget.community.welcomeMessage);
    _isWelcomeMessageEnabled = widget.community.isWelcomeMessageEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _welcomeMessageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() {
        if (type == 'icon') _iconFile = File(image.path);
        if (type == 'banner') _bannerFile = File(image.path);
        if (type == 'background') _backgroundFile = File(image.path);
      });
    }
  }

  void _saveChanges() {
    final bloc = context.read<CommunityBloc>();

    // Save Community Administration Changes (Admins only)
    if (_isAdmin) {
      final updates = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'category': _category,
        'privacy': _privacy,
        'themeColorValue': _themeColor.value,
        'welcomeMessage': _welcomeMessageController.text,
        'isWelcomeMessageEnabled': _isWelcomeMessageEnabled,
      };

      bloc.add(UpdateCommunity(
        communityId: widget.community.id,
        updates: updates,
        icon: _iconFile,
        banner: _bannerFile,
        background: _backgroundFile,
      ));
    } else {
      // For normal users, maybe just close or show a message if they try to save
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommunityBloc, CommunityState>(
      listener: (context, state) {
        if (state is CommunityUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Ajustes guardados correctamente'))),
          );
          Navigator.pop(context);
        } else if (state is CommunityLeft) {
          context.read<CommunityContextBloc>().add(ExitCommunity());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Has abandonado la comunidad.'))),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (state is CommunityDeletedState) {
          context.read<CommunityContextBloc>().add(ExitCommunity());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Comunidad eliminada permanentemente.'))),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (state is CommunityError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Wumbleheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Wumbleheme.backgroundColor,
          elevation: 0,
          title: Text(_isAdmin ? 'Ajustes de Comunidad' : 'Información', style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            if (_isAdmin)
              TextButton(
                onPressed: _saveChanges,
                child: Text(tr('GUARDAR'), style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Display Community Overview for everyone
                _buildCommunityOverview(),
                
                const SizedBox(height: 32),
                
                // SECTION: ADMINISTRATION (Only for Leaders/Curators)
                if (_isAdmin) ...[
                  _buildSectionHeader('Administración'),
                  _buildAdminIdentitySection(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Estilo Visual'),
                  _buildColorPicker(),
                  const SizedBox(height: 20),
                  _buildImageSelectors(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Privacidad'),
                  _buildPrivacyOptions(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Moderación'),
                  _buildMemberManagementOption(),
                  _buildModerationCenterOption(),
                  _buildJoinRequestsOption(),
                  const SizedBox(height: 12),
                  _buildBannedUsersOption(),
                  const SizedBox(height: 12),
                  _buildLevelTitlesOption(),
                  const SizedBox(height: 12),
                  _buildNavigationManagementOption(),
                  const SizedBox(height: 12),
                  _buildWikiApprovalOption(),
                  const SizedBox(height: 12),
                  _buildBotManagementOption(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Herramientas de Bienvenida'),
                  _buildWelcomeMessageConfig(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Mantenimiento'),
                  _buildOptimizeMembersOption(),
                ] else ...[
                  // Options for normal users
                  _buildSectionHeader('Privacidad'),
                  _buildPrivacyBadge(),
                ],

                const SizedBox(height: 32),
                _buildSectionHeader('Acciones'),
                _buildDangerZone(),

                const SizedBox(height: 40),
              ],
            ),
            
            // Loading Overlay
            BlocBuilder<CommunityBloc, CommunityState>(
              builder: (context, state) {
                if (state is CommunityUpdating) {
                  return Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: Colors.black54,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: _themeColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildCommunityOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _themeColor, width: 2),
              image: widget.community.iconUrl.isNotEmpty
                ? DecorationImage(image: CachedNetworkImageProvider(widget.community.iconUrl), fit: BoxFit.cover)
                : null,
            ),
            child: widget.community.iconUrl.isEmpty ? const Icon(Icons.group, color: Colors.white24, size: 40) : null,
          ),
          const SizedBox(height: 16),
          Text(widget.community.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('@${widget.community.handle}', style: TextStyle(color: _themeColor, fontSize: 14)),
          const SizedBox(height: 12),
          Text(
            widget.community.description,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- ADMIN SECTIONS ---

  Widget _buildAdminIdentitySection() {
    return Column(
      children: [
        _buildTextField('Nombre del Wumble', _nameController),
        SizedBox(height: 16),
        _buildTextField('Descripción', _descriptionController, maxLines: 3),
        SizedBox(height: 16),
        _buildDropdown('Categoría', _category, _categories, (val) => setState(() => _category = val!)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white60, fontSize: 12)),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white60, fontSize: 12)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Wumbleheme.surfaceColor,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Wumbleheme.surfaceColor,
                title: Text(tr('Color de Tema'), style: TextStyle(color: Colors.white)),
                content: SingleChildScrollView(
                  child: ColorPicker(
                    pickerColor: _themeColor,
                    onColorChanged: (c) => setState(() => _themeColor = c),
                    enableAlpha: false,
                    paletteType: PaletteType.hsvWithHue,
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('OK'))),
                ],
              ),
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _themeColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 2),
              boxShadow: [BoxShadow(color: _themeColor.withOpacity(0.3), blurRadius: 10)],
            ),
            child: const Icon(Icons.colorize, color: Colors.white),
          ),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Text(
            tr('Personaliza el color que define la identidad de tu comunidad.'),
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelectors() {
    return Column(
      children: [
        _buildImagePickerRow('Icono del Wumble', 'icon', _iconFile, widget.community.iconUrl),
        const SizedBox(height: 12),
        _buildImagePickerRow('Banner Lanzamiento', 'banner', _bannerFile, widget.community.bannerUrl),
        const SizedBox(height: 12),
        _buildImagePickerRow('Fondo Inmersivo', 'background', _backgroundFile, widget.community.backgroundUrl),
      ],
    );
  }

  Widget _buildImagePickerRow(String label, String type, File? localFile, String remoteUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          GestureDetector(
            onTap: () => _pickImage(type),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
                image: localFile != null 
                  ? DecorationImage(image: FileImage(localFile), fit: BoxFit.cover)
                  : remoteUrl.isNotEmpty 
                    ? DecorationImage(image: NetworkImage(remoteUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: (localFile == null && remoteUrl.isEmpty) 
                ? const Icon(Icons.add_a_photo, color: Colors.white24, size: 20) 
                : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOptions() {
    return Column(
      children: [
        _buildPrivacyRadio('Comunidad Abierta', 'Libre acceso para todos.', 'open'),
        const SizedBox(height: 12),
        _buildPrivacyRadio('Bajo Aprobación', 'Los Líderes aceptan miembros.', 'approval'),
        const SizedBox(height: 12),
        _buildPrivacyRadio('Privada / Oculta', 'Solo mediante invitación.', 'private'),
      ],
    );
  }

  Widget _buildPrivacyRadio(String title, String subtitle, String value) {
    bool isSelected = _privacy == value;
    return GestureDetector(
      onTap: () => setState(() => _privacy = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _themeColor.withOpacity(0.1) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? _themeColor.withOpacity(0.4) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              value == 'open' ? Icons.public : value == 'approval' ? Icons.approval : Icons.lock,
              color: isSelected ? _themeColor : Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: _themeColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyBadge() {
    final isPrivate = widget.community.privacy != 'open';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(isPrivate ? Icons.lock : Icons.public, color: _themeColor),
          const SizedBox(width: 16),
          Text(
            isPrivate ? 'Comunidad Privada' : 'Comunidad Pública',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberManagementOption() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _themeColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.admin_panel_settings, color: _themeColor),
      ),
      title: Text(tr('Gestión de Staff y Miembros'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Administrar roles y moderación'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberManagementScreen(
              communityId: widget.community.id,
              themeColor: _themeColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildModerationCenterOption() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.security_rounded, color: Colors.orangeAccent),
      ),
      title: Text(tr('Centro de Moderación (Líderes)'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Cola de revisión y reportes de IA'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModerationCenterScreen(
              community: widget.community,
            ),
          ),
        );
      },
    );
  }

  Widget _buildJoinRequestsOption() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: _themeColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.mark_email_unread_rounded, color: _themeColor),
      ),
      title: Text(tr('Solicitudes de Ingreso'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Revisar y aprobar nuevos miembros'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JoinRequestsScreen(community: widget.community),
          ),
        );
      },
    );
  }

  Widget _buildBannedUsersOption() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.gavel_rounded, color: Colors.redAccent),
      ),
      title: Text(tr('Usuarios Expulsados'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Gestionar baneos temporales y permanentes'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BannedUsersScreen(
              communityId: widget.community.id,
              themeColor: _themeColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelTitlesOption() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.stars_rounded, color: Colors.amber),
      ),
      title: Text(tr('Niveles de la Comunidad'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Personaliza los nombres de los 20 niveles'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () => _showLevelTitlesEditor(),
    );
  }

  Widget _buildNavigationManagementOption() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: _themeColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.explore_outlined, color: _themeColor),
      ),
      title: Text(tr('Configurar Navegación'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Reordenar, renombrar y añadir pestañas'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityManagementScreen(community: widget.community),
          ),
        );
      },
    );
  }

  void _showLevelTitlesEditor() {
    final Map<String, String> currentTitles = Map.from(widget.community.levelTitles);
    final controllers = <int, TextEditingController>{};
    
    for (int i = 1; i <= 20; i++) {
      controllers[i] = TextEditingController(
        text: currentTitles[i.toString()] ?? ReputationService.getLevelTitle(i, null)
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Wumbleheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Niveles de la Comunidad'), style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () async {
                          final newTitles = <String, String>{};
                          controllers.forEach((lvl, ctrl) {
                            if (ctrl.text.trim().isNotEmpty) {
                              newTitles[lvl.toString()] = ctrl.text.trim();
                            }
                          });
                          
                          try {
                            await di.sl<CommunityRepository>().updateLevelTitles(widget.community.id, newTitles);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(tr('Niveles de la comunidad actualizados'))),
                              );
                              // Refrescar estado local si es necesario o esperar a que el stream de Firebase haga su magia
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        child: Text(tr('GUARDAR'), style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    tr('Define cómo se llamarán los miembros al alcanzar cada nivel de reputación.'),
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.separated(
                      itemCount: 20,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final lvl = index + 1;
                        return Row(
                          children: [
                            Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: _themeColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$lvl',
                                  style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: controllers[lvl],
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  hintText: 'Título del nivel $lvl',
                                  hintStyle: const TextStyle(color: Colors.white24),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildOptimizeMembersOption() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.auto_fix_high_rounded, color: Colors.blueAccent),
      ),
      title: Text(tr('Optimizar Datos de Miembros'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Prepara a los miembros antiguos para el nuevo sistema'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.bolt_rounded, color: Colors.blueAccent),
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Wumbleheme.surfaceColor,
            title: Text(tr('¿Optimizar datos?'), style: TextStyle(color: Colors.white)),
            content: Text('Esta acción actualizará a los miembros antiguos para que sean compatibles con el nuevo sistema de baneos y mejora el rendimiento general.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('CANCELAR'))),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('OPTIMIZAR'), style: TextStyle(color: _themeColor)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          if (!mounted) return;
          
          // Show progress
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Optimizando miembros...')), duration: Duration(seconds: 1)),
          );

          try {
            await di.sl<CommunityRepository>().migrateMemberBanData(widget.community.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('¡Optimización completada con éxito!'))),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        }
      },
    );
  }

  Widget _buildDangerZone() {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          tileColor: Colors.redAccent.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
            side: BorderSide(color: Colors.redAccent.withOpacity(0.1))
          ),
          leading: Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
          title: Text(tr('Abandonar Comunidad'), style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Wumbleheme.surfaceColor,
                title: Text(tr('¿Abandonar comunidad?'), style: TextStyle(color: Colors.white)),
                content: Text('¿Estás seguro de que quieres salir de esta comunidad? Perderás tu racha y reputación.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
                  TextButton(
                    onPressed: () {
                      // Usar Auth directamente como protección contra miembros oxidados o en caché pasados por UI
                      final actualUserId = FirebaseAuth.instance.currentUser?.uid ?? widget.member!.userId;
                      context.read<CommunityBloc>().add(
                        LeaveCommunityEvent(
                          communityId: widget.community.id,
                          userId: actualUserId,
                        ),
                      );
                      Navigator.pop(context); // Close dialog
                    }, 
                    child: Text(tr('ABANDONAR'), style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
          },
        ),
        if (_isAdmin && _isOwner) ...[
          SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            tileColor: Colors.red.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), 
              side: BorderSide(color: Colors.red.withOpacity(0.2))
            ),
            leading: Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: Text(tr('Eliminar Comunidad'), style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
            onTap: () {
              final confirmController = TextEditingController();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Wumbleheme.surfaceColor,
                  title: Text('BORRAR ABSOLUTAMENTE TODO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Esta acción borrará permanentemente la comunidad, todos sus miembros, todos los posts y todas las imágenes del servidor. ¡NO HAY VUELTA ATRÁS!',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 20),
                      Text(
                        tr('Escribe "BORRAR" para confirmar:'),
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: tr('BORRAR'),
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
                    TextButton(
                      onPressed: () {
                        if (confirmController.text == 'BORRAR') {
                          context.read<CommunityBloc>().add(
                            DeleteCommunityEvent(communityId: widget.community.id),
                          );
                          Navigator.pop(context); // Close dialog
                        }
                      }, 
                      child: Text(tr('ELIMINAR TODO'), style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildWikiApprovalOption() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.book_rounded, color: Colors.amber),
      ),
      title: Text(tr('Entregas al Wiki'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Revisar y aprobar wikis oficiales'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WikiApprovalScreen(communityId: widget.community.id),
          ),
        );
      },
    );
  }

  Widget _buildBotManagementOption() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: _themeColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.smart_toy_outlined, color: _themeColor),
      ),
      title: Text(tr('Gestión de Bots'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(tr('Crea y configura bots personalizados'), style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BotManagementScreen(community: widget.community),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeMessageConfig() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Mensaje Automático'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(tr('Se muestra al unirse un nuevo miembro'), style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              Switch(
                value: _isWelcomeMessageEnabled,
                onChanged: (val) => setState(() => _isWelcomeMessageEnabled = val),
                activeColor: _themeColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField('Texto de Bienvenida', _welcomeMessageController, maxLines: 4),
          const SizedBox(height: 8),
          const Text(
            'Consejo: ¡Sé creativo! Un buen mensaje hace que los miembros se sientan como en casa.',
            style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
