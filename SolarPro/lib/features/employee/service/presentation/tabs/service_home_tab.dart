import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/service/presentation/screens/service_ticket_detail_screen.dart';
import 'package:solar_pro/features/employee/service/presentation/widgets/service_ticket_card.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';
import 'package:solar_pro/features/tickets/data/repositories/ticket_repository.dart';

class ServiceHomeTab extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final TicketRepository? repository;

  const ServiceHomeTab({
    super.key,
    this.onNavigateTab,
    this.repository,
  });

  @override
  State<ServiceHomeTab> createState() => _ServiceHomeTabState();
}

class _ServiceHomeTabState extends State<ServiceHomeTab> {
  late TicketRepository _repo;
  bool _isLoading = true;
  List<TicketModel> _tickets = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TicketRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.listTickets();
      if (mounted) {
        setState(() {
          _tickets = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDetail(TicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceTicketDetailScreen(
          initialTicket: ticket,
          repository: _repo,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final assignedCount = _tickets.where((t) => t.status == TicketStatus.assigned).length;
    final inProgressCount = _tickets.where((t) => t.status == TicketStatus.inProgress).length;
    final resolvedCount = _tickets.where((t) => t.status == TicketStatus.resolved).length;
    final urgentCount = _tickets.where((t) => (t.priority == TicketPriority.urgent || t.priority == TicketPriority.high) && t.status != TicketStatus.resolved).length;

    final urgentTickets = _tickets.where((t) => t.status != TicketStatus.resolved && (t.priority == TicketPriority.urgent || t.priority == TicketPriority.high)).toList();
    final activeTickets = _tickets.where((t) => t.status != TicketStatus.resolved).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy800,
                    AppColors.gold500.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.gold500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: AppColors.gold500, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service & Maintenance',
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Client resolution desk & warranty support',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.grey400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (urgentCount > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$urgentCount urgent ticket${urgentCount > 1 ? 's' : ''} require immediate site attention',
                              style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => widget.onNavigateTab?.call(1),
                            child: const Text(
                              'VIEW',
                              style: TextStyle(color: AppColors.gold400, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metrics KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Assigned',
                    count: '$assignedCount',
                    icon: Icons.assignment_ind_rounded,
                    color: AppColors.gold500,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'In Progress',
                    count: '$inProgressCount',
                    icon: Icons.engineering_rounded,
                    color: AppColors.info,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Resolved',
                    count: '$resolvedCount',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Handled',
                    count: '${_tickets.length}',
                    icon: Icons.confirmation_number_outlined,
                    color: AppColors.grey400,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Serial Lookup Action Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.navy600),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.teal500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.teal500, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reverse Serial Lookup',
                          style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Verify warranty status, customer details and installation specs by component serial.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => widget.onNavigateTab?.call(2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal500,
                      foregroundColor: AppColors.ink900,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    child: const Text('Lookup'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Urgent Tickets Section (if any)
            if (urgentTickets.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.priority_high_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Urgent Attention (${urgentTickets.length})',
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab?.call(1),
                    child: const Text('See All', style: TextStyle(color: AppColors.gold400, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...urgentTickets.take(2).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ServiceTicketCard(
                      ticket: t,
                      onTap: () => _openDetail(t),
                    ),
                  )),
              const SizedBox(height: 16),
            ],

            // Active Tickets Queue Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions_rounded, color: AppColors.gold500, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Assigned Tickets (${activeTickets.length})',
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(1),
                  child: const Text('View All', style: TextStyle(color: AppColors.gold400, fontSize: 13)),
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
            else if (activeTickets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.navy600),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 44),
                    SizedBox(height: 12),
                    Text(
                      'All Tickets Resolved!',
                      style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No pending issues assigned to you at the moment.',
                      style: TextStyle(color: AppColors.grey400, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...activeTickets.take(3).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ServiceTicketCard(
                      ticket: t,
                      onTap: () => _openDetail(t),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.navy600),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(icon, color: color.withValues(alpha: 0.7), size: 22),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.grey400,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
