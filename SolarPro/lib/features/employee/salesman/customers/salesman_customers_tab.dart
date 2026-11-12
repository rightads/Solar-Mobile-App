import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/customers/data/customer_repository.dart';
import 'package:solar_pro/features/customers/data/models/customer_model.dart';
import 'package:solar_pro/features/customers/presentation/screens/customer_detail_screen.dart';

class SalesmanCustomersTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const SalesmanCustomersTab({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<SalesmanCustomersTab> createState() => _SalesmanCustomersTabState();
}

class _SalesmanCustomersTabState extends State<SalesmanCustomersTab> {
  final _searchController = TextEditingController();
  final _repository = CustomerRepository();

  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedStageFilter = 'All';

  final List<String> _stages = [
    'All',
    'Sale Confirmed',
    'Docs Received',
    'Advance Verified',
    'Work In Progress',
    'Handed Over',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? backendStage;
      if (_selectedStageFilter == 'Sale Confirmed') {
        backendStage = 'SALE_CONFIRMED';
      } else if (_selectedStageFilter == 'Docs Received') {
        backendStage = 'DOCUMENTS_RECEIVED';
      } else if (_selectedStageFilter == 'Advance Verified') {
        backendStage = 'ADVANCE_VERIFIED';
      } else if (_selectedStageFilter == 'Handed Over') {
        backendStage = 'HANDED_OVER';
      }

      final items = await _repository.getCustomers(
        stage: backendStage,
        search: _searchController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _customers = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SafeArea(
        child: Column(
          children: [
            // Search & Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Converted Customers',
                        style: TextStyle(
                          color: AppColors.fg,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.teal500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.teal500.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${_customers.length} Accounts',
                          style: const TextStyle(
                            color: AppColors.teal500,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.fg, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search customer name, phone, address...',
                      hintStyle: const TextStyle(color: AppColors.grey500),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppColors.grey400, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadCustomers();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.navy800,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.navy700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.navy700),
                      ),
                    ),
                    onSubmitted: (_) => _loadCustomers(),
                  ),
                ],
              ),
            ),

            // Stage Filter Chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _stages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final stage = _stages[index];
                  final isSelected = stage == _selectedStageFilter;

                  return FilterChip(
                    label: Text(
                      stage,
                      style: TextStyle(
                        color: isSelected ? AppColors.fg : AppColors.grey400,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStageFilter = stage);
                        _loadCustomers();
                      }
                    },
                    backgroundColor: AppColors.navy800,
                    selectedColor: AppColors.teal500,
                    checkmarkColor: AppColors.fg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      side: BorderSide(
                        color: isSelected ? AppColors.teal500 : AppColors.navy700,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Customer List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCustomers,
                color: AppColors.teal500,
                backgroundColor: AppColors.navy800,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal500),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey300, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCustomers,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal500,
                  foregroundColor: AppColors.fg,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_off_rounded, color: AppColors.grey500, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Converted Customers Found',
                style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you convert Closed leads with complete solar specifications, they will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey400, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return _CustomerCard(
          customer: customer,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(customerId: customer.id),
              ),
            );
          },
          onPaymentsTap: () {
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(3); // Navigate to Payments tab
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Manage payments for ${customer.name} in Prompt 5.'),
                  backgroundColor: AppColors.gold500,
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;
  final VoidCallback onPaymentsTap;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onPaymentsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.navy700),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name + Stage
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, color: AppColors.grey500, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              customer.mobile,
                              style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Stage pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: customer.stageColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: customer.stageColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      customer.stageDisplayLabel,
                      style: TextStyle(
                        color: customer.stageColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Address
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.grey500, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      customer.address,
                      style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.navy700, height: 20),

              // Specifications Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SpecItem(
                    label: 'System Size',
                    value: '${customer.capacityKw} kW',
                    icon: Icons.solar_power_rounded,
                  ),
                  _SpecItem(
                    label: 'Phase',
                    value: customer.phase.toUpperCase(),
                    icon: Icons.bolt_rounded,
                  ),
                  _SpecItem(
                    label: 'Contract Value',
                    value: customer.formattedPriceRupees,
                    icon: Icons.currency_rupee_rounded,
                    valueColor: AppColors.gold500,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPaymentsTap,
                    icon: const Icon(Icons.payments_outlined, color: AppColors.gold500, size: 15),
                    label: const Text('Payments', style: TextStyle(color: AppColors.gold500, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.gold500),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.fg, size: 15),
                    label: const Text('Details', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal500,
                      foregroundColor: AppColors.fg,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _SpecItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.grey500, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.fg,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
