import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/kedl_demand_card.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/pay_demand_sheet.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';

class KedlDemandsTab extends StatefulWidget {
  final KedlRepository? repository;

  const KedlDemandsTab({
    super.key,
    this.repository,
  });

  @override
  State<KedlDemandsTab> createState() => _KedlDemandsTabState();
}

class _KedlDemandsTabState extends State<KedlDemandsTab> {
  late KedlRepository _repo;
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'open', 'overdue', 'paid', 'waived'
  String _searchQuery = '';
  List<KedlFileModel> _files = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? KedlRepository();
    _loadDemands();
  }

  Future<void> _loadDemands() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.listKedlFiles();
      if (mounted) {
        setState(() {
          _files = list;
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
          _loadDemands();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demand marked as resolved!'), backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }

  Future<void> _handleWaive(KedlDemandModel demand) async {
    try {
      await _repo.updateDemand(demand.id, status: KedlDemandStatus.waived);
      _loadDemands();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demand waived.'), backgroundColor: AppColors.warning),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Collect all demands across files
    final List<KedlDemandModel> allDemands = [];
    for (final f in _files) {
      allDemands.addAll(f.demands);
    }

    // Sort by due date (overdue first, then upcoming due dates, then no due date)
    allDemands.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    final filtered = allDemands.where((d) {
      // Filter status
      switch (_filterStatus) {
        case 'open':
          if (d.status != KedlDemandStatus.open) return false;
          break;
        case 'overdue':
          if (!d.isOverdue) return false;
          break;
        case 'paid':
          if (d.status != KedlDemandStatus.paid) return false;
          break;
        case 'waived':
          if (d.status != KedlDemandStatus.waived) return false;
          break;
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = d.customerName.toLowerCase().contains(q) || d.description.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    final overdueCount = allDemands.where((d) => d.isOverdue).length;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Fee Demands',
                    style: TextStyle(color: AppColors.fg, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (overdueCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text(
                            '$overdueCount OVERDUE',
                            style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppColors.fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search customer name or fee note...',
                  hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.grey400, size: 20),
                  filled: true,
                  fillColor: AppColors.navy800,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Filter Chips
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip('All (${allDemands.length})', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Open (${allDemands.where((d) => d.status == KedlDemandStatus.open).length})', 'open'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Overdue ($overdueCount)', 'overdue', isAlert: overdueCount > 0),
                  const SizedBox(width: 8),
                  _buildFilterChip('Paid (${allDemands.where((d) => d.status == KedlDemandStatus.paid).length})', 'paid'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Waived (${allDemands.where((d) => d.status == KedlDemandStatus.waived).length})', 'waived'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Demands List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
                  : filtered.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadDemands,
                          color: AppColors.gold500,
                          backgroundColor: AppColors.navy800,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: const [
                                  SizedBox(height: 40),
                                  Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                                  SizedBox(height: 12),
                                  Text(
                                    'No demands matching filter.',
                                    style: TextStyle(color: AppColors.grey400, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDemands,
                          color: AppColors.gold500,
                          backgroundColor: AppColors.navy800,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final demand = filtered[index];
                              return KedlDemandCard(
                                demand: demand,
                                onMarkPaid: () => _showPayDemand(demand),
                                onWaive: () => _handleWaive(demand),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, {bool isAlert = false}) {
    final isSelected = _filterStatus == key;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filterStatus = key);
      },
      selectedColor: isAlert ? AppColors.error.withValues(alpha: 0.3) : AppColors.gold500.withValues(alpha: 0.25),
      checkmarkColor: isAlert ? AppColors.error : AppColors.gold500,
      labelStyle: TextStyle(
        color: isSelected ? (isAlert ? AppColors.error : AppColors.gold500) : AppColors.grey400,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: AppColors.navy800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
    );
  }
}
