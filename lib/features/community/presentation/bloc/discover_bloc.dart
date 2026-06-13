import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/community_model.dart';
import '../../domain/community_repository.dart';

// Eventos
abstract class DiscoverEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDiscoverCommunities extends DiscoverEvent {
  final String? category;
  LoadDiscoverCommunities({this.category});

  @override
  List<Object?> get props => [category];
}

class SearchDiscoverCommunities extends DiscoverEvent {
  final String query;
  SearchDiscoverCommunities(this.query);

  @override
  List<Object?> get props => [query];
}

class LoadMoreDiscoverCommunities extends DiscoverEvent {}

// Estados
abstract class DiscoverState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DiscoverInitial extends DiscoverState {}
class DiscoverLoading extends DiscoverState {}
class DiscoverLoaded extends DiscoverState {
  final List<Community> communities;
  final List<Community> featuredCommunities;
  final List<Community> trendingCommunities;
  final List<Community> newCommunities;
  final String? activeCategory;
  final dynamic lastDocument;
  final bool hasMore;
  final bool isLoadingMore;

  DiscoverLoaded({
    required this.communities, 
    this.featuredCommunities = const [],
    this.trendingCommunities = const [],
    this.newCommunities = const [], 
    this.activeCategory,
    this.lastDocument,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  DiscoverLoaded copyWith({
    List<Community>? communities,
    List<Community>? featuredCommunities,
    List<Community>? trendingCommunities,
    List<Community>? newCommunities,
    String? activeCategory,
    dynamic lastDocument,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return DiscoverLoaded(
      communities: communities ?? this.communities,
      featuredCommunities: featuredCommunities ?? this.featuredCommunities,
      trendingCommunities: trendingCommunities ?? this.trendingCommunities,
      newCommunities: newCommunities ?? this.newCommunities,
      activeCategory: activeCategory ?? this.activeCategory,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    communities, 
    featuredCommunities, 
    trendingCommunities, 
    newCommunities, 
    activeCategory, 
    lastDocument, 
    hasMore, 
    isLoadingMore
  ];
}

class DiscoverError extends DiscoverState {
  final String message;
  DiscoverError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  final CommunityRepository _repository;

  DiscoverBloc({required CommunityRepository repository})
      : _repository = repository,
        super(DiscoverInitial()) {
    on<LoadDiscoverCommunities>(_onLoadDiscoverCommunities);
    on<SearchDiscoverCommunities>(_onSearchDiscoverCommunities);
    on<LoadMoreDiscoverCommunities>(_onLoadMoreDiscoverCommunities);
  }

  Future<void> _onLoadDiscoverCommunities(LoadDiscoverCommunities event, Emitter<DiscoverState> emit) async {
    emit(DiscoverLoading());
    try {
      List<Community> communities = [];
      List<Community> featured = [];
      List<Community> trending = [];
      List<Community> newItem = [];
      dynamic lastDoc;
      
      if (event.category != null) {
        final result = await _repository.getCommunitiesPaginated(category: event.category, limit: 12);
        communities = result['communities'];
        lastDoc = result['lastDocument'];
      } else {
        // Parallel load for efficiency
        final results = await Future.wait([
          _repository.getFeaturedCommunities(),
          _repository.getTrendingCommunities(),
          _repository.getNewCommunities(),
          _repository.getCommunitiesPaginated(limit: 12),
        ]);
        
        featured = results[0] as List<Community>;
        
        // Trending: filter out those already in featured
        final rawTrending = results[1] as List<Community>;
        trending = rawTrending.where((t) => !featured.any((f) => f.id == t.id)).toList();
        
        // New: Don't deduplicate for now as user wants them always visible and replacing
        newItem = results[2] as List<Community>;
        
        final paginatedResult = results[3] as Map<String, dynamic>;
        communities = paginatedResult['communities'];
        lastDoc = paginatedResult['lastDocument'];
      }

      emit(DiscoverLoaded(
        communities: communities, 
        featuredCommunities: featured,
        trendingCommunities: trending,
        newCommunities: newItem,
        activeCategory: event.category,
        lastDocument: lastDoc,
        hasMore: communities.length >= 12,
      ));
    } catch (e) {
      emit(DiscoverError(e.toString()));
    }
  }

  Future<void> _onLoadMoreDiscoverCommunities(LoadMoreDiscoverCommunities event, Emitter<DiscoverState> emit) async {
    final state = this.state;
    if (state is! DiscoverLoaded || state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));
    
    try {
      final result = await _repository.getCommunitiesPaginated(
        category: state.activeCategory,
        lastDocument: state.lastDocument,
        limit: 12,
      );
      
      final List<Community> newItems = result['communities'];
      final lastDoc = result['lastDocument'];
      
      emit(state.copyWith(
        communities: List.from(state.communities)..addAll(newItems),
        lastDocument: lastDoc,
        hasMore: newItems.length >= 12,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSearchDiscoverCommunities(SearchDiscoverCommunities event, Emitter<DiscoverState> emit) async {
    emit(DiscoverLoading());
    try {
      final communities = await _repository.searchCommunities(event.query);
      emit(DiscoverLoaded(communities: communities));
    } catch (e) {
      emit(DiscoverError(e.toString()));
    }
  }
}
