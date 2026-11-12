import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<_Lead> _openLeads = [];
  List<_Lead> _closedLeads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    try {
      final rawLeads = await ApiClient().getLeads();
      final List<_Lead> open = [];
      final List<_Lead> closed = [];
      for (final item in rawLeads) {
        final l = _Lead(
          id: item['id']?.toString() ?? item['_id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Unnamed Lead',
          phone: item['phone']?.toString() ?? '',
          area: item['area']?.toString() ?? 'Delhi NCR',
          kw: (item['kw'] is num) ? (item['kw'] as num).toInt() : 3,
          status: item['status']?.toString() ?? 'new',
          source: item['source']?.toString() ?? 'Direct',
          assignedSalesId: item['assigned_sales_id']?.toString(),
          assignedSalesName: item['assigned_sales_name']?.toString(),
        );

        if (l.status == 'converted' || l.status == 'lost') {
          closed.add(l);
        } else {
          open.add(l);
        }
      }
      if (mounted) {
        setState(() {
          _openLeads = open;
          _closedLeads = closed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    return switch (status) {
      'new' => AppColors.teal500,
      'contacted' => AppColors.info,
      'follow_up' => AppColors.warning,
      'converted' => AppColors.success,
      'lost' => AppColors.error,
      _ => AppColors.grey500,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'new' => 'New',
      'contacted' => 'Contacted',
      'follow_up' => 'Follow Up',
      'converted' => 'Converted',
      'lost' => 'Lost',
      _ => status,
    };
  }

  List<_Lead> _filtered(List<_Lead> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((l) {
      return l.name.toLowerCase().contains(_searchQuery) ||
          l.phone.contains(_searchQuery) ||
          l.area.toLowerCase().contains(_searchQuery) ||
          (l.referrerName?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  void _onStatusChanged(_Lead lead, String newStatus) {
    setState(() {
      _openLeads.removeWhere((l) => l.id == lead.id);
      _closedLeads.removeWhere((l) => l.id == lead.id);
      final updated = lead.copyWith(status: newStatus);
      if (newStatus == 'converted' || newStatus == 'lost') {
        _closedLeads.insert(0, updated);
      } else {
        _openLeads.insert(0, updated);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lead status updated to ${_statusLabel(newStatus)}'),
        backgroundColor: _statusColor(newStatus),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOpen = _filtered(_openLeads);
    final filteredClosed = _filtered(_closedLeads);

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Lead Management'),
        actions: [
          IconButton(
            tooltip: 'Add Employee / Labour',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.teal500.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.teal500),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.teal400, size: 18),
            ),
            onPressed: () => _showAddEmployeeSheet(context),
          ),
          IconButton(
            tooltip: 'Add Lead',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: () => _showAddLeadSheet(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold500,
          indicatorWeight: 2,
          labelStyle: AppTextStyles.labelLarge,
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          labelColor: AppColors.gold500,
          unselectedLabelColor: AppColors.grey500,
          tabs: [
            Tab(text: 'Lead Management (${_openLeads.length})'),
            Tab(text: 'Sales Closed (${_closedLeads.length})'),
          ],
        ),

      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
              decoration: InputDecoration(
                hintText: 'Search leads by name, phone, area...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold500),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _LeadList(
                        leads: filteredOpen,
                        statusColor: _statusColor,
                        statusLabel: _statusLabel,
                        onLeadTap: (l) => _showLeadDetailSheet(context, l),
                      ),
                      _LeadList(
                        leads: filteredClosed,
                        statusColor: _statusColor,
                        statusLabel: _statusLabel,
                        onLeadTap: (l) => _showLeadDetailSheet(context, l),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddLeadSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final kwCtrl = TextEditingController();
    final referrerCtrl = TextEditingController();
    String source = 'Reference';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Add New Lead', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Customer Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Mobile Number (10 digits)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: areaCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Area / Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: kwCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Expected kW',
                          prefixIcon: Icon(Icons.bolt_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Lead Source',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey400)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Reference', 'WhatsApp', 'Instagram', 'Call', 'Website']
                      .map((s) {
                    final isSel = source == s;
                    return GestureDetector(
                      onTap: () => setSheetState(() => source = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.gold500.withValues(alpha: 0.15)
                              : AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: isSel ? AppColors.gold500 : AppColors.navy600,
                          ),
                        ),
                        child: Text(
                          s,
                          style: AppTextStyles.caption.copyWith(
                            color: isSel ? AppColors.gold400 : AppColors.grey400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (source == 'Reference') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: referrerCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Referred By (Name of Person)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0),
                ],
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final area = areaCtrl.text.trim();
                    final kw = int.tryParse(kwCtrl.text.trim()) ?? 3;
                    final referrer = source == 'Reference'
                        ? referrerCtrl.text.trim()
                        : null;

                    if (name.isEmpty || phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter name and phone number'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    final newLead = _Lead(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      phone: phone,
                      area: area.isEmpty ? 'Delhi NCR' : area,
                      kw: kw,
                      status: 'new',
                      source: source,
                      referrerName: referrer?.isNotEmpty == true ? referrer : null,
                    );

                    setState(() {
                      _openLeads.insert(0, newLead);
                    });

                    // Save to backend asynchronously
                    ApiClient().createLead(
                      name: name,
                      phone: phone,
                      area: area.isEmpty ? 'Delhi NCR' : area,
                      kw: kw.toDouble(),
                      status: 'new',
                      source: source,
                    ).catchError((_) => null);

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lead "${newLead.name}" added successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold500.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Save Lead',
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900),
                      ),
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

  void _showLeadDetailSheet(BuildContext context, _Lead lead) {
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _statusColor(lead.status).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      lead.name[0],
                      style: AppTextStyles.headlineMedium
                          .copyWith(color: _statusColor(lead.status)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead.name, style: AppTextStyles.headlineSmall),
                      const SizedBox(height: 2),
                      Text('+91 ${lead.phone}', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(lead.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _statusLabel(lead.status),
                    style: AppTextStyles.caption
                        .copyWith(color: _statusColor(lead.status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info rows
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy700,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.navy600),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: AppColors.grey400),
                      const SizedBox(width: 8),
                      Text('Area: ', style: AppTextStyles.caption),
                      Text(lead.area, style: AppTextStyles.labelMedium),
                      const Spacer(),
                      const Icon(Icons.bolt_rounded, size: 16, color: AppColors.gold500),
                      const SizedBox(width: 4),
                      Text('${lead.kw} kW Expected',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.gold400)),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.navy600),
                  Row(
                    children: [
                      const Icon(Icons.source_rounded,
                          size: 16, color: AppColors.teal500),
                      const SizedBox(width: 8),
                      Text('Source: ', style: AppTextStyles.caption),
                      Text(
                        lead.source == 'Reference' &&
                                (lead.referrerName?.isNotEmpty ?? false)
                            ? 'Reference (by ${lead.referrerName})'
                            : lead.source,
                        style: AppTextStyles.labelMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons: Call & WhatsApp
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.phone_in_talk_rounded,
                                  color: AppColors.fg, size: 18),
                              const SizedBox(width: 8),
                              Text('Calling +91 ${lead.phone}...'),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_rounded,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Text('Call Lead',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.chat_bubble_rounded,
                                  color: AppColors.fg, size: 18),
                              const SizedBox(width: 8),
                              Text('Opening WhatsApp chat with ${lead.name}...'),
                            ],
                          ),
                          backgroundColor: AppColors.teal500,
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.teal500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.teal500.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_rounded,
                              color: AppColors.teal500, size: 18),
                          const SizedBox(width: 8),
                          Text('WhatsApp',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.teal500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Notebook Page 1: Sale Person Assign
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navy700,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: (lead.assignedSalesName?.isNotEmpty ?? false)
                      ? AppColors.teal500
                      : AppColors.navy600,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_circle_rounded,
                      size: 20, color: AppColors.teal500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assigned Sales Person (Page 1):',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.grey400)),
                        Text(
                          (lead.assignedSalesName?.isNotEmpty ?? false)
                              ? lead.assignedSalesName!
                              : 'No Sales Person Assigned',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: (lead.assignedSalesName?.isNotEmpty ?? false)
                                ? AppColors.teal400
                                : AppColors.fg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAssignSalesSheet(context, lead);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.teal500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.teal500),
                      ),
                      child: Text(
                        (lead.assignedSalesName?.isNotEmpty ?? false)
                            ? 'Reassign'
                            : 'Assign',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.teal400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text('Update Status',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['new', 'contacted', 'follow_up', 'converted', 'lost'].map((st) {
                final isCurrent = lead.status == st;
                final col = _statusColor(st);
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _onStatusChanged(lead, st);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent ? col.withValues(alpha: 0.2) : AppColors.navy700,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isCurrent ? col : AppColors.navy600,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      _statusLabel(st),
                      style: AppTextStyles.caption.copyWith(
                        color: isCurrent ? col : AppColors.grey400,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Notebook Page 1: Sales Closed (Convert to Customer)
            if (lead.status != 'converted')
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiClient().closeSaleLead(
                      leadId: lead.id,
                      customerData: {
                        'name': lead.name,
                        'phone': lead.phone,
                        'address': lead.area,
                        'kw': lead.kw.toDouble(),
                      },
                    );
                    _onStatusChanged(lead, 'converted');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '🎉 Sales Closed for ${lead.name}! Credited to ${lead.assignedSalesName ?? "Sales Team"}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      context.push(
                          '/vendor/customers/${lead.name.replaceAll(' ', '-').toLowerCase()}');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error closing sale: $e'),
                            backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                child: Container(
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.ink900, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Sales Closed (Convert to Customer)',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.ink900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Assign Sales Person Sheet ────────────────────────────────────
  void _showAssignSalesSheet(BuildContext context, _Lead lead) async {
    List<Map<String, dynamic>> salespersons =
        await ApiClient().getSalespersons();
    if (!context.mounted) return;
    if (salespersons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No approved sales staff yet. Approve a sales registration first.'),
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
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
            const SizedBox(height: 16),
            Text('Assign Sales Person', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text('Assign ${lead.name} to salesperson for follow-up & closing:',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 16),
            ...salespersons.map((sp) {
              final name = sp['name']?.toString() ?? 'Sales Staff';
              final spId = sp['id']?.toString() ?? '';
              final isCurrent = lead.assignedSalesId == spId ||
                  lead.assignedSalesName == name;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.teal500.withValues(alpha: 0.15)
                      : AppColors.navy700,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: isCurrent ? AppColors.teal500 : AppColors.navy600),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent ? AppColors.teal500 : AppColors.navy600,
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.fg, size: 20),
                  ),
                  title: Text(name, style: AppTextStyles.labelMedium),
                  subtitle: Text(sp['phone']?.toString() ?? '',
                      style: AppTextStyles.caption),
                  trailing: Icon(
                    isCurrent
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isCurrent ? AppColors.teal400 : AppColors.grey500,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ApiClient().assignLead(
                        leadId: lead.id,
                        salesId: spId,
                        salesName: name,
                      );
                      setState(() {
                        final idx =
                            _openLeads.indexWhere((it) => it.id == lead.id);
                        if (idx != -1) {
                          _openLeads[idx] = _openLeads[idx].copyWith(
                            assignedSalesId: spId,
                            assignedSalesName: name,
                            status: 'contacted',
                          );
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lead assigned to $name!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to assign lead: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Employees Add Like Labour Sheet ───────────────────────────────
  void _showAddEmployeeSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final customTeamCtrl = TextEditingController();
    String selectedTrade = 'Structure Labour';
    String selectedTeam = 'Team A';
    bool isSaving = false;

    final trades = [
      'Structure Labour',
      'Electrical Labour (Electrician)',
      'Civil Work Labour',
      'Sales Person',
      'KEDL Liaison Executive',
    ];

    final teams = ['Team A', 'Team B', 'Team C', 'Custom Team'];

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
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Employees Add Like Labour',
                        style: AppTextStyles.headlineSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.teal500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('Page 1 & 2',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.teal400)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Worker / Employee Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),

                // Phone
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Mobile Number (10 digits)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 16),

                // Trade / Role
                Text('Trade / Worker Skill:',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.grey400)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: trades.map((tr) {
                    final isSel = selectedTrade == tr;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedTrade = tr),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.teal500.withValues(alpha: 0.2)
                              : AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: isSel ? AppColors.teal500 : AppColors.navy600,
                          ),
                        ),
                        child: Text(
                          tr,
                          style: AppTextStyles.caption.copyWith(
                            color: isSel ? AppColors.teal400 : AppColors.grey300,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Team assignment
                Text('Team Assignment (Page 2: Team A, Team B, ...):',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.grey400)),
                const SizedBox(height: 8),
                Row(
                  children: teams.map((tm) {
                    final isSel = selectedTeam == tm;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedTeam = tm),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.gold500.withValues(alpha: 0.2)
                                : AppColors.navy700,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: isSel ? AppColors.gold500 : AppColors.navy600,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              tm,
                              style: AppTextStyles.caption.copyWith(
                                color: isSel ? AppColors.gold400 : AppColors.grey400,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedTeam == 'Custom Team') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customTeamCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter Custom Team Name (e.g. Team D)',
                      prefixIcon: Icon(Icons.groups_rounded),
                    ),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.fg),
                  ),
                ],
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final team = selectedTeam == 'Custom Team'
                              ? customTeamCtrl.text.trim()
                              : selectedTeam;

                          if (name.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter name and mobile number'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);
                          try {
                            await ApiClient().createEmployee(
                              name: name,
                              phone: phone,
                              trade: selectedTrade,
                              team: team.isEmpty ? 'Team A' : team,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Employee "$name" added to $team as $selectedTrade!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add employee: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.navy900),
                            )
                          : Text(
                              'Save Employee & Add to Team',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: AppColors.ink900),
                            ),
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

}

class _LeadList extends StatelessWidget {
  final List<_Lead> leads;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final ValueChanged<_Lead> onLeadTap;

  const _LeadList({
    required this.leads,
    required this.statusColor,
    required this.statusLabel,
    required this.onLeadTap,
  });

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded,
                color: AppColors.grey600, size: 48),
            const SizedBox(height: 12),
            Text('No leads found',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final lead = leads[i];
        final color = statusColor(lead.status);
        return GestureDetector(
          onTap: () => onLeadTap(lead),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.navy600),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      lead.name[0],
                      style: AppTextStyles.headlineSmall.copyWith(color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(lead.name, style: AppTextStyles.labelLarge),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              statusLabel(lead.status),
                              style: AppTextStyles.caption.copyWith(color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.grey500),
                          const SizedBox(width: 4),
                          Text(lead.area, style: AppTextStyles.bodySmall),
                          const SizedBox(width: 12),
                          const Icon(Icons.bolt_rounded,
                              size: 12, color: AppColors.gold500),
                          const SizedBox(width: 4),
                          Text('${lead.kw} kW',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.gold400)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lead.source == 'Reference' &&
                                      (lead.referrerName?.isNotEmpty ?? false)
                                  ? 'Source: Reference (${lead.referrerName})'
                                  : 'Source: ${lead.source}',
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tap for details →',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.gold400, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_pin_circle_rounded,
                              size: 12,
                              color: (lead.assignedSalesName?.isNotEmpty ?? false)
                                  ? AppColors.teal400
                                  : AppColors.grey500),
                          const SizedBox(width: 4),
                          Text(
                            (lead.assignedSalesName?.isNotEmpty ?? false)
                                ? 'Sales: ${lead.assignedSalesName}'
                                : 'Unassigned Sales',
                            style: AppTextStyles.caption.copyWith(
                              color: (lead.assignedSalesName?.isNotEmpty ?? false)
                                  ? AppColors.teal400
                                  : AppColors.grey500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              ],
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 350.ms)
            .slideX(begin: 0.05, end: 0);
      },
    );
  }
}

class _Lead {
  final String id, name, phone, area, status, source;
  final String? referrerName;
  final String? assignedSalesId;
  final String? assignedSalesName;
  final int kw;

  const _Lead({
    required this.id,
    required this.name,
    required this.phone,
    required this.area,
    required this.kw,
    required this.status,
    required this.source,
    this.referrerName,
    this.assignedSalesId,
    this.assignedSalesName,
  });

  _Lead copyWith({
    String? id,
    String? name,
    String? phone,
    String? area,
    String? status,
    String? source,
    String? referrerName,
    String? assignedSalesId,
    String? assignedSalesName,
    int? kw,
  }) {
    return _Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      area: area ?? this.area,
      status: status ?? this.status,
      source: source ?? this.source,
      referrerName: referrerName ?? this.referrerName,
      assignedSalesId: assignedSalesId ?? this.assignedSalesId,
      assignedSalesName: assignedSalesName ?? this.assignedSalesName,
      kw: kw ?? this.kw,
    );
  }
}
