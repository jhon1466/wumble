import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/notification_repository.dart';

// --- Events ---
abstract class NotificationCountEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SubscribeToCounts extends NotificationCountEvent {
  final String userId;
  SubscribeToCounts(this.userId);
  @override
  List<Object?> get props => [userId];
}

class _UpdateCounts extends NotificationCountEvent {
  final int totalCount;
  final int chatCount;
  final Map<String, int> communityCounts;
  _UpdateCounts({required this.totalCount, required this.chatCount, required this.communityCounts});
  @override
  List<Object?> get props => [totalCount, chatCount, communityCounts];
}

// --- State ---
class NotificationCountState extends Equatable {
  final int totalUnreadCount;
  final int chatUnreadCount;
  final Map<String, int> communityUnreadCounts;

  const NotificationCountState({
    this.totalUnreadCount = 0,
    this.chatUnreadCount = 0,
    this.communityUnreadCounts = const {},
  });

  @override
  List<Object?> get props => [totalUnreadCount, chatUnreadCount, communityUnreadCounts];
}

// --- BLoC ---
class NotificationCountBloc extends Bloc<NotificationCountEvent, NotificationCountState> {
  final NotificationRepository _repository;
  StreamSubscription? _totalSub;
  StreamSubscription? _chatSub;
  StreamSubscription? _communitySub;

  NotificationCountBloc({required NotificationRepository repository})
      : _repository = repository,
        super(const NotificationCountState()) {
    
    on<SubscribeToCounts>((event, emit) {
      _totalSub?.cancel();
      _chatSub?.cancel();
      _communitySub?.cancel();

      int currentTotal = state.totalUnreadCount;
      int currentChat = state.chatUnreadCount;
      Map<String, int> currentCommunity = state.communityUnreadCounts;

      _totalSub = _repository.getUnreadCount(event.userId).listen((count) {
        currentTotal = count;
        add(_UpdateCounts(totalCount: currentTotal, chatCount: currentChat, communityCounts: currentCommunity));
      });

      _chatSub = _repository.getUnreadChatCount(event.userId).listen((count) {
        currentChat = count;
        add(_UpdateCounts(totalCount: currentTotal, chatCount: currentChat, communityCounts: currentCommunity));
      });

      _communitySub = _repository.getCommunityUnreadCounts(event.userId).listen((counts) {
        currentCommunity = counts;
        add(_UpdateCounts(totalCount: currentTotal, chatCount: currentChat, communityCounts: currentCommunity));
      });
    });

    on<_UpdateCounts>((event, emit) {
      emit(NotificationCountState(
        totalUnreadCount: event.totalCount,
        chatUnreadCount: event.chatCount,
        communityUnreadCounts: event.communityCounts,
      ));
    });
  }

  @override
  Future<void> close() {
    _totalSub?.cancel();
    _chatSub?.cancel();
    _communitySub?.cancel();
    return super.close();
  }
}
