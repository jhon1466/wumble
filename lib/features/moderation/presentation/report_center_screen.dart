import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wumble/core/theme.dart';
import 'package:wumble/injection_container.dart';
import 'bloc/moderation_bloc.dart';
import 'bloc/moderation_event.dart';
import 'bloc/moderation_state.dart';
import '../domain/moderation_models.dart';
import 'widgets/sanction_dialog.dart';

class ReportCenterScreen extends StatefulWidget {
  const ReportCenterScreen({super.key});

  @override
  State<ReportCenterScreen> createState() => _ReportCenterScreenState();
}

class _ReportCenterScreenState extends State<ReportCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return BlocProvider(
      create: (context) => sl<ModerationBloc>()..add(LoadModerationDashboard()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Centro de Reportes', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Wumbleheme.primaryColor,
            labelColor: Wumbleheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Pendientes'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: BlocConsumer<ModerationBloc, ModerationState>(
          listener: (context, state) {
            if (state is ModerationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.green),
              );
            }
            if (state is ModerationError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
              );
            }
          },
          builder: (context, state) {
            if (state is ModerationLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ModerationLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _ReportList(reports: state.pendingReports, isPending: true),
                  _ReportList(reports: state.handledReports, isPending: false),
                ],
              );
            }

            return const Center(child: Text('Cargando panel de moderación...'));
          },
        ),
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  final List<ModerationReport> reports;
  final bool isPending;

  const _ReportList({required this.reports, required this.isPending});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline_rounded : Icons.history_rounded,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No hay reportes pendientes' : 'El historial está vacío',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = reports[index];
        return _ReportCard(report: report, isPending: isPending);
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ModerationReport report;
  final bool isPending;

  const _ReportCard({required this.report, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTypeBadge(report.type),
              const Spacer(),
              Text(
                DateFormat('dd MMM, HH:mm').format(report.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Razón: ${report.reason}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (report.details != null && report.details!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              report.details!,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'ID Objetivo: ${report.targetId}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleResolve(context, ReportStatus.dismissed),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleResolve(context, ReportStatus.resolved),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Wumbleheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Resolver'),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(report.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 14, color: _getStatusColor(report.status)),
                  const SizedBox(width: 8),
                  Text(
                    'Por: ${report.handledBy ?? "Sistema"}',
                    style: TextStyle(color: _getStatusColor(report.status), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    report.status.name.toUpperCase(),
                    style: TextStyle(color: _getStatusColor(report.status), fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleResolve(BuildContext context, ReportStatus status) async {
    final bloc = context.read<ModerationBloc>();
    
    if (status == ReportStatus.resolved && report.type == ReportType.user) {
      final sanction = await showDialog<Sanction>(
        context: context,
        builder: (context) => SanctionDialog(userId: report.targetId),
      );

      if (sanction != null) {
        bloc.add(ApplySanctionEvent(sanction));
      }
    }

    bloc.add(ResolveReport(
      reportId: report.id,
      status: status,
      adminId: 'mock_admin_id',
      note: 'Resuelto desde el panel',
    ));
  }

  Widget _buildTypeBadge(ReportType type) {
    Color color;
    IconData icon;
    switch (type) {
      case ReportType.user:
        color = Colors.blue;
        icon = Icons.person_rounded;
        break;
      case ReportType.post:
        color = Colors.orange;
        icon = Icons.article_rounded;
        break;
      case ReportType.comment:
        color = Colors.green;
        icon = Icons.comment_rounded;
        break;
      case ReportType.chat:
        color = Colors.purple;
        icon = Icons.chat_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            type.name.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending: return Colors.orange;
      case ReportStatus.reviewed: return Colors.blue;
      case ReportStatus.resolved: return Colors.green;
      case ReportStatus.dismissed: return Colors.grey;
    }
  }
}
