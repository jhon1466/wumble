import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import '../../../../core/theme.dart';
import '../../domain/community_model.dart';
import 'package:intl/intl.dart';

class BannedScreen extends StatelessWidget {
  final Community community;
  final DateTime? expiresAt;

  BannedScreen({
    super.key, 
    required this.community, 
    this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final isPermanent = expiresAt == null;

    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      body: Stack(
        children: [
          // Background decoration
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.red.withOpacity(0.2),
                    Wumbleheme.backgroundColor,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon/Logo with restriction
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red, width: 3),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              community.iconUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.group, size: 60, color: Colors.white24),
                            ),
                          ),
                        ),
                        const Icon(Icons.block, color: Colors.red, size: 140),
                      ],
                    ),
                    SizedBox(height: 32),
                    Text(
                      tr('Acceso Restringido'),
                      style: Wumbleheme.darkTheme.textTheme.headlineLarge?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Has sido expulsado de ${community.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        isPermanent 
                          ? 'Esta expulsión es permanente.'
                          : 'Tu expulsión expira el: ${DateFormat('dd/MM/yyyy HH:mm').format(expiresAt!)}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 48),
                    Text(
                      tr('Si crees que esto es un error, contacta con los administradores de la comunidad.'),
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tr('Volver al Explorador')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
