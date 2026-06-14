import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/user_model.dart';
import '../profile_bloc.dart';
import 'package:wumble/core/theme.dart';

class CheckInWidget extends StatefulWidget {
  final UserProfile user;
  final String? communityId;

  const CheckInWidget({
    super.key,
    required this.user,
    this.communityId,
  });

  @override
  State<CheckInWidget> createState() => _CheckInWidgetState();
}

class _CheckInWidgetState extends State<CheckInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  bool get _isCheckInDoneToday {
    if (widget.user.lastCheckIn == null) return false;
    final now = DateTime.now();
    final last = widget.user.lastCheckIn!;
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerSuccessAnimation(BuildContext context) {
    // Show the same style dialog as the community check-in
    _controller.reset();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => _CheckInSuccessDialog(user: widget.user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _isCheckInDoneToday;

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileActionSuccess && state.message.contains('Check-in realizado')) {
          _triggerSuccessAnimation(context);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: isDone
                ? null
                : () {
                    context.read<ProfileBloc>().add(PerformCheckInRequested(widget.user.id));
                  },
            onLongPress: () => _triggerSuccessAnimation(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDone ? Colors.green.withOpacity(0.2) : Wumbleheme.secondaryColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDone ? Colors.greenAccent : Colors.white.withOpacity(0.3),
                ),
                boxShadow: [
                  if (!isDone)
                    BoxShadow(
                      color: Wumbleheme.secondaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.calendar_today,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDone ? 'CHECK-IN HECHO' : 'CHECK-IN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (widget.user.checkInStreak > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🔥 ${widget.user.checkInStreak}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _triggerSuccessAnimation(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: const Text('✨', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exact same style as DailyCheckInDialog ──────────────────────────────────

class _CheckInSuccessDialog extends StatefulWidget {
  final UserProfile user;
  _CheckInSuccessDialog({required this.user});

  @override
  State<_CheckInSuccessDialog> createState() => _CheckInSuccessDialogState();
}

class _CheckInSuccessDialogState extends State<_CheckInSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _currentCoins = 0;
  int _currentRep = 0;
  bool _isFinished = false;

  static int _coinsReward = 5;
  static int _repReward = 10;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _startCounting();
  }

  void _startCounting() async {
    await Future.delayed(Duration(milliseconds: 500));

    // Count up both coins and rep in parallel
    final maxSteps = _repReward; // rep is bigger, drive loop by it
    for (int i = 1; i <= maxSteps; i++) {
      if (!mounted) return;
      setState(() {
        _currentRep = i;
        // coins finish faster but scale with same steps
        _currentCoins = ((i / maxSteps) * _coinsReward).round();
      });
      HapticFeedback.lightImpact();
      await Future.delayed(Duration(milliseconds: 50));
    }

    if (mounted) {
      setState(() {
        _currentCoins = _coinsReward;
        _currentRep = _repReward;
        _isFinished = true;
      });
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Wumbleheme.secondaryColor;

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 40),
          padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Wumbleheme.backgroundColor.withOpacity(0.97),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: themeColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.25),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              SizedBox(height: 24),

              Text(
                tr('¡CHECK-IN EXITOSO!'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                widget.user.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeColor.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 36),

              // Counters row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CounterBadge(
                    label: tr('REPUTACIÓN'),
                    value: _currentRep,
                    color: themeColor,
                  ),
                  SizedBox(width: 24),
                  _CounterBadge(
                    label: tr('WUMBLE COINS'),
                    value: _currentCoins,
                    color: Colors.amber,
                    emoji: '🪙',
                  ),
                ],
              ),

              if (widget.user.checkInStreak > 0) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    '🔥 Racha de ${widget.user.checkInStreak} días',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              SizedBox(height: 36),

              AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: _isFinished ? 1.0 : 0.3,
                child: ElevatedButton(
                  onPressed: _isFinished ? () => Navigator.pop(context) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: _isFinished ? 8 : 0,
                    shadowColor: themeColor.withOpacity(0.5),
                  ),
                  child: Text(
                    tr('¡GENIAL!'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String? emoji;

  const _CounterBadge({
    required this.label,
    required this.value,
    required this.color,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '+',
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (emoji != null) ...[
              const SizedBox(width: 4),
              Text(emoji!, style: const TextStyle(fontSize: 24)),
            ],
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
