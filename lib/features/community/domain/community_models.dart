import 'package:flutter/material.dart';

enum CommunityPrivacy {
  open,     // Cualquiera puede unirse
  approval, // Requiere aprobación del staff
  private   // Solo por invitación
}

enum CommunityRole {
  agent,    // Creador/Dueño (No se puede expulsar)
  leader,   // Admin completo
  curator,  // Moderador (Destacar, Ocultar)
  member    // Usuario normal
}

class Community {
  final String id;
  final String name;
  final String handle; // URL única (ej: "anime-art")
  final String description;
  final String iconUrl;
  final String bannerUrl;
  final Color themeColor;
  final CommunityPrivacy privacy;
  final DateTime createdAt;
  
  // Staff IDs
  final String agentId;
  final List<String> leaderIds;
  final List<String> curatorIds;
  
  // Stats
  final int membersCount;
  final int activeNow;

  const Community({
    required this.id,
    required this.name,
    required this.handle,
    required this.description,
    required this.iconUrl,
    required this.bannerUrl,
    required this.themeColor,
    required this.privacy,
    required this.createdAt,
    required this.agentId,
    this.leaderIds = const [],
    this.curatorIds = const [],
    this.membersCount = 1,
    this.activeNow = 1,
  });

  // Factory para crear una comunidad vacía/inicial
  factory Community.initial() {
    return Community(
      id: '',
      name: '',
      handle: '',
      description: '',
      iconUrl: '',
      bannerUrl: '',
      themeColor: Colors.blue,
      privacy: CommunityPrivacy.open,
      createdAt: DateTime.now(),
      agentId: '',
    );
  }
}
