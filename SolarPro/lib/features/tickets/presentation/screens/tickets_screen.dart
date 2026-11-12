import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  String _filterStatus = 'all';

  final List<_Ticket> _tickets = [];

  void _onStatusChange(_Ticket t, String newStatus) {
    setState(() {
      final idx = _tickets.indexWhere((it) => it.id == t.id);
      if (idx != -1) {
        _tickets[idx] = _tickets[idx].copyWith(status: newStatus);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ticket "${t.title}" status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}'),
        backgroundColor: newStatus == 'resolved' ? AppColors.success : AppColors.warning,
      ),
    );
  }

  void _showTicketDetail(BuildContext context, _Ticket t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.grey600,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: AppTextStyles.headlineSmall),
                      Text('Reported on ${t.date} • ${t.photoCount} photos attached',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(t.priority.toUpperCase(),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navy700,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                t.description,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey200, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            Text('Update Ticket Status',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _onStatusChange(t, 'in_progress');
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text('In Progress',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.warning)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _onStatusChange(t, 'resolved');
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text('Resolve ✓',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.success)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Service Technician dispatched to customer site for ${t.title}!'),
                    backgroundColor: AppColors.teal500,
                  ),
                );
              },
              child: Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text('Dispatch Service Technician',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.ink900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewTicketSheet(BuildContext context) {
    String selectedType = 'structure';
    int attachedPhotos = 2;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.grey600,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Raise Service Ticket', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 16),
                Text('Issue Type',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.grey400)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TicketTypeBtn(
                      label: 'Structure',
                      icon: Icons.foundation_rounded,
                      color: AppColors.orange500,
                      isSelected: selectedType == 'structure',
                      onTap: () =>
                          setModalState(() => selectedType = 'structure'),
                    ),
                    const SizedBox(width: 8),
                    _TicketTypeBtn(
                      label: 'Wiring',
                      icon: Icons.electrical_services_rounded,
                      color: AppColors.purple500,
                      isSelected: selectedType == 'wiring',
                      onTap: () => setModalState(() => selectedType = 'wiring'),
                    ),
                    const SizedBox(width: 8),
                    _TicketTypeBtn(
                      label: 'Inverter',
                      icon: Icons.power_rounded,
                      color: AppColors.error,
                      isSelected: selectedType == 'inverter',
                      onTap: () =>
                          setModalState(() => selectedType = 'inverter'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Short Title (e.g. Inverter Error E04)',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue in detail...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 14),
                // Upload photos
                GestureDetector(
                  onTap: () {
                    setModalState(() {
                      if (attachedPhotos < 6) attachedPhotos++;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Attached photo $attachedPhotos of site issue'),
                        backgroundColor: AppColors.teal500,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.navy700,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color: AppColors.gold500.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_rounded,
                            color: AppColors.gold500, size: 20),
                        const SizedBox(width: 8),
                        Text('Attach Photo ($attachedPhotos attached)',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.gold400)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    final title = titleCtrl.text.trim();
                    final desc = descCtrl.text.trim();
                    if (title.isEmpty) return;

                    final newTicket = _Ticket(
                      DateTime.now().millisecondsSinceEpoch.toString(),
                      title,
                      selectedType,
                      'open',
                      desc.isEmpty ? 'Service inspection requested by customer' : desc,
                      'Today',
                      'high',
                      attachedPhotos,
                    );

                    setState(() {
                      _tickets.insert(0, newTicket);
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Service Ticket "$title" raised successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: Text('Submit Service Ticket',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.ink900)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterStatus == 'all'
        ? _tickets
        : _tickets.where((t) => t.status == _filterStatus).toList();

    final openCount = _tickets.where((t) => t.status == 'open').length;
    final inProgCount = _tickets.where((t) => t.status == 'in_progress').length;
    final resolvedCount = _tickets.where((t) => t.status == 'resolved').length;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Service Tickets'),
        actions: [
          IconButton(
            tooltip: 'Raise Ticket',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: () => _showNewTicketSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _TicketBadge(
                  label: 'All (${_tickets.length})',
                  color: AppColors.teal500,
                  isSelected: _filterStatus == 'all',
                  onTap: () => setState(() => _filterStatus = 'all'),
                ),
                const SizedBox(width: 8),
                _TicketBadge(
                  label: 'Open ($openCount)',
                  color: AppColors.error,
                  isSelected: _filterStatus == 'open',
                  onTap: () => setState(() => _filterStatus = 'open'),
                ),
                const SizedBox(width: 8),
                _TicketBadge(
                  label: 'In Progress ($inProgCount)',
                  color: AppColors.warning,
                  isSelected: _filterStatus == 'in_progress',
                  onTap: () => setState(() => _filterStatus = 'in_progress'),
                ),
                const SizedBox(width: 8),
                _TicketBadge(
                  label: 'Resolved ($resolvedCount)',
                  color: AppColors.success,
                  isSelected: _filterStatus == 'resolved',
                  onTap: () => setState(() => _filterStatus = 'resolved'),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 12),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.support_agent_rounded,
                            size: 48, color: AppColors.grey600),
                        const SizedBox(height: 12),
                        Text('No tickets in this category',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.grey500)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      final typeColor = switch (t.type) {
                        'structure' => AppColors.orange500,
                        'wiring' => AppColors.purple500,
                        'inverter' => AppColors.error,
                        _ => AppColors.grey500,
                      };
                      final statusColor = switch (t.status) {
                        'open' => AppColors.error,
                        'in_progress' => AppColors.warning,
                        'resolved' => AppColors.success,
                        _ => AppColors.grey500,
                      };
                      return GestureDetector(
                        onTap: () => _showTicketDetail(context, t),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.navy800,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border:
                                Border.all(color: typeColor.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Icon(_typeIcon(t.type),
                                        color: typeColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t.title,
                                            style: AppTextStyles.labelLarge),
                                        Text(t.date,
                                            style: AppTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.pill),
                                        ),
                                        child: Text(
                                          t.status.replaceAll('_', ' '),
                                          style: AppTextStyles.caption.copyWith(
                                              color: statusColor, fontSize: 9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(t.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.grey400)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.pill),
                                    ),
                                    child: Text(t.type.toUpperCase(),
                                        style: AppTextStyles.caption.copyWith(
                                            color: typeColor, fontSize: 9)),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.image_rounded,
                                      size: 14, color: AppColors.grey500),
                                  Text(' ${t.photoCount} photos • Tap to manage →',
                                      style: AppTextStyles.caption.copyWith(
                                          color: AppColors.gold400, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(delay: Duration(milliseconds: i * 80))
                          .fadeIn(duration: 380.ms)
                          .slideY(begin: 0.05, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
        'structure' => Icons.foundation_rounded,
        'wiring' => Icons.electrical_services_rounded,
        'inverter' => Icons.power_rounded,
        _ => Icons.build_rounded,
      };
}

class _TicketBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TicketBadge({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? color : AppColors.navy600,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? color : AppColors.grey400,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _TicketTypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _TicketTypeBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppColors.navy700,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: isSelected ? color : AppColors.navy500,
                width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : AppColors.grey500, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                      color: isSelected ? color : AppColors.grey500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ticket {
  final String id, title, type, status, description, date, priority;
  final int photoCount;
  const _Ticket(this.id, this.title, this.type, this.status, this.description, this.date,
      this.priority, this.photoCount);

  _Ticket copyWith({String? status}) {
    return _Ticket(
      id,
      title,
      type,
      status ?? this.status,
      description,
      date,
      priority,
      photoCount,
    );
  }
}
