import 'dart:io';
import 'package:equatable/equatable.dart';

class CompleteProfileState extends Equatable {
  final int currentStep;
  final String displayName;
  final String bio;
  final File? avatarFile;
  final File? bannerFile;
  final File? backgroundFile;
  final bool isSubmitting;
  final double uploadProgress;
  final bool isSuccess;
  final String? errorMessage;
  final DateTime? birthday;

  const CompleteProfileState({
    this.currentStep = 0,
    this.displayName = '',
    this.bio = '',
    this.avatarFile,
    this.bannerFile,
    this.backgroundFile,
    this.isSubmitting = false,
    this.uploadProgress = 0.0,
    this.isSuccess = false,
    this.errorMessage,
    this.birthday,
  });

  CompleteProfileState copyWith({
    int? currentStep,
    String? displayName,
    String? bio,
    File? avatarFile,
    File? bannerFile,
    File? backgroundFile,
    bool? isSubmitting,
    double? uploadProgress,
    bool? isSuccess,
    String? errorMessage,
    DateTime? birthday,
  }) {
    return CompleteProfileState(
      currentStep: currentStep ?? this.currentStep,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarFile: avatarFile ?? this.avatarFile,
      bannerFile: bannerFile ?? this.bannerFile,
      backgroundFile: backgroundFile ?? this.backgroundFile,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
      birthday: birthday ?? this.birthday,
    );
  }

  @override
  List<Object?> get props => [
        currentStep,
        displayName,
        bio,
        avatarFile,
        bannerFile,
        backgroundFile,
        isSubmitting,
        uploadProgress,
        isSuccess,
        errorMessage,
        birthday,
      ];
}
