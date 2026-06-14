import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/widgets/user_avatar.dart';

import '../../../../core/theme.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/community_model.dart';
import '../../domain/community_repository.dart';
import '../../domain/join_request_model.dart';

class JoinRequestsScreen extends StatefulWidget {
  final Community community;

  JoinRequestsScreen({super.key, required this.community});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  final _repository = di.sl<CommunityRepository>();
  List<JoinRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final requestsDynamic = await _repository.getJoinRequests(widget.community.id);
      setState(() {
        _requests = requestsDynamic.cast<JoinRequest>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(JoinRequest request) async {
    try {
      // Optimizacion UX: remover de la lista inmediatamente
      setState(() {
        _requests.remove(request);
      });
      await _repository.approveJoinRequest(widget.community.id, request.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Solicitud aprobada y usuario notificado'))),
        );
      }
    } catch (e) {
      // Revertir
      if (mounted) _loadRequests();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleDeny(JoinRequest request) async {
    try {
      setState(() {
        _requests.remove(request);
      });
      await _repository.denyJoinRequest(widget.community.id, request.userId);
    } catch (e) {
      if (mounted) _loadRequests();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.community.themeColor,
        title: Text(tr('Solicitudes de Ingreso'), style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: widget.community.themeColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
            SizedBox(height: 16),
            Text(tr('Error al cargar solicitudes'), style: TextStyle(color: Colors.white)),
            TextButton(
              onPressed: _loadRequests,
              child: Text(tr('Reintentar'), style: TextStyle(color: widget.community.themeColor)),
            )
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
            SizedBox(height: 16),
            Text(
              tr('No hay solicitudes pendientes'),
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: widget.community.themeColor,
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          return _RequestTile(
            request: _requests[index],
            themeColor: widget.community.themeColor,
            onApprove: () => _handleApprove(_requests[index]),
            onDeny: () => _handleDeny(_requests[index]),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final JoinRequest request;
  final Color themeColor;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const _RequestTile({
    required this.request,
    required this.themeColor,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(request.userId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final displayName = userData['displayName'] ?? userData['username'] ?? 'Usuario Desconocido';
        final avatarUrl = userData['avatarUrl'] as String?;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Wumbleheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    userId: request.userId,
                    avatarUrl: avatarUrl ?? '',
                    displayName: displayName,
                    radius: 24,
                    isClickable: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          timeago.format(request.requestedAt, locale: 'es'),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (request.message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${request.message}"',
                    style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDeny,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(tr('Rechazar')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(tr('Aprobar'), style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
