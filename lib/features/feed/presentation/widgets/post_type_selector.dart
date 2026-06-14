import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../../core/theme.dart';
import '../blog_editor_screen.dart';
import '../wiki_editor_screen.dart';
import '../poll_editor_screen.dart';

class PostTypeSelector extends StatelessWidget {
  const PostTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Wumbleheme.backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            tr('¿Qué quieres publicar?'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            children: [
              _PostTypeButton(
                label: 'Blog',
                icon: Icons.article_outlined,
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BlogEditorScreen()),
                  );
                },
              ),
              _PostTypeButton(
                label: 'Wiki',
                icon: Icons.book_outlined,
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WikiEditorScreen()),
                  );
                },
              ),
              _PostTypeButton(
                label: 'Personaje',
                icon: Icons.face_retouching_natural,
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => WikiEditorScreen(isOC: true)),
                  );
                },
              ),
              _PostTypeButton(
                label: 'Encuesta',
                icon: Icons.poll_outlined,
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PollEditorScreen()),
                  );
                },
              ),
              _PostTypeButton(
                label: 'Quiz',
                icon: Icons.extension_outlined,
                color: Colors.purple,
                onTap: () {},
              ),
              _PostTypeButton(
                label: 'Pregunta',
                icon: Icons.help_outline_rounded,
                color: Colors.pink,
                onTap: () {},
              ),
              _PostTypeButton(
                label: 'Link',
                icon: Icons.link_rounded,
                color: Colors.cyan,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PostTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PostTypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
