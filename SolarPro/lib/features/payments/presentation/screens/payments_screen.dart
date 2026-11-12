import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_Payment> _pending = [];
  final List<_Payment> _verified = [];

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

  int get _totalPendingAmount =>
      _pending.fold(0, (sum, p) => sum + p.amount);

  int get _totalVerifiedAmount =>
      _verified.fold(0, (sum, p) => sum + p.amount);

  void _verifyPayment(_Payment p) {
    setState(() {
      _pending.removeWhere((item) => item.id == p.id);
      _verified.insert(0, p.copyWith(status: 'verified'));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment of ₹${p.amount} from ${p.name} verified successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _rejectPayment(_Payment p) {
    setState(() {
      _pending.removeWhere((item) => item.id == p.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment of ₹${p.amount} rejected and returned for review.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showRecordPaymentSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String milestone = 'Advance';
    String mode = 'UPI';

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
                Text('Record Payment / Invoice',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Customer Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Reference / UTR / Cheque No.',
                    prefixIcon: Icon(Icons.receipt_outlined),
                  ),
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 14),
                Text('Milestone', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['Advance', '2nd Instalment', '3rd Instalment', 'Final Balance']
                      .map((m) {
                    final isSel = milestone == m;
                    return GestureDetector(
                      onTap: () => setSheetState(() => milestone = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.gold500.withValues(alpha: 0.2)
                              : AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color:
                                  isSel ? AppColors.gold500 : AppColors.navy600),
                        ),
                        child: Text(m,
                            style: AppTextStyles.caption.copyWith(
                                color: isSel
                                    ? AppColors.gold400
                                    : AppColors.grey400)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('Payment Mode', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['UPI', 'Bank Transfer', 'Cheque', 'Cash'].map((mod) {
                    final isSel = mode == mod;
                    return GestureDetector(
                      onTap: () => setSheetState(() => mode = mod),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.teal500.withValues(alpha: 0.2)
                              : AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color:
                                  isSel ? AppColors.teal500 : AppColors.navy600),
                        ),
                        child: Text(mod,
                            style: AppTextStyles.caption.copyWith(
                                color: isSel
                                    ? AppColors.teal400
                                    : AppColors.grey400)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    final name = nameCtrl.text.trim();
                    final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (name.isEmpty || amt <= 0) return;

                    final newPay = _Payment(
                      DateTime.now().millisecondsSinceEpoch.toString(),
                      name,
                      amt,
                      milestone,
                      'sales_approved',
                      'Today',
                      mode,
                      refCtrl.text.trim().isEmpty ? 'Pending UTR' : refCtrl.text.trim(),
                    );

                    setState(() {
                      _pending.insert(0, newPay);
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Payment of ₹$amt for $name recorded for verification!'),
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
                      child: Text('Submit for Verification',
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

  void _showPaymentSlip(BuildContext context, _Payment p) {
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
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.gold500, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Receipt', style: AppTextStyles.headlineSmall),
                    Text(p.ref, style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
            const Divider(height: 28, color: AppColors.navy600),
            _slipRow('Customer', p.name),
            const SizedBox(height: 8),
            _slipRow('Amount', '₹${p.amount}'),
            const SizedBox(height: 8),
            _slipRow('Milestone', p.label),
            const SizedBox(height: 8),
            _slipRow('Payment Mode', p.mode),
            const SizedBox(height: 8),
            _slipRow('Date', p.date),
            const SizedBox(height: 8),
            _slipRow('Status', p.status.toUpperCase()),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment receipt downloaded as PDF!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: Text('Download Receipt',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.ink900)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _slipRow(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: AppTextStyles.caption),
        Text(v,
            style:
                AppTextStyles.labelMedium.copyWith(color: AppColors.grey100)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            tooltip: 'Record Payment',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: () => _showRecordPaymentSheet(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold500,
          labelColor: AppColors.gold500,
          unselectedLabelColor: AppColors.grey500,
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'Verified (${_verified.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDDD7F2), Color(0xFFFFFFFF)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border:
                  Border.all(color: AppColors.gold500.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                _SummaryItem(
                    label: 'Total Pending',
                    value: '₹${(_totalPendingAmount / 1000).toStringAsFixed(0)}K',
                    color: AppColors.warning),
                _VerticalDivider(),
                _SummaryItem(
                    label: 'Total Verified',
                    value: '₹${(_totalVerifiedAmount / 1000).toStringAsFixed(0)}K',
                    color: AppColors.success),
                _VerticalDivider(),
                _SummaryItem(
                    label: 'Total Collected',
                    value: '₹${((_totalPendingAmount + _totalVerifiedAmount) / 1000).toStringAsFixed(0)}K',
                    color: AppColors.gold500),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PaymentList(
                  payments: _pending,
                  isVerifyMode: true,
                  onVerify: _verifyPayment,
                  onReject: _rejectPayment,
                  onTapItem: (p) => _showPaymentSlip(context, p),
                ),
                _PaymentList(
                  payments: _verified,
                  isVerifyMode: false,
                  onVerify: _verifyPayment,
                  onReject: _rejectPayment,
                  onTapItem: (p) => _showPaymentSlip(context, p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentList extends StatelessWidget {
  final List<_Payment> payments;
  final bool isVerifyMode;
  final ValueChanged<_Payment> onVerify;
  final ValueChanged<_Payment> onReject;
  final ValueChanged<_Payment> onTapItem;

  const _PaymentList({
    required this.payments,
    required this.isVerifyMode,
    required this.onVerify,
    required this.onReject,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payments_outlined,
                size: 48, color: AppColors.grey600),
            const SizedBox(height: 12),
            Text('No payments in this tab',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.grey500)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      physics: const BouncingScrollPhysics(),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = payments[i];
        final statusColor = switch (p.status) {
          'verified' => AppColors.success,
          'sales_approved' => AppColors.warning,
          'pending' => AppColors.grey400,
          _ => AppColors.grey400,
        };
        return GestureDetector(
          onTap: () => onTapItem(p),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.navy600),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(p.name[0],
                            style: AppTextStyles.headlineSmall
                                .copyWith(color: statusColor)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: AppTextStyles.labelLarge),
                          Text('${p.label} • ${p.ref}',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${(p.amount / 1000).toStringAsFixed(0)}K',
                          style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.fg, fontSize: 18),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(p.mode,
                              style: AppTextStyles.caption
                                  .copyWith(color: statusColor)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.navy600),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 13, color: AppColors.grey500),
                    const SizedBox(width: 4),
                    Text(p.date, style: AppTextStyles.caption),
                    const Spacer(),
                    if (isVerifyMode)
                      Row(
                        children: [
                          _ActionBtn(
                            label: 'Reject',
                            color: AppColors.error,
                            onTap: () => onReject(p),
                          ),
                          const SizedBox(width: 8),
                          _ActionBtn(
                            label: 'Verify ✓',
                            color: AppColors.success,
                            filled: true,
                            onTap: () => onVerify(p),
                          ),
                        ],
                      ),
                    if (p.status == 'verified')
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 4),
                          Text('Verified',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.success)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: i * 80))
            .fadeIn(duration: 380.ms)
            .slideY(begin: 0.06, end: 0);
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.color,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border:
              filled ? null : Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: filled ? AppColors.navy900 : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.headlineSmall.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.navy600);
  }
}

class _Payment {
  final String id, name, label, status, date, mode, ref;
  final int amount;
  const _Payment(this.id, this.name, this.amount, this.label, this.status, this.date, this.mode, this.ref);

  _Payment copyWith({String? status}) {
    return _Payment(
      id,
      name,
      amount,
      label,
      status ?? this.status,
      date,
      mode,
      ref,
    );
  }
}
