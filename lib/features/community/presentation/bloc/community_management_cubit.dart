import 'dart:io';
import 'package:bloc/bloc.dart';
import '../../domain/community_model.dart';
import '../../domain/community_member_model.dart';
import '../../domain/community_repository.dart';
import '../../domain/navigation_tab_model.dart';
import '../../../feed/domain/feed_repository.dart';
import '../../../feed/domain/category_model.dart';
import 'community_management_state.dart';

class CommunityManagementCubit extends Cubit<CommunityManagementState> {
  final CommunityRepository _repository;
  final FeedRepository _feedRepository;

  CommunityManagementCubit(this._repository, this._feedRepository) : super(CommunityManagementInitial());

  Future<void> loadManagementData(Community community) async {
    emit(CommunityManagementLoading());
    try {
      final members = await _repository.getCommunityMembers(community.id);
      final categories = await _feedRepository.getCategories(community.id);
      emit(CommunityManagementLoaded(members: members, community: community, categories: categories));
    } catch (e) {
      emit(CommunityManagementError('Error loading data: $e'));
    }
  }

  Future<void> updateCommunityDetails({
    required String communityId,
    required String name,
    required String description,
    required int themeColorValue,
    File? icon,
    File? banner,
    File? background,
    required Community currentCommunity,
  }) async {
    // Keep current state to revert or update
    final currentState = state;
    List<dynamic> currentMembers = [];
    if (currentState is CommunityManagementLoaded) {
      currentMembers = currentState.members;
    }
    
    emit(CommunityManagementLoading());
    
    try {
      final updates = {
        'name': name,
        'description': description,
        'themeColorValue': themeColorValue,
      };

      await _repository.updateCommunity(communityId, updates, icon, banner, background);
      
      // Optimistic update or reload? Reload is safer for images.
      // But we need the updated community object to emit Loaded.
      // For now, allow trigger a success which will pop the screen or show a specific message
      emit(const CommunityManagementSuccess('Comunidad actualizada correctamente'));
      
      // Re-emit loaded if we want to stay on screen, but usually we go back.
    } catch (e) {
      emit(CommunityManagementError('Error updating community: $e'));
       if (currentState is CommunityManagementLoaded) {
        emit(currentState); // Restore on error
      }
    }
  }

  Future<void> updateLevelTitles(String communityId, Map<String, String> titles) async {
    try {
      await _repository.updateLevelTitles(communityId, titles);
      emit(const CommunityManagementSuccess('Niveles de la comunidad actualizados'));
    } catch (e) {
      emit(CommunityManagementError('Error updating titles: $e'));
    }
  }

  Future<void> promoteMember(String communityId, String userId, String newRole) async {
    try {
      await _repository.updateMemberRole(communityId, userId, newRole);
      // Reload members
      final members = await _repository.getCommunityMembers(communityId);
      if (state is CommunityManagementLoaded) {
        final current = state as CommunityManagementLoaded;
        emit(CommunityManagementLoaded(members: members, community: current.community, categories: current.categories));
      }
      emit(const CommunityManagementSuccess('Rol actualizado correctamente'));
    } catch (e) {
      emit(CommunityManagementError('Error updating role: $e'));
    }
  }

  Future<void> kickMember(String communityId, String userId) async {
    try {
      await _repository.kickMember(communityId, userId);
      // Reload members
      final members = await _repository.getCommunityMembers(communityId);
      if (state is CommunityManagementLoaded) {
        final current = state as CommunityManagementLoaded;
        emit(CommunityManagementLoaded(members: members, community: current.community, categories: current.categories));
      }
      emit(const CommunityManagementSuccess('Miembro expulsado'));
    } catch (e) {
      emit(CommunityManagementError('Error kicking member: $e'));
    }
  }

  Future<void> updateNavigationTabs(String communityId, List<CommunityNavigationTab> tabs) async {
    final currentState = state;
    List<CommunityMember> currentMembers = [];
    Community? currentCommunity;

    if (currentState is CommunityManagementLoaded) {
      currentMembers = currentState.members;
      currentCommunity = currentState.community;
    }

    emit(CommunityManagementLoading());

    try {
      await _repository.updateNavigationTabs(communityId, tabs);
      
      // Emit success state for listeners (Snackbar)
      emit(const CommunityNavigationSuccess('Navegación de la comunidad actualizada'));
      
      // Restore loaded state with updated community
      if (currentCommunity != null && currentState is CommunityManagementLoaded) {
        emit(CommunityManagementLoaded(
          members: currentMembers, 
          community: currentCommunity.copyWith(navigationTabs: tabs),
          categories: currentState.categories,
        ));
      }
    } catch (e) {
      emit(CommunityManagementError('Error updating navigation: $e'));
      // Restore previous state if error
      if (currentCommunity != null && currentState is CommunityManagementLoaded) {
        emit(CommunityManagementLoaded(
          members: currentMembers, 
          community: currentCommunity,
          categories: currentState.categories,
        ));
      }
    }
  }

  Future<void> createCategory(String communityId, PostCategory category) async {
    final currentState = state;
    if (currentState is CommunityManagementLoaded) {
      try {
        await _feedRepository.createCategory(communityId, category);
        final categories = await _feedRepository.getCategories(communityId);
        emit(const CommunityManagementSuccess('Categoría creada correctamente'));
        emit(CommunityManagementLoaded(
          members: currentState.members,
          community: currentState.community,
          categories: categories,
        ));
      } catch (e) {
        emit(CommunityManagementError('Error creando categoría: $e'));
      }
    }
  }

  Future<void> updateCategory(String communityId, PostCategory category) async {
    final currentState = state;
    if (currentState is CommunityManagementLoaded) {
      try {
        await _feedRepository.updateCategory(communityId, category);
        final categories = await _feedRepository.getCategories(communityId);
        emit(const CommunityManagementSuccess('Categoría actualizada correctamente'));
        emit(CommunityManagementLoaded(
          members: currentState.members,
          community: currentState.community,
          categories: categories,
        ));
      } catch (e) {
        emit(CommunityManagementError('Error actualizando categoría: $e'));
      }
    }
  }

  Future<void> deleteCategory(String communityId, String categoryId) async {
    final currentState = state;
    if (currentState is CommunityManagementLoaded) {
      try {
        await _feedRepository.deleteCategory(communityId, categoryId);
        final categories = await _feedRepository.getCategories(communityId);
        emit(const CommunityManagementSuccess('Categoría eliminada correctamente'));
        emit(CommunityManagementLoaded(
          members: currentState.members,
          community: currentState.community,
          categories: categories,
        ));
      } catch (e) {
        emit(CommunityManagementError('Error eliminando categoría: $e'));
      }
    }
  }
}
