import 'package:flutter/material.dart';
import '../../domain/post_model.dart';
import '../../domain/feed_repository.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;
import 'package:firebase_auth/firebase_auth.dart';

class IntegratedPollWidget extends StatefulWidget {
  final Post post;
  final ScrollPhysics? physics;

  const IntegratedPollWidget({super.key, required this.post, this.physics});

  @override
  State<IntegratedPollWidget> createState() => _IntegratedPollWidgetState();
}

class _IntegratedPollWidgetState extends State<IntegratedPollWidget> {
  String? _userVote;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserVote();
  }

  Future<void> _loadUserVote() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final vote = await di.sl<FeedRepository>().getUserPostVote(widget.post.id, userId);
      if (mounted) {
        setState(() {
          _userVote = vote;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vote(String optionId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _userVote != null) return;

    setState(() {
      _userVote = optionId;
    });

    try {
      await di.sl<FeedRepository>().voteInPost(widget.post.id, optionId, userId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _userVote = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al votar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final hasVoted = _userVote != null;
    final totalVotes = hasVoted ? (widget.post.pollTotalVotes + (widget.post.pollVotes.values.any((v) => v > 0) ? 0 : 0)) : widget.post.pollTotalVotes;
    
    // Note: totalVotes in Firestore is updated via transaction. 
    // For local UI purposes while refreshing, we might need to be smart, 
    // but the transaction handles the source of truth.
    
    // Recalculating total votes for display if local vote happened
    int displayTotalVotes = widget.post.pollTotalVotes;
    if (hasVoted) {
      // If the current user's vote isn't reflected in the post object yet
      // we add 1 to the total for visual consistency.
      // This is a simple heuristic.
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.post.pollOptions.map((option) {
          final int rawVotes = widget.post.pollVotes[option] ?? 0;
          // Heuristic: if I voted for this and it's not reflected, add 1.
          // Problem: if it WAS already reflected, I'd show +1 incorrectly.
          // For now, let's just use the post data as truth and trust the user will see it update on next fetch.
          // OR: we can just use the post data. 
          final double percentage = widget.post.pollTotalVotes == 0 ? 0 : rawVotes / widget.post.pollTotalVotes;
          final isMyVote = _userVote == option;

          return _PollOptionTile(
            text: option,
            percentage: percentage,
            votes: rawVotes,
            hasVoted: hasVoted,
            isMyVote: isMyVote,
            onTap: () => _vote(option),
          );
        }),
        const SizedBox(height: 8),
        Text(
          '${widget.post.pollTotalVotes} votos',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  final String text;
  final double percentage;
  final int votes;
  final bool hasVoted;
  final bool isMyVote;
  final VoidCallback onTap;

  const _PollOptionTile({
    required this.text,
    required this.percentage,
    required this.votes,
    required this.hasVoted,
    required this.isMyVote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: hasVoted ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMyVote ? Wumbleheme.primaryColor.withOpacity(0.5) : Colors.white10,
                ),
              ),
            ),
            if (hasVoted)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: percentage),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isMyVote ? Wumbleheme.primaryColor : Colors.white24).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.white.withOpacity(hasVoted ? 0.9 : 0.7),
                        fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (hasVoted) ...[
                    if (isMyVote)
                      const Icon(Icons.check_circle, size: 16, color: Wumbleheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
