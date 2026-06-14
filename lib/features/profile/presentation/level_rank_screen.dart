import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../../core/theme.dart';
import '../domain/user_model.dart';
import '../../community/domain/reputation_service.dart';

class LevelRankScreen extends StatelessWidget {
  final UserProfile user;
  final Map<String, String>? levelTitles;
  final Color themeColor;

  LevelRankScreen({
    super.key, 
    required this.user, 
    this.levelTitles,
    this.themeColor = Wumbleheme.secondaryColor,
  });

  List<Map<String, dynamic>> _generateLevels() {
    final List<Map<String, dynamic>> generated = [];
    final thresholds = ReputationService.levelThresholds;
    
    for (int i = 1; i <= 20; i++) {
      generated.add({
        'level': i,
        'name': ReputationService.getLevelTitle(i, levelTitles),
        'xp': thresholds[i] ?? 0,
        'color': _getLevelColor(i),
      });
    }
    return generated;
  }

  Color _getLevelColor(int level) {
    if (level < 5) return Colors.grey;
    if (level < 10) return Colors.blue;
    if (level < 15) return Colors.green;
    if (level < 20) return Colors.orange;
    return Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    final levels = _generateLevels();
    
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Wumbleheme.backgroundColor,
        title: Text(tr('Niveles y Títulos')),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentStatus(context, levels),
            SizedBox(height: 32),
            Text(
              tr('Rangos de Reputación'),
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: levels.length,
              separatorBuilder: (context, index) => Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final lvl = levels[index];
                final bool isUnlocked = user.reputation >= lvl['xp'];
                final bool isCurrent = user.level == lvl['level'];
                
                return Container(
                  decoration: BoxDecoration(
                    color: isCurrent ? themeColor.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: lvl['color'].withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUnlocked ? lvl['color'] : Colors.white10, 
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${lvl['level']}',
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : Colors.white24,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      lvl['name'],
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.white24,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${lvl['xp']} REP', 
                      style: const TextStyle(color: Colors.white12, fontSize: 11),
                    ),
                    trailing: isCurrent 
                      ? Icon(Icons.stars_rounded, color: themeColor, size: 24)
                      : Icon(
                          isUnlocked ? Icons.check_circle_outline : Icons.lock_outline,
                          size: 18,
                          color: isUnlocked ? themeColor.withOpacity(0.5) : Colors.white12,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatus(BuildContext context, List<Map<String, dynamic>> levels) {
    // Buscar rango actual
    Map<String, dynamic> currentRank = levels.first;
    Map<String, dynamic>? nextRank;

    for (int i = 0; i < levels.length; i++) {
      if (user.reputation >= levels[i]['xp']) {
        currentRank = levels[i];
        if (i + 1 < levels.length) {
          nextRank = levels[i + 1];
        }
      }
    }

    double progress = 1.0;
    int repMissing = 0;
    if (nextRank != null) {
      int range = nextRank['xp'] - currentRank['xp'];
      int currentInLevel = (user.reputation - currentRank['xp']).toInt();
      progress = (currentInLevel / range).clamp(0.0, 1.0);
      repMissing = nextRank['xp'] - user.reputation;
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Wumbleheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('TU REPUTACIÓN'), 
                    style: TextStyle(
                      color: Colors.white38, 
                      fontSize: 10, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user.reputation}', 
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900, 
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: currentRank['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentRank['color'].withOpacity(0.3)),
                ),
                child: Text(
                  'LV ${user.level}',
                  style: TextStyle(
                    color: currentRank['color'],
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(currentRank['color']),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentRank['name'],
                style: TextStyle(
                  color: Colors.white70, 
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (nextRank != null)
                Text(
                  'Faltan $repMissing REP para el siguiente nivel', 
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                )
              else
                Text(
                  tr('¡HAS ALCANZADO EL RANGO MÁXIMO!'), 
                  style: TextStyle(
                    color: Colors.amber, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
