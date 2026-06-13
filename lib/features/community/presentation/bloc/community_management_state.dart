import 'package:equatable/equatable.dart';
import '../../domain/community_member_model.dart';
import '../../domain/community_model.dart';
import '../../../feed/domain/category_model.dart';

abstract class CommunityManagementState extends Equatable {
  const CommunityManagementState();

  @override
  List<Object?> get props => [];
}

class CommunityManagementInitial extends CommunityManagementState {}

class CommunityManagementLoading extends CommunityManagementState {}

class CommunityManagementLoaded extends CommunityManagementState {
  final List<CommunityMember> members;
  final Community community;
  final List<PostCategory> categories;

  const CommunityManagementLoaded({required this.members, required this.community, required this.categories});

  @override
  List<Object?> get props => [members, community, categories];
}

class CommunityManagementUpdating extends CommunityManagementState {
   final List<CommunityMember> members;
   final Community community;
   
   const CommunityManagementUpdating({required this.members, required this.community});
}

class CommunityManagementSuccess extends CommunityManagementState {
  final String message;
  
  const CommunityManagementSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class CommunityNavigationSuccess extends CommunityManagementState {
  final String message;
  
  const CommunityNavigationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class CommunityManagementError extends CommunityManagementState {
  final String message;

  const CommunityManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
