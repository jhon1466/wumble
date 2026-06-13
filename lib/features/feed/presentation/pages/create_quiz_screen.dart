import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/utils/media_helper.dart';
import '../../domain/quiz_model.dart';
import '../../domain/feed_repository.dart';
import '../../../../injection_container.dart' as di;
import '../../../../core/services/storage_service.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/domain/user_model.dart';
import '../../../community/domain/community_member_model.dart';

class CreateQuizScreen extends StatefulWidget {
  final String communityId;
  final Color themeColor;
  final Quiz? quiz;

  const CreateQuizScreen({
    super.key, 
    required this.communityId, 
    this.themeColor = Colors.blueAccent,
    this.quiz,
  });

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _quizImage;
  final List<_QuestionEditorData> _questions = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.quiz != null) {
      _titleController.text = widget.quiz!.title;
      _descriptionController.text = widget.quiz!.description;
      // Note: For editing, we don't load the file into _quizImage 
      // because we already have the URL in the Quiz model.
      for (var q in widget.quiz!.questions) {
        final data = _QuestionEditorData();
        data.textController.text = q.text;
        data.correctIndex = q.correctOptionIndex;
        data.explanationController.text = q.explanation ?? '';
        for (var i = 0; i < q.options.length; i++) {
          data.optionControllers[i].text = q.options[i];
        }
        _questions.add(data);
      }
    } else {
      _addQuestion();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionEditorData());
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions[index].dispose();
        _questions.removeAt(index);
      });
    }
  }

  Future<void> _pickQuizImage() async {
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      setState(() => _quizImage = File(image.path));
    }
  }

  Future<void> _submitQuiz() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un título')));
      return;
    }

    // Basic validation for questions
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('La pregunta ${i + 1} está vacía')));
        return;
      }
      for (var j = 0; j < 4; j++) {
        if (q.optionControllers[j].text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falta la opción ${j + 1} en la pregunta ${i + 1}')));
          return;
        }
      }
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

      final storage = di.sl<StorageService>();
      String? quizImageUrl;
      if (_quizImage != null) {
        quizImageUrl = await storage.uploadPostImage(_quizImage!, folder: 'quizzes');
      }

      final List<QuizQuestion> finalQuestions = [];
      for (var qData in _questions) {
        String? qImageUrl;
        if (qData.image != null) {
          qImageUrl = await storage.uploadPostImage(qData.image!, folder: 'quizzes/questions');
        }

        finalQuestions.add(QuizQuestion(
          text: qData.textController.text.trim(),
          options: qData.optionControllers.map((c) => c.text.trim()).toList(),
          correctOptionIndex: qData.correctIndex,
          explanation: qData.explanationController.text.trim().isNotEmpty ? qData.explanationController.text.trim() : null,
          imageUrl: qImageUrl,
        ));
      }

      final quiz = Quiz(
        id: widget.quiz?.id ?? '',
        creatorId: user.uid,
        creatorName: authorName,
        creatorAvatarUrl: authorAvatar,
        communityId: widget.communityId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: quizImageUrl ?? widget.quiz?.imageUrl,
        questions: finalQuestions,
        createdAt: widget.quiz?.createdAt ?? DateTime.now(),
      );

      if (widget.quiz != null) {
        await di.sl<FeedRepository>().updateQuiz(quiz);
      } else {
        await di.sl<FeedRepository>().createQuiz(quiz);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.quiz != null ? 'Quiz actualizado con éxito' : 'Quiz creado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: Text(widget.quiz != null ? 'Editar Quiz' : 'Nuevo Quiz', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitQuiz,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.quiz != null ? 'GUARDAR' : 'CREAR', style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Info
          _buildHeaderSection(),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          
          // Questions List
          ..._questions.asMap().entries.map((entry) => _buildQuestionEditor(entry.key, entry.value)),
          
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Pregunta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.themeColor,
              side: BorderSide(color: widget.themeColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickQuizImage,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              image: _quizImage != null 
                ? DecorationImage(image: FileImage(_quizImage!), fit: BoxFit.cover) 
                : (widget.quiz?.imageUrl != null && widget.quiz!.imageUrl!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(widget.quiz!.imageUrl!), fit: BoxFit.cover)
                  : null,
              border: Border.all(color: Colors.white10),
            ),
            child: (_quizImage == null && (widget.quiz?.imageUrl == null || widget.quiz!.imageUrl!.isEmpty)) 
              ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white24) 
              : null,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Título del Quiz',
            hintStyle: TextStyle(color: Colors.white24),
            border: InputBorder.none,
          ),
        ),
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Descripción breve...',
            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionEditor(int index, _QuestionEditorData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: widget.themeColor,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              const Text('Pregunta', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_questions.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeQuestion(index),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: data.textController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '¿Cuál es la pregunta?',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Opciones (Selecciona la correcta)', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          ...List.generate(4, (optIdx) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Radio<int>(
                  value: optIdx,
                  groupValue: data.correctIndex,
                  onChanged: (val) {
                    if (val != null) setState(() => data.correctIndex = val);
                  },
                  activeColor: Colors.greenAccent,
                ),
                Expanded(
                  child: TextField(
                    controller: data.optionControllers[optIdx],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Opción ${optIdx + 1}',
                      hintStyle: const TextStyle(color: Colors.white24),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          TextField(
            controller: data.explanationController,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Explicación (opcional)',
              hintStyle: TextStyle(color: Colors.white24),
              prefixIcon: Icon(Icons.info_outline, size: 16, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionEditorData {
  final textController = TextEditingController();
  final explanationController = TextEditingController();
  final List<TextEditingController> optionControllers = List.generate(4, (_) => TextEditingController());
  int correctIndex = 0;
  File? image;

  void dispose() {
    textController.dispose();
    explanationController.dispose();
    for (var c in optionControllers) {
      c.dispose();
    }
  }
}
