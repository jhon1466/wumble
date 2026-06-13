import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';
import 'dart:async';
import '../../domain/community_model.dart';
import '../../../../core/theme.dart';

class DailyCheckInDialog extends StatefulWidget {
  final Community community;
  final int rewardAmount;
  final int coinAmount;

  const DailyCheckInDialog({
    super.key,
    required this.community,
    this.rewardAmount = 15,
    this.coinAmount = 5,
  });

  static void show(BuildContext context, Community community, {int rewardAmount = 15, int coinAmount = 5}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => DailyCheckInDialog(
        community: community,
        rewardAmount: rewardAmount,
        coinAmount: coinAmount,
      ),
    );
  }

  @override
  State<DailyCheckInDialog> createState() => _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends State<DailyCheckInDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _currentRepValue = 0;
  bool _isFinished = false;
  bool _hasSelectedCard = false;
  int? _selectedCardIndex;
  late List<int> _cardRewards;
  late List<int> _cardPositions;

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

    // Prepare 3 rewards: the real one + 2 other possibilities
    _cardRewards = [
      widget.coinAmount,
      (widget.coinAmount * 0.5).round().clamp(1, 100),
      (widget.coinAmount * 2.0).round().clamp(1, 100),
    ];
    // Mix them
    _cardPositions = [0, 1, 2]..shuffle();

    _controller.forward();
  }

  void _onCardSelected(int index) {
    if (_hasSelectedCard) return;
    
    // Ensure the picked card actually contains the real reward (index 0 of _cardRewards)
    // We do this by swapping values in _cardPositions if necessary
    int currentRewardAtPos = _cardPositions[index];
    if (currentRewardAtPos != 0) {
      // Find where the real reward (0) is
      int realRewardIndex = _cardPositions.indexOf(0);
      // Swap!
      _cardPositions[realRewardIndex] = currentRewardAtPos;
      _cardPositions[index] = 0;
    }

    setState(() {
      _hasSelectedCard = true;
      _selectedCardIndex = index;
    });

    HapticFeedback.mediumImpact();

    // Small delay before starting the rep count
    Future.delayed(const Duration(milliseconds: 1000), () {
      _startCounting();
    });
  }

  void _startCounting() async {
    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 1; i <= widget.rewardAmount; i++) {
      if (!mounted) return;
      setState(() {
        _currentRepValue = i;
      });
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (mounted) {
      setState(() {
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
    final themeColor = widget.community.themeColor;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: Wumbleheme.backgroundColor.withOpacity(0.98),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: themeColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Title
              Text(
                _hasSelectedCard ? '¡CHECK-IN EXITOSO!' : '¡ESCOGE UNA CARTA!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasSelectedCard ? widget.community.name : 'Elige tu premio diario de Wumble Coins',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hasSelectedCard ? themeColor.withOpacity(0.8) : Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: _hasSelectedCard ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Cards Row (Always present and keyed for state persistence)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) => _buildCard(index)),
              ),

              // Reward Details (Appears after selection)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 500),
                crossFadeState: _hasSelectedCard ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(height: 0, width: double.infinity),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Lottie celebration animation
                    SizedBox(
                      height: 100,
                      width: 100,
                      child: Lottie.network(
                        'https://assets9.lottiefiles.com/packages/lf20_touohxv0.json',
                        repeat: false,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Reputation + Coins animated counters
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Reputation Counter
                        Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '+',
                                  style: TextStyle(
                                    color: themeColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  _currentRepValue.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'REPUTACIÓN',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        // Vertical divider
                        Container(height: 30, width: 1, color: Colors.white10),
                        // Coin Counter
                        Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: Colors.yellowAccent,
                                  size: 24,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+${(_currentRepValue / widget.rewardAmount * widget.coinAmount).floor()}',
                                  style: const TextStyle(
                                    color: Colors.yellowAccent,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'AMINO COINS',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Done Button
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _isFinished ? 1.0 : 0.3,
                      child: ElevatedButton(
                        onPressed: _isFinished ? () => Navigator.pop(context) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: _isFinished ? 8 : 0,
                          shadowColor: themeColor.withOpacity(0.5),
                        ),
                        child: const Text(
                          '¡GENIAL!',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildCard(int index) {
    return RewardCard(
      key: ValueKey('reward_card_$index'),
      index: index,
      rewardValue: _cardRewards[_cardPositions[index]],
      onSelected: () => _onCardSelected(index),
      isSelected: _selectedCardIndex == index,
      isRevealed: _hasSelectedCard,
    );
  }
}

class RewardCard extends StatefulWidget {
  final int index;
  final int rewardValue;
  final VoidCallback onSelected;
  final bool isSelected;
  final bool isRevealed;

  const RewardCard({
    super.key,
    required this.index,
    required this.rewardValue,
    required this.onSelected,
    required this.isSelected,
    required this.isRevealed,
  });

  @override
  State<RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<RewardCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(RewardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isRevealed ? null : widget.onSelected,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * 3.14159;
          final isBack = angle > 3.14159 / 2;
          
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(3.14159),
                  child: _buildFrontSide(), 
                )
              : _buildBackSide(), 
          );
        },
      ),
    );
  }

  Widget _buildBackSide() {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.help_outline,
            color: Colors.white.withOpacity(0.05),
            size: 40,
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: const Icon(
              Icons.question_mark_rounded,
              color: Colors.white24,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontSide() {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: widget.isSelected ? Colors.yellowAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isSelected ? Colors.yellowAccent : Colors.white24,
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (widget.isSelected)
            BoxShadow(
              color: Colors.yellowAccent.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.monetization_on,
            color: Colors.yellowAccent,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.rewardValue}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const Text(
            'AC',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
