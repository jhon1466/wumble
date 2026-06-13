import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/community_model.dart';
import '../../domain/community_repository.dart';

// Events
abstract class CommunityEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCommunities extends CommunityEvent {
  final String? category;
  LoadCommunities({this.category});
}

class LoadUserCommunities extends CommunityEvent {
  final String userId;
  LoadUserCommunities(this.userId);

  @override
  List<Object?> get props => [userId];
}

class SearchCommunities extends CommunityEvent {
  final String query;
  SearchCommunities(this.query);
}

class CreateCommunity extends CommunityEvent {
  final Community community;
  final File? icon;
  final File? banner;
  final File? background;

  CreateCommunity({
    required this.community,
    required this.icon,
    required this.banner,
    this.background,
  });
}

class UpdateCommunity extends CommunityEvent {
  final String communityId;
  final Map<String, dynamic> updates;
  final File? icon;
  final File? banner;
  final File? background;

  UpdateCommunity({
    required this.communityId,
    required this.updates,
    this.icon,
    this.banner,
    this.background,
  });

  @override
  List<Object?> get props => [communityId, updates, icon, banner, background];
}

class UpdateMemberProfile extends CommunityEvent {
  final String communityId;
  final String userId;
  final Map<String, dynamic> updates;
  final File? avatar;

  UpdateMemberProfile({
    required this.communityId,
    required this.userId,
    required this.updates,
    this.avatar,
  });

  @override
  List<Object?> get props => [communityId, userId, updates, avatar];
}

class LeaveCommunityEvent extends CommunityEvent {
  final String communityId;
  final String userId;

  LeaveCommunityEvent({required this.communityId, required this.userId});

  @override
  List<Object?> get props => [communityId, userId];
}

class DeleteCommunityEvent extends CommunityEvent {
  final String communityId;

  DeleteCommunityEvent({required this.communityId});

  @override
  List<Object?> get props => [communityId];
}

class ToggleCommunityNotifications extends CommunityEvent {
  final String communityId;
  final String userId;
  final bool mute;

  ToggleCommunityNotifications({
    required this.communityId,
    required this.userId,
    required this.mute,
  });

  @override
  List<Object?> get props => [communityId, userId, mute];
}

// States
abstract class CommunityState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CommunityInitial extends CommunityState {}

class CommunityLoading extends CommunityState {}

class CommunityCreating extends CommunityState {}

class CommunityUpdating extends CommunityState {}

class CommunityLoaded extends CommunityState {
  final List<Community> communities;
  final String? activeCategory;

  CommunityLoaded({required this.communities, this.activeCategory});

  @override
  List<Object?> get props => [communities, activeCategory];
}

class CommunityCreated extends CommunityState {
  final Community community;
  CommunityCreated(this.community);

  @override
  List<Object?> get props => [community];
}

class CommunityUpdated extends CommunityState {}

class CommunityLeft extends CommunityState {}

class CommunityDeletedState extends CommunityState {}

class CommunityError extends CommunityState {
  final String message;
  CommunityError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  final CommunityRepository _repository;
  String? _currentUserId;

  CommunityBloc({required CommunityRepository repository})
      : _repository = repository,
        super(CommunityInitial()) {
    on<LoadCommunities>(_onLoadCommunities);
    on<LoadUserCommunities>(_onLoadUserCommunities);
    on<SearchCommunities>(_onSearchCommunities);
    on<CreateCommunity>(_onCreateCommunity);
    on<UpdateCommunity>(_onUpdateCommunity);
    on<UpdateMemberProfile>(_onUpdateMemberProfile);
    on<LeaveCommunityEvent>(_onLeaveCommunity);
    on<DeleteCommunityEvent>(_onDeleteCommunity);
    on<ToggleCommunityNotifications>(_onToggleNotifications);
  }

  Future<void> _onLoadCommunities(LoadCommunities event, Emitter<CommunityState> emit) async {
    _currentUserId = null;
    emit(CommunityLoading());
    try {
      List<Community> communities;
      if (event.category != null) {
        communities = await _repository.getCommunitiesByCategory(event.category!);
      } else {
        communities = await _repository.getCommunities();
      }
      emit(CommunityLoaded(communities: communities, activeCategory: event.category));
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onLoadUserCommunities(LoadUserCommunities event, Emitter<CommunityState> emit) async {
    _currentUserId = event.userId;
    emit(CommunityLoading());
    try {
      final communities = await _repository.getUserCommunities(event.userId);
      emit(CommunityLoaded(communities: communities));
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onSearchCommunities(SearchCommunities event, Emitter<CommunityState> emit) async {
    emit(CommunityLoading());
    try {
      final communities = await _repository.searchCommunities(event.query);
      emit(CommunityLoaded(communities: communities));
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onCreateCommunity(CreateCommunity event, Emitter<CommunityState> emit) async {
    emit(CommunityCreating());
    try {
      final newCommunity = await _repository.createCommunity(event.community, event.icon, event.banner, event.background);
      emit(CommunityCreated(newCommunity));
      // Reload list after creation
      if (_currentUserId != null) {
        add(LoadUserCommunities(_currentUserId!));
      } else {
        add(LoadCommunities());
      }
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onUpdateCommunity(UpdateCommunity event, Emitter<CommunityState> emit) async {
    emit(CommunityUpdating());
    try {
      await _repository.updateCommunity(
        event.communityId, 
        event.updates, 
        event.icon, 
        event.banner, 
        event.background
      );
      emit(CommunityUpdated());
      if (_currentUserId != null) {
        add(LoadUserCommunities(_currentUserId!));
      } else {
        add(LoadCommunities());
      }
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onUpdateMemberProfile(UpdateMemberProfile event, Emitter<CommunityState> emit) async {
    emit(CommunityUpdating());
    try {
      await _repository.updateMemberProfile(
        event.communityId, 
        event.userId, 
        event.updates, 
        event.avatar
      );
      emit(CommunityUpdated());
      // No necesitamos recargar todas las comunidades, pero tal vez el perfil del contexto?
      // Por ahora emitimos éxito.
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onLeaveCommunity(LeaveCommunityEvent event, Emitter<CommunityState> emit) async {
    emit(CommunityUpdating());
    try {
      await _repository.leaveCommunity(event.communityId, event.userId);
      emit(CommunityLeft()); 
      if (_currentUserId != null) {
        add(LoadUserCommunities(_currentUserId!));
      } else {
        add(LoadCommunities());
      }
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onDeleteCommunity(DeleteCommunityEvent event, Emitter<CommunityState> emit) async {
    emit(CommunityUpdating());
    try {
      await _repository.deleteCommunity(event.communityId);
      emit(CommunityDeletedState());
      if (_currentUserId != null) {
        add(LoadUserCommunities(_currentUserId!));
      } else {
        add(LoadCommunities());
      }
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }

  Future<void> _onToggleNotifications(ToggleCommunityNotifications event, Emitter<CommunityState> emit) async {
    try {
      await _repository.toggleCommunityNotifications(event.communityId, event.userId, event.mute);
      // We don't necessarily need to emit a new state here if we want it to be silent,
      // but emitting CommunityUpdated helps the UI know it can show a success message.
      emit(CommunityUpdated());
    } catch (e) {
      emit(CommunityError(e.toString()));
    }
  }
}
