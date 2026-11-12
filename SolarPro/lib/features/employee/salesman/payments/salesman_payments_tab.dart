import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/customers/data/customer_repository.dart';
import 'package:solar_pro/features/customers/data/models/customer_model.dart';
import 'package:solar_pro/features/employee/salesman/payments/customer_payment_detail_screen.dart';
import 'package:solar_pro/features/employee/salesman/payments/widgets/pending_approval_card.dart';
import 'package:solar_pro/features/payments/data/models/payment_model.dart';
import 'package:solar_pro/features/payments/data/payment_repository.dart';

class SalesmanPaymentsTab extends StatefulWidget {
  const SalesmanPaymentsTab({super.key});

  @override
  State<SalesmanPaymentsTab> createState() => _SalesmanPaymentsTabState();
}

class _SalesmanPaymentsTabState extends State<SalesmanPaymentsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _paymentRepo = PaymentRepository();
  final _customerRepo = CustomerRepository();

  List<PaymentModel> _pendingQueue = [];
  List<CustomerModel> _customers = [];

  bool _isLoadingQueue = true;
  bool _isLoadingCustomers = true;
  String? _queueError;
  String? _customersError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQueue();
    _loadCustomers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoadingQueue = true;
      _queueError = null;
    });

    try {
      final items = await _paymentRepo.getPendingPayments();
      if (mounted) {
        setState(() {
          _pendingQueue = items;
          _isLoadingQueue = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _queueError = e.toString().replaceAll('Exception: ', '');
          _isLoadingQueue = false;
        });
      }
    }
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
      _customersError = null;
    });

    try {
      final items = await _customerRepo.getCustomers();
      if (mounted) {
        setState(() {
          _customers = items;
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _customersError = e.toString().replaceAll('Exception: ', '');
          _isLoadingCustomers = false;
        });
      }
    }
  }

  Future<void> _approvePayment(PaymentModel payment) async {
    try {
      final approved = await _paymentRepo.salesApprovePayment(payment.id);
      setState(() {
        final index = _pendingQueue.indexWhere((p) => p.id == payment.id);
        if (index != -1) {
          _pendingQueue[index] = approved;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment approved! Forwarded to Admin for final account verification.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectPayment(PaymentModel payment, String reason) async {
    try {
      await _paymentRepo.rejectPayment(payment.id, reason: reason);
      setState(() {
        _pendingQueue.removeWhere((p) => p.id == payment.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected and client notified with reason.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingQueue
        .where((p) => p.status.toLowerCase() == 'pending')
        .length;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payments & Collections',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.grey300),
                    onPressed: () {
                      _loadQueue();
                      _loadCustomers();
                    },
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.navy700),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.teal500,
                labelColor: AppColors.fg,
                unselectedLabelColor: AppColors.grey400,
                indicator: BoxDecoration(
                  color: AppColors.teal500,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('To Approve', style: TextStyle(fontWeight: FontWeight.w700)),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold500,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(color: AppColors.shadow, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(
                    child: Text('Customer Accounts', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildQueueTab(),
                  _buildCustomerAccountsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    if (_isLoadingQueue) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal500));
    }

    if (_queueError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44),
              const SizedBox(height: 12),
              Text(_queueError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey300)),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _loadQueue, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_pendingQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Approval Queue Clean!',
                style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'All customer payment submissions have been reviewed.',
                style: TextStyle(color: AppColors.grey400, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueue,
      color: AppColors.teal500,
      backgroundColor: AppColors.navy800,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingQueue.length,
        itemBuilder: (context, index) {
          final payment = _pendingQueue[index];
          return PendingApprovalCard(
            payment: payment,
            onApprove: () => _approvePayment(payment),
            onReject: (reason) => _rejectPayment(payment, reason),
          );
        },
      ),
    );
  }

  Widget _buildCustomerAccountsTab() {
    if (_isLoadingCustomers) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal500));
    }

    if (_customersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44),
              const SizedBox(height: 12),
              Text(_customersError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey300)),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _loadCustomers, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(
        child: Text(
          'No customers available yet. Convert Closed leads to begin tracking collections.',
          style: TextStyle(color: AppColors.grey400, fontSize: 13),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomers,
      color: AppColors.teal500,
      backgroundColor: AppColors.navy800,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final c = _customers[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.navy700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      c.formattedPriceRupees,
                      style: const TextStyle(color: AppColors.gold500, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${c.capacityKw} kW • ${c.address}',
                  style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(color: AppColors.navy700, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.stageColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        c.stageDisplayLabel,
                        style: TextStyle(color: c.stageColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerPaymentDetailScreen(
                              customerId: c.id,
                              customerName: c.name,
                              finalPricePaise: c.finalPrice,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                      label: const Text('Manage Payments', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.teal500,
                        foregroundColor: AppColors.fg,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
