import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/community_model.dart';
import 'package:wumble/features/community/presentation/bloc/community_members_bloc.dart';
import 'package:wumble/core/widgets/user_avatar.dart';
import 'package:wumble/core/widgets/user_badge_widget.dart';
import 'package:wumble/injection_container.dart' as di;

class MemberPickerSheet extends StatefulWidget {
  final String communityId;
  final String title;
  final List<String> excludedIds;

  const MemberPickerSheet({
    super.key,
    required this.communityId,
    this.title = 'Invitar Miembro',
    this.excludedIds = const [],
  });

  static Future<CommunityMember?> show(
    BuildContext context, {
    required String communityId,
    String title = 'Invitar Miembro',
    List<String> excludedIds = const [],
  }) {
    return showModalBottomSheet<CommunityMember>(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => MemberPickerSheet(
        communityId: communityId,
        title: title,
        excludedIds: excludedIds,
      ),
    );
  }

  @override
  State<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<MemberPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      // Lazy loading more members if needed
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll - 200);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<CommunityMembersBloc>()..add(LoadInitialMembers(widget.communityId)),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, controller) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre...',
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (val) {
                    if (val.isEmpty) {
                      context.read<CommunityMembersBloc>().add(ClearSearch(widget.communityId));
                    } else {
                      context.read<CommunityMembersBloc>().add(SearchMembers(widget.communityId, val));
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: BlocBuilder<CommunityMembersBloc, CommunityMembersState>(
                  builder: (context, state) {
                    if (state.isLoading && state.members.isEmpty) {
                      return Center(child: CircularProgressIndicator());
                    }
                    
                    final filteredMembers = state.members.where((m) => !widget.excludedIds.contains(m.userId)).toList();

                    if (filteredMembers.isEmpty) {
                      return Center(
                        child: Text(tr('No hay más miembros para invitar'), style: TextStyle(color: Colors.white38)),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        return ListTile(
                          leading: UserAvatar(
                            userId: member.userId,
                            avatarUrl: member.avatarUrl ?? '',
                            displayName: member.displayName ?? 'Usuario',
                            radius: 20,
                            skipFirestoreSync: true,
                            isAnimated: false,
                          ),
                          title: Text(member.displayName ?? 'Usuario', style: const TextStyle(color: Colors.white)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: UserBadgeWidget(
                              level: member.level,
                              isBot: member.isBot,
                              fontSize: 9,
                              showTitles: false,
                            ),
                          ),
                          trailing: const Icon(Icons.add_circle_outline, color: Wumbleheme.primaryColor),
                          onTap: () => Navigator.pop(context, member),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
