import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wumble/core/services/notification_service.dart';
import 'package:wumble/features/community/domain/moderation_report_model.dart';
import 'package:nsfw_detector_flutter/nsfw_detector_flutter.dart';

enum ModerationLevel { low, medium, high }

class ModerationResult {
  final bool isFlagged;
  final String reason;
  final double confidence;

  ModerationResult({
    required this.isFlagged,
    this.reason = '',
    this.confidence = 0.0,
  });
}

class ModerationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Map<String, dynamic>? _systemConfig;
  static DateTime? _lastConfigFetch;

  /// Fetches the global moderation configuration from Firestore
  static Future<void> ensureConfig() async {
    if (_systemConfig != null && _lastConfigFetch != null && 
        DateTime.now().difference(_lastConfigFetch!).inMinutes < 5) {
      return;
    }
    
    try {
      final doc = await _firestore.collection('config').doc('system').get();
      if (doc.exists) {
        _systemConfig = doc.data();
        _lastConfigFetch = DateTime.now();
        debugPrint('ModerationService: Global config loaded: $_systemConfig');
      }
    } catch (e) {
      debugPrint('ModerationService: Error fetching config: $e');
    }
  }

  static String get botName => _systemConfig?['botName'] ?? 'System Assistant';
  static String get botAvatar => _systemConfig?['botAvatarUrl'] ?? '';

  static bool get workshopEnabled => _systemConfig?['workshopEnabled'] ?? true;
  static bool get reportsEnabled => _systemConfig?['reportsEnabled'] ?? false;
  static bool get groupMessagesEnabled => _systemConfig?['groupMessagesEnabled'] ?? true;

  // Lista de palabras tóxicas comunes
  static final List<String> _toxicKeywords = [
    // English
    'fuck', 'shit', 'nazi', 'racist', 'kill yourself', 'kys', 'porn', 'xxx',
    'idiot', 'dick', 'pussy', 'hentai', 'sext',
    // Spanish
    'pendejo', 'estupido', 'mierda', 'puta', 'gonorrea', 'malparido',
    'hijueputa', 'hp', 'perra', 'basura', 'culear', 'chingar', 'verga',
    'pito', 'mamon', 'cabron', 'zorra', 'maricon', 'puto', 'culero',
    'pajero', 'tetas', 'trasero', 'nalgas', 'penetracion', 'orgasmo',
    'desnuda', 'desnudo', 'sexo', 'coito', 'paja', 'mamada', 'zorrita',
    'bastardo', 'imbecil', 'idiota', 'estupida', 'putita', 'perrita',
    'follar', 'cojer', 'seks', 'pornografia', 'p0rn', 'narcotrafico',
    'sicario', 'muerte', 'asesinato', 'violacion', 'pedofilo', 'vagina',
    'pene', 'clitoris', 'ereccion', 'esperma', 'semen', 'escort', 'puton',
    'zorron', 'malparida', 'gonorriento', 'carechimba', 'chimba',
    'pirobo', 'webada', 'gilipollas', 'coño', 'joder'
  ];

  /// Mapeo para detección de Leetspeak/Bypass
  static final Map<String, String> _leetspeakMap = {
    '4': 'a',
    '@': 'a',
    '3': 'e',
    '1': 'i',
    '!': 'i',
    '0': 'o',
    '7': 't',
    '5': 's',
    r'$': 's',
    '8': 'b',
    '9': 'g',
    '2': 'z',
    'v': 'u',
  };

  /// Normalizes text for toxicity analysis
  static String _normalizeText(String text, {bool keepSpaces = false}) {
    // 1. Remove non-printable / zero-width characters
    String normalized = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    normalized = normalized.toLowerCase();
    
    // 2. Normalize accents (Spanish specific)
    normalized = normalized.replaceAll(RegExp(r'[áàäâ]'), 'a');
    normalized = normalized.replaceAll(RegExp(r'[éèëê]'), 'e');
    normalized = normalized.replaceAll(RegExp(r'[íìïî]'), 'i');
    normalized = normalized.replaceAll(RegExp(r'[óòöô]'), 'o');
    normalized = normalized.replaceAll(RegExp(r'[úùüû]'), 'u');
    normalized = normalized.replaceAll(RegExp(r'[ñ]'), 'n');

    // 3. Remove non-alphanumeric characters but optionally keep spaces
    if (keepSpaces) {
      normalized = normalized.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
      normalized = normalized.replaceAll(RegExp(r'\s+'), ' '); // Collapse spaces
    } else {
      normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    }
    
    // 4. Leetspeak substitution
    _leetspeakMap.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });

    // 5. Remove character repetitions (e.g., "mooooortallll" -> "mortal")
    if (normalized.length > 1) {
      final buffer = StringBuffer();
      buffer.write(normalized[0]);
      for (int i = 1; i < normalized.length; i++) {
        if (normalized[i] != normalized[i - 1] || (keepSpaces && normalized[i] == ' ')) {
          buffer.write(normalized[i]);
        }
      }
      normalized = buffer.toString();
    }
    
    return normalized.trim();
  }

  /// Detects if text likely has a poetic structure (short lines, multiple breaks)
  static bool _isPoetic(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 3) return false;
    
    int shortLines = 0;
    for (var line in lines) {
      if (line.trim().length < 50) shortLines++;
    }
    
    // If more than 70% of lines are "short", it's likely a poem or list
    return (shortLines / lines.length) > 0.7;
  }

  /// Calculates Levenshtein Distance between two strings
  static int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  /// Analyzes text for toxicity/spam with fuzzy matching
  static Future<ModerationResult> analyzeText(String text, {ModerationLevel? level}) async {
    if (text.isEmpty) return ModerationResult(isFlagged: false);

    await ensureConfig();
    
    // Determine level: passed param > global config > default medium
    ModerationLevel actualLevel = level ?? ModerationLevel.medium;
    if (level == null && _systemConfig != null) {
      final globalLevel = _systemConfig!['textModerationLevel'];
      if (globalLevel == 'low') actualLevel = ModerationLevel.low;
      else if (globalLevel == 'high') actualLevel = ModerationLevel.high;
    }

    double maxConfidence = 0.0;
    String matchedReason = '';

    // 1. Context Check: Is it a poem?
    final isPoem = _isPoetic(text);
    double sensitivityModifier = isPoem ? 0.7 : 1.0;

    // 2. Fast Scan (Preserving spaces to detect whole words)
    final normalizedWithSpaces = _normalizeText(text, keepSpaces: true);
    final words = normalizedWithSpaces.split(' ');
    
    for (var word in _toxicKeywords) {
      if (words.contains(word)) {
        maxConfidence = 0.95;
        matchedReason = 'LENGUAJE INAPROPIADO';
        break;
      }
    }

    // 3. Advanced Bypass Scan (No spaces)
    if (maxConfidence < 0.9 && actualLevel != ModerationLevel.low) {
      final ultraNormalized = _normalizeText(text, keepSpaces: false);
      
      for (var word in _toxicKeywords) {
        // Only trigger bypass if the match is distinct and not too long away
        // Or if the content is not poetic
        if (ultraNormalized.contains(word)) {
          // PROTECTION: Avoid Scunthorpe problem (substrings of valid words)
          // If the match is in ultraNormalized but NOT in normalizedWithSpaces as a word
          bool isLikelyFalsePositive = isPoem && word.length < 6;
          
          if (!isLikelyFalsePositive) {
            maxConfidence = 0.98 * sensitivityModifier;
            matchedReason = 'DETECCIÓN DE EVASIÓN (Bypass)';
            break;
          }
        }
        
        // Fuzzy matching (Level High ONLY)
        if (actualLevel == ModerationLevel.high && word.length > 4) {
          for (int i = 0; i <= ultraNormalized.length - word.length; i++) {
              final sub = ultraNormalized.substring(i, i + word.length);
              final dist = _levenshtein(sub, word);
              if (dist <= 1) {
                maxConfidence = max(maxConfidence, 0.85 * sensitivityModifier);
                matchedReason = 'CONTENIDO LÍMITE (Fuzzy)';
              }
          }
        }
      }
    }

    // 3. Spam Detection
    if (maxConfidence < 0.8 && _isSpam(text)) {
      maxConfidence = 0.9;
      matchedReason = 'SPAM DETECTADO';
    }

    // Decision Logic:
    // High sensitivity level = lower block threshold
    double blockThreshold = 0.8;
    if (actualLevel == ModerationLevel.high) blockThreshold = 0.7;
    if (actualLevel == ModerationLevel.low) blockThreshold = 0.9;

    return ModerationResult(
      isFlagged: maxConfidence >= blockThreshold,
      reason: matchedReason,
      confidence: maxConfidence,
    );
  }

  /// Creates a moderation report in the community's moderation_reports collection
  static Future<void> reportToModerators({
    required String communityId,
    required String reporterId,
    required String targetId,
    required String targetUserId,
    required ModerationTargetType targetType,
    required String contentPreview,
    String? mediaUrl,
    required String reason,
    double confidenceScore = 0.5,
  }) async {
    await ensureConfig();
    if (!reportsEnabled) {
      debugPrint('ModerationService: Reporting is globally disabled. Skipping report.');
      return;
    }

    try {
      final reportRef = _firestore
          .collection('communities')
          .doc(communityId)
          .collection('moderation_reports')
          .doc();
      
      final report = ModerationReport(
        id: reportRef.id,
        communityId: communityId,
        reporterId: reporterId,
        targetId: targetId,
        targetUserId: targetUserId,
        targetType: targetType,
        contentPreview: contentPreview,
        mediaUrl: mediaUrl,
        reason: reason,
        createdAt: DateTime.now(),
        confidenceScore: confidenceScore,
      );

      await reportRef.set(report.toFirestore());
      
      // Trigger a local notification for moderators (simulation for now)
      // In a real app, this would be handled by a Cloud Function trigger on 'moderation_reports'
      _notifyModeratorsLocally(communityId, report);
      
    } catch (e) {
      debugPrint('Error creating moderation report: $e');
    }
  }

  static void _notifyModeratorsLocally(String communityId, ModerationReport report) {
     // Trigger a local notification to simulate the alert for moderators
     NotificationService.showLocalNotification(
       id: report.id.hashCode,
       title: '🛡️ ALERTA DE MODERACIÓN',
       body: 'La IA ha detectado contenido sospechoso: ${report.reason}',
       data: {
         'type': 'moderation_report',
         'communityId': communityId,
         'reportId': report.id,
       },
     );
     debugPrint('NOTIFICACIÓN DE MODERACIÓN: Nuevo reporte en $communityId (${report.reason})');
  }

  /// Analyzes image for safety
  static Future<ModerationResult> analyzeImage(dynamic imageSource, {ModerationLevel? level}) async {
    try {
      await ensureConfig();
      debugPrint('--- ModerationService.analyzeImage START ---');
      // imageSource can be File (mobile) or XFile/String (web)
      String fileName = '';
      if (kIsWeb) {
        debugPrint('Moderation: Web mode - Skipping for now');
        return ModerationResult(isFlagged: false);
      } else if (imageSource is File) {
        fileName = imageSource.path.toLowerCase();
        debugPrint('Moderation: File path: $fileName');
      }

      // 1. Heuristic Scan (Filename/Metadata)
      if (fileName.contains('porn') || fileName.contains('xxx') || fileName.contains('nude') || 
          fileName.contains('sex') || fileName.contains('sext') || fileName.contains('hentai') ||
          fileName.contains('erot') || fileName.contains('desnud')) {
         debugPrint('Moderation: BLOCKED by heuristics');
         return ModerationResult(isFlagged: true, reason: 'IMAGEN INAPROPIADA (METADATOS)', confidence: 1.0);
      }

      // 2. Neural Visual Scan (Pixel-level analysis)
      if (!kIsWeb && imageSource is File) {
        debugPrint('Moderation: Starting Visual Scan...');
        final visualResult = await _analyzeImageVisually(imageSource);
        debugPrint('Moderation: Visual Scan Result: ${visualResult.isFlagged}');
        if (visualResult.isFlagged) return visualResult;
      }

      debugPrint('Moderation: ALLOWED');
      return ModerationResult(isFlagged: false);
    } catch (e) {
      debugPrint('Error en ModerationService.analyzeImage: $e');
      return ModerationResult(isFlagged: false);
    }
  }

  /// Performs deep neural analysis of the image using a specialized TFLite NSFW model (OpenNSFW)
  /// This model distinguishes intelligently between safe content (gym/beach) and explicit content.
  /// 
  /// Decision zones (calibrated to minimize false positives):
  /// - 0.00 – 0.60: SAFE → Allow without hesitation (clothed people, gym, beach, memes, art)
  /// - 0.60 – 0.75: GREY ZONE → Allow but log for optional manual review
  /// - 0.75 – 1.00: BLOCK → Clearly explicit content, block immediately
  static Future<ModerationResult> _analyzeImageVisually(File file) async {
    try {
      debugPrint('Moderation: Starting specialized TFLite analysis...');
      
      // Load the model — the threshold here is for the model's internal isNsfw boolean,
      // but we override with our own smarter logic below.
      final double configThreshold = (_systemConfig?['imageModerationThreshold'] as num?)?.toDouble() ?? 0.75;
      final detector = await NsfwDetector.load(threshold: configThreshold);
      
      // Analyze the file using the instance
      final nsfwResult = await detector.detectNSFWFromFile(file);
      
      if (nsfwResult == null) {
        debugPrint('Moderation: Detection failed (result is null)');
        return ModerationResult(isFlagged: false);
      }
      
      final double score = nsfwResult.score;
      
      debugPrint('Moderation: NSFW Score: ${score.toStringAsFixed(4)} (threshold: $configThreshold)');

      // --- CALIBRATED DECISION ENGINE ---
      // OpenNSFW models are notoriously aggressive with skin tones, beaches, 
      // fitness content, and artistic images. A 0.5 threshold causes massive
      // false positives in a social network context.
      //
      // Only block when we are HIGHLY confident the content is explicit.

      if (score >= configThreshold) {
        // HIGH CONFIDENCE: Block
        final String reason = score >= 0.9
            ? 'CONTENIDO EXPLÍCITO DETECTADO'
            : 'PROBABILIDAD ALTA DE CONTENIDO INAPROPIADO';
        debugPrint('Moderation: BLOCKED (score: ${score.toStringAsFixed(4)})');
        return ModerationResult(
          isFlagged: true, 
          reason: reason, 
          confidence: score,
        );
      }
      
      if (score >= 0.6) {
        // GREY ZONE: Allow but return a non-zero confidence so callers can
        // optionally report for manual review without blocking the user.
        debugPrint('Moderation: Grey zone (score: ${score.toStringAsFixed(4)}) — allowed but logged');
        return ModerationResult(isFlagged: false, confidence: score);
      }
      
      // SAFE: Nothing to worry about
      debugPrint('Moderation: SAFE (score: ${score.toStringAsFixed(4)})');
      return ModerationResult(isFlagged: false);
    } catch (e) {
      debugPrint('Moderation: Error in visual analysis: $e');
      // Fallback: If the model fails, allow but log the error
      return ModerationResult(isFlagged: false);
    }
  }

  static bool _isSpam(String text) {
    if (text.length < 10) return false;
    final words = text.split(' ');
    if (words.length > 5 && words.every((w) => w == words[0])) return true;
    
    int maxRep = 0;
    int currentRep = 1;
    for (int i = 1; i < text.length; i++) {
        if (text[i] == text[i - 1]) {
            currentRep++;
            if (currentRep > maxRep) maxRep = currentRep;
        } else {
            currentRep = 1;
        }
    }
    return maxRep > 15;
  }
}
