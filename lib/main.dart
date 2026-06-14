import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wumble/core/widgets/update_dialog.dart';
import 'package:wumble/core/localization/locale_controller.dart';
import 'package:wumble/core/localization/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:wumble/core/services/presence_service_supabase.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'core/theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'features/feed/presentation/explore_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/profile/presentation/complete_profile_screen.dart';
import 'features/chat/presentation/chat_list_screen.dart';
import 'features/profile/presentation/profile_bloc.dart';
import 'features/profile/presentation/bloc/notification_count_bloc.dart';
import 'features/feed/presentation/feed_bloc.dart';
import 'features/feed/presentation/bloc/search_bloc.dart';
import 'features/community/presentation/bloc/community_bloc.dart';
import 'features/community/presentation/bloc/discover_bloc.dart';
import 'features/chat/presentation/chat_bloc.dart';
import 'features/community/presentation/bloc/community_members_bloc.dart';
import 'injection_container.dart' as di;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/community/presentation/create_community_screen.dart';
import 'features/chat/domain/moderation_service.dart';
import 'features/community/presentation/bloc/community_context_bloc.dart';
import 'features/chat/domain/chat_repository.dart';
import 'features/profile/domain/profile_repository.dart';
import 'features/profile/domain/user_model.dart';
import 'features/community/presentation/home_screen.dart';
import 'core/widgets/user_avatar.dart';
import 'features/auth/presentation/bloc/connectivity_cubit.dart';
import 'core/widgets/connectivity_wrapper.dart';

import 'core/services/notification_service.dart';
import 'core/services/presence_service.dart'; // Added
import 'features/profile/presentation/widgets/birthday_celebration_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/presentation/dynamic_theme_wrapper.dart';
import 'core/utils/link_navigator.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  
  // 1. Initialize Firebase first
  await Firebase.initializeApp();

  // Configure Firestore persistence and cache size (100MB)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize Supabase (used only for live presence; no Firebase cost).
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }
  
  // 2. Now initialize dependency injection
  await di.init();

  // 3. Initialize Presence (starts lifecycle tracking)
  di.sl<PresenceService>();
  
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  
  // Initialize Notifications
  await NotificationService.initialize();
  NotificationService.navigatorKey = navigatorKey;

  // Initialize Date Formatting
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('ru', null);

  // Load the persisted app language (Spanish by default)
  await LocaleController.load();

  // Load Global Config (Feature Toggles, Moderation, etc)
  await ModerationService.ensureConfig();
  
  // Configure System UI for edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  runApp(const WumbleCloneApp());
}

class WumbleCloneApp extends StatelessWidget {
  const WumbleCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ChatRepository>(
      create: (_) => di.sl<ChatRepository>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => di.sl<FeedBloc>()),
          BlocProvider(create: (_) => di.sl<AuthBloc>()),
          BlocProvider(create: (_) => di.sl<ProfileBloc>()),
          BlocProvider(create: (_) => di.sl<CommunityBloc>()),
          BlocProvider(create: (_) => di.sl<DiscoverBloc>()),
          BlocProvider(create: (_) => di.sl<GlobalSearchBloc>()),
          BlocProvider(create: (_) => di.sl<CommunityContextBloc>()),
          BlocProvider(create: (_) => di.sl<ChatBloc>()),
          BlocProvider(create: (_) => di.sl<CommunityMembersBloc>()),
          BlocProvider(create: (_) => di.sl<NotificationCountBloc>()),
          BlocProvider(create: (_) => ConnectivityCubit()),
        ],
        child: ValueListenableBuilder<Locale>(
          valueListenable: LocaleController.locale,
          builder: (context, locale, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Wumble',
              debugShowCheckedModeBanner: false,
              theme: Wumbleheme.darkTheme,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: LocaleController.supported,
              locale: locale,
              builder: (context, child) {
                return ConnectivityWrapper(child: child!);
              },
              home: const DynamicThemeWrapper(child: AuthWrapper()),
            );
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          context.read<ProfileBloc>().add(ResetProfile());
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            return ProfileCheckWrapper(userId: state.user!.uid);
          }
          if (state.status == AuthStatus.loading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class ProfileCheckWrapper extends StatefulWidget {
  final String userId;
  const ProfileCheckWrapper({super.key, required this.userId});

  @override
  State<ProfileCheckWrapper> createState() => _ProfileCheckWrapperState();
}

class _ProfileCheckWrapperState extends State<ProfileCheckWrapper> {
  late Stream<UserProfile> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = di.sl<ProfileRepository>().getUserProfile(widget.userId);
    // Initialize the global ProfileBloc once authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileBloc>().add(LoadProfileRequested(widget.userId));
        context.read<NotificationCountBloc>().add(SubscribeToCounts(widget.userId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (!user.isProfileComplete) {
            return CompleteProfileScreen(user: user);
          }
          return const MainScaffold();
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error al cargar perfil: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _profileStream = di.sl<ProfileRepository>().getUserProfile(widget.userId);
                      });
                    },
                    child: Text(tr('Reintentar')),
                  ),
                ],
              ),
            ),
          );
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _selectedIndex;
  DateTime? _lastPressedAt;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    
    _initDeepLinks();

    final authState = context.read<AuthBloc>().state;
    if (authState.status == AuthStatus.authenticated && authState.user != null) {
      final userId = authState.user!.uid;
      context.read<ProfileBloc>().add(LoadProfileRequested(userId));
      context.read<ChatBloc>().add(LoadChatRooms(userId));
      _syncNotifications(userId);
    }

    // Process notification after a small delay to ensure navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          NotificationService.handlePendingNotification(context);
        }
      });
      // OTA: check GitHub Releases for a newer build and prompt to update.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          checkAndPromptUpdate(context);
        }
      });
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Deep link received: $uri');
      if (mounted) {
        LinkNavigator.handleUrl(context, uri.toString());
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncNotifications(String userId) async {
    final token = await NotificationService.getToken();
    if (token != null && mounted) {
      di.sl<ProfileRepository>().syncFcmToken(userId, token);
    }
  }

  final List<Widget> _pages = [
    const HomeScreen(),
    const ExploreScreen(),
    const ChatListScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          _checkBirthdayCelebration(state.user);
        }
      },
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, rootProfileState) {
        if (rootProfileState is ProfileLoaded &&
            rootProfileState.user.displayName == 'Usuario de Wumble' &&
            rootProfileState.user.avatarUrl.isEmpty) {
          return CompleteProfileScreen(user: rootProfileState.user);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (_selectedIndex != 0) {
              setState(() => _selectedIndex = 0);
              return;
            }

            final now = DateTime.now();
            if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
              _lastPressedAt = now;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('Presiona atrás de nuevo para salir')),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(bottom: 140, left: 20, right: 20),
                ),
              );
              return;
            }

            await SystemNavigator.pop();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.light,
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
              extendBody: true,
              body: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
              floatingActionButton: null,
              bottomNavigationBar: SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 10),
                    child: Container(
                      height: 58,
                      clipBehavior: Clip.none,
                      decoration: BoxDecoration(
                        color: Wumbleheme.surfaceColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Theme(
                        data: ThemeData(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: BlocBuilder<ProfileBloc, ProfileState>(
                          builder: (context, profileState) {
                            return BlocBuilder<CommunityContextBloc, CommunityContextState>(
                              builder: (context, contextState) {
                                final authUser = context.read<AuthBloc>().state.user;
                                String globalUrl = authUser?.photoURL ?? "";
                                String? globalName = authUser?.displayName;
                                if (globalName == 'Usuario de Wumble') globalName = 'Usuario';

                                if (profileState is ProfileLoaded && profileState.communityId == null) {
                                  // Solo actualizar si el perfil cargado coincide con el usuario autenticado
                                  if (profileState.user.id == authUser?.uid) {
                                    globalUrl = profileState.user.avatarUrl;
                                    globalName = profileState.user.displayName;
                                  }
                                } else if (profileState is ProfileUpdateInProgress && profileState.user != null) {
                                  if (profileState.user!.id == authUser?.uid) {
                                    globalUrl = profileState.user!.avatarUrl;
                                    globalName = profileState.user!.displayName;
                                  }
                                } else if (profileState is ProfileUpdateSuccess && profileState.communityId == null) {
                                  if (profileState.user.id == authUser?.uid) {
                                    globalUrl = profileState.user.avatarUrl;
                                    globalName = profileState.user.displayName;
                                  }
                                }

                                 return BlocBuilder<NotificationCountBloc, NotificationCountState>(
                                  builder: (context, notifState) {
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildNavItem(0, Icons.home_rounded, 'Inicio'),
                                        _buildNavItem(1, Icons.explore_rounded, 'Descubrir'),
                                        // Center + Button
                                        _buildCreateButton(),
                                        _buildNavItem(2, Icons.chat_bubble_rounded, 'Chats', badgeCount: notifState.chatUnreadCount),
                                        _buildProfileNavItem(
                                          3,
                                          globalUrl,
                                          globalName,
                                          'Yo',
                                          userId: (profileState is ProfileLoaded)
                                              ? profileState.user.id
                                              : (profileState is ProfileUpdateInProgress && profileState.user != null
                                                  ? profileState.user!.id
                                                  : null),
                                          communityId: null,
                                        ),
                                      ],
                                    );
                                  },
                                );

                              },
                            );
                          },
                        ),
                      ),
                    ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Future<void> _checkBirthdayCelebration(UserProfile user) async {
    if (user.birthday == null) return;

    final now = DateTime.now();
    // Comparar día y mes
    if (user.birthday!.day == now.day && user.birthday!.month == now.month) {
      final prefs = await SharedPreferences.getInstance();
      final String key = 'last_birthday_year_${user.id}';
      final int? lastYear = prefs.getInt(key);

      if (lastYear == null || lastYear < now.year) {
        if (mounted) {
          BirthdayCelebrationOverlay.show(context);
          await prefs.setInt(key, now.year);
        }
      }
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? Wumbleheme.secondaryColor : Wumbleheme.textSecondary,
            ),
            if (badgeCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Wumbleheme.surfaceColor, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileNavItem(int index, String imageUrl, String? displayName, String label, {String? userId, String? communityId}) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: UserAvatar(
        userId: userId,
        avatarUrl: imageUrl,
        displayName: displayName,
        radius: 14,
        communityId: communityId,
        isClickable: false,
        border: Border.all(
          color: isSelected ? Wumbleheme.secondaryColor : Colors.transparent,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CreateCommunityScreen()),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Wumbleheme.secondaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Wumbleheme.secondaryColor.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
