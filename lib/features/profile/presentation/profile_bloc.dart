import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/community/domain/community_member_model.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/chat/domain/chat_model.dart';
import 'package:wumble/features/moderation/domain/moderation_models.dart';
import 'package:wumble/features/moderation/domain/moderation_repository.dart';
import 'package:wumble/core/services/notification_service.dart';

// Events
abstract class ProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ResetProfile extends ProfileEvent {}

class LoadProfileRequested extends ProfileEvent {
  final String userId;
  final String? communityId;
  LoadProfileRequested(this.userId, {this.communityId});
  @override
  List<Object?> get props => [userId, communityId];
}

class UpdateProfileRequested extends ProfileEvent {
  final String userId;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? avatarPath;
  final String? bannerPath;
  final String? backgroundPath;
  final String? status;
  final String? statusEmoji;
  final bool? isOnline;
  final String? communityId;
  final bool? isProfileComplete;
  final List<CommunityLabel>? titles;
  final int? themeColorValue;
  final List<String>? socialLinks;
  final bool? showFollows;
  final ChatBubbleStyle? chatBubbleStyle;
  final DateTime? birthday;
  final String? wallPrivacy;
  final String? chatInvitePrivacy;
  final bool? isBot;
  final double? bannerAlignmentY;

  UpdateProfileRequested({
    required this.userId,
    this.username,
    this.displayName,
    this.bio,
    this.avatarPath,
    this.bannerPath,
    this.backgroundPath,
    this.status,
    this.statusEmoji,
    this.isOnline,
    this.isProfileComplete,
    this.communityId,
    this.titles,
    this.themeColorValue,
    this.socialLinks,
    this.showFollows,
    this.chatBubbleStyle,
    this.birthday,
    this.wallPrivacy,
    this.chatInvitePrivacy,
    this.isBot,
    this.bannerAlignmentY,
  });

  @override
  List<Object?> get props => [
        userId,
        username,
        displayName,
        bio,
        avatarPath,
        bannerPath,
        backgroundPath,
        status,
        statusEmoji,
        isOnline,
        isProfileComplete,
        communityId,
        titles,
        themeColorValue,
        socialLinks,
        showFollows,
        chatBubbleStyle,
        birthday,
        wallPrivacy,
        chatInvitePrivacy,
        isBot,
        bannerAlignmentY,
      ];
}

class FollowUserRequested extends ProfileEvent {
  final String currentUserId;
  final String targetUserId;
  FollowUserRequested({required this.currentUserId, required this.targetUserId});
  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class UnfollowUserRequested extends ProfileEvent {
  final String currentUserId;
  final String targetUserId;
  UnfollowUserRequested({required this.currentUserId, required this.targetUserId});
  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class CheckFollowStatus extends ProfileEvent {
  final String currentUserId;
  final String targetUserId;
  CheckFollowStatus({required this.currentUserId, required this.targetUserId});
  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class BlockUserRequested extends ProfileEvent {
  final String currentUserId;
  final String targetUserId;
  BlockUserRequested({required this.currentUserId, required this.targetUserId});
  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class ReportUserRequested extends ProfileEvent {
  final String reporterId;
  final String targetUserId;
  final String reason;
  final String? communityId;
  ReportUserRequested({
    required this.reporterId,
    required this.targetUserId,
    required this.reason,
    this.communityId,
  });
  @override
  List<Object?> get props => [reporterId, targetUserId, reason, communityId];
}

class LoadSanctionsRequested extends ProfileEvent {
  final String userId;
  final String? communityId;
  LoadSanctionsRequested(this.userId, {this.communityId});
  @override
  List<Object?> get props => [userId, communityId];
}

class UpdateEmailRequested extends ProfileEvent {
  final String newEmail;
  final String password;
  UpdateEmailRequested({required this.newEmail, required this.password});
  @override
  List<Object?> get props => [newEmail, password];
}

class UpdatePasswordRequested extends ProfileEvent {
  final String oldPassword;
  final String newPassword;
  UpdatePasswordRequested({required this.oldPassword, required this.newPassword});
  @override
  List<Object?> get props => [oldPassword, newPassword];
}

class DeleteAccountRequested extends ProfileEvent {
  final String password;
  DeleteAccountRequested({required this.password});
  @override
  List<Object?> get props => [password];
}

class UpdateSettingsRequested extends ProfileEvent {
  final String userId;
  final Map<String, dynamic> settings;
  UpdateSettingsRequested({required this.userId, required this.settings});
  @override
  List<Object?> get props => [userId, settings];
}

class UnblockUserRequested extends ProfileEvent {
  final String currentUserId;
  final String targetUserId;
  UnblockUserRequested({required this.currentUserId, required this.targetUserId});
  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class PerformCheckInRequested extends ProfileEvent {
  final String userId;
  PerformCheckInRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}

class PurchaseFrameRequested extends ProfileEvent {
  final String userId;
  final String frameUrl;
  final int price;
  PurchaseFrameRequested(this.userId, this.frameUrl, this.price);
  @override
  List<Object?> get props => [userId, frameUrl, price];
}

class PurchasePackRequested extends ProfileEvent {
  final String userId;
  final String packId;
  PurchasePackRequested(this.userId, this.packId);
  @override
  List<Object?> get props => [userId, packId];
}

class EquipFrameRequested extends ProfileEvent {
  final String userId;
  final String? frameUrl;
  EquipFrameRequested(this.userId, this.frameUrl);
  @override
  List<Object?> get props => [userId, frameUrl];
}


// States
abstract class ProfileState extends Equatable {
  const ProfileState();
  
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded extends ProfileState {
  final UserProfile user;
  final String? communityId;
  final bool isGlobal;
  final List<Sanction> sanctions;

  const ProfileLoaded(this.user, {this.communityId, this.isGlobal = false, this.sanctions = const []});

  @override
  List<Object?> get props => [user, communityId, isGlobal, sanctions];
}

class ProfileUpdateInProgress extends ProfileState {
  final double progress;
  final UserProfile? user;
  final bool isGlobal;
  const ProfileUpdateInProgress({this.progress = 0.0, this.user, this.isGlobal = false});
  @override
  List<Object?> get props => [progress, user, isGlobal];
}
class ProfileUpdateSuccess extends ProfileState {
  final UserProfile user;
  final String? communityId;
  final bool isGlobal;
  final List<Sanction> sanctions;

  const ProfileUpdateSuccess(this.user, {this.communityId, this.isGlobal = false, this.sanctions = const []});

  @override
  List<Object?> get props => [user, communityId, isGlobal, sanctions];
}
class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object?> get props => [message];
}
class FollowStatusLoaded extends ProfileState {
  final bool isFollowing;
  const FollowStatusLoaded(this.isFollowing);
  @override
  List<Object?> get props => [isFollowing];
}

class ProfileActionSuccess extends ProfileState {
  final String message;
  final bool isPurchase;
  const ProfileActionSuccess(this.message, {this.isPurchase = false});
  @override
  List<Object?> get props => [message, isPurchase];
}

// BLoC
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;
  final ModerationRepository _moderationRepository;
  final CommunityRepository _communityRepository;
  StreamSubscription? _sanctionsSub;

  ProfileBloc({
    required ProfileRepository profileRepository,
    required ModerationRepository moderationRepository,
    required CommunityRepository communityRepository,
  })  : _profileRepository = profileRepository,
        _moderationRepository = moderationRepository,
        _communityRepository = communityRepository,
        super(ProfileInitial()) {
    on<LoadProfileRequested>((event, emit) async {
      emit(ProfileLoading());
      
      final controller = StreamController<UserProfile>();
      UserProfile? lastUser;
      CommunityMember? lastMember;

      void pushUpdate() {
        if (lastUser != null) {
          var user = lastUser!;
          if (event.communityId != null && lastMember != null) {
            user = user.copyWith(
              displayName: (lastMember!.displayName != null && lastMember!.displayName!.isNotEmpty) 
                  ? lastMember!.displayName : user.displayName,
              avatarUrl: (lastMember!.avatarUrl != null && lastMember!.avatarUrl!.isNotEmpty) 
                  ? lastMember!.avatarUrl : user.avatarUrl,
              bannerUrl: (lastMember!.bannerUrl != null && lastMember!.bannerUrl!.isNotEmpty) 
                  ? lastMember!.bannerUrl : user.bannerUrl,
              backgroundUrl: (lastMember!.backgroundUrl != null && lastMember!.backgroundUrl!.isNotEmpty) 
                  ? lastMember!.backgroundUrl : user.backgroundUrl,
              bio: (lastMember!.bio != null && lastMember!.bio!.isNotEmpty) 
                  ? lastMember!.bio : user.bio,
              status: lastMember!.status ?? user.status,
              reputation: lastMember!.reputation,
              level: lastMember!.level,
              titles: lastMember!.titles.isNotEmpty ? lastMember!.titles : user.titles,
              themeColorValue: lastMember!.themeColorValue ?? user.themeColorValue,
              showFollows: lastMember!.showFollows,
              chatBubbleStyle: lastMember!.chatBubbleStyle ?? user.chatBubbleStyle,
              communityRole: lastMember!.role,
            );
          }
          if (!controller.isClosed) {
            controller.add(user);
          }
        }
      }

      final globalSub = _profileRepository.getUserProfile(event.userId).listen(
        (user) {
          lastUser = user;
          pushUpdate();
        },
        onError: (e) => controller.addError(e),
      );

      StreamSubscription? memberSub;
      if (event.communityId != null) {
        memberSub = _profileRepository.getMemberProfileStream(event.communityId!, event.userId).listen(
          (member) {
            lastMember = member;
            pushUpdate();
          },
          onError: (e) => controller.addError(e),
        );
      }

      try {
        await emit.forEach<UserProfile>(
          controller.stream,
          onData: (user) {
            final currentSanctions = (state is ProfileLoaded) ? (state as ProfileLoaded).sanctions : <Sanction>[];
            return ProfileLoaded(
              user, 
              communityId: event.communityId, 
              isGlobal: event.communityId == null,
              sanctions: currentSanctions,
            );
          },
          onError: (e, stack) => ProfileError(e.toString()),
        );
      } finally {
        await globalSub.cancel();
        await memberSub?.cancel();
        await controller.close();
      }
    });

    on<LoadSanctionsRequested>((event, emit) async {
      await _sanctionsSub?.cancel();

      // Combinar sanciones globales y locales
      final globalStream = _moderationRepository.getUserSanctions(event.userId);
      final localStream = event.communityId != null 
          ? _communityRepository.getMemberSanctions(event.communityId!, event.userId)
          : Stream.value(<Sanction>[]);

      _sanctionsSub = Rx.combineLatest2<List<Sanction>, List<Sanction>, List<Sanction>>(
        globalStream,
        localStream,
        (global, local) {
          final all = [...global, ...local];
          all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return all;
        },
      ).listen(
        (combined) {
          add(_UpdateSanctionsInternal(combined));
        },
        onError: (e) {
          debugPrint('Error loading sanctions: $e');
          add(_UpdateSanctionsInternal([]));
        },
      );
    });

    on<_UpdateSanctionsInternal>((event, emit) {
      final current = state;
      if (current is ProfileLoaded) {
        emit(ProfileLoaded(
          current.user,
          communityId: current.communityId,
          isGlobal: current.isGlobal,
          sanctions: event.sanctions,
        ));
      } else if (current is ProfileUpdateSuccess) {
        emit(ProfileUpdateSuccess(
          current.user,
          communityId: current.communityId,
          isGlobal: current.isGlobal,
          sanctions: event.sanctions,
        ));
      }
    });

    on<UpdateProfileRequested>((event, emit) async {
      UserProfile? currentUser;
      if (state is ProfileLoaded) {
        currentUser = (state as ProfileLoaded).user;
      } else if (state is ProfileUpdateInProgress) {
        currentUser = (state as ProfileUpdateInProgress).user;
      }

      final bool wasGlobal = (state is ProfileLoaded) ? (state as ProfileLoaded).isGlobal : (event.communityId == null);
      emit(ProfileUpdateInProgress(progress: 0.0, user: currentUser, isGlobal: wasGlobal));
      try {
        await _profileRepository.updateProfile(
          userId: event.userId,
          username: event.username,
          displayName: event.displayName,
          bio: event.bio,
          avatarPath: event.avatarPath,
          bannerPath: event.bannerPath,
          backgroundPath: event.backgroundPath,
          status: event.status,
          statusEmoji: event.statusEmoji,
          isOnline: event.isOnline,
          isProfileComplete: event.isProfileComplete,
          communityId: event.communityId,
          titles: event.titles,
          themeColorValue: event.themeColorValue,
          socialLinks: event.socialLinks,
          showFollows: event.showFollows,
          chatBubbleStyle: event.chatBubbleStyle,
          birthday: event.birthday,
          wallPrivacy: event.wallPrivacy,
          chatInvitePrivacy: event.chatInvitePrivacy,
          isBot: event.isBot,
          bannerAlignmentY: event.bannerAlignmentY,
          onProgress: (progress) {
             if (!emit.isDone) {
               emit(ProfileUpdateInProgress(progress: progress, user: currentUser, isGlobal: wasGlobal));
             }
          },
        );
        
        // Obtener el perfil fresquito y mezclado de Firestore
        final globalUser = await _profileRepository.getUserProfile(event.userId).first;
        UserProfile finalUser = globalUser;

        if (event.communityId != null) {
          final member = await _profileRepository.getMemberProfileStream(event.communityId!, event.userId).first;
          if (member != null) {
            finalUser = globalUser.copyWith(
              displayName: (member.displayName != null && member.displayName!.isNotEmpty) 
                  ? member.displayName : globalUser.displayName,
              avatarUrl: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) 
                  ? member.avatarUrl : globalUser.avatarUrl,
              bannerUrl: (member.bannerUrl != null && member.bannerUrl!.isNotEmpty) 
                  ? member.bannerUrl : globalUser.bannerUrl,
              backgroundUrl: (member.backgroundUrl != null && member.backgroundUrl!.isNotEmpty) 
                  ? member.backgroundUrl : globalUser.backgroundUrl,
              bio: (member.bio != null && member.bio!.isNotEmpty) 
                  ? member.bio : globalUser.bio,
              status: member.status ?? globalUser.status,
              reputation: member.reputation,
              level: member.level,
              titles: member.titles.isNotEmpty ? member.titles : globalUser.titles,
              themeColorValue: member.themeColorValue ?? globalUser.themeColorValue,
              showFollows: member.showFollows,
              chatBubbleStyle: member.chatBubbleStyle ?? globalUser.chatBubbleStyle,
              wallPrivacy: globalUser.wallPrivacy,
              chatInvitePrivacy: globalUser.chatInvitePrivacy,
            );
          }
        }
        
        emit(ProfileUpdateSuccess(
          finalUser, 
          communityId: event.communityId,
          isGlobal: event.communityId == null,
          sanctions: (state is ProfileLoaded) ? (state as ProfileLoaded).sanctions : [],
        ));

        if (event.birthday != null) {
          await NotificationService.scheduleBirthdayNotification(event.birthday!);
        }
      } catch (e) {
        emit(ProfileError('Error al actualizar perfil: ${e.toString()}'));
      }
    });


    on<FollowUserRequested>((event, emit) async {
      try {
        await _profileRepository.followUser(event.currentUserId, event.targetUserId);
        emit(const FollowStatusLoaded(true));
      } catch (e) {
        emit(ProfileError('Error al seguir: ${e.toString()}'));
      }
    });

    on<UnfollowUserRequested>((event, emit) async {
      try {
        await _profileRepository.unfollowUser(event.currentUserId, event.targetUserId);
        emit(const FollowStatusLoaded(false));
      } catch (e) {
        emit(ProfileError('Error al dejar de seguir: ${e.toString()}'));
      }
    });

    on<CheckFollowStatus>((event, emit) async {
      try {
        await emit.forEach(
          _profileRepository.isFollowing(event.currentUserId, event.targetUserId),
          onData: (isFollowing) => FollowStatusLoaded(isFollowing),
        );
      } catch (e) {
        emit(const FollowStatusLoaded(false));
      }
    });

    on<BlockUserRequested>((event, emit) async {
      try {
        await _profileRepository.blockUser(event.currentUserId, event.targetUserId);
        emit(const ProfileActionSuccess('Usuario bloqueado correctamente'));
      } catch (e) {
        emit(ProfileError('Error al bloquear: ${e.toString()}'));
      }
    });

    on<ReportUserRequested>((event, emit) async {
      try {
        await _profileRepository.reportUser(
          reporterId: event.reporterId,
          targetUserId: event.targetUserId,
          reason: event.reason,
          communityId: event.communityId,
        );
        emit(const ProfileActionSuccess('Reporte enviado correctamente'));
      } catch (e) {
        emit(ProfileError('Error al enviar el reporte: ${e.toString()}'));
      }
    });

    on<UpdateEmailRequested>((event, emit) async {
      emit(ProfileLoading());
      try {
        await _profileRepository.updateEmail(event.newEmail, event.password);
        emit(const ProfileActionSuccess('Se ha enviado un correo de verificación a la nueva dirección.'));
      } catch (e) {
        emit(ProfileError('Error al actualizar email: ${e.toString()}'));
      }
    });

    on<UpdatePasswordRequested>((event, emit) async {
      emit(ProfileLoading());
      try {
        await _profileRepository.updatePassword(event.oldPassword, event.newPassword);
        emit(const ProfileActionSuccess('Contraseña actualizada correctamente.'));
      } catch (e) {
        emit(ProfileError('Error al actualizar contraseña: ${e.toString()}'));
      }
    });

    on<DeleteAccountRequested>((event, emit) async {
      emit(ProfileLoading());
      try {
        await _profileRepository.deleteAccount(event.password);
        emit(const ProfileActionSuccess('Cuenta eliminada permanentemente. Hasta pronto.'));
      } catch (e) {
        emit(ProfileError('Error al eliminar cuenta: ${e.toString()}'));
      }
    });

    on<PerformCheckInRequested>((event, emit) async {
      try {
        await _profileRepository.performCheckIn(event.userId);
        // El perfil se actualizará automáticamente ya que getUserProfile es un Stream
        // Pero emitimos una acción exitosa para mostrar un mensaje si es necesario
        emit(const ProfileActionSuccess('¡Check-in realizado con éxito! +5 AC 🪙 y +10 Rep. ✨'));
      } catch (e) {
        emit(ProfileError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<PurchaseFrameRequested>((event, emit) async {
      try {
        await _profileRepository.purchaseFrame(event.userId, event.frameUrl, event.price);
        emit(const ProfileActionSuccess('¡Marco comprado con éxito! ✨', isPurchase: true));
      } catch (e) {
        emit(ProfileError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<PurchasePackRequested>((event, emit) async {
      try {
        await _profileRepository.purchasePack(event.userId, event.packId);
        emit(const ProfileActionSuccess('¡Pack completado con éxito! ✨', isPurchase: true));
      } catch (e) {
        emit(ProfileError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<EquipFrameRequested>((event, emit) async {
      try {
        await _profileRepository.equipFrame(event.userId, event.frameUrl);
        emit(ProfileActionSuccess(event.frameUrl != null ? '¡Marco equipado!' : 'Marco quitado.'));
      } catch (e) {
        emit(ProfileError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<UpdateSettingsRequested>((event, emit) async {
      try {
        await _profileRepository.updateSettings(event.userId, event.settings);
        emit(const ProfileActionSuccess('Ajustes actualizados'));
      } catch (e) {
        emit(ProfileError('Error al actualizar ajustes: ${e.toString()}'));
      }
    });

    on<UnblockUserRequested>((event, emit) async {
      try {
        await _profileRepository.unblockUser(event.currentUserId, event.targetUserId);
        emit(const ProfileActionSuccess('Usuario desbloqueado'));
      } catch (e) {
        emit(ProfileError('Error al desbloquear: ${e.toString()}'));
      }
    });

    on<ResetProfile>((event, emit) {
      _sanctionsSub?.cancel();
      emit(ProfileInitial());
    });
  }

  @override
  Future<void> close() {
    _sanctionsSub?.cancel();
    return super.close();
  }
}

class _UpdateSanctionsInternal extends ProfileEvent {
  final List<Sanction> sanctions;
  _UpdateSanctionsInternal(this.sanctions);
  @override
  List<Object?> get props => [sanctions];
}

