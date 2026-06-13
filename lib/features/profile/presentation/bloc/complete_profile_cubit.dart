import 'dart:io';
import 'package:bloc/bloc.dart';
import '../../domain/profile_repository.dart';
import '../../domain/user_model.dart';
import '../../../../core/services/notification_service.dart';
import 'complete_profile_state.dart';

class CompleteProfileCubit extends Cubit<CompleteProfileState> {
  final ProfileRepository _profileRepository;
  final UserProfile currentUser;

  CompleteProfileCubit(this._profileRepository, this.currentUser)
      : super(CompleteProfileState(
          displayName: currentUser.displayName,
          bio: currentUser.bio.isNotEmpty && currentUser.bio != '¡Hola! Soy nuevo en la comunidad. ✨' 
              ? currentUser.bio 
              : '',
        ));

  void nextStep() {
    if (state.currentStep < 3) {
      emit(state.copyWith(currentStep: state.currentStep + 1));
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      emit(state.copyWith(currentStep: state.currentStep - 1));
    }
  }

  void updateIdentity(String displayName, File? avatar) {
    emit(state.copyWith(displayName: displayName, avatarFile: avatar));
  }

  void updateBio(String bio) {
    emit(state.copyWith(bio: bio));
  }

  void updateBirthday(DateTime birthday) {
    emit(state.copyWith(birthday: birthday));
  }

  void updateStyle(File? background, File? banner) {
    emit(state.copyWith(backgroundFile: background, bannerFile: banner));
  }

  Future<void> submitProfile() async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      // If no new avatar is picked, but the current one is the Google default,
      // we clear it to force UserAvatar to show the initial of the NEW displayName.
      String? avatarPath = state.avatarFile?.path;
      if (avatarPath == null && currentUser.avatarUrl.contains('googleusercontent.com')) {
        avatarPath = "[DELETE]";
      }

      await _profileRepository.updateProfile(
        userId: currentUser.id,
        displayName: state.displayName.isNotEmpty ? state.displayName : null,
        bio: state.bio.isNotEmpty ? state.bio : null,
        avatarPath: avatarPath,
        bannerPath: state.bannerFile?.path,
        backgroundPath: state.backgroundFile?.path,
        birthday: state.birthday,
        isProfileComplete: true,
        onProgress: (progress) {
          if (!isClosed) {
            emit(state.copyWith(uploadProgress: progress));
          }
        },
      );

      // Programar notificación de cumpleaños si se estableció
      if (state.birthday != null) {
        await NotificationService.scheduleBirthdayNotification(state.birthday!);
      }

      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false, isSuccess: true));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false, errorMessage: 'Error al actualizar: $e'));
      }
    }
  }

  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
