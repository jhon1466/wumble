import 'package:wumble/features/community/domain/navigation_tab_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum CommunityPrivacy { open, approval, private }

class Community {
  static const List<String> categories = [
    'General',
    'Anime',
    'Gaming',
    'Música',
    'Roleplay',
    'Arte',
    'Estilo de Vida',
    'Tecnología',
    'Cine & TV',
  ];

  final String id;
  final String name;
  final String description;
  final String handle; // URL suffix
  final String creatorId;
  final int membersCount;
  final String iconUrl;
  final String bannerUrl;
  final String backgroundUrl;
  final int themeColorValue; // Store int for easy serialization
  final String category;
  final String privacy; // 'open', 'approval', 'private'
  final DateTime createdAt;
  final Map<String, String> levelTitles; // '1': 'Novato', '20': 'Dios'
  final String? welcomeMessage;
  final bool isWelcomeMessageEnabled;
  final bool isFeatured; // New field for featured communities
  final List<String> tags; // NEW
  final List<CommunityNavigationTab> navigationTabs; // NEW

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.handle,
    required this.creatorId,
    required this.membersCount,
    required this.iconUrl,
    required this.bannerUrl,
    this.backgroundUrl = "",
    required this.themeColorValue,
    required this.category,
    required this.privacy,
    required this.createdAt,
    this.levelTitles = const {}, // Default empty map
    this.welcomeMessage,
    this.isWelcomeMessageEnabled = false,
    this.isFeatured = false, // Default to false
    this.tags = const [], // NEW
    this.navigationTabs = const [], // NEW
  });

  Color get themeColor => Color(themeColorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_lowercase': name.toLowerCase(),
      'description': description,
      'handle': handle,
      'creatorId': creatorId,
      'membersCount': membersCount,
      'iconUrl': iconUrl,
      'bannerUrl': bannerUrl,
      'backgroundUrl': backgroundUrl,
      'themeColorValue': themeColorValue,
      'category': category,
      'privacy': privacy,
      'createdAt': Timestamp.fromDate(createdAt),
      'levelTitles': levelTitles,
      'welcomeMessage': welcomeMessage,
      'isWelcomeMessageEnabled': isWelcomeMessageEnabled,
      'isFeatured': isFeatured,
      'tags': tags, // NEW
      'navigationTabs': navigationTabs.map((t) => t.toMap()).toList(), // NEW
    };
  }

  factory Community.fromMap(Map<String, dynamic> map, String documentId) {
    return Community(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      handle: map['handle'] ?? '',
      creatorId: map['creatorId'] ?? '',
      membersCount: map['membersCount'] ?? 1,
      iconUrl: map['iconUrl'] ?? '',
      bannerUrl: map['bannerUrl'] ?? '',
      backgroundUrl: map['backgroundUrl'] ?? '',
      themeColorValue: map['themeColorValue'] ?? 0xFF7F4DFF,
      category: map['category'] ?? 'General',
      privacy: map['privacy'] ?? 'open',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      levelTitles: Map<String, String>.from(map['levelTitles'] ?? {}),
      welcomeMessage: map['welcomeMessage'],
      isWelcomeMessageEnabled: map['isWelcomeMessageEnabled'] ?? false,
      isFeatured: map['isFeatured'] ?? false,
      tags: List<String>.from(map['tags'] ?? []), // NEW
      navigationTabs: map['navigationTabs'] != null
          ? (map['navigationTabs'] as List)
              .map((t) => CommunityNavigationTab.fromMap(t as Map<String, dynamic>))
              .toList()
          : defaultTabs, // NEW
    );
  }

  static List<CommunityNavigationTab> get defaultTabs => [
        const CommunityNavigationTab(id: 'f1', title: 'Destacados', type: NavigationTabType.featured, order: 0),
        const CommunityNavigationTab(id: 'c1', title: 'Chats', type: NavigationTabType.chats, order: 1),
        const CommunityNavigationTab(id: 'l1', title: 'Líderes', type: NavigationTabType.leaderboard, order: 2),
        const CommunityNavigationTab(id: 'w1', title: 'Wiki', type: NavigationTabType.wikis, order: 3),
        const CommunityNavigationTab(id: 'q1', title: 'Quizzes', type: NavigationTabType.quizzes, order: 4),
        const CommunityNavigationTab(id: 's1', title: 'Carpeta', type: NavigationTabType.sharedFolder, order: 5),
        const CommunityNavigationTab(id: 'p1', title: 'Encuestas', type: NavigationTabType.polls, order: 6),
        const CommunityNavigationTab(id: 'r1', title: 'Reciente', type: NavigationTabType.recent, order: 7),
      ];

  // CopyWith for optimistic updates
  Community copyWith({
    String? name,
    String? description,
    int? membersCount,
    String? iconUrl,
    String? bannerUrl,
    String? backgroundUrl,
    int? themeColorValue,
    Map<String, String>? levelTitles,
    String? welcomeMessage,
    bool? isWelcomeMessageEnabled,
    List<String>? tags, // NEW
    List<CommunityNavigationTab>? navigationTabs, // NEW
  }) {
    return Community(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      handle: handle,
      creatorId: creatorId,
      membersCount: membersCount ?? this.membersCount,
      iconUrl: iconUrl ?? this.iconUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      category: category,
      privacy: privacy,
      createdAt: createdAt,
      levelTitles: levelTitles ?? this.levelTitles,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      isWelcomeMessageEnabled: isWelcomeMessageEnabled ?? this.isWelcomeMessageEnabled,
      isFeatured: isFeatured,
      tags: tags ?? this.tags, // NEW
      navigationTabs: navigationTabs ?? this.navigationTabs, // NEW
    );
  }
}
