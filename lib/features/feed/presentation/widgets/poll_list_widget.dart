import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../domain/poll_model.dart';
import '../../domain/feed_repository.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;
import '../pages/create_poll_screen.dart';
import '../../../../core/widgets/user_avatar.dart';

class PollListWidget extends StatefulWidget {
  final String communityId;

  const PollListWidget({super.key, required this.communityId});

  @override
  State<PollListWidget> createState() => PollListWidgetState();
}

class PollListWidgetState extends State<PollListWidget> with AutomaticKeepAliveClientMixin {
  late Future<List<Poll>> _pollsFuture;
  final Map<String, PollVote?> _userVotes = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  void refresh() {
    if (mounted) {
      setState(() {
        _loadPolls();
      });
    }
  }

  void _loadPolls() {
    _pollsFuture = di.sl<FeedRepository>().getCommunityPolls(widget.communityId).then((polls) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        for (var poll in polls) {
          final vote = await di.sl<FeedRepository>().getUserPollVote(poll.id, userId);
          _userVotes[poll.id] = vote;
        }
      }
      return polls;
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadPolls();
    });
    await _pollsFuture;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1E1E2C),
      child: FutureBuilder<List<Poll>>(
        future: _pollsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          }
          final polls = snapshot.data ?? [];
          if (polls.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const Center(
                    child: Text('No hay encuestas aún.', style: TextStyle(color: Colors.white38)),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: polls.length,
            itemBuilder: (context, index) {
              final poll = polls[index];
              return _PollCard(
                poll: poll, 
                userVote: _userVotes[poll.id],
                onVote: () => setState(() => _loadPolls()),
              );
            },
          );
        },
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final Poll poll;
  final PollVote? userVote;
  final VoidCallback onVote;

  const _PollCard({required this.poll, this.userVote, required this.onVote});

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white70),
              title: const Text('Editar Encuesta', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatePollScreen(
                      communityId: poll.communityId,
                      poll: poll,
                    ),
                  ),
                ).then((value) {
                  if (value == true) onVote();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Eliminar Encuesta', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E2C),
                    title: const Text('¿Eliminar Encuesta?', style: TextStyle(color: Colors.white)),
                    content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (context.mounted) Navigator.pop(context);
                  await di.sl<FeedRepository>().deletePoll(poll.id);
                  onVote();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpired = poll.isExpired;
    final String endsIn = isExpired 
        ? 'Finalizada' 
        : 'Termina en ${poll.endsAt.difference(DateTime.now()).inDays} días';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                userId: poll.creatorId,
                avatarUrl: poll.creatorAvatarUrl,
                displayName: poll.creatorName,
                radius: 12,
                communityId: poll.communityId,
                isAnimated: false,
              ),
              const SizedBox(width: 8),
              Text(poll.creatorName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              if (FirebaseAuth.instance.currentUser?.uid == poll.creatorId)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
                  onPressed: () => _showOptionsMenu(context),
                ),
              const SizedBox(width: 8),
              Text(
                endsIn,
                style: TextStyle(
                  color: isExpired ? Colors.redAccent : Colors.white24,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            poll.question,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ...poll.options.map((opt) => _OptionTile(
            poll: poll,
            option: opt,
            hasVoted: userVote != null,
            isMyVote: userVote?.optionId == opt.id,
            onVote: onVote,
          )),
          const SizedBox(height: 12),
          Text(
            '${poll.totalVotes} votos',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final Poll poll;
  final PollOption option;
  final bool hasVoted;
  final bool isMyVote;
  final VoidCallback onVote;

  const _OptionTile({
    required this.poll, 
    required this.option, 
    required this.hasVoted,
    required this.isMyVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = poll.totalVotes == 0 ? 0 : option.voteCount / poll.totalVotes;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: (poll.isExpired || hasVoted) ? null : () async {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId == null) return;
          
          await di.sl<FeedRepository>().voteInPoll(poll.id, option.id, userId);
          onVote();
        },
        child: Stack(
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isMyVote ? Colors.blueAccent.withOpacity(0.5) : Colors.white10),
              ),
            ),
            if (hasVoted || poll.isExpired)
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: (isMyVote ? Colors.blueAccent : Wumbleheme.primaryColor).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  if (isMyVote)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.check_circle, size: 16, color: Colors.blueAccent),
                    ),
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        color: isMyVote ? Colors.blueAccent : Colors.white, 
                        fontSize: 14,
                        fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (hasVoted || poll.isExpired)
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
