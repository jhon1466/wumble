import 'package:flutter/material.dart';
import '../../domain/quiz_model.dart';
import '../../domain/feed_repository.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/quiz_play_screen.dart';
import '../pages/create_quiz_screen.dart';
import '../../../../core/widgets/user_avatar.dart';

class QuizListWidget extends StatefulWidget {
  final String communityId;

  const QuizListWidget({super.key, required this.communityId});

  @override
  State<QuizListWidget> createState() => QuizListWidgetState();
}

class QuizListWidgetState extends State<QuizListWidget> with AutomaticKeepAliveClientMixin {
  late Future<List<Quiz>> _quizzesFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  void refresh() {
    if (mounted) {
      setState(() {
        _loadQuizzes();
      });
    }
  }

  void _loadQuizzes() {
    _quizzesFuture = di.sl<FeedRepository>().getCommunityQuizzes(widget.communityId);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadQuizzes();
    });
    await _quizzesFuture;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1E1E2C),
      child: FutureBuilder<List<Quiz>>(
        future: _quizzesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          }
          final quizzes = snapshot.data ?? [];
          if (quizzes.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const Center(
                    child: Text('No hay quizzes aún.', style: TextStyle(color: Colors.white38)),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return _QuizCard(quiz: quiz, onPlay: () => setState(() => _loadQuizzes()));
            },
          );
        },
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final Quiz quiz;
  final VoidCallback onPlay;

  const _QuizCard({required this.quiz, required this.onPlay});

  void _showPlayDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(quiz.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('${quiz.questions.length} preguntas • ${quiz.playCount} jugadas', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),
            _buildPlayOption(
              context, 
              label: 'Jugar (Normal)', 
              icon: Icons.play_arrow_rounded, 
              color: Colors.blueAccent, 
              onTap: () => _startQuiz(context, false),
            ),
            const SizedBox(height: 12),
            _buildPlayOption(
              context, 
              label: 'Modo Infernal (Difícil)', 
              icon: Icons.local_fire_department_rounded, 
              color: Colors.redAccent, 
              onTap: () => _startQuiz(context, true),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _startQuiz(BuildContext context, bool hardMode) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz, isHardMode: hardMode)),
    ).then((_) => onPlay());
  }

  void _showOptionsMenu(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != quiz.creatorId) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white70),
              title: const Text('Editar Quiz', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateQuizScreen(
                      communityId: quiz.communityId,
                      quiz: quiz,
                    ),
                  ),
                ).then((value) {
                  if (value == true) onPlay();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Eliminar Quiz', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E2C),
                    title: const Text('¿Eliminar Quiz?', style: TextStyle(color: Colors.white)),
                    content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (context.mounted) Navigator.pop(context);
                  await di.sl<FeedRepository>().deleteQuiz(quiz.id);
                  onPlay();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayOption(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        onTap: () => _showPlayDialog(context),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quiz.imageUrl != null && quiz.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: quiz.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        userId: quiz.creatorId,
                        avatarUrl: quiz.creatorAvatarUrl,
                        displayName: quiz.creatorName,
                        radius: 10,
                        communityId: quiz.communityId,
                        isAnimated: false,
                      ),
                      const SizedBox(width: 8),
                      Text(quiz.creatorName, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      const Spacer(),
                      if (FirebaseAuth.instance.currentUser?.uid == quiz.creatorId)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
                          onPressed: () => _showOptionsMenu(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quiz.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quiz.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _QuizBadge(icon: Icons.help_outline, label: '${quiz.questions.length} preg.'),
                      const SizedBox(width: 12),
                      _QuizBadge(icon: Icons.play_arrow_rounded, label: '${quiz.playCount} veces jugado'),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuizBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
