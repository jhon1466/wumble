
class ModerationResult {
  final bool isFlagged;
  final String reason;
  final double confidence;
  ModerationResult({required this.isFlagged, this.reason = '', this.confidence = 0.0});
}

enum ModerationLevel { low, medium, high }

class ModerationServiceMock {
  static final List<String> _toxicKeywords = [
    'fuck', 'shit', 'nazi', 'racist', 'kill yourself', 'kys', 'porn', 'xxx',
    'idiot', 'dick', 'pussy', 'hentai', 'sext',
    'pendejo', 'estupido', 'mierda', 'puta', 'gonorrea', 'malparido',
    'pene', 'paja'
  ];

  static final Map<String, String> _leetspeakMap = {'4': 'a', '@': 'a', '3': 'e', '1': 'i', '!': 'i', '0': 'o', '7': 't', '5': 's', '8': 'b', '9': 'g', '2': 'z', 'v': 'u'};

  static String _normalizeText(String text, {bool keepSpaces = false}) {
    String normalized = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    normalized = normalized.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[áàäâ]'), 'a').replaceAll(RegExp(r'[éèëê]'), 'e').replaceAll(RegExp(r'[íìïî]'), 'i').replaceAll(RegExp(r'[óòöô]'), 'o').replaceAll(RegExp(r'[úùüû]'), 'u').replaceAll(RegExp(r'[ñ]'), 'n');
    if (keepSpaces) {
      normalized = normalized.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    } else {
      normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    }
    _leetspeakMap.forEach((key, value) => normalized = normalized.replaceAll(key, value));
    if (normalized.length > 1) {
      final buffer = StringBuffer()..write(normalized[0]);
      for (int i = 1; i < normalized.length; i++) {
        if (normalized[i] != normalized[i - 1] || (keepSpaces && normalized[i] == ' ')) buffer.write(normalized[i]);
      }
      normalized = buffer.toString();
    }
    return normalized.trim();
  }

  static bool _isPoetic(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 3) return false;
    int shortLines = 0;
    for (var line in lines) if (line.trim().length < 50) shortLines++;
    return (shortLines / lines.length) > 0.7;
  }

  static Future<ModerationResult> analyzeText(String text, {ModerationLevel level = ModerationLevel.medium}) async {
    final isPoem = _isPoetic(text);
    double sensitivityModifier = isPoem ? 0.7 : 1.0;
    final normalizedWithSpaces = _normalizeText(text, keepSpaces: true);
    final words = normalizedWithSpaces.split(' ');
    double maxConfidence = 0.0;
    String matchedReason = '';

    for (var word in _toxicKeywords) {
      if (words.contains(word)) {
        maxConfidence = 0.95;
        matchedReason = 'LENGUAJE INAPROPIADO';
        break;
      }
    }

    if (maxConfidence < 0.9 && level != ModerationLevel.low) {
      final ultraNormalized = _normalizeText(text, keepSpaces: false);
      for (var word in _toxicKeywords) {
        if (ultraNormalized.contains(word)) {
          bool isLikelyFalsePositive = isPoem && word.length < 6;
          if (!isLikelyFalsePositive) {
            maxConfidence = 0.98 * sensitivityModifier;
            matchedReason = 'DETECCIÓN DE EVASIÓN (Bypass)';
            break;
          }
        }
      }
    }
    double blockThreshold = 0.8;
    if (level == ModerationLevel.high) blockThreshold = 0.7;
    if (level == ModerationLevel.low) blockThreshold = 0.9;
    return ModerationResult(isFlagged: maxConfidence >= blockThreshold, reason: matchedReason, confidence: maxConfidence);
  }
}

void main() async {
  final poem = '''Me encuentro una vez mas,
Sentada en el mismo lugar,
El mismo cuarto de paredes blancas,
La misma cama de cobijas grises,
El mismo aire tibio y gastado,
Repidiendo mi nombre sin voz.
Me pierdo en la inmensidad de mi.''';

  final result = await ModerationServiceMock.analyzeText(poem);
  print('Poem Result: Flagged=${result.isFlagged}, Reason=${result.reason}, Confidence=${result.confidence}');

  final insult = 'p.u.t.a';
  final result2 = await ModerationServiceMock.analyzeText(insult);
  print('Insult Result: Flagged=${result2.isFlagged}, Reason=${result2.reason}, Confidence=${result2.confidence}');
}
