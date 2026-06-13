class ReputationService {
  static const Map<int, int> levelThresholds = {
    1: 0,
    2: 20,
    3: 50,
    4: 100,
    5: 250,
    6: 500,
    7: 1000,
    8: 2000,
    9: 4000,
    10: 7000,
    11: 10000,
    12: 15000,
    13: 25000,
    14: 40000,
    15: 60000,
    16: 85000,
    17: 120000,
    18: 200000,
    19: 350000,
    20: 500000,
  };

  static int getLevel(int reputation) {
    int currentLevel = 1;
    for (int level = 1; level <= 20; level++) {
      if (reputation >= (levelThresholds[level] ?? 0)) {
        currentLevel = level;
      } else {
        break;
      }
    }
    return currentLevel;
  }

  static double getLevelProgress(int? reputation) {
    if (reputation == null) return 0.0;
    int currentLevel = getLevel(reputation);
    if (currentLevel >= 20) return 1.0;

    int currentThreshold = levelThresholds[currentLevel] ?? 0;
    int nextThreshold = levelThresholds[currentLevel + 1] ?? (currentThreshold + 1);

    if (nextThreshold <= currentThreshold) return 1.0;

    final progress = (reputation - currentThreshold) / (nextThreshold - currentThreshold);
    return progress.clamp(0.0, 1.0).toDouble();
  }

  static int getPointsToNextLevel(int reputation) {
    int currentLevel = getLevel(reputation);
    if (currentLevel >= 20) return 0;

    int nextThreshold = levelThresholds[currentLevel + 1] ?? 0;
    return nextThreshold - reputation;
  }

  static String getLevelTitle(int level, Map<String, dynamic>? customTitles) {
    if (customTitles != null && customTitles.containsKey(level.toString())) {
      return customTitles[level.toString()];
    }

    // Default titles if none provided
    const defaultTitles = {
      1: 'Nuevo',
      2: 'Principiante',
      3: 'Aprendiz',
      4: 'Iniciado',
      5: 'Miembro',
      6: 'Senior',
      7: 'Experto',
      8: 'Veterano',
      9: 'Maestro',
      10: 'Héroe',
      11: 'Guardián',
      12: 'Legendario',
      13: 'Místico',
      14: 'Divino',
      15: 'Inmortal',
      16: 'Celestial',
      17: 'Trascendente',
      18: 'Supremo',
      19: 'Omnisciente',
      20: 'Dios de la Comunidad',
    };

    return defaultTitles[level] ?? 'Miembro';
  }
}
