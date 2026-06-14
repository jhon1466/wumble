import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:wumble/injection_container.dart' as di;
import 'package:firebase_auth/firebase_auth.dart';

class WalletScreen extends StatelessWidget {
  WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Scaffold(body: Center(child: Text(tr('No has iniciado sesión'))));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(tr('Mi Monedero'), style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<UserProfile>(
        stream: di.sl<ProfileRepository>().getUserProfile(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final user = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildBalanceCard(user.coins),
                      SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tr('OBTENER MONEDAS'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCoinPackage(context, 100, '0.99 USD', Icons.wallet_giftcard_rounded),
                      _buildCoinPackage(context, 500, '4.99 USD', Icons.card_giftcard_rounded),
                      _buildCoinPackage(context, 1000, '8.99 USD', Icons.redeem_rounded),
                      _buildCoinPackage(context, 5000, 'DEMO: GRATIS', Icons.auto_awesome_rounded, isFree: true),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(int coins) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.monetization_on_rounded, size: 48, color: Colors.white),
          SizedBox(height: 12),
          Text(
            tr('Saldo actual'),
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            coins.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            tr('MONEDAS'),
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinPackage(BuildContext context, int coins, String price, IconData icon, {bool isFree = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final userId = FirebaseAuth.instance.currentUser?.uid;
            if (userId != null) {
              await di.sl<ProfileRepository>().updateCoins(userId, coins);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('¡Has obtenido $coins monedas!')),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFree ? Colors.blue.withValues(alpha: 0.1) : Colors.yellow.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isFree ? Colors.blue : Colors.yellow, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$coins Monedas',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (isFree)
                        Text(tr('Regalo especial por ser beta tester'), style: TextStyle(color: Colors.blue, fontSize: 12))
                      else
                        Text(tr('Compra segura con un click'), style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    color: isFree ? Colors.blue : Colors.yellow,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
