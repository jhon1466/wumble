import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';

// --- Events ---
abstract class CommunityMembersEvent {}

class LoadInitialMembers extends CommunityMembersEvent {
  final String communityId;
  LoadInitialMembers(this.communityId);
}

class LoadMoreMembers extends CommunityMembersEvent {
  final String communityId;
  LoadMoreMembers(this.communityId);
}

class SearchMembers extends CommunityMembersEvent {
  final String communityId;
  final String query;
  SearchMembers(this.communityId, this.query);
}

class ClearSearch extends CommunityMembersEvent {
  final String communityId;
  ClearSearch(this.communityId);
}

// --- States ---
class CommunityMembersState {
  final List<CommunityMember> members;
  final bool isLoading;
  final bool hasReachedMax;
  final String? error;
  final dynamic lastDocument;
  final bool isSearch;

  CommunityMembersState({
    this.members = const [],
    this.isLoading = false,
    this.hasReachedMax = false,
    this.error,
    this.lastDocument,
    this.isSearch = false,
  });

  CommunityMembersState copyWith({
    List<CommunityMember>? members,
    bool? isLoading,
    bool? hasReachedMax,
    String? error,
    dynamic lastDocument,
    bool? isSearch,
  }) {
    return CommunityMembersState(
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      error: error,
      lastDocument: lastDocument ?? this.lastDocument,
      isSearch: isSearch ?? this.isSearch,
    );
  }
}

// --- BLoC ---
class CommunityMembersBloc extends Bloc<CommunityMembersEvent, CommunityMembersState> {
  final CommunityRepository _repository;

  CommunityMembersBloc({required CommunityRepository repository})
      : _repository = repository,
        super(CommunityMembersState()) {
    on<LoadInitialMembers>(_onLoadInitial);
    on<LoadMoreMembers>(_onLoadMore);
    on<SearchMembers>(_onSearch);
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onLoadInitial(LoadInitialMembers event, Emitter<CommunityMembersState> emit) async {
    emit(state.copyWith(isLoading: true, hasReachedMax: false, members: [], error: null, lastDocument: null, isSearch: false));
    
    try {
      // 1. Fetch Bots (they appear first)
      final bots = await _repository.getCommunityBotsFuture(event.communityId);
      final botMembers = bots.where((b) => b.isActive).map((b) => CommunityMember(
        userId: b.id,
        communityId: event.communityId,
        displayName: b.name,
        avatarUrl: b.avatarUrl,
        joinedAt: b.createdAt,
        isBot: true,
        role: 'bot',
        level: 1,
        reputation: 0,
      )).toList();

      // 2. Fetch Members
      final result = await _repository.getCommunityMembersPaginated(
        event.communityId, 
        limit: 20, 
      );
      final members = result['members'] as List<CommunityMember>;
      final lastDoc = result['lastDocument'];

      // 3. Inject Secure Guard V1 (System Assistant)
      final systemGuard = CommunityMember(
        userId: 'system_secure_guard',
        communityId: event.communityId,
        displayName: 'Secure Guard V1',
        avatarUrl: 'https://www.gstatic.com/images/branding/product/2x/security_shield_48dp.png', // Google Security Shield Icon
        joinedAt: DateTime(2024),
        isBot: true,
        role: 'system',
        level: 99,
        reputation: 9999,
        titles: const [CommunityLabel(text: 'PROTECCIÓN GLOBAL'), CommunityLabel(text: 'SISTEMA')],
      );

      // Combine: System Guard + Active Bots + Members
      final combined = <CommunityMember>[systemGuard, ...botMembers, ...members];

      emit(state.copyWith(
        isLoading: false,
        members: combined,
        hasReachedMax: members.length < 20,
        lastDocument: lastDoc,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadMore(LoadMoreMembers event, Emitter<CommunityMembersState> emit) async {
    if (state.hasReachedMax || state.isLoading || state.isSearch) return;

    emit(state.copyWith(isLoading: true));

    try {
      final result = await _repository.getCommunityMembersPaginated(
        event.communityId,
        lastDocument: state.lastDocument,
        limit: 20,
      );
      
      final newMembers = result['members'] as List<CommunityMember>;
      final lastDoc = result['lastDocument'];

      emit(state.copyWith(
        isLoading: false,
        members: List.of(state.members)..addAll(newMembers),
        hasReachedMax: newMembers.isEmpty || newMembers.length < 20,
        lastDocument: lastDoc,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSearch(SearchMembers event, Emitter<CommunityMembersState> emit) async {
    if (event.query.isEmpty) {
      add(ClearSearch(event.communityId));
      return;
    }

    emit(state.copyWith(isLoading: true, isSearch: true, error: null));

    try {
      final members = await _repository.searchCommunityMembers(event.communityId, event.query);
      
      // Also search through bots
      final bots = await _repository.getCommunityBotsFuture(event.communityId);
      final botResults = bots
          .where((b) => b.isActive && b.name.toLowerCase().contains(event.query.toLowerCase()))
          .map((b) => CommunityMember(
            userId: b.id,
            communityId: event.communityId,
            displayName: b.name,
            avatarUrl: b.avatarUrl,
            joinedAt: b.createdAt,
            isBot: true,
            role: 'bot',
          ))
          .toList();
      
      // Inject System Guard if query matches
      final List<CommunityMember> systemResults = [];
      if ('secure guard v1'.contains(event.query.toLowerCase()) || 'sistema'.contains(event.query.toLowerCase())) {
        systemResults.add(CommunityMember(
          userId: 'system_secure_guard',
          communityId: event.communityId,
          displayName: 'Secure Guard V1',
          avatarUrl: 'https://www.gstatic.com/images/branding/product/2x/security_shield_48dp.png', // Google Security Shield Icon
          joinedAt: DateTime(2024),
          isBot: true,
          role: 'system',
          level: 99,
          titles: const [CommunityLabel(text: 'PROTECCIÓN GLOBAL'), CommunityLabel(text: 'SISTEMA')],
        ));
      }

      emit(state.copyWith(
        isLoading: false,
        members: <CommunityMember>[...systemResults, ...botResults, ...members],
        hasReachedMax: true,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onClearSearch(ClearSearch event, Emitter<CommunityMembersState> emit) async {
    if (!state.isSearch) return;
    add(LoadInitialMembers(event.communityId));
  }
}
