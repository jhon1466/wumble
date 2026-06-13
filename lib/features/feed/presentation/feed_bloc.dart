import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../domain/post_model.dart';
import '../domain/feed_repository.dart';

// Events
abstract class FeedEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGlobalFeed extends FeedEvent {}

// States
abstract class FeedState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {}
class FeedLoading extends FeedState {}
class FeedLoaded extends FeedState {
  final List<Post> posts;
  FeedLoaded(this.posts);
  @override
  List<Object?> get props => [posts];
}
class FeedError extends FeedState {
  final String message;
  FeedError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final FeedRepository repository;

  FeedBloc({required this.repository}) : super(FeedInitial()) {
    on<LoadGlobalFeed>((event, emit) async {
      emit(FeedLoading());
      try {
        final posts = await repository.getGlobalFeed();
        emit(FeedLoaded(posts));
      } catch (e) {
        emit(FeedError('Error al cargar el muro global: ${e.toString()}'));
      }
    });
  }
}
