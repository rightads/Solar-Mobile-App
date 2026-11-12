import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/salesman/payments/models/loan_details_model.dart';
import 'package:uuid/uuid.dart';

/// Loan details and flexible installment management card.
class LoanDetailsCard extends StatefulWidget {
  final LoanDetailsModel loanDetails;
  final ValueChanged<LoanDetailsModel> onSaveLoan;

  const LoanDetailsCard({
    super.key,
    required this.loanDetails,
    required this.onSaveLoan,
  });

  @override
  State<LoanDetailsCard> createState() => _LoanDetailsCardState();
}

class _LoanDetailsCardState extends State<LoanDetailsCard> {
  late bool _hasLoan;
  late TextEditingController _bankNameController;
  late TextEditingController _loanAmountController;
  late List<LoanInstallment> _installments;

  @override
  void initState() {
    super.initState();
    _hasLoan = widget.loanDetails.hasLoan;
    _bankNameController = TextEditingController(text: widget.loanDetails.bankName);
    _loanAmountController = TextEditingController(
      text: widget.loanDetails.loanAmountRupees > 0
          ? widget.loanDetails.loanAmountRupees.toString()
          : '',
    );
    _installments = List.from(widget.loanDetails.installments);
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _loanAmountController.dispose();
    super.dispose();
  }

  int get _enteredLoanAmountPaise {
    final clean = _loanAmountController.text.replaceAll(RegExp(r'\D'), '');
    final rupees = int.tryParse(clean) ?? 0;
    return rupees * 100;
  }

  int get _totalInstallmentsPaise {
    return _installments.fold(0, (sum, i) => sum + i.amountPaise);
  }

  bool get _isExceedingLoanAmount => _totalInstallmentsPaise > _enteredLoanAmountPaise;

  void _addInstallment() {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    bool isReceived = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.navy800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Add Loan Installment', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Installment Amount (Rupees) *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.gold500),
                  hintText: 'e.g. 25000',
                  hintStyle: const TextStyle(color: AppColors.grey500),
                  filled: true,
                  fillColor: AppColors.navy900,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Expected Date *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setDlgState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.navy900,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.navy700),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: AppColors.fg)),
                      const Icon(Icons.calendar_month_rounded, color: AppColors.teal500, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Received status switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disbursed / Received?', style: TextStyle(color: AppColors.grey300, fontSize: 13)),
                  Switch(
                    value: isReceived,
                    activeThumbColor: AppColors.teal500,
                    onChanged: (val) => setDlgState(() => isReceived = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
            ),
            ElevatedButton(
              onPressed: () {
                final rupees = int.tryParse(amountController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
                if (rupees > 0) {
                  setState(() {
                    _installments.add(
                      LoanInstallment(
                        id: const Uuid().v4(),
                        amountPaise: rupees * 100,
                        expectedDate: selectedDate,
                        isReceived: isReceived,
                      ),
                    );
                  });
                  Navigator.of(ctx).pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal500, foregroundColor: AppColors.fg),
              child: const Text('Add Installment'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveLoan() {
    if (_hasLoan && _isExceedingLoanAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Installment total cannot exceed the sanctioned loan amount!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final updated = widget.loanDetails.copyWith(
      hasLoan: _hasLoan,
      bankName: _bankNameController.text.trim(),
      loanAmountPaise: _enteredLoanAmountPaise,
      installments: _installments,
    );

    widget.onSaveLoan(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loan details saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // Header & Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: AppColors.teal500, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Bank Solar Loan Details',
                    style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Switch(
                value: _hasLoan,
                activeThumbColor: AppColors.teal500,
                onChanged: (val) => setState(() => _hasLoan = val),
              ),
            ],
          ),

          if (_hasLoan) ...[
            const SizedBox(height: 14),

            // Bank Name
            const Text('Financing Bank / NBFC *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _bankNameController,
              style: const TextStyle(color: AppColors.fg, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. SBI Solar Loan, HDFC Bank, PNB, Tata Capital',
                hintStyle: const TextStyle(color: AppColors.grey500),
                filled: true,
                fillColor: AppColors.navy900,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            const SizedBox(height: 12),

            // Loan Sanctioned Amount
            const Text('Sanctioned Loan Amount (Rupees) *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _loanAmountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.gold500),
                hintText: 'e.g. 200000',
                hintStyle: const TextStyle(color: AppColors.grey500),
                filled: true,
                fillColor: AppColors.navy900,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),

            // Installment Summary Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _isExceedingLoanAmount
                      ? AppColors.error
                      : AppColors.teal500.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Installments Allocated', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                      Text(
                        formatter.format(_totalInstallmentsPaise ~/ 100),
                        style: TextStyle(
                          color: _isExceedingLoanAmount ? AppColors.error : AppColors.teal500,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (_isExceedingLoanAmount)
                    const Text('Exceeds Loan Amount!', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold))
                  else
                    Text(
                      '${_installments.length} Installments',
                      style: const TextStyle(color: AppColors.grey300, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Installments List
            if (_installments.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: const Text('No installments scheduled yet.', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _installments.length,
                itemBuilder: (context, index) {
                  final inst = _installments[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.navy900,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.navy700),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          inst.isReceived ? Icons.check_circle_rounded : Icons.pending_rounded,
                          color: inst.isReceived ? AppColors.success : AppColors.gold500,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inst.formattedAmount, style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Expected: ${inst.formattedExpectedDate}', style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (inst.isReceived ? AppColors.success : AppColors.gold500).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            inst.isReceived ? 'Received' : 'Pending',
                            style: TextStyle(
                              color: inst.isReceived ? AppColors.success : AppColors.gold500,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                          onPressed: () => setState(() => _installments.removeAt(index)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addInstallment,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Installment', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.teal500,
                    side: const BorderSide(color: AppColors.teal500),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saveLoan,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.teal500,
                    foregroundColor: AppColors.fg,
                  ),
                  child: const Text('Save Loan Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Customer has not opted for financing or loan. Direct customer payments apply.',
              style: TextStyle(color: AppColors.grey400, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
