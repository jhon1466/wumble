class PostCategory {
  final String id;
  final String name;
  final String icon;
  final String communityId;
  final int order;

  PostCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.communityId,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'communityId': communityId,
      'order': order,
    };
  }

  factory PostCategory.fromMap(Map<String, dynamic> map, String documentId) {
    return PostCategory(
      id: documentId,
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      communityId: map['communityId'] ?? '',
      order: map['order'] ?? 0,
    );
  }

  PostCategory copyWith({
    String? id,
    String? name,
    String? icon,
    String? communityId,
    int? order,
  }) {
    return PostCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      communityId: communityId ?? this.communityId,
      order: order ?? this.order,
    );
  }
}
