import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BotResponseType { text, image, gif, multi }

enum BotCommandProvider { local, webhook, groq, gemini }

enum BotStatusType { 
  playing, 
  watching, 
  listening, 
  competing, 
  custom,
  none 
}

class BotButton extends Equatable {
  final String label;
  final String trigger; // Command to execute or URL
  final bool isUrl;

  const BotButton({
    required this.label,
    required this.trigger,
    this.isUrl = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'trigger': trigger,
      'isUrl': isUrl,
    };
  }

  factory BotButton.fromFirestore(Map<String, dynamic> data) {
    return BotButton(
      label: data['label'] ?? '',
      trigger: data['trigger'] ?? '',
      isUrl: data['isUrl'] ?? false,
    );
  }

  @override
  List<Object?> get props => [label, trigger, isUrl];
}

class BotCommand extends Equatable {
  final String trigger;
  final String response;
  final List<String> responses; // For randomized responses
  final BotResponseType type;
  final String? mediaUrl;
  final String description;
  final bool isEmbed;
  final String? footerText;
  final String? title;
  final List<BotButton> buttons; // NEW: Interaction buttons
  final List<String> allowedRoles; // NEW: Permissions (admin, curator, etc.)
  final String? webhookUrl; // NEW: External integration
  final BotCommandProvider provider; // NEW: AI Integration
  final String? apiKey; // NEW: AI Key
  final String? aiModel; // NEW: AI Model selection
  final String? prompt; // NEW: System prompt for AI

  const BotCommand({
    required this.trigger,
    required this.response,
    this.responses = const [],
    this.type = BotResponseType.text,
    this.mediaUrl,
    this.description = '',
    this.isEmbed = false,
    this.footerText,
    this.title,
    this.buttons = const [],
    this.allowedRoles = const [],
    this.webhookUrl,
    this.provider = BotCommandProvider.local,
    this.apiKey,
    this.aiModel,
    this.prompt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'trigger': trigger,
      'response': response,
      'responses': responses,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'description': description,
      'isEmbed': isEmbed,
      'footerText': footerText,
      'title': title,
      'buttons': buttons.map((b) => b.toFirestore()).toList(),
      'allowedRoles': allowedRoles,
      'webhookUrl': webhookUrl,
      'provider': provider.name,
      'apiKey': apiKey,
      'aiModel': aiModel,
      'prompt': prompt,
    };
  }

  factory BotCommand.fromFirestore(Map<String, dynamic> data) {
    return BotCommand(
      trigger: data['trigger'] ?? '',
      response: data['response'] ?? '',
      responses: (data['responses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      type: BotResponseType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => BotResponseType.text,
      ),
      mediaUrl: data['mediaUrl'],
      description: data['description'] ?? '',
      isEmbed: data['isEmbed'] ?? false,
      footerText: data['footerText'],
      title: data['title'],
      buttons: (data['buttons'] as List<dynamic>?)
              ?.map((b) => BotButton.fromFirestore(b as Map<String, dynamic>))
              .toList() ??
          [],
      allowedRoles: List<String>.from(data['allowedRoles'] ?? []),
      webhookUrl: data['webhookUrl'],
      provider: BotCommandProvider.values.firstWhere(
        (e) => e.name == data['provider'],
        orElse: () => data['webhookUrl'] != null ? BotCommandProvider.webhook : BotCommandProvider.local,
      ),
      apiKey: data['apiKey'],
      aiModel: data['aiModel'],
      prompt: data['prompt'],
    );
  }

  @override
  List<Object?> get props => [
    trigger, response, responses, type, mediaUrl, 
    description, isEmbed, footerText, title, 
    buttons, allowedRoles, webhookUrl,
    provider, apiKey, aiModel, prompt
  ];
}

class BotConfig extends Equatable {
  final String id;
  final String name;
  final String prefix;
  final String avatarUrl;
  final String description;
  final List<BotCommand> commands;
  final bool isActive;
  final String creatorId;
  final DateTime createdAt;
  final BotStatusType statusType;
  final String statusText;
  final int embedColorValue;
  final bool isGuardian;
  final double chatModerationSensitivity;
  final double feedModerationSensitivity;
  final Map<String, String> eventTriggers;
  final bool allowMention; // NEW: Call with @name
  final String? bannerUrl; // NEW: Bot Mini-profile banner
  final int? backgroundColorValue; // NEW: Bot Mini-profile accent color
  final String? customStatusPrefix; // NEW: Custom activity prefix (e.g., "Sleeping", "Coding")

  const BotConfig({
    required this.id,
    required this.name,
    required this.prefix,
    required this.avatarUrl,
    this.description = '',
    this.commands = const [],
    this.isActive = true,
    required this.creatorId,
    required this.createdAt,
    this.statusType = BotStatusType.none,
    this.statusText = '',
    this.embedColorValue = 0xFF2196F3,
    this.isGuardian = false,
    this.chatModerationSensitivity = 0.5,
    this.feedModerationSensitivity = 0.5,
    this.eventTriggers = const {},
    this.allowMention = true,
    this.bannerUrl,
    this.backgroundColorValue,
    this.customStatusPrefix,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id, // Include ID for nested reconstruction
      'name': name,
      'prefix': prefix,
      'avatarUrl': avatarUrl,
      'description': description,
      'commands': commands.map((c) => c.toFirestore()).toList(),
      'isActive': isActive,
      'creatorId': creatorId,
      'createdAt': createdAt,
      'statusType': statusType.name,
      'statusText': statusText,
      'embedColorValue': embedColorValue,
      'isGuardian': isGuardian,
      'chatModerationSensitivity': chatModerationSensitivity,
      'feedModerationSensitivity': feedModerationSensitivity,
      'eventTriggers': eventTriggers,
      'allowMention': allowMention,
      'bannerUrl': bannerUrl,
      'backgroundColorValue': backgroundColorValue,
      'customStatusPrefix': customStatusPrefix,
    };
  }

  factory BotConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BotConfig.fromMap(data, id: doc.id);
  }

  factory BotConfig.fromMap(Map<String, dynamic> data, {String? id}) {
    return BotConfig(
      id: id ?? data['id'] ?? '',
      name: data['name'] ?? '',
      prefix: data['prefix'] ?? '/',
      avatarUrl: data['avatarUrl'] ?? '',
      description: data['description'] ?? '',
      commands: (data['commands'] as List<dynamic>?)
              ?.map((c) => BotCommand.fromFirestore(c as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: data['isActive'] ?? true,
      creatorId: data['creatorId'] ?? '',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate() 
          : (data['createdAt'] is String ? DateTime.parse(data['createdAt']) : DateTime.now()),
      statusType: BotStatusType.values.firstWhere(
        (e) => e.name == data['statusType'],
        orElse: () => BotStatusType.none,
      ),
      statusText: data['statusText'] ?? '',
      embedColorValue: data['embedColorValue'] ?? 0xFF2196F3,
      isGuardian: data['isGuardian'] ?? false,
      chatModerationSensitivity: (data['chatModerationSensitivity'] ?? data['moderationSensitivity'] ?? 0.5).toDouble(),
      feedModerationSensitivity: (data['feedModerationSensitivity'] ?? data['moderationSensitivity'] ?? 0.5).toDouble(),
      eventTriggers: Map<String, String>.from(data['eventTriggers'] ?? {}),
      allowMention: data['allowMention'] ?? true,
      bannerUrl: data['bannerUrl'],
      backgroundColorValue: data['backgroundColorValue'],
      customStatusPrefix: data['customStatusPrefix'],
    );
  }

  BotConfig copyWith({
    String? name,
    String? prefix,
    String? avatarUrl,
    String? description,
    List<BotCommand>? commands,
    bool? isActive,
    BotStatusType? statusType,
    String? statusText,
    int? embedColorValue,
    bool? isGuardian,
    double? chatModerationSensitivity,
    double? feedModerationSensitivity,
    Map<String, String>? eventTriggers,
    bool? allowMention,
    String? bannerUrl,
    int? backgroundColorValue,
    String? customStatusPrefix,
  }) {
    return BotConfig(
      id: id,
      name: name ?? this.name,
      prefix: prefix ?? this.prefix,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      description: description ?? this.description,
      commands: commands ?? this.commands,
      isActive: isActive ?? this.isActive,
      creatorId: creatorId,
      createdAt: createdAt,
      statusType: statusType ?? this.statusType,
      statusText: statusText ?? this.statusText,
      embedColorValue: embedColorValue ?? this.embedColorValue,
      isGuardian: isGuardian ?? this.isGuardian,
      chatModerationSensitivity: chatModerationSensitivity ?? this.chatModerationSensitivity,
      feedModerationSensitivity: feedModerationSensitivity ?? this.feedModerationSensitivity,
      eventTriggers: eventTriggers ?? this.eventTriggers,
      allowMention: allowMention ?? this.allowMention,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      customStatusPrefix: customStatusPrefix ?? this.customStatusPrefix,
    );
  }

  @override
  List<Object?> get props => [
    id, name, prefix, avatarUrl, description, 
    commands, isActive, creatorId, createdAt,
    statusType, statusText, embedColorValue,
    isGuardian, chatModerationSensitivity, feedModerationSensitivity, eventTriggers, allowMention,
    bannerUrl, backgroundColorValue, customStatusPrefix
  ];
}
