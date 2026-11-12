import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/salesman/payments/models/loan_details_model.dart';
import 'package:solar_pro/features/employee/salesman/payments/models/payment_plan_model.dart';
import 'package:solar_pro/features/employee/salesman/payments/widgets/loan_details_card.dart';
import 'package:solar_pro/features/employee/salesman/payments/widgets/payment_plan_builder_card.dart';
import 'package:solar_pro/features/employee/salesman/payments/widgets/record_payment_sheet.dart';
import 'package:solar_pro/features/payments/data/models/payment_model.dart';
import 'package:solar_pro/features/payments/data/payment_repository.dart';

class CustomerPaymentDetailScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final int finalPricePaise;

  const CustomerPaymentDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.finalPricePaise = 25000000,
  });

  @override
  State<CustomerPaymentDetailScreen> createState() => _CustomerPaymentDetailScreenState();
}

class _CustomerPaymentDetailScreenState extends State<CustomerPaymentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repository = PaymentRepository();

  bool _isLoading = true;
  String? _errorMessage;
  List<PaymentModel> _payments = [];
  late PaymentSummaryModel _summary;
  late PaymentPlanModel _plan;
  late LoanDetailsModel _loan;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _summary = PaymentSummaryModel(
      finalPrice: widget.finalPricePaise,
      totalVerified: 0,
      totalPending: 0,
      balance: widget.finalPricePaise,
      status: 'pending',
    );
    _plan = PaymentPlanModel(customerId: widget.customerId);
    _loan = LoanDetailsModel(customerId: widget.customerId);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final paymentsResult = await _repository.getCustomerPayments(widget.customerId);
      final planData = await _repository.getPaymentPlan(widget.customerId);
      final loanData = await _repository.getLoanDetails(widget.customerId);

      // Lock plan if any payment has been approved or verified
      final hasApprovedPayment = paymentsResult.items.any(
        (p) => p.status == 'sales_approved' || p.status == 'verified',
      );

      final updatedPlan = planData.copyWith(
        isLocked: planData.isLocked || hasApprovedPayment,
      );

      if (mounted) {
        setState(() {
          _payments = paymentsResult.items;
          _summary = paymentsResult.summary;
          _plan = updatedPlan;
          _loan = loanData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback gracefully to default summary
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _openRecordPayment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordPaymentSheet(
        customerId: widget.customerId,
        customerName: widget.customerName,
        balancePaise: _summary.balance,
        onPaymentRecorded: _loadAllData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy800,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customerName,
              style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Payments & Financing Management',
              style: TextStyle(color: AppColors.teal500, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.grey300),
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.teal500,
          labelColor: AppColors.teal500,
          unselectedLabelColor: AppColors.grey400,
          tabs: const [
            Tab(text: 'Payments'),
            Tab(text: 'Payment Plan'),
            Tab(text: 'Loan Details'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecordPayment,
        backgroundColor: AppColors.teal500,
        foregroundColor: AppColors.fg,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Financial Summary Card
            _buildFinancialSummaryCard(),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teal500))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPaymentsTab(),
                        _buildPlanTab(),
                        _buildLoanTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Contract Price', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                  Text(
                    _summary.formattedFinalPrice,
                    style: const TextStyle(color: AppColors.fg, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Remaining Balance', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                  Text(
                    _summary.formattedBalance,
                    style: const TextStyle(color: AppColors.gold500, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: _summary.verifiedProgress,
              minHeight: 6,
              backgroundColor: AppColors.navy900,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 12),

          // Metrics breakdown row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FinancialStat(
                label: 'Verified',
                value: _summary.formattedVerified,
                color: AppColors.success,
              ),
              _FinancialStat(
                label: 'Pending Approval',
                value: _summary.formattedPending,
                color: AppColors.info,
              ),
              _FinancialStat(
                label: 'Verified %',
                value: '${(_summary.verifiedProgress * 100).toInt()}%',
                color: AppColors.fg,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey300, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, color: AppColors.grey600, size: 48),
              SizedBox(height: 12),
              Text('No Payments Recorded Yet', style: TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'Tap "Record Payment" below to record booking advance or milestones.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey400, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
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
                    p.formattedAmountRupees,
                    style: const TextStyle(color: AppColors.gold500, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      p.statusLabel,
                      style: TextStyle(color: p.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(p.modeIcon, color: AppColors.teal500, size: 14),
                  const SizedBox(width: 4),
                  Text(p.modeLabel, style: const TextStyle(color: AppColors.fg, fontSize: 12)),
                  const Spacer(),
                  Text(p.formattedPaidDate, style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                ],
              ),
              if (p.referenceNo != null && p.referenceNo!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Ref: ${p.referenceNo}', style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
              ],
              if (p.rejectionReason != null && p.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Rejected: "${p.rejectionReason}"',
                          style: const TextStyle(color: AppColors.error, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: PaymentPlanBuilderCard(
        plan: _plan,
        finalPricePaise: widget.finalPricePaise,
        onSavePlan: (updated) async {
          await _repository.savePaymentPlan(updated);
          setState(() => _plan = updated);
        },
      ),
    );
  }

  Widget _buildLoanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: LoanDetailsCard(
        loanDetails: _loan,
        onSaveLoan: (updated) async {
          await _repository.saveLoanDetails(updated);
          setState(() => _loan = updated);
        },
      ),
    );
  }
}

class _FinancialStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FinancialStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey400, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
