import 'package:flutter_bloc/flutter_bloc.dart';
 import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../community/domain/community_model.dart';
import '../../../community/domain/community_repository.dart';
import '../../../profile/domain/user_model.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../domain/post_model.dart';
import '../../domain/feed_repository.dart';

enum SearchType { community, user, universal }

// Events
abstract class SearchEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SearchStarted extends SearchEvent {
  final String query;
  final SearchType searchType;
  SearchStarted({required this.query, required this.searchType});

  @override
  List<Object?> get props => [query, searchType];
}

class SearchTypeToggled extends SearchEvent {
  final SearchType searchType;
  final String query;
  SearchTypeToggled({required this.searchType, required this.query});

  @override
  List<Object?> get props => [searchType, query];
}

class ClearSearch extends SearchEvent {}

// States
abstract class SearchState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchResultsLoaded extends SearchState {
  final List<Community> communities;
  final List<UserProfile> users;
  final SearchType searchType;

  SearchResultsLoaded({
    this.communities = const [],
    this.users = const [],
    required this.searchType,
  });

  @override
  List<Object?> get props => [communities, users, searchType];
}

class SearchError extends SearchState {
  final String message;
  SearchError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class GlobalSearchBloc extends Bloc<SearchEvent, SearchState> {
  final CommunityRepository _communityRepository;
  final ProfileRepository _profileRepository;
  final FeedRepository _feedRepository;

  GlobalSearchBloc({
    required CommunityRepository communityRepository,
    required ProfileRepository profileRepository,
    required FeedRepository feedRepository,
  })  : _communityRepository = communityRepository,
        _profileRepository = profileRepository,
        _feedRepository = feedRepository,
        super(SearchInitial()) {
    on<SearchStarted>(_onSearchStarted);
    on<SearchTypeToggled>(_onSearchTypeToggled);
    on<ClearSearch>((event, emit) => emit(SearchInitial()));
  }

  Future<void> _onSearchStarted(SearchStarted event, Emitter<SearchState> emit) async {
    if (event.query.isEmpty) {
      emit(SearchInitial());
      return;
    }

    emit(SearchLoading());
    try {
      switch (event.searchType) {
        case SearchType.user:
          final users = await _profileRepository.searchUsers(event.query);
          emit(SearchResultsLoaded(users: users, searchType: SearchType.user));
          break;
        case SearchType.community:
          final communities = await _communityRepository.searchCommunities(event.query);
          emit(SearchResultsLoaded(communities: communities, searchType: SearchType.community));
          break;
        case SearchType.universal:
          // Unified search: run both in parallel
          final results = await Future.wait([
            _communityRepository.searchCommunities(event.query),
            _profileRepository.searchUsers(event.query),
          ]);
          emit(SearchResultsLoaded(
            communities: results[0] as List<Community>,
            users: results[1] as List<UserProfile>,
            searchType: SearchType.universal,
          ));
          break;
      }
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }

  Future<void> _onSearchTypeToggled(SearchTypeToggled event, Emitter<SearchState> emit) async {
    add(SearchStarted(query: event.query, searchType: event.searchType));
  }
}
