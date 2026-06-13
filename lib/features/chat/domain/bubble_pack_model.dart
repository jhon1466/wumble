import 'package:equatable/equatable.dart';
import 'chat_model.dart';

class BubblePack extends Equatable {
  final String id;
  final String name;
  final String description;
  final String category; // e.g., 'Aesthetic', 'Anime', 'Tech', 'Nature'
  final String? coverImageUrl;
  final double price; // 0.0 for free
  final List<ChatBubbleStyle> styles;
  final String? creatorId; // null means official pack
  final bool isPublic; // To allow private drafting or public workshop
  
  const BubblePack({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.coverImageUrl,
    this.price = 0.0,
    required this.styles,
    this.creatorId,
    this.isPublic = true,
  });

  @override
  List<Object?> get props => [id, name, description, category, coverImageUrl, price, styles, creatorId, isPublic];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'coverImageUrl': coverImageUrl,
      'price': price,
      'styles': styles.map((s) => s.toMap()).toList(),
      'creatorId': creatorId,
      'isPublic': isPublic,
    };
  }

  factory BubblePack.fromMap(Map<String, dynamic> map) {
    return BubblePack(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      coverImageUrl: map['coverImageUrl'],
      price: (map['price'] ?? 0.0).toDouble(),
      styles: (map['styles'] as List<dynamic>?)
              ?.map((s) => ChatBubbleStyle.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      creatorId: map['creatorId'],
      isPublic: map['isPublic'] ?? true,
    );
  }
}
