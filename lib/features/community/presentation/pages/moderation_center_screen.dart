import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme.dart';
import '../../domain/moderation_report_model.dart';
import '../../domain/community_model.dart';

class ModerationCenterScreen extends StatefulWidget {
  final Community community;

  ModerationCenterScreen({super.key, required this.community});

  @override
  State<ModerationCenterScreen> createState() => _ModerationCenterScreenState();
}

class _ModerationCenterScreenState extends State<ModerationCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Wumbleheme.backgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Centro de Moderación'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(tr('Reportes de IA y Usuarios'), style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: widget.community.themeColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsList(ModerationReportStatus.pending),
          _buildReportsList(null), // History (everything not pending)
        ],
      ),
    );
  }

  Widget _buildReportsList(ModerationReportStatus? filterStatus) {
    Query query = _firestore
        .collection('communities')
        .doc(widget.community.id)
        .collection('moderation_reports')
        .orderBy('createdAt', descending: true);

    if (filterStatus != null) {
      query = query.where('status', isEqualTo: filterStatus.name);
    } else {
      query = query.where('status', whereIn: [
        ModerationReportStatus.approved.name,
        ModerationReportStatus.rejected.name
      ]);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs.map((doc) => ModerationReport.fromFirestore(doc)).toList();

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text(
                  filterStatus == ModerationReportStatus.pending ? 'No hay reportes pendientes' : 'El historial está vacío',
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) => _buildReportCard(reports[index]),
        );
      },
    );
  }

  Widget _buildReportCard(ModerationReport report) {
    final isPending = report.status == ModerationReportStatus.pending;
    final accentColor = widget.community.themeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending 
            ? (report.confidenceScore > 0.7 ? Colors.redAccent.withOpacity(0.3) : Colors.orangeAccent.withOpacity(0.3))
            : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type & Confidence
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildTargetTypeBadge(report.targetType),
                const SizedBox(width: 8),
                if (isPending)
                  _buildConfidenceBadge(report.confidenceScore),
                const Spacer(),
                Text(
                  timeago.format(report.createdAt, locale: 'es'),
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),

          // Content Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.reason,
                  style: TextStyle(
                    color: isPending ? Colors.redAccent : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.contentPreview,
                    style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (report.mediaUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: report.mediaUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          if (isPending)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAction(report, ModerationReportStatus.approved),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(tr('APROBAR')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        foregroundColor: Colors.greenAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAction(report, ModerationReportStatus.rejected),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(tr('ELIMINAR')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.2),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Row(
                children: [
                  Icon(
                    report.status == ModerationReportStatus.approved ? Icons.verified : Icons.block,
                    size: 14,
                    color: report.status == ModerationReportStatus.approved ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    report.status == ModerationReportStatus.approved ? 'Aprobado por Staff' : 'Contenido Eliminado',
                    style: TextStyle(
                      color: report.status == ModerationReportStatus.approved ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetTypeBadge(ModerationTargetType type) {
    IconData icon;
    String label;
    switch (type) {
      case ModerationTargetType.post:
        icon = Icons.article_outlined;
        label = 'Blog';
        break;
      case ModerationTargetType.comment:
        icon = Icons.comment_outlined;
        label = 'Comentario';
        break;
      case ModerationTargetType.chat:
        icon = Icons.chat_bubble_outline;
        label = 'Chat';
        break;
      case ModerationTargetType.profile:
        icon = Icons.person_outline;
        label = 'Perfil';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(double score) {
    final color = score > 0.7 ? Colors.redAccent : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'RIESGO: ${(score * 100).toInt()}%',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }

  Future<void> _handleAction(ModerationReport report, ModerationReportStatus newStatus) async {
    // 1. Show confirmation if deleting
    if (newStatus == ModerationReportStatus.rejected) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Wumbleheme.surfaceColor,
          title: Text(tr('¿Eliminar contenido?'), style: TextStyle(color: Colors.white)),
          content: const Text('Esta acción eliminará permanentemente el contenido reportado y notificará al usuario.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('CANCELAR'))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('ELIMINAR'), style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      // 2. Update report status
      await _firestore
          .collection('communities')
          .doc(widget.community.id)
          .collection('moderation_reports')
          .doc(report.id)
          .update({'status': newStatus.name});

      // 3. Perform the actual content deletion if rejected
      if (newStatus == ModerationReportStatus.rejected) {
        await _deleteTargetContent(report);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == ModerationReportStatus.approved ? 'Contenido aprobado' : 'Contenido eliminado'),
            backgroundColor: newStatus == ModerationReportStatus.approved ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteTargetContent(ModerationReport report) async {
    // Logic to delete based on type
    switch (report.targetType) {
      case ModerationTargetType.post:
        await _firestore.collection('communities').doc(report.communityId).collection('posts').doc(report.targetId).delete();
        break;
      case ModerationTargetType.comment:
        // Needs proper path to comments (usually a subcollection of post or a global collection)
        // Assuming global comments for now or nested
        await _firestore.collection('comments').doc(report.targetId).delete();
        break;
      case ModerationTargetType.chat:
        // Chat messages deletion depends on room
        if (report.metadata['roomId'] != null) {
          await _firestore.collection('chats').doc(report.metadata['roomId']).collection('messages').doc(report.targetId).delete();
        }
        break;
      case ModerationTargetType.profile:
        // Reset bio or name?
        await _firestore.collection('communities').doc(report.communityId).collection('members').doc(report.targetUserId).update({
          'bio': '[Contenido eliminado por moderación]',
        });
        break;
    }
  }
}
