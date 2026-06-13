import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../domain/poll_model.dart';
import '../../domain/feed_repository.dart';
import '../../../../injection_container.dart' as di;
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/domain/user_model.dart';
import '../../../community/domain/community_member_model.dart';

class CreatePollScreen extends StatefulWidget {
  final String communityId;
  final Color themeColor;
  final Poll? poll;

  const CreatePollScreen({
    super.key, 
    required this.communityId, 
    this.themeColor = Colors.blueAccent,
    this.poll,
  });

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _durationDays = 3;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.poll != null) {
      _questionController.text = widget.poll!.question;
      _durationDays = widget.poll!.durationDays;
      // Clear initial empty controllers and load poll options
      _optionControllers.clear();
      for (var opt in widget.poll!.options) {
        _optionControllers.add(TextEditingController(text: opt.text));
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 5) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitPoll() async {
    final question = _questionController.text.trim();
    final optionsText = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa una pregunta.')),
      );
      return;
    }

    if (optionsText.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requieren al menos 2 opciones.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Obtener el perfil de la comunidad o global para el nombre y avatar
      final profileRepo = di.sl<ProfileRepository>();
      final member = await profileRepo.getMemberProfile(widget.communityId, user.uid);
      
      String authorName = user.displayName ?? 'Usuario';
      String authorAvatar = user.photoURL ?? '';

      if (member != null) {
        authorName = member.displayName ?? authorName;
        authorAvatar = member.avatarUrl ?? authorAvatar;
      } else {
        // Fallback al perfil global si no hay perfil de comunidad
        final globalProfile = await profileRepo.getUserProfile(user.uid).first;
        authorName = globalProfile.displayName;
        authorAvatar = globalProfile.avatarUrl;
      }

      // In a real app, we'd fetch the user's display name and avatar
      final poll = Poll(
        id: widget.poll?.id ?? '', 
        creatorId: user.uid,
        creatorName: authorName,
        creatorAvatarUrl: authorAvatar,
        communityId: widget.communityId,
        question: question,
        options: optionsText.map((text) {
          // If editing, try to keep existing IDs for options if possible (not strictly necessary here but good practice)
          return PollOption(id: const Uuid().v4(), text: text);
        }).toList(),
        durationDays: _durationDays,
        endsAt: widget.poll?.endsAt ?? DateTime.now().add(Duration(days: _durationDays)),
        createdAt: widget.poll?.createdAt ?? DateTime.now(),
      );

      if (widget.poll != null) {
        await di.sl<FeedRepository>().updatePoll(poll);
      } else {
        await di.sl<FeedRepository>().createPoll(poll);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.poll != null ? 'Encuesta actualizada con éxito' : 'Encuesta creada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.poll != null ? 'Editar Encuesta' : 'Nueva Encuesta', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPoll,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.poll != null ? 'GUARDAR' : 'PUBLICAR', style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _questionController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Haz una pregunta...',
                hintStyle: const TextStyle(color: Colors.white30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Opciones',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._optionControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Opción ${index + 1}',
                          hintStyle: const TextStyle(color: Colors.white24),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () => _removeOption(index),
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 5)
              TextButton.icon(
                onPressed: _addOption,
                icon: Icon(Icons.add, color: widget.themeColor),
                label: Text('Agregar opción', style: TextStyle(color: widget.themeColor)),
              ),
            const SizedBox(height: 24),
            const Text(
              'Duración de la encuesta',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _durationDays,
                  dropdownColor: const Color(0xFF1E1E2C),
                  style: const TextStyle(color: Colors.white),
                  items: [1, 3, 5, 7, 14, 30].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value ${value == 1 ? 'día' : 'días'}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _durationDays = val);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
