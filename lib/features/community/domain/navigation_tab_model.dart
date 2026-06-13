import 'package:equatable/equatable.dart';

enum NavigationTabType {
  featured,      // Destacados (Popular feed)
  recent,        // Reciente (Recent feed)
  chats,         // Lista de chats públicos
  wikis,         // Entradas Wiki
  quizzes,       // Quizzes
  polls,         // Encuestas
  sharedFolder,  // Carpeta Compartida
  leaderboard,   // Salón de la Fama
  externalLink,  // Enlace externo (Web)
  category,      // Feed filtrado por categoría
}

class CommunityNavigationTab extends Equatable {
  final String id;
  final String title;
  final NavigationTabType type;
  final String? content; // URL for externalLink, or category name for category
  final String? iconName; // "home", "chat", "book", etc.
  final bool isHidden;
  final int order;

  const CommunityNavigationTab({
    required this.id,
    required this.title,
    required this.type,
    this.content,
    this.iconName,
    this.isHidden = false,
    this.order = 0,
  });

  @override
  List<Object?> get props => [id, title, type, content, iconName, isHidden, order];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'content': content,
      'iconName': iconName,
      'isHidden': isHidden,
      'order': order,
    };
  }

  factory CommunityNavigationTab.fromMap(Map<String, dynamic> map) {
    return CommunityNavigationTab(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: NavigationTabType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'featured'),
        orElse: () => NavigationTabType.featured,
      ),
      content: map['content'],
      iconName: map['iconName'],
      isHidden: map['isHidden'] ?? false,
      order: map['order'] ?? 0,
    );
  }

  CommunityNavigationTab copyWith({
    String? title,
    NavigationTabType? type,
    String? content,
    String? iconName,
    bool? isHidden,
    int? order,
  }) {
    return CommunityNavigationTab(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      iconName: iconName ?? this.iconName,
      isHidden: isHidden ?? this.isHidden,
      order: order ?? this.order,
    );
  }
}
