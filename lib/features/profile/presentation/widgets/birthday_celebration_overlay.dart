import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class BirthdayCelebrationOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const BirthdayCelebrationOverlay({super.key, required this.onDismiss});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: BirthdayCelebrationOverlay(
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  State<BirthdayCelebrationOverlay> createState() => _BirthdayCelebrationOverlayState();
}

class _BirthdayCelebrationOverlayState extends State<BirthdayCelebrationOverlay> {
  late ConfettiController _controllerTopCenter;
  late ConfettiController _controllerTopLeft;
  late ConfettiController _controllerTopRight;

  @override
  void initState() {
    super.initState();
    _controllerTopCenter = ConfettiController(duration: const Duration(seconds: 10));
    _controllerTopLeft = ConfettiController(duration: const Duration(seconds: 10));
    _controllerTopRight = ConfettiController(duration: const Duration(seconds: 10));
    
    // Iniciar la animación de confeti
    _controllerTopCenter.play();
    _controllerTopLeft.play();
    _controllerTopRight.play();
  }

  @override
  void dispose() {
    _controllerTopCenter.dispose();
    _controllerTopLeft.dispose();
    _controllerTopRight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fondo para cerrar al tocar fuera del mensaje central
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // Confeti desde el CENTRO SUPERIOR
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _controllerTopCenter,
              blastDirection: pi / 2,
              maxBlastForce: 10,
              minBlastForce: 5,
              emissionFrequency: 0.1,
              numberOfParticles: 20,
              gravity: 0.2,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),
          
          // Confeti desde la IZQUIERDA SUPERIOR
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _controllerTopLeft,
              blastDirection: pi / 4,
              maxBlastForce: 10,
              minBlastForce: 5,
              emissionFrequency: 0.1,
              numberOfParticles: 10,
              gravity: 0.2,
            ),
          ),
          
          // Confeti desde la DERECHA SUPERIOR
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _controllerTopRight,
              blastDirection: 3 * pi / 4,
              maxBlastForce: 10,
              minBlastForce: 5,
              emissionFrequency: 0.1,
              numberOfParticles: 10,
              gravity: 0.2,
            ),
          ),

          // Mensaje Central
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎂',
                    style: TextStyle(fontSize: 60),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '¡FELIZ CUMPLEAÑOS!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¡De parte de todo el equipo de Wumble, te deseamos un día lleno de alegría y sorpresas! ✨',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      '¡Gritar de Alegría! 🎈',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
