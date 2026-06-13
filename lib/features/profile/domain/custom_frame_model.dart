import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/avatar_frame.dart';

class CustomAvatarFrame {
  final String id;
  final String uploaderId;
  final String name;
  final int price;        // Precio individual del marco
  final int packPrice;    // Precio total del pack completo (0 si es suelto)
  final int packSize;     // Total de marcos en el pack (0 o 1 si es suelto)
  final FrameType type;
  final String url;
  final String? packId;
  final String? packName;
  final DateTime createdAt;
  final int purchases;
  final String? credits;

  const CustomAvatarFrame({
    required this.id,
    required this.uploaderId,
    required this.name,
    required this.price,
    this.packPrice = 0,
    this.packSize = 0,
    required this.type,
    required this.url,
    this.packId,
    this.packName,
    required this.createdAt,
    this.purchases = 0,
    this.credits,
  });

  factory CustomAvatarFrame.fromMap(Map<String, dynamic> map, String id) {
    return CustomAvatarFrame(
      id: id,
      uploaderId: map['uploaderId'] ?? '',
      name: map['name'] ?? '',
      price: map['price']?.toInt() ?? 0,
      packPrice: map['packPrice']?.toInt() ?? 0,
      packSize: map['packSize']?.toInt() ?? 0,
      type: map['type'] == 'video' ? FrameType.video : FrameType.image,
      url: map['url'] ?? '',
      packId: map['packId'],
      packName: map['packName'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      purchases: map['purchases']?.toInt() ?? 0,
      credits: map['credits'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploaderId': uploaderId,
      'name': name,
      'price': price,
      if (packPrice > 0) 'packPrice': packPrice,
      if (packSize > 0) 'packSize': packSize,
      'type': type == FrameType.video ? 'video' : 'image',
      'url': url,
      if (packId != null) 'packId': packId,
      if (packName != null) 'packName': packName,
      'createdAt': Timestamp.fromDate(createdAt),
      'purchases': purchases,
      if (credits != null) 'credits': credits,
    };
  }

  // Helper to convert to the UI widget model
  AvatarFrame toAvatarFrame() {
    return AvatarFrame(
      id: id,
      name: name,
      colors: const [], // Custom frames don't use glow colors
      price: price,
      type: type,
      networkUrl: url,
      packId: packId,
      packName: packName,
      packPrice: packPrice,
      packSize: packSize,
      uploaderId: uploaderId,
      createdAt: createdAt,
      credits: credits,
    );
  }
}

class AvatarFramePack {
  final String id;
  final String uploaderId;
  final String name;
  final String description;
  final String coverUrl;
  final int price;
  final List<String> frameIds;
  final DateTime createdAt;
  final int purchases;

  const AvatarFramePack({
    required this.id,
    required this.uploaderId,
    required this.name,
    required this.description,
    required this.coverUrl,
    required this.price,
    required this.frameIds,
    required this.createdAt,
    this.purchases = 0,
  });

  factory AvatarFramePack.fromMap(Map<String, dynamic> map, String id) {
    return AvatarFramePack(
      id: id,
      uploaderId: map['uploaderId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      price: map['price']?.toInt() ?? 0,
      frameIds: List<String>.from(map['frameIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      purchases: map['purchases']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploaderId': uploaderId,
      'name': name,
      'description': description,
      'coverUrl': coverUrl,
      'price': price,
      'frameIds': frameIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'purchases': purchases,
    };
  }
}
