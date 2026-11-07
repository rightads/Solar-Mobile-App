import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';
import 'package:solar_pro/features/client/presentation/widgets/raise_ticket_modal.dart';

class ClientTicketsTab extends StatefulWidget {
  final List<ClientTicketRecord> tickets;
  final Function(ClientTicketRecord) onTicketCreated;

  const ClientTicketsTab({
    super.key,
    required this.tickets,
    required this.onTicketCreated,
  });

  @override
  State<ClientTicketsTab> createState() => _ClientTicketsTabState();
}

class _ClientTicketsTabState extends State<ClientTicketsTab> {
  String _filter = 'all'; // 'all', 'open', 'in_progress', 'resolved'

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _filter == 'all'
        ? widget.tickets
        : widget.tickets.where((t) => t.status == _filter).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.orange500,
      backgroundColor: AppColors.navy800,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Banner explaining the 3 Ticket categories
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C1E14), Color(0xFF161C2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.orange500.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange500.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: AppColors.orange500, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Solar Customer Care Desk', style: AppTextStyles.headlineMedium),
                            Text('Fast response by certified solar maintenance crew',
                                style: AppTextStyles.caption.copyWith(color: AppColors.orange400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3 Category Highlights from user notes
                  Row(
                    children: [
                      _categoryChip('Structure', '2-10 Photos', Icons.foundation_rounded, AppColors.orange500),
                      const SizedBox(width: 6),
                      _categoryChip('Wiring', 'Photos upload', Icons.electrical_services_rounded, AppColors.purple500),
                      const SizedBox(width: 6),
                      _categoryChip('Inverter', 'Error Code', Icons.power_rounded, AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Raise Ticket Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: () => RaiseTicketModal.show(
                        context,
                        onTicketCreated: widget.onTicketCreated,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, size: 20),
                          const SizedBox(width: 6),
                          Text('Raise New Service Ticket',
                              style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All Tickets (${widget.tickets.length})'),
                    const SizedBox(width: 8),
                    _filterChip('open', 'Open'),
                    const SizedBox(width: 8),
                    _filterChip('in_progress', 'In Progress'),
                    const SizedBox(width: 8),
                    _filterChip('resolved', 'Resolved'),
                  ],
                ),
              ),
            ),
          ),

          // Tickets List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            sliver: filteredTickets.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: AppColors.teal400, size: 48),
                            const SizedBox(height: 12),
                            Text('No active service tickets',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey300, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('Solar system running smoothly without reported issues.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.grey500), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final t = filteredTickets[i];
                        return _buildTicketCard(context, t);
                      },
                      childCount: filteredTickets.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String title, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: AppColors.grey400, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.orange500,
      backgroundColor: AppColors.navy800,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.grey400,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) setState(() => _filter = key);
      },
    );
  }

  Widget _buildTicketCard(BuildContext context, ClientTicketRecord t) {
    Color typeColor;
    switch (t.type) {
      case ClientTicketType.structure:
        typeColor = AppColors.orange500;
        break;
      case ClientTicketType.wiring:
        typeColor = AppColors.purple500;
        break;
      case ClientTicketType.inverter:
        typeColor = AppColors.error;
        break;
    }

    Color statusColor;
    String statusLabel;
    if (t.status == 'resolved') {
      statusColor = AppColors.success;
      statusLabel = 'Resolved ✓';
    } else if (t.status == 'in_progress') {
      statusColor = AppColors.warning;
      statusLabel = 'In Progress';
    } else {
      statusColor = AppColors.info;
      statusLabel = 'Open (Assigned)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Ticket No + Type + Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.type.icon, color: typeColor, size: 14),
                    const SizedBox(width: 4),
                    Text(t.type.label,
                        style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(t.ticketNo, style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Description
          Text(t.title, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.white)),
          const SizedBox(height: 6),
          Text(
            t.description,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey300, height: 1.4),
          ),

          // Optional Inverter Fault Code
          if (t.errorCode != null && t.errorCode!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  Text('Inverter Fault Code: ${t.errorCode}',
                      style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],

          const Divider(color: AppColors.navy700, height: 18),

          // Attached Images Count & Assigned Technician with Employee No
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy900,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.gold500.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_rounded, color: AppColors.gold400, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${t.images.length} photos attached',
                      style: const TextStyle(fontSize: 11, color: AppColors.gold400, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (t.assignedStaff != null)
                Text(
                  (t.assignedStaff != null && t.assignedStaff!.isNotEmpty) ? 'Staff: ${t.assignedStaff}${t.assignedStaffEmpNo != null ? " (${t.assignedStaffEmpNo})" : ""}' : 'Awaiting Staff Assignment',
                  style: AppTextStyles.caption.copyWith(color: AppColors.teal400, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
