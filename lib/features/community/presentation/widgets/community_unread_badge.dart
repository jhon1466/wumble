import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/profile/presentation/bloc/notification_count_bloc.dart';

class CommunityUnreadBadge extends StatelessWidget {
  final String communityId;

  const CommunityUnreadBadge({
    super.key,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCountBloc, NotificationCountState>(
      buildWhen: (previous, current) => 
          previous.communityUnreadCounts[communityId] != current.communityUnreadCounts[communityId],
      builder: (context, state) {
        final unreadCount = state.communityUnreadCounts[communityId] ?? 0;
        
        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
          constraints: const BoxConstraints(
            minWidth: 16,
            minHeight: 16,
          ),
          child: Center(
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
