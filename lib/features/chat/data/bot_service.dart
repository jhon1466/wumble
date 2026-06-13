import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/bot_framework.dart';
import '../domain/moderation_service.dart';
import '../../chat/domain/chat_model.dart';
import 'package:uuid/uuid.dart';

class BotService {
  static final BotService _instance = BotService._internal();
  factory BotService() => _instance;
  BotService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // Caching for community-specific bots
  final Map<String, _BotCache> _botsCache = {};
  
  // Caching for metadata variables (short-lived)
  final Map<String, _MetadataCache> _metadataCache = {};

  /// Analiza un mensaje y devuelve una respuesta de bot si coincide con un comando o mención.
  Future<ChatMessage?> processMessage(String text, String senderId, String communityId, {List<ChatMessage>? context, String? replyToBotId}) async {
    debugPrint('BotService: Processing message: "$text" for community: $communityId');
    
    if (communityId.isNotEmpty) {
      // 1. Check for community-specific bots (with Cache)
      try {
        List<BotConfig> botConfigs;
        
        final cached = _botsCache[communityId];
        if (cached != null && DateTime.now().difference(cached.timestamp).inMinutes < 5) {
          botConfigs = cached.bots;
          debugPrint('BotService: Using cached bots for community $communityId');
        } else {
          debugPrint('BotService: Fetching bots from Firestore for $communityId');
          final botsSnapshot = await _firestore
              .collection('communities')
              .doc(communityId)
              .collection('bots')
              .where('isActive', isEqualTo: true)
              .get();
          
          botConfigs = botsSnapshot.docs.map((doc) => BotConfig.fromFirestore(doc)).toList();
          _botsCache[communityId] = _BotCache(bots: botConfigs, timestamp: DateTime.now());
        }

        debugPrint('BotService: Found ${botConfigs.length} active bots for community $communityId');

        for (var bot in botConfigs) {
          bool isMatch = false;
          String commandText = '';

          // A. Check by Prefix (Traditional command)
          if (text.startsWith(bot.prefix)) {
            isMatch = true;
            commandText = text.substring(bot.prefix.length).trim();
          } 
          // B. Check by Mention (Anywhere in text if enabled) or Reply
          bool matchedBySpecial = false;
          if (bot.allowMention) {
            final botNameEscaped = RegExp.escape(bot.name);
            final botNameNoSpaces = RegExp.escape(bot.name.replaceAll(' ', ''));
            final mentionRegex = RegExp('@$botNameEscaped|@$botNameNoSpaces', caseSensitive: false);
            
            if (mentionRegex.hasMatch(text)) {
              isMatch = true;
              matchedBySpecial = true;
              debugPrint('BotService: Mention detected for bot ${bot.name}');
              commandText = text.replaceFirst(mentionRegex, '').trim();
              if (commandText.isEmpty) commandText = text; 
            }
          }

          if (!matchedBySpecial && replyToBotId == 'BOT_${bot.id}') {
            isMatch = true;
            commandText = text;
            debugPrint('BotService: Direct reply detected for bot ${bot.name}');
          }

          if (isMatch) {
            final String commandPart = commandText.isEmpty ? '' : commandText.split(' ')[0].toLowerCase();
            debugPrint('BotService: Command text: "$commandText", Part: "$commandPart"');
            
            BotCommand? matchedCommand;
            // 1. Exact Match (only if not a pure join/leave text)
            if (commandPart.isNotEmpty) {
              for (var command in bot.commands) {
                if (command.trigger == commandPart) {
                  matchedCommand = command;
                  break;
                }
              }
            }
            
            if (matchedCommand == null) {
              debugPrint('BotService: No exact command match for "$commandPart", checking fallback "*"');
              for (var command in bot.commands) {
                if (command.trigger == '*') {
                  matchedCommand = command;
                  break;
                }
              }
            }
            
            if (matchedCommand == null) {
              debugPrint('BotService: No command or "*" found for ${bot.name}');
            }

            if (matchedCommand != null) {
              final command = matchedCommand;
              // Check Permissions
              if (command.allowedRoles.isNotEmpty) {
                try {
                  final memberDoc = await _firestore
                      .collection('communities')
                      .doc(communityId)
                      .collection('members')
                      .doc(senderId)
                      .get();
                  
                  final userRole = memberDoc.data()?['role'] ?? 'member';
                  if (!command.allowedRoles.contains(userRole) && userRole != 'leader') {
                    debugPrint('BotService: Permission denied for role: $userRole');
                    continue; 
                  }
                } catch (e) {
                  debugPrint('BotService: Error checking permissions: $e');
                  continue;
                }
              }

              debugPrint('BotService: MATCH! Trigger found: ${command.trigger}');
              
              // Determine what text to send to the bot (the "arguments")
              String subText = commandText;
              if (command.trigger != '*' && commandPart == command.trigger) {
                // If it was a specific command, remove the trigger word from the start
                if (commandText.toLowerCase().startsWith(command.trigger.toLowerCase())) {
                   subText = commandText.substring(command.trigger.length).trim();
                }
              }
              
              // If subText is empty but it was a mention, use the full message for context
              if (subText.isEmpty) subText = text;

              return await _createBotMessage(bot, command, senderId, communityId, subText, context: context);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching community bots: $e');
      }
    } else {
      debugPrint('BotService: communityId is empty, skipping community bots check.');
    }

    // 2. Fallback to Global Assistant
    if (text.startsWith('/')) {
      final commandPart = text.substring(1).split(' ')[0].toLowerCase();
      if (commandPart == 'ping') {
        return _createAssistantMessage('¡Pong! 🏓 El sistema está respondiendo correctamente.');
      } else if (commandPart == 'ayuda') {
         return _createAssistantMessage('Comandos del Sistema:\n/ayuda - Muestra esto\n/ping - Prueba de latencia');
      }
    }

    return null;
  }

  /// Procesa un evento (onJoin, onLeave) y ejecuta comandos automáticos.
  Future<ChatMessage?> processEvent(String eventType, String userId, String communityId) async {
    debugPrint('BotService: Processing event: $eventType for user: $userId in community: $communityId');
    
    if (communityId.isEmpty) return null;

    try {
      List<BotConfig> botConfigs;
      final cached = _botsCache[communityId];
      if (cached != null && DateTime.now().difference(cached.timestamp).inMinutes < 10) {
        botConfigs = cached.bots;
      } else {
        final botsSnapshot = await _firestore
            .collection('communities')
            .doc(communityId)
            .collection('bots')
            .where('isActive', isEqualTo: true)
            .get();
        botConfigs = botsSnapshot.docs.map((doc) => BotConfig.fromFirestore(doc)).toList();
        _botsCache[communityId] = _BotCache(bots: botConfigs, timestamp: DateTime.now());
      }

      for (var bot in botConfigs) {
        // Check if event is mapped to a trigger
        final trigger = bot.eventTriggers[eventType];
        if (trigger != null && trigger.isNotEmpty) {
          debugPrint('BotService: Event $eventType matched trigger: $trigger for bot: ${bot.name}');
          
          // Find the command
          for (var command in bot.commands) {
            if (command.trigger == trigger) {
              return await _createBotMessage(bot, command, userId, communityId, 'EVENT_$eventType');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing bot event: $e');
    }
    
    return null;
  }

  BotCommand _getBestCommand(BotConfig bot, String text) {
    final String commandPart = text.split(' ')[0].toLowerCase().replaceFirst(bot.prefix, '');
    for (var cmd in bot.commands) {
      if (cmd.trigger == commandPart) return cmd;
    }
    // Fallback to wildcard
    return bot.commands.firstWhere((c) => c.trigger == '*', orElse: () => bot.commands.first);
  }

  Future<ChatMessage> _createBotMessage(BotConfig bot, BotCommand command, String senderId, String communityId, String text, {List<ChatMessage>? context}) async {
    // Pick random response if available
    String finalResponse = command.response;
    if (command.responses.isNotEmpty) {
      final allResponses = [command.response, ...command.responses];
      finalResponse = allResponses[_random.nextInt(allResponses.length)];
    }

    // Determine type
    MessageType type = MessageType.text;
    String? imageUrl = (command.type == BotResponseType.image || command.type == BotResponseType.gif) ? command.mediaUrl : null;
    String? embedTitle = command.title != null ? await _parseVariables(command.title!, senderId, communityId) : null;
    String? embedFooter = command.footerText != null ? await _parseVariables(command.footerText!, senderId, communityId) : null;
    List<BotButton> buttons = command.buttons;

    // --- AI PROVIDER INTEGRATION ---
    if ((command.provider == BotCommandProvider.groq || command.provider == BotCommandProvider.gemini) && command.apiKey != null) {
      String aiQuery = text;
      try {
        // Fetch sender name for better context
        final senderDoc = await _firestore
            .collection('communities')
            .doc(communityId)
            .collection('members')
            .doc(senderId)
            .get();
        final senderName = senderDoc.data()?['displayName'] ?? 'Usuario';
        aiQuery = 'Usuario ($senderName) dice: $text';
      } catch (e) {
        debugPrint('BotService: Could not fetch sender name for AI context: $e');
      }

      if (command.provider == BotCommandProvider.groq) {
        try {
          final aiResponse = await _callGroqDirect(command.apiKey!, command.aiModel ?? 'llama3-8b-8192', command.prompt, aiQuery, context: context, botId: 'BOT_${bot.id}');
          if (aiResponse != null) finalResponse = aiResponse;
        } catch (e) {
          debugPrint('Error calling Groq: $e');
        }
      } else if (command.provider == BotCommandProvider.gemini) {
        try {
          final aiResponse = await _callGeminiDirect(command.apiKey!, command.aiModel ?? 'gemini-1.5-flash', command.prompt, aiQuery, context: context, botId: 'BOT_${bot.id}');
          if (aiResponse != null) finalResponse = aiResponse;
        } catch (e) {
          debugPrint('Error calling Gemini: $e');
        }
      }
    }
    // --- WEBHOOK INTEGRATION (OLD/MANUAL) ---
    else if (command.provider == BotCommandProvider.webhook && command.webhookUrl != null && command.webhookUrl!.isNotEmpty) {
      try {
        final webhookData = await _callWebhook(command.webhookUrl!, senderId, communityId, text);
        if (webhookData != null) {
          if (webhookData['response'] != null) {
            finalResponse = webhookData['response'].toString();
          }
          // Dynamic overrides from webhook
          if (webhookData['imageUrl'] != null) {
            imageUrl = webhookData['imageUrl'].toString();
            type = MessageType.image;
          }
          if (webhookData['type'] == 'image' || webhookData['type'] == 'gif') {
            type = MessageType.image;
          }
          if (webhookData['embedTitle'] != null) {
            embedTitle = webhookData['embedTitle'].toString();
          }
          if (webhookData['embedFooter'] != null) {
            embedFooter = webhookData['embedFooter'].toString();
          }
          if (webhookData['buttons'] != null && webhookData['buttons'] is List) {
            buttons = (webhookData['buttons'] as List)
                .map((b) => BotButton.fromFirestore(b as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error calling bot webhook: $e');
      }
    }

    // Parse Variables again in case webhook returned text with variables
    if (finalResponse.contains('{')) {
      finalResponse = await _parseVariables(finalResponse, senderId, communityId);
    }

    return ChatMessage(
      id: const Uuid().v4(),
      senderId: 'BOT_${bot.id}',
      senderName: bot.name,
      senderAvatarUrl: bot.avatarUrl,
      text: finalResponse,
      type: type,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      isBotEmbed: command.isEmbed,
      embedTitle: embedTitle,
      embedFooter: embedFooter,
      embedColor: bot.embedColorValue,
      botButtons: buttons,
      botConfig: bot,
    );
  }

  Future<Map<String, dynamic>?> _callWebhook(String url, String senderId, String communityId, String text) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': senderId,
          'communityId': communityId,
          'text': text,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('BotService: Webhook error: $e');
    }
    return null;
  }

  Future<String?> _callGroqDirect(String apiKey, String model, String? prompt, String userText, {List<ChatMessage>? context, String? botId}) async {
    try {
      final List<Map<String, String>> messages = [];
      if (prompt != null && prompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': prompt});
      }

      // Add context
      if (context != null && context.isNotEmpty) {
        for (var msg in context) {
          if (msg.text != null) {
            final role = msg.senderId == botId ? 'assistant' : 'user';
            messages.add({'role': role, 'content': msg.text!});
          }
        }
      }

      // Add current text
      messages.add({'role': 'user', 'content': userText});

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'].toString();
        return _cleanAiResponse(content);
      } else {
        debugPrint('Groq Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error in _callGroqDirect: $e');
    }
    return null;
  }

  Future<String?> _callGeminiDirect(String apiKey, String model, String? prompt, String userText, {List<ChatMessage>? context, String? botId}) async {
    try {
      // Simplest Gemini API call (no stream)
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''${prompt ?? "Eres un asistente de IA."}
                  
Historial de conversación (contexto):
${context?.map((m) => "${m.senderName}: ${m.text}").join('\n') ?? 'Sin historial previo.'}

Pregunta actual:
$userText'''
                }
              ]
            }
          ],
          'generationConfig': {'maxOutputTokens': 800}
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'].toString();
        return _cleanAiResponse(content);
      } else {
        debugPrint('Gemini Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error in _callGeminiDirect: $e');
    }
    return null;
  }

  Future<String> _parseVariables(String text, String senderId, String communityId) async {
    if (!text.contains('{')) return text;

    String parsed = text;

    // 1. User Variable
    if (parsed.contains('{user}') || parsed.contains('{sender}')) {
      try {
        String userName = 'Usuario';
        final cacheKey = 'user_$senderId';
        final cached = _metadataCache[cacheKey];
        
        if (cached != null && DateTime.now().difference(cached.timestamp).inMinutes < 10) {
          userName = cached.value;
        } else {
          final userDoc = await _firestore.collection('users').doc(senderId).get();
          userName = userDoc.data()?['username'] ?? 'Usuario';
          _metadataCache[cacheKey] = _MetadataCache(value: userName, timestamp: DateTime.now());
        }
        parsed = parsed.replaceAll('{user}', userName).replaceAll('{sender}', userName);
      } catch (_) {}
    }

    // 2. Community Variable
    if (parsed.contains('{community}')) {
      try {
        String commName = 'Comunidad';
        final cacheKey = 'comm_$communityId';
        final cached = _metadataCache[cacheKey];

        if (cached != null && DateTime.now().difference(cached.timestamp).inMinutes < 10) {
          commName = cached.value;
        } else {
          final commDoc = await _firestore.collection('communities').doc(communityId).get();
          commName = commDoc.data()?['name'] ?? 'Comunidad';
          _metadataCache[cacheKey] = _MetadataCache(value: commName, timestamp: DateTime.now());
        }
        parsed = parsed.replaceAll('{community}', commName);
      } catch (_) {}
    }

    // 3. Time Variable
    if (parsed.contains('{time}')) {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      parsed = parsed.replaceAll('{time}', timeStr);
    }

    // 4. ID Variables
    parsed = parsed.replaceAll('{user_id}', senderId).replaceAll('{community_id}', communityId);

    return parsed;
  }

  ChatMessage _createAssistantMessage(String text) {
    return ChatMessage(
      id: const Uuid().v4(),
      senderId: 'BOT_Assistant',
      senderName: ModerationService.botName,
      senderAvatarUrl: ModerationService.botAvatar,
      text: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isBotEmbed: true,
      embedTitle: 'System Guard',
      embedColor: 0xFF2196F3,
    );
  }

  String _cleanAiResponse(String text) {
    // Remove everything between <think> and </think> (including the tags)
    // Using [\s\S]*? to handle newlines within the reasoning
    return text.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '').trim();
  }
}

class _BotCache {
  final List<BotConfig> bots;
  final DateTime timestamp;
  _BotCache({required this.bots, required this.timestamp});
}

class _MetadataCache {
  final String value;
  final DateTime timestamp;
  _MetadataCache({required this.value, required this.timestamp});
}
