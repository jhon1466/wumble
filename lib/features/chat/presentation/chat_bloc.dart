import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../domain/chat_model.dart';
import '../domain/chat_repository.dart';

// ──── Events ────

abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadChatRooms extends ChatEvent {
  final String userId;
  LoadChatRooms(this.userId);
  @override
  List<Object?> get props => [userId];
}

class LoadMessages extends ChatEvent {
  final String chatRoomId;
  LoadMessages(this.chatRoomId);
  @override
  List<Object?> get props => [chatRoomId];
}

class SendMessageEvent extends ChatEvent {
  final String chatRoomId;
  final ChatMessage message;
  SendMessageEvent({required this.chatRoomId, required this.message});
  @override
  List<Object?> get props => [chatRoomId, message];
}

class DeleteMessageEvent extends ChatEvent {
  final String chatRoomId;
  final String messageId;
  DeleteMessageEvent({required this.chatRoomId, required this.messageId});
  @override
  List<Object?> get props => [chatRoomId, messageId];
}

class EditMessageEvent extends ChatEvent {
  final String chatRoomId;
  final String messageId;
  final String newText;
  EditMessageEvent({required this.chatRoomId, required this.messageId, required this.newText});
  @override
  List<Object?> get props => [chatRoomId, messageId, newText];
}

class ClearChatEvent extends ChatEvent {
  final String chatRoomId;
  ClearChatEvent({required this.chatRoomId});
  @override
  List<Object?> get props => [chatRoomId];
}

class UpdateChatBackgroundEvent extends ChatEvent {
  final String chatRoomId;
  final String? imageUrl;
  UpdateChatBackgroundEvent({required this.chatRoomId, this.imageUrl});
  @override
  List<Object?> get props => [chatRoomId, imageUrl];
}

class DeleteChatRoomEvent extends ChatEvent {
  final String chatRoomId;
  DeleteChatRoomEvent(this.chatRoomId);
  @override
  List<Object?> get props => [chatRoomId];
}

class LeaveChatEvent extends ChatEvent {
  final String chatRoomId;
  final String userId;
  final String username;
  LeaveChatEvent({required this.chatRoomId, required this.userId, required this.username});
  @override
  List<Object?> get props => [chatRoomId, userId, username];
}

class AcceptChatRequestEvent extends ChatEvent {
  final String chatRoomId;
  final String userId;
  final String username;
  AcceptChatRequestEvent({required this.chatRoomId, required this.userId, required this.username});
  @override
  List<Object?> get props => [chatRoomId, userId, username];
}

class RejectChatRequestEvent extends ChatEvent {
  final String chatRoomId;
  final String userId;
  RejectChatRequestEvent({required this.chatRoomId, required this.userId});
  @override
  List<Object?> get props => [chatRoomId, userId];
}

class LoadOlderMessages extends ChatEvent {
  final String chatRoomId;
  final DateTime beforeTimestamp;
  LoadOlderMessages({required this.chatRoomId, required this.beforeTimestamp});
  @override
  List<Object?> get props => [chatRoomId, beforeTimestamp];
}

class EditChatRoomEvent extends ChatEvent {
  final String chatRoomId;
  final String? title;
  final String? description;
  final String? imageUrl;
  
  EditChatRoomEvent({
    required this.chatRoomId,
    this.title,
    this.description,
    this.imageUrl,
  });
  
  @override
  List<Object?> get props => [chatRoomId, title, description, imageUrl];
}

class JoinPublicChatEvent extends ChatEvent {
  final String chatRoomId;
  final String userId;
  final String username;
  final String userAvatar;
  JoinPublicChatEvent({
    required this.chatRoomId,
    required this.userId,
    required this.username,
    required this.userAvatar,
  });
  @override
  List<Object?> get props => [chatRoomId, userId, username, userAvatar];
}

// ──── States ────

abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}

class ChatRoomsLoaded extends ChatState {
  final List<ChatRoom> rooms;
  const ChatRoomsLoaded(this.rooms);
  @override
  List<Object?> get props => [rooms];
}

class MessagesLoaded extends ChatState {
  final List<ChatMessage> messages;
  /// Whether there are older messages to load (scroll-up pagination)
  final bool hasMore;
  /// Whether a load-older request is in flight
  final bool isLoadingOlder;

  const MessagesLoaded(
    this.messages, {
    this.hasMore = true,
    this.isLoadingOlder = false,
  });

  MessagesLoaded copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? isLoadingOlder,
  }) {
    return MessagesLoaded(
      messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    );
  }

  @override
  List<Object?> get props => [messages, hasMore, isLoadingOlder];
}

class MessageSent extends ChatState {}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);
  @override
  List<Object?> get props => [message];
}

// ──── BLoC ────

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;

  ChatBloc({required ChatRepository repository})
      : _repository = repository,
        super(ChatInitial()) {

    on<LoadChatRooms>((event, emit) async {
      emit(ChatLoading());
      try {
        await emit.forEach(
          _repository.getChatRooms(event.userId),
          onData: (rooms) => ChatRoomsLoaded(rooms),
          onError: (e, _) => ChatError(e.toString()),
        );
      } catch (e) {
        emit(ChatError(e.toString()));
      }
    });

    on<LoadMessages>((event, emit) async {
      emit(ChatLoading());
      // Accumulate older messages prepended before stream messages
      List<ChatMessage> olderMessages = [];
      try {
        await emit.forEach(
          _repository.getMessages(event.chatRoomId),
          onData: (streamMessages) {
            final seen = <String>{};
            final merged = <ChatMessage>[...olderMessages, ...streamMessages]
                .where((m) => m.id.isEmpty || seen.add(m.id))
                .toList();
            // Sort Descending (Newest first) for reverse:true ListView
            merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            return MessagesLoaded(merged, hasMore: true);
          },
          onError: (e, _) => ChatError(e.toString()),
        );
      } catch (e) {
        emit(ChatError(e.toString()));
      }
    });

    on<LoadOlderMessages>((event, emit) async {
      final current = state;
      if (current is! MessagesLoaded) return;
      if (current.isLoadingOlder) return;

      emit(current.copyWith(isLoadingOlder: true));
      try {
        final older = await _repository.getMessagesBefore(
          event.chatRoomId,
          beforeTimestamp: event.beforeTimestamp,
        );

        final seen = <String>{};
        final merged = <ChatMessage>[...older, ...current.messages]
            .where((m) => m.id.isEmpty || seen.add(m.id))
            .toList();
        // Sort Descending (Newest first)
        merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        emit(current.copyWith(
          messages: merged,
          hasMore: older.length >= 30,
          isLoadingOlder: false,
        ));
      } catch (e) {
        emit(current.copyWith(isLoadingOlder: false));
      }
    });

    on<SendMessageEvent>((event, emit) async {
      try {
        await _repository.sendMessage(event.chatRoomId, event.message);
      } catch (e) {
        emit(ChatError('Error al enviar mensaje: ${e.toString()}'));
      }
    });

    on<DeleteMessageEvent>((event, emit) async {
      try {
        await _repository.deleteMessage(event.chatRoomId, event.messageId);
      } catch (e) {
        emit(ChatError('Error al eliminar mensaje: ${e.toString()}'));
      }
    });

    on<EditMessageEvent>((event, emit) async {
      try {
        await _repository.editMessage(event.chatRoomId, event.messageId, event.newText);
      } catch (e) {
        emit(ChatError('Error al editar mensaje: ${e.toString()}'));
      }
    });

    on<ClearChatEvent>((event, emit) async {
      try {
        await _repository.clearChat(event.chatRoomId);
      } catch (e) {
        emit(ChatError('Error al vaciar chat: ${e.toString()}'));
      }
    });

    on<UpdateChatBackgroundEvent>((event, emit) async {
      try {
        await _repository.updateChatBackground(event.chatRoomId, event.imageUrl);
      } catch (e) {
        emit(ChatError('Error al cambiar fondo: ${e.toString()}'));
      }
    });

    on<DeleteChatRoomEvent>((event, emit) async {
      try {
        await _repository.deleteChatRoom(event.chatRoomId);
      } catch (e) {
        emit(ChatError('Error al eliminar chat: ${e.toString()}'));
      }
    });

    on<LeaveChatEvent>((event, emit) async {
      try {
        await _repository.leaveChat(event.chatRoomId, event.userId, event.username);
      } catch (e) {
        emit(ChatError('Error al abandonar chat: ${e.toString()}'));
      }
    });

    on<AcceptChatRequestEvent>((event, emit) async {
      try {
        await _repository.acceptChatRequest(event.chatRoomId, event.userId, event.username);
      } catch (e) {
        emit(ChatError('Error al aceptar chat: ${e.toString()}'));
      }
    });

    on<RejectChatRequestEvent>((event, emit) async {
      try {
        await _repository.rejectChatRequest(event.chatRoomId, event.userId);
      } catch (e) {
        emit(ChatError('Error al rechazar chat: ${e.toString()}'));
      }
    });

    on<EditChatRoomEvent>((event, emit) async {
      try {
        await _repository.updateChatRoom(
          event.chatRoomId,
          title: event.title,
          description: event.description,
          imageUrl: event.imageUrl,
        );
      } catch (e) {
        emit(ChatError('Error al editar chat: ${e.toString()}'));
      }
    });

    on<JoinPublicChatEvent>((event, emit) async {
      try {
        await _repository.joinPublicChat(
          chatRoomId: event.chatRoomId,
          userId: event.userId,
          username: event.username,
          userAvatar: event.userAvatar,
        );
      } catch (e) {
        emit(ChatError('Error al unirse al chat: ${e.toString()}'));
      }
    });
  }
}
