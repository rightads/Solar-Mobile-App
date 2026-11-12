import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/salesman/payments/models/payment_plan_model.dart';
import 'package:uuid/uuid.dart';

/// Dynamic Payment Plan Builder widget.
/// Enforces business rule: No hard-coded percentages. Salesman defines bespoke milestones.
/// Locks automatically if the first customer payment is approved.
class PaymentPlanBuilderCard extends StatefulWidget {
  final PaymentPlanModel plan;
  final int finalPricePaise;
  final ValueChanged<PaymentPlanModel> onSavePlan;

  const PaymentPlanBuilderCard({
    super.key,
    required this.plan,
    required this.finalPricePaise,
    required this.onSavePlan,
  });

  @override
  State<PaymentPlanBuilderCard> createState() => _PaymentPlanBuilderCardState();
}

class _PaymentPlanBuilderCardState extends State<PaymentPlanBuilderCard> {
  late List<PaymentMilestone> _milestones;

  @override
  void initState() {
    super.initState();
    _milestones = List.from(widget.plan.milestones);
  }

  @override
  void didUpdateWidget(covariant PaymentPlanBuilderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plan != oldWidget.plan) {
      _milestones = List.from(widget.plan.milestones);
    }
  }

  double get _totalPercentage {
    return _milestones
        .where((m) => m.isPercentage)
        .fold(0.0, (sum, m) => sum + m.percentage);
  }

  int get _totalPaise {
    return _milestones.fold(0, (sum, m) => sum + m.computedAmountPaise(widget.finalPricePaise));
  }

  int get _finalPriceRupees => widget.finalPricePaise ~/ 100;
  int get _totalRupees => _totalPaise ~/ 100;

  bool get _is100Percent => (_totalPercentage - 100.0).abs() < 0.01;
  bool get _matchesFinalPrice => _totalPaise == widget.finalPricePaise;

  void _addMilestone() {
    _showMilestoneDialog(
      milestone: PaymentMilestone(
        id: const Uuid().v4(),
        title: 'Milestone ${_milestones.length + 1}',
        isPercentage: true,
        percentage: 20.0,
      ),
      isNew: true,
    );
  }

  void _editMilestone(int index) {
    _showMilestoneDialog(
      milestone: _milestones[index],
      isNew: false,
      index: index,
    );
  }

  void _deleteMilestone(int index) {
    setState(() {
      _milestones.removeAt(index);
    });
  }

  void _showMilestoneDialog({
    required PaymentMilestone milestone,
    required bool isNew,
    int? index,
  }) {
    final titleController = TextEditingController(text: milestone.title);
    final valueController = TextEditingController(
      text: milestone.isPercentage
          ? milestone.percentage.toStringAsFixed(0)
          : (milestone.fixedAmountPaise ~/ 100).toString(),
    );
    final conditionController = TextEditingController(text: milestone.dueCondition ?? '');
    bool isPercent = milestone.isPercentage;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.navy800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text(
            isNew ? 'Add Payment Milestone' : 'Edit Milestone',
            style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Milestone Title *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: titleController,
                    style: const TextStyle(color: AppColors.fg, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Booking Advance, Structure Delivery',
                      hintStyle: const TextStyle(color: AppColors.grey500),
                      filled: true,
                      fillColor: AppColors.navy900,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Percentage vs Fixed Amount Toggle
                  const Text('Payment Type *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => isPercent = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isPercent ? AppColors.teal500 : AppColors.navy900,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: isPercent ? AppColors.teal500 : AppColors.navy700),
                            ),
                            child: Center(
                              child: Text(
                                'Percentage (%)',
                                style: TextStyle(
                                  color: isPercent ? AppColors.fg : AppColors.grey400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => isPercent = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isPercent ? AppColors.teal500 : AppColors.navy900,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: !isPercent ? AppColors.teal500 : AppColors.navy700),
                            ),
                            child: Center(
                              child: Text(
                                'Fixed Amount (₹)',
                                style: TextStyle(
                                  color: !isPercent ? AppColors.fg : AppColors.grey400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Value Input
                  Text(
                    isPercent ? 'Percentage (0 - 100%) *' : 'Amount in Rupees *',
                    style: const TextStyle(color: AppColors.grey300, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: valueController,
                    keyboardType: isPercent
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        isPercent ? Icons.percent_rounded : Icons.currency_rupee_rounded,
                        color: AppColors.gold500,
                        size: 18,
                      ),
                      hintText: isPercent ? 'e.g. 25' : 'e.g. 60000',
                      hintStyle: const TextStyle(color: AppColors.grey500),
                      filled: true,
                      fillColor: AppColors.navy900,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    validator: (v) {
                      final val = double.tryParse((v ?? '').trim()) ?? 0;
                      if (val <= 0) return 'Valid positive value required';
                      if (isPercent && val > 100) return 'Cannot exceed 100%';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Due Condition Note
                  const Text('Due Condition (Optional)', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: conditionController,
                    style: const TextStyle(color: AppColors.fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Due before module delivery, on completion',
                      hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.navy900,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final title = titleController.text.trim();
                  final val = double.tryParse(valueController.text.trim()) ?? 0.0;
                  final condition = conditionController.text.trim().isNotEmpty
                      ? conditionController.text.trim()
                      : null;

                  final updated = milestone.copyWith(
                    title: title,
                    isPercentage: isPercent,
                    percentage: isPercent ? val : 0.0,
                    fixedAmountPaise: isPercent ? 0 : (val.toInt() * 100),
                    dueCondition: condition,
                  );

                  setState(() {
                    if (isNew) {
                      _milestones.add(updated);
                    } else if (index != null) {
                      _milestones[index] = updated;
                    }
                  });
                  Navigator.of(ctx).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal500,
                foregroundColor: AppColors.fg,
              ),
              child: Text(isNew ? 'Add Milestone' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndSave() {
    final hasPercentage = _milestones.any((m) => m.isPercentage);
    final is100 = _is100Percent;
    final isPriceMatch = _matchesFinalPrice;

    // Check if totals don't match
    if ((hasPercentage && !is100) || (!hasPercentage && !isPriceMatch)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.navy800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
              SizedBox(width: 8),
              Text('Unbalanced Plan', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            hasPercentage
                ? 'Your milestone percentages sum to ${_totalPercentage.toStringAsFixed(1)}% (expected 100%). Do you want to save this customized plan anyway?'
                : 'Your milestone amounts sum to ₹$_totalRupees (contract price: ₹$_finalPriceRupees). Do you want to save anyway?',
            style: const TextStyle(color: AppColors.grey300, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Keep Editing', style: TextStyle(color: AppColors.grey400)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _doSave();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: AppColors.shadow),
              child: const Text('Confirm & Save'),
            ),
          ],
        ),
      );
    } else {
      _doSave();
    }
  }

  void _doSave() {
    final updatedPlan = widget.plan.copyWith(milestones: _milestones);
    widget.onSavePlan(updatedPlan);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment plan saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.plan.isLocked;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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
          // Header with Lock Badge
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, color: AppColors.teal500, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bespoke Payment Plan',
                      style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Salesman-defined milestones with live validation',
                      style: TextStyle(color: AppColors.grey400, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: AppColors.gold500, size: 12),
                      SizedBox(width: 4),
                      Text('Locked', style: TextStyle(color: AppColors.gold500, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Running Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.navy900,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _is100Percent || _matchesFinalPrice
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Plan Allocation', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                    Text(
                      '${_totalPercentage.toStringAsFixed(1)}% • ${formatter.format(_totalRupees)}',
                      style: TextStyle(
                        color: _is100Percent || _matchesFinalPrice ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  _is100Percent || _matchesFinalPrice ? 'Balanced (100%)' : 'Needs Adjustment',
                  style: TextStyle(
                    color: _is100Percent || _matchesFinalPrice ? AppColors.success : AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Milestones List
          if (_milestones.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              alignment: Alignment.center,
              child: const Text('No milestones defined yet. Tap below to create milestones.', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _milestones.length,
              onReorderItem: isLocked
                  ? (_, __) {}
                  : (oldIndex, newIndex) {
                      setState(() {
                        final item = _milestones.removeAt(oldIndex);
                        _milestones.insert(newIndex, item);
                      });
                    },
              itemBuilder: (context, index) {
                final m = _milestones[index];
                return Container(
                  key: ValueKey(m.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.navy900,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.navy700),
                  ),
                  child: Row(
                    children: [
                      if (!isLocked)
                        const Icon(Icons.drag_indicator_rounded, color: AppColors.grey600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title, style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13)),
                            if (m.dueCondition != null)
                              Text(m.dueCondition!, style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            m.isPercentage ? '${m.percentage.toStringAsFixed(1)}%' : m.formattedAmount(widget.finalPricePaise),
                            style: const TextStyle(color: AppColors.gold500, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (m.isPercentage)
                            Text(
                              m.formattedAmount(widget.finalPricePaise),
                              style: const TextStyle(color: AppColors.grey500, fontSize: 11),
                            ),
                        ],
                      ),
                      if (!isLocked) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.teal500, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _editMilestone(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteMilestone(index),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 10),

          // Actions Row
          if (!isLocked)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addMilestone,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Milestone', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.teal500,
                    side: const BorderSide(color: AppColors.teal500),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _confirmAndSave,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.teal500,
                    foregroundColor: AppColors.fg,
                  ),
                  child: const Text('Save Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
