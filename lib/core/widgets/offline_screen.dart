import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/connectivity_cubit.dart';
import '../theme.dart';

class OfflineScreen extends StatelessWidget {
  OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Wumbleheme.backgroundColor,
              Wumbleheme.secondaryColor.withOpacity(0.05),
              Wumbleheme.backgroundColor,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Wumbleheme.secondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Wumbleheme.secondaryColor.withOpacity(0.2), width: 1),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 80,
                color: Wumbleheme.secondaryColor,
              ),
            ),
            SizedBox(height: 48),
            Text(
              tr('CONEXIÓN PERDIDA'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Text(
                tr('Wumble necesita una conexión a internet para funcionar correctamente.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: () => BlocProvider.of<ConnectivityCubit>(context).check(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Wumbleheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
                shadowColor: Wumbleheme.secondaryColor.withOpacity(0.5),
              ),
              icon: Icon(Icons.refresh_rounded),
              label: Text(
                tr('VERIFICAR CONEXIÓN'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Wumbleheme.secondaryColor.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('ESPERANDO SEÑAL...'),
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
