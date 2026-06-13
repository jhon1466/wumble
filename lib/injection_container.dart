import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get_it/get_it.dart';
import 'features/feed/domain/feed_repository.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/profile/domain/profile_repository.dart';
import 'features/profile/domain/notification_repository.dart';
import 'features/profile/data/profile_repository_impl.dart';
import 'features/profile/data/notification_repository_impl.dart';
import 'features/community/domain/community_repository.dart';
import 'features/community/data/community_repository_impl.dart';
import 'features/community/domain/wiki_repository.dart'; // Added
import 'features/community/data/wiki_repository_impl.dart'; // Added
import 'features/community/domain/shared_folder_repository.dart'; // Added
import 'features/community/data/shared_folder_repository_impl.dart'; // Added
import 'features/community/presentation/bloc/community_bloc.dart';
import 'features/profile/presentation/profile_bloc.dart';
import 'features/profile/presentation/bloc/notification_count_bloc.dart';
import 'features/feed/presentation/feed_bloc.dart';
import 'features/feed/presentation/bloc/search_bloc.dart';
import 'features/community/presentation/bloc/community_context_bloc.dart';
import 'features/community/presentation/bloc/community_management_cubit.dart';
import 'features/community/presentation/bloc/community_members_bloc.dart';
import 'features/community/presentation/bloc/discover_bloc.dart';
import 'features/chat/domain/chat_repository.dart';
import 'features/chat/data/chat_repository_impl.dart';
import 'features/chat/presentation/chat_bloc.dart';
import 'features/moderation/domain/moderation_repository.dart';
import 'features/moderation/data/moderation_repository_impl.dart';
import 'features/moderation/presentation/bloc/moderation_bloc.dart'; // We'll create this next

import 'core/services/storage_service.dart'; // Added
import 'core/services/presence_service.dart'; // Added
import 'features/feed/data/real_feed_repository_impl.dart'; // Added
import 'features/feed/presentation/bloc/community_feed_bloc.dart'; // Added
import 'features/feed/presentation/bloc/create_post_cubit.dart'; // Added

final sl = GetIt.instance;

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  sl.registerLazySingleton(() => firestore);
  sl.registerLazySingleton(() => GoogleSignIn());
  sl.registerLazySingleton(() => StorageService()); // Added
  sl.registerLazySingleton(() => PresenceService()); // Added

  // Features - Auth
  sl.registerFactory(() => AuthBloc(
        authRepository: sl(),
        profileRepository: sl(),
      ));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      firebaseAuth: sl(),
      googleSignIn: sl(),
    ),
  );

  // Features - Profile
  sl.registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl());
  sl.registerLazySingleton<NotificationRepository>(() => NotificationRepositoryImpl());
  sl.registerFactory(() => ProfileBloc(
        profileRepository: sl(),
        moderationRepository: sl(),
        communityRepository: sl(),
      ));
  sl.registerFactory(() => NotificationCountBloc(repository: sl()));
  // We need to pass currentUser to CompleteProfileCubit, so we register it as a factory taking the user as a param, 
  // OR we can pass it dynamically when creating the BlocProvider. We'll pass it when creating BlocProvider.

  // Features - Feed
  sl.registerFactory(() => FeedBloc(repository: sl()));
  sl.registerFactory(() => CommunityFeedBloc(repository: sl())); // Added
  sl.registerFactory(() => CreatePostCubit(repository: sl(), communityRepository: sl())); // Added
  // Repository
  sl.registerLazySingleton<FeedRepository>(() => RealFeedRepositoryImpl(storageService: sl())); // Changed
  
  // Features - Community
  sl.registerLazySingleton<CommunityRepository>(() => CommunityRepositoryImpl());
  sl.registerLazySingleton<WikiRepository>(() => WikiRepositoryImpl(storageService: sl())); // Added
  sl.registerLazySingleton<SharedFolderRepository>(() => SharedFolderRepositoryImpl(storageService: sl())); // Added
  sl.registerFactory(() => CommunityBloc(repository: sl()));
  sl.registerFactory(() => CommunityContextBloc(profileRepository: sl(), communityRepository: sl(), auth: sl()));
  sl.registerFactory(() => GlobalSearchBloc(
    communityRepository: sl(),
    profileRepository: sl(),
    feedRepository: sl(),
  ));
  sl.registerFactory(() => CommunityManagementCubit(sl(), sl()));
  sl.registerFactory(() => CommunityMembersBloc(repository: sl()));
  sl.registerFactory(() => DiscoverBloc(repository: sl()));

  // Features - Chat
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl());
  sl.registerFactory(() => ChatBloc(repository: sl()));

  // Features - Moderation
  sl.registerLazySingleton<ModerationRepository>(() => ModerationRepositoryImpl(sl()));
  sl.registerFactory(() => ModerationBloc(repository: sl()));
}
