import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart';
import '../../domain/wiki_model.dart';
import '../../domain/wiki_repository.dart';
import '../../../feed/presentation/wiki_editor_screen.dart';
import '../pages/wiki_detail_screen.dart';
import 'wiki_card.dart';

class WikiListWidget extends StatefulWidget {
  final String communityId;

  const WikiListWidget({super.key, required this.communityId});

  @override
  State<WikiListWidget> createState() => WikiListWidgetState();
}

class WikiListWidgetState extends State<WikiListWidget> with AutomaticKeepAliveClientMixin {
  late Future<List<WikiPage>> _wikisFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWikis();
  }

  void refresh() {
    if (mounted) {
      setState(() {
        _loadWikis();
      });
    }
  }

  void _loadWikis() {
    _wikisFuture = sl<WikiRepository>().getCommunityWikis(widget.communityId);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadWikis();
    });
    await _wikisFuture;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1E1E2C),
      child: FutureBuilder<List<WikiPage>>(
        future: _wikisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          
          final wikis = snapshot.data ?? [];

          return Container(
            color: Colors.transparent,
            child: wikis.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.book_outlined, size: 60, color: Colors.white24),
                              const SizedBox(height: 10),
                              const Text('El catálogo está vacío', style: TextStyle(color: Colors.white24)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 100), // Padding for nav pill
                    itemCount: wikis.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 0),
                    itemBuilder: (context, index) {
                      final wiki = wikis[index];
                      return WikiCard(
                        wiki: wiki,
                        onDeleted: _onRefresh,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}


