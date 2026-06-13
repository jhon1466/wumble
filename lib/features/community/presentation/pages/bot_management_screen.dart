import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/community_repository.dart';
import '../../domain/community_model.dart';
import '../../../chat/domain/bot_framework.dart';
import 'bot_editor_screen.dart';
import 'package:uuid/uuid.dart';

class BotManagementScreen extends StatelessWidget {
  final Community community;

  const BotManagementScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Bots'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewBot(context),
          ),
        ],
      ),
      body: StreamBuilder<List<BotConfig>>(
        stream: di.sl<CommunityRepository>().getCommunityBots(community.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bots = snapshot.data ?? [];
          if (bots.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('No hay bots en esta comunidad', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _createNewBot(context),
                    style: ElevatedButton.styleFrom(backgroundColor: community.themeColor),
                    child: const Text('Crear Primer Bot'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: bots.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final bot = bots[index];
              return Card(
                color: Wumbleheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: bot.avatarUrl.isNotEmpty ? NetworkImage(bot.avatarUrl) : null,
                    backgroundColor: community.themeColor.withOpacity(0.2),
                    child: bot.avatarUrl.isEmpty ? const Icon(Icons.smart_toy) : null,
                  ),
                  title: Text(bot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Prefijo: ${bot.prefix} • ${bot.commands.length} comandos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BotEditorScreen(community: community, bot: bot),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _createNewBot(BuildContext context) {
    final newBot = BotConfig(
      id: const Uuid().v4(),
      name: 'Nuevo Bot',
      prefix: '!',
      avatarUrl: '',
      creatorId: '', // Ideally current user ID
      createdAt: DateTime.now(),
      commands: const [
        BotCommand(trigger: 'hola', response: '¡Hola! Soy un bot personalizado.'),
      ],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BotEditorScreen(community: community, bot: newBot, isNew: true),
      ),
    );
  }
}
