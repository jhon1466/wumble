import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:wumble/features/community/domain/wiki_model.dart';
import 'package:wumble/features/community/domain/wiki_repository.dart';
import 'package:wumble/injection_container.dart';

class WikiApprovalScreen extends StatefulWidget {
  final String communityId;

  WikiApprovalScreen({super.key, required this.communityId});

  @override
  State<WikiApprovalScreen> createState() => _WikiApprovalScreenState();
}

class _WikiApprovalScreenState extends State<WikiApprovalScreen> {
  final WikiRepository _repository = sl<WikiRepository>();
  List<WikiPage> _pendingWikis = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingWikis();
  }

  Future<void> _loadPendingWikis() async {
    setState(() => _isLoading = true);
    try {
      final wikis = await _repository.getPendingSubmissions(widget.communityId);
      setState(() {
        _pendingWikis = wikis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar wikis: $e')),
      );
    }
  }

  Future<void> _approveWiki(String wikiId) async {
    try {
      await _repository.approveWiki(wikiId);
      _loadPendingWikis();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Wiki aprobada con éxito'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aprobar wiki: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Pendientes de Aprobación')),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pendingWikis.isEmpty
              ? Center(child: Text(tr('No hay wikis pendientes.')))
              : ListView.builder(
                  itemCount: _pendingWikis.length,
                  itemBuilder: (context, index) {
                    final wiki = _pendingWikis[index];
                    return ListTile(
                      leading: wiki.iconUrl != null
                          ? CircleAvatar(backgroundImage: NetworkImage(wiki.iconUrl!))
                          : const CircleAvatar(child: Icon(Icons.book)),
                      title: Text(wiki.title),
                      subtitle: Text('De: ${wiki.authorId}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _approveWiki(wiki.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              // TODO: Implement rejection/delete
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Preview wiki
                      },
                    );
                  },
                ),
    );
  }
}
