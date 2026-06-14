import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wumble/core/utils/media_helper.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart';
import '../../domain/community_model.dart';
import '../../domain/community_member_model.dart';
import '../../domain/navigation_tab_model.dart';
import '../../../feed/domain/category_model.dart';
import '../bloc/community_management_cubit.dart';
import '../bloc/community_management_state.dart';

class CommunityManagementScreen extends StatefulWidget {
  final Community community;

  CommunityManagementScreen({super.key, required this.community});

  @override
  State<CommunityManagementScreen> createState() => _CommunityManagementScreenState();
}

class _CommunityManagementScreenState extends State<CommunityManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CommunityManagementCubit>()..loadManagementData(widget.community),
      child: Scaffold(
        backgroundColor: Wumbleheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: widget.community.themeColor,
          title: Text(tr('Navegación y Categorías')),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Categorías'),
              Tab(text: 'Navegación'),
            ],
          ),
        ),
        body: BlocConsumer<CommunityManagementCubit, CommunityManagementState>(
          listener: (context, state) {
            if (state is CommunityManagementSuccess || state is CommunityNavigationSuccess) {
              final message = state is CommunityManagementSuccess 
                ? (state as CommunityManagementSuccess).message 
                : (state as CommunityNavigationSuccess).message;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            }
            if (state is CommunityManagementError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
            }
          },
          builder: (context, state) {
            if (state is CommunityManagementLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            // Si cargó o se aplicó una actualización exitosa, mostramos la interfaz
            if (state is CommunityManagementLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _CategoriesTab(community: state.community, categories: state.categories),
                  _NavigationManagementTab(community: state.community),
                ],
              );
            }

            return Center(child: Text(tr('Cargando...')));
          },
        ),
      ),
    );
  }
}

class _EditDetailsTab extends StatefulWidget {
  final Community community;

  _EditDetailsTab({required this.community});

  @override
  State<_EditDetailsTab> createState() => _EditDetailsTabState();
}

class _EditDetailsTabState extends State<_EditDetailsTab> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late int _themeColorValue;
  File? _iconFile;
  File? _bannerFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.community.name);
    _descController = TextEditingController(text: widget.community.description);
    _themeColorValue = widget.community.themeColorValue;
  }

  Future<void> _pickImage(bool isIcon) async {
    final XFile? picked = await MediaHelper.pickImageWithOptimization(context);
    if (picked != null) {
      setState(() {
        if (isIcon) {
          _iconFile = File(picked.path);
        } else {
          _bannerFile = File(picked.path);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Apariencia'),
          SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => _pickImage(true),
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _iconFile != null
                      ? FileImage(_iconFile!)
                      : NetworkImage(widget.community.iconUrl) as ImageProvider,
                  child: const Icon(Icons.camera_alt, color: Colors.white54),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(false),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                      image: _bannerFile != null
                          ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                          : (widget.community.bannerUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(widget.community.bannerUrl), fit: BoxFit.cover)
                              : null),
                    ),
                    child: const Center(child: Icon(Icons.camera_alt, color: Colors.white54)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildSectionTitle('Información'),
          SizedBox(height: 10),
          TextField(
            controller: _nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: 'Nombre de la Comunidad', labelStyle: TextStyle(color: Colors.white70)),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _descController,
            style: TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(labelText: 'Descripción', labelStyle: TextStyle(color: Colors.white70)),
          ),
          SizedBox(height: 20),
          _buildSectionTitle('Tema'),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              0xFF7F4DFF, 0xFFE91E63, 0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0
            ].map((colorValue) {
              return GestureDetector(
                onTap: () => setState(() => _themeColorValue = colorValue),
                child: CircleAvatar(
                  backgroundColor: Color(colorValue),
                  radius: 18,
                  child: _themeColorValue == colorValue ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(_themeColorValue)),
              onPressed: () {
                context.read<CommunityManagementCubit>().updateCommunityDetails(
                  communityId: widget.community.id,
                  name: _nameController.text,
                  description: _descController.text,
                  themeColorValue: _themeColorValue,
                  icon: _iconFile,
                  banner: _bannerFile,
                  currentCommunity: widget.community,
                );
              },
              child: Text(tr('GUARDAR CAMBIOS'), style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(color: Wumbleheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16));
  }
}

class _MembersTab extends StatelessWidget {
  final List<CommunityMember> members;
  final String communityId;

  _MembersTab({required this.members, required this.communityId});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
            child: member.avatarUrl == null ? Icon(Icons.person) : null,
          ),
          title: Text(member.displayName ?? 'Usuario', style: TextStyle(color: Colors.white)),
          subtitle: Text(member.role, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'kick') {
                context.read<CommunityManagementCubit>().kickMember(communityId, member.userId);
              } else {
                context.read<CommunityManagementCubit>().promoteMember(communityId, member.userId, value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'leader', child: Text(tr('Promover a Líder'))),
              PopupMenuItem(value: 'curator', child: Text(tr('Promover a Curador'))),
              PopupMenuItem(value: 'member', child: Text(tr('Degradar a Miembro'))),
              PopupMenuItem(value: 'kick', child: Text(tr('Expulsar'), style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
    );
  }
}

class _LevelTitlesTab extends StatefulWidget {
  final Community community;

  const _LevelTitlesTab({required this.community});

  @override
  State<_LevelTitlesTab> createState() => _LevelTitlesTabState();
}

class _LevelTitlesTabState extends State<_LevelTitlesTab> {
  final Map<String, String> _titles = {};

  @override
  void initState() {
    super.initState();
    _titles.addAll(widget.community.levelTitles);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 20,
            itemBuilder: (context, index) {
              final levelMethod = (index + 1).toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: Text('$levelMethod', style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _titles[levelMethod],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Título para Nivel $levelMethod',
                          hintStyle: const TextStyle(color: Colors.white24),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          _titles[levelMethod] = value;
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.community.themeColor),
              onPressed: () {
                context.read<CommunityManagementCubit>().updateLevelTitles(widget.community.id, _titles);
              },
              child: Text(tr('GUARDAR TÍTULOS'), style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigationManagementTab extends StatefulWidget {
  final Community community;

  const _NavigationManagementTab({required this.community});

  @override
  State<_NavigationManagementTab> createState() => _NavigationManagementTabState();
}

class _NavigationManagementTabState extends State<_NavigationManagementTab> {
  late List<CommunityNavigationTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = List.from(widget.community.navigationTabs.isEmpty 
        ? Community.defaultTabs 
        : widget.community.navigationTabs);
    _tabs.sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _tabs.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _tabs.removeAt(oldIndex);
                _tabs.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final tab = _tabs[index];
              return Card(
                key: ValueKey(tab.id),
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle, color: Colors.white24),
                  title: Row(
                    children: [
                      Icon(_getTabIcon(tab.type), size: 16, color: widget.community.themeColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: tab.title,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) {
                            _tabs[index] = tab.copyWith(title: val);
                          },
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _getTabTypeName(tab.type).toUpperCase(),
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          tab.isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: tab.isHidden ? Colors.white24 : widget.community.themeColor,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _tabs[index] = tab.copyWith(isHidden: !tab.isHidden);
                          });
                        },
                      ),
                      if (tab.type == NavigationTabType.externalLink || tab.type == NavigationTabType.category)
                         IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                          onPressed: () => _showEditTabDialog(index, tab),
                        ),
                      if (tab.type == NavigationTabType.externalLink || tab.type == NavigationTabType.category)
                         IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              _tabs.removeAt(index);
                            });
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(tr('ENLACE WEB')),
                      style: OutlinedButton.styleFrom(foregroundColor: widget.community.themeColor),
                      onPressed: _showAddLinkDialog,
                    ),
                  ),
                  const SizedBox(width: 12),
                   Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.category_outlined),
                      label: Text(tr('CATEGORÍA')),
                      style: OutlinedButton.styleFrom(foregroundColor: widget.community.themeColor),
                      onPressed: _showAddCategoryDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: widget.community.themeColor),
                  onPressed: () {
                    // Update orders
                    final orderedTabs = _tabs.asMap().entries.map((entry) {
                      return entry.value.copyWith(order: entry.key);
                    }).toList();
                    
                    context.read<CommunityManagementCubit>().updateNavigationTabs(widget.community.id, orderedTabs);
                  },
                  child: Text(tr('GUARDAR NAVEGACIÓN'), style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddLinkDialog() {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Nuevo Enlace Externo'), style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'URL (http://...)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _tabs.add(CommunityNavigationTab(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleCtrl.text,
                  type: NavigationTabType.externalLink,
                  content: urlCtrl.text,
                  order: _tabs.length,
                ));
              });
              Navigator.pop(context);
            },
            child: Text(tr('Agregar')),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final state = context.read<CommunityManagementCubit>().state;
    if (state is! CommunityManagementLoaded) return;
    
    final categories = state.categories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Primero debes crear categorías personalizadas en la pestaña "Categorías".')),
      );
      return;
    }

    PostCategory? selectedCategory = categories.first;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: Wumbleheme.surfaceColor,
          title: Text(tr('Nueva Pestaña de Categoría'), style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Se creará una pestaña que solo muestre publicaciones de esta categoría.', 
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PostCategory>(
                value: selectedCategory,
                dropdownColor: Wumbleheme.surfaceColor,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Selecciona una Categoría',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem<PostCategory>(
                    value: cat,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setStateModal(() => selectedCategory = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.community.themeColor),
              onPressed: selectedCategory == null ? null : () {
                setState(() {
                  _tabs.add(CommunityNavigationTab(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: selectedCategory!.name,
                    type: NavigationTabType.category,
                    content: selectedCategory!.id, // Aquí guardamos el ID para filtrar correctamente
                    order: _tabs.length,
                  ));
                });
                Navigator.pop(context);
              },
              child: Text(tr('Agregar'), style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTabDialog(int index, CommunityNavigationTab tab) {
    final titleCtrl = TextEditingController(text: tab.title);
    final contentCtrl = TextEditingController(text: tab.content);
    
    // For category tabs, we need to handle the dropdown
    final state = context.read<CommunityManagementCubit>().state;
    PostCategory? selectedCategory;
    List<PostCategory> categories = [];
    
    if (tab.type == NavigationTabType.category && state is CommunityManagementLoaded) {
      categories = state.categories;
      selectedCategory = categories.firstWhere(
        (c) => c.id == tab.content, 
        orElse: () => categories.isNotEmpty ? categories.first : PostCategory(id: '', name: 'N/A', icon: '', communityId: '', order: 0)
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: Wumbleheme.surfaceColor,
          title: Text(
            tab.type == NavigationTabType.externalLink ? 'Editar Enlace Web' : 'Editar Pestaña de Categoría', 
            style: TextStyle(color: Colors.white)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Título',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              if (tab.type == NavigationTabType.externalLink)
                TextField(
                  controller: contentCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'URL (http://...)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              if (tab.type == NavigationTabType.category && categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: DropdownButtonFormField<PostCategory>(
                    value: selectedCategory,
                    dropdownColor: Wumbleheme.surfaceColor,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Selecciona una Categoría',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                    items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.name))).toList(),
                    onChanged: (val) => setStateModal(() => selectedCategory = val),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white70))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.community.themeColor),
              onPressed: () {
                setState(() {
                  _tabs[index] = tab.copyWith(
                    title: titleCtrl.text.trim(),
                    content: tab.type == NavigationTabType.externalLink 
                      ? contentCtrl.text.trim() 
                      : selectedCategory?.id,
                  );
                });
                Navigator.pop(context);
              },
              child: Text(tr('Guardar'), style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTabIcon(NavigationTabType type) {
    switch (type) {
      case NavigationTabType.featured: return Icons.label_important_outline_rounded;
      case NavigationTabType.recent: return Icons.access_time_rounded;
      case NavigationTabType.chats: return Icons.chat_bubble_outline_rounded;
      case NavigationTabType.wikis: return Icons.menu_book_rounded;
      case NavigationTabType.quizzes: return Icons.quiz_outlined;
      case NavigationTabType.polls: return Icons.poll_outlined;
      case NavigationTabType.sharedFolder: return Icons.folder_shared_outlined;
      case NavigationTabType.leaderboard: return Icons.emoji_events_outlined;
      case NavigationTabType.externalLink: return Icons.link_rounded;
      case NavigationTabType.category: return Icons.category_outlined;
      default: return Icons.circle_outlined;
    }
  }

  String _getTabTypeName(NavigationTabType type) {
    switch (type) {
      case NavigationTabType.featured: return 'Destacados';
      case NavigationTabType.recent: return 'Reciente';
      case NavigationTabType.chats: return 'Chats Públicos';
      case NavigationTabType.wikis: return 'Entradas Wiki';
      case NavigationTabType.quizzes: return 'Quizzes';
      case NavigationTabType.polls: return 'Encuestas';
      case NavigationTabType.sharedFolder: return 'Carpeta Compartida';
      case NavigationTabType.leaderboard: return 'Salón de la Fama';
      case NavigationTabType.externalLink: return 'Enlace Web';
      case NavigationTabType.category: return 'Categoría';
      default: return type.name.toUpperCase();
    }
  }
}

class _CategoriesTab extends StatefulWidget {
  final Community community;
  final List<PostCategory> categories;

  _CategoriesTab({required this.community, required this.categories});

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final cubit = context.read<CommunityManagementCubit>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Nueva Categoría'), style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nombre de la categoría'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final newCat = PostCategory(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                icon: '', // Categorías básicas no tienen icono obligatorio
                communityId: widget.community.id,
                order: widget.categories.length,
              );
              cubit.createCategory(widget.community.id, newCat);
              Navigator.pop(context);
            },
            child: Text(tr('Crear')),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(PostCategory category) {
    final cubit = context.read<CommunityManagementCubit>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Eliminar Categoría'), style: TextStyle(color: Colors.white)),
        content: Text('¿Seguro que quieres eliminar "${category.name}"?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              cubit.deleteCategory(widget.community.id, category.id);
              Navigator.pop(context);
            },
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(PostCategory category) {
    final nameCtrl = TextEditingController(text: category.name);
    final cubit = context.read<CommunityManagementCubit>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Wumbleheme.surfaceColor,
        title: Text(tr('Editar Categoría'), style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre de la categoría',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(tr('Cancelar'), style: TextStyle(color: Colors.white70))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.community.themeColor),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final updatedCat = category.copyWith(name: nameCtrl.text.trim());
              cubit.updateCategory(widget.community.id, updatedCat);
              Navigator.pop(context);
            },
            child: Text(tr('Guardar'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Las categorías que crees aquí podrán ser seleccionadas por los usuarios al publicar, o usadas como nuevas Pestañas de Navegación.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showAddCategoryDialog,
                icon: const Icon(Icons.add),
                label: Text(tr('Nueva')),
                style: ElevatedButton.styleFrom(backgroundColor: widget.community.themeColor),
              ),
            ],
          ),
        ),
        Divider(color: Colors.white24, height: 1),
        Expanded(
          child: widget.categories.isEmpty
              ? Center(child: Text(tr('No hay categorías personalizadas'), style: TextStyle(color: Colors.white54)))
              : ReorderableListView.builder(
                  itemCount: widget.categories.length,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final cat = widget.categories.removeAt(oldIndex);
                    widget.categories.insert(newIndex, cat);
                    
                    // Update orders in DB sequentially
                    for (int i = 0; i < widget.categories.length; i++) {
                      final updatedCat = widget.categories[i].copyWith(order: i);
                      context.read<CommunityManagementCubit>().updateCategory(widget.community.id, updatedCat);
                    }
                  },
                  itemBuilder: (context, index) {
                    final category = widget.categories[index];
                    return ListTile(
                      key: ValueKey(category.id),
                      leading: const Icon(Icons.drag_handle, color: Colors.white54),
                      title: Text(category.name, style: const TextStyle(color: Colors.white)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white54),
                            onPressed: () => _showEditCategoryDialog(category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white54),
                            onPressed: () => _deleteCategory(category),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

