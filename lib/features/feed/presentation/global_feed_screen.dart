import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'widgets/post_card.dart';
import '../domain/post_model.dart';
import 'feed_bloc.dart';
import '../../../../core/theme.dart';

class GlobalFeedScreen extends StatelessWidget {
  const GlobalFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Wumbleheme.primaryColor, Wumbleheme.secondaryColor],
          ).createShader(bounds),
          child: Text(tr('Muro Global')),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Wumbleheme.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Wumbleheme.secondaryColor),
            );
          } else if (state is FeedLoaded) {
            return ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 120),
              itemCount: state.posts.length,
              cacheExtent: 1000,
              itemBuilder: (context, index) {
                return PostCard(post: state.posts[index]);
              },
            );
          } else if (state is FeedError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Wumbleheme.primaryColor,
        child: const Icon(Icons.edit_note_rounded, color: Colors.white),
      ),
    );
  }
}
