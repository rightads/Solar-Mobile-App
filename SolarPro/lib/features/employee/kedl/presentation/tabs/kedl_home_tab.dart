import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/kedl_demand_card.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/pay_demand_sheet.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';

class KedlHomeTab extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final KedlRepository? repository;

  const KedlHomeTab({
    super.key,
    this.onNavigateTab,
    this.repository,
  });

  @override
  State<KedlHomeTab> createState() => _KedlHomeTabState();
}

class _KedlHomeTabState extends State<KedlHomeTab> {
  late KedlRepository _repo;
  bool _isLoading = true;
  KedlDashboardMetricsModel? _metrics;
  List<KedlFileModel> _allFiles = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? KedlRepository();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final metrics = await _repo.getDashboardMetrics();
      final files = await _repo.listKedlFiles();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _allFiles = files;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPayDemand(KedlDemandModel demand) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => PayDemandSheet(
        demand: demand,
        repository: _repo,
        onDemandUpdated: (_) {
          _loadDashboard();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demand resolved successfully!'), backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }

  Future<void> _handleWaiveDemand(KedlDemandModel demand) async {
    try {
      await _repo.updateDemand(demand.id, status: KedlDemandStatus.waived);
      _loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demand waived.'), backgroundColor: AppColors.warning),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Extract open and overdue demands across all files
    final List<KedlDemandModel> allOpenDemands = [];
    for (final f in _allFiles) {
      allOpenDemands.addAll(f.demands.where((d) => d.status == KedlDemandStatus.open));
    }
    allOpenDemands.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    final totalFiles = _metrics?.totalFiles ?? _allFiles.length;
    final openCount = _metrics?.openDemandsCount ?? allOpenDemands.length;
    final overdueCount = _metrics?.overdueDemandsCount ?? allOpenDemands.where((d) => d.isOverdue).length;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy800,
                    AppColors.teal500.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.teal500.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.teal500.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: AppColors.teal500, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KEDL Discom Desk',
                          style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Paperwork Tracking & Fee Demands',
                          style: TextStyle(color: AppColors.grey400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Files',
                    value: '$totalFiles',
                    color: AppColors.gold500,
                    icon: Icons.folder_shared_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Open Demands',
                    value: '$openCount',
                    color: AppColors.warning,
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Overdue Demands',
                    value: '$overdueCount',
                    color: overdueCount > 0 ? AppColors.error : AppColors.success,
                    icon: Icons.warning_amber_rounded,
                    isAlert: overdueCount > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // File Types Breakdown Counters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.navy700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Files by Paperwork Type',
                    style: TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypePill(
                          type: KedlFileType.nameChange,
                          count: _allFiles.where((f) => f.fileType == KedlFileType.nameChange).length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypePill(
                          type: KedlFileType.loadIncrease,
                          count: _allFiles.where((f) => f.fileType == KedlFileType.loadIncrease).length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypePill(
                          type: KedlFileType.net,
                          count: _allFiles.where((f) => f.fileType == KedlFileType.net).length,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Demands Attention Section
            Row(
              children: [
                const Icon(Icons.notification_important_rounded, color: AppColors.gold500, size: 20),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Demands Requiring Action',
                    style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.onNavigateTab != null)
                  TextButton(
                    onPressed: () => widget.onNavigateTab!(2), // Demands tab
                    child: const Text('View All Demands', style: TextStyle(color: AppColors.gold500, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.gold500),
                ),
              )
            else if (allOpenDemands.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'All Discom Demands Resolved',
                      style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No pending fee demands currently waiting for payment or waiver.',
                      style: TextStyle(color: AppColors.grey400, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...allOpenDemands.take(5).map(
                    (d) => KedlDemandCard(
                      demand: d,
                      onMarkPaid: () => _showPayDemand(d),
                      onWaive: () => _handleWaiveDemand(d),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAlert ? AppColors.error.withValues(alpha: 0.12) : AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: isAlert ? AppColors.error : AppColors.navy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: AppColors.grey400, fontSize: 11, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill({required KedlFileType type, required int count}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navy700.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: type.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type.icon, color: type.color, size: 16),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(color: type.color, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            type.displayName,
            style: const TextStyle(color: AppColors.fg, fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
