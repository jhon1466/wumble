import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/quiz_model.dart';
import '../../domain/feed_repository.dart';
import '../../../../injection_container.dart' as di;
import 'package:cached_network_image/cached_network_image.dart';

class QuizPlayScreen extends StatefulWidget {
  final Quiz quiz;
  final bool isHardMode;

  const QuizPlayScreen({super.key, required this.quiz, this.isHardMode = false});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  int _secondsRemaining = 10;
  Timer? _timer;
  bool _isGameOver = false;
  bool _answered = false;
  int? _selectedOptionIndex;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = widget.isHardMode ? 5 : 10;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _onTimeOut();
        }
      });
    });
  }

  void _onTimeOut() {
    _timer?.cancel();
    setState(() {
      _isGameOver = true;
    });
    _finishQuiz();
  }

  void _answerQuestion(int index) {
    if (_answered || _isGameOver) return;
    _timer?.cancel();

    setState(() {
      _answered = true;
      _selectedOptionIndex = index;
      final correct = widget.quiz.questions[_currentQuestionIndex].correctOptionIndex == index;
      if (correct) {
        _correctAnswers++;
        _score += (_secondsRemaining * 100) * (widget.isHardMode ? 2 : 1);
      } else {
        _isGameOver = true;
      }
    });

    if (!_isGameOver) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
          setState(() {
            _currentQuestionIndex++;
            _answered = false;
            _selectedOptionIndex = null;
          });
          _startTimer();
        } else {
          _finishQuiz();
        }
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final attempt = QuizAttempt(
      id: '',
      quizId: widget.quiz.id,
      userId: user.uid,
      username: user.displayName ?? 'Usuario',
      userAvatarUrl: user.photoURL ?? '',
      score: _score,
      correctAnswers: _correctAnswers,
      totalQuestions: widget.quiz.questions.length,
      isHardMode: widget.isHardMode,
      completedAt: DateTime.now(),
    );

    try {
      await di.sl<FeedRepository>().submitQuizAttempt(attempt);
    } catch (e) {
      print('Error submitting quiz attempt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameOver || (_currentQuestionIndex >= widget.quiz.questions.length && _answered)) {
      return _buildResultView();
    }

    final question = widget.quiz.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // Progress & Timer
            _buildTopBar(progress),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (question.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(imageUrl: question.imageUrl!, height: 180, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 32),
                    _buildQuestionText(question.text),
                    const SizedBox(height: 48),
                    ...List.generate(question.options.length, (i) => _buildOptionButton(i, question.options[i], question.correctOptionIndex)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(double progress) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white70)),
              Text('Score: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              _buildTimerCircle(),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(widget.isHardMode ? Colors.redAccent : Colors.blueAccent),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCircle() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _secondsRemaining < 3 ? Colors.red : Colors.white24, width: 2),
      ),
      alignment: Alignment.center,
      child: Text('$_secondsRemaining', style: TextStyle(color: _secondsRemaining < 3 ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildQuestionText(String text) {
    if (widget.isHardMode) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationX(math.pi), // Upside down
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildOptionButton(int index, String text, int correctIndex) {
    Color bColor = Colors.white.withOpacity(0.05);
    if (_answered) {
      if (index == correctIndex) bColor = Colors.green.withOpacity(0.3);
      else if (index == _selectedOptionIndex) bColor = Colors.red.withOpacity(0.3);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _answerQuestion(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: bColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_correctAnswers == widget.quiz.questions.length ? Icons.emoji_events : Icons.sentiment_very_dissatisfied, 
                 size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            const Text('Quiz Finalizado', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Puntaje Final: $_score', style: const TextStyle(color: Colors.blueAccent, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_correctAnswers/${widget.quiz.questions.length} correctas', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
              child: const Text('Volver a la comunidad'),
            ),
          ],
        ),
      ),
    );
  }
}
