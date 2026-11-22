import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/quotations/data/quotation_api.dart';
import 'package:solar_pro/features/quotations/presentation/quotation_form_screen.dart';
import 'package:solar_pro/features/quotations/presentation/widgets/quotation_card.dart';

/// Customer detail → Quotation tab (salesman / admin): every version sent to
/// this customer, and the action that fits where things stand.
class CustomerQuotationsTab extends StatefulWidget {
  final String customerId;
  final String customerName;
  final bool canCreate;

  /// Called after a quotation is sent (so the parent can refresh).
  final VoidCallback? onChanged;

  const CustomerQuotationsTab({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.canCreate,
    this.onChanged,
  });

  @override
  State<CustomerQuotationsTab> createState() => _CustomerQuotationsTabState();
}

class _CustomerQuotationsTabState extends State<CustomerQuotationsTab> {
  List<Quotation> _quotes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quotes = await QuotationApi.forCustomer(widget.customerId);
      if (mounted) setState(() => _quotes = quotes);
    } catch (e) {
      final code = e is DioException ? e.response?.statusCode : null;
      if (mounted) {
        setState(() => _error = code == 403
            ? 'Quotations are visible to admins and the salesman only.'
            : ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Quotation? from}) async {
    final sent = await QuotationFormScreen.open(context,
        customerId: widget.customerId, customerName: widget.customerName, previous: from);
    if (sent != null) {
      await _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final approved = _quotes.where((q) => q.isApproved).firstOrNull;
    final latest = _quotes.isEmpty ? null : _quotes.first;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            _Banner(icon: Icons.info_outline_rounded, color: AppColors.grey400, text: _error!)
          else ...[
            _statusBanner(approved, latest),
            if (widget.canCreate && approved == null) ...[
              const SizedBox(height: 12),
              _actionButton(latest),
            ],
            const SizedBox(height: 18),
            for (var i = 0; i < _quotes.length; i++)
              QuotationCard(quotation: _quotes[i], initiallyExpanded: i == 0 || _quotes[i].isApproved),
          ],
        ],
      ),
    );
  }

  Widget _statusBanner(Quotation? approved, Quotation? latest) {
    if (approved != null) {
      return _Banner(
        icon: Icons.lock_rounded,
        color: AppColors.success,
        text: '${widget.customerName} approved ${approved.quoteNo} (${formatInr(approved.total)}). '
            'It is final: no one, including admins, can change its values or send another quotation.',
      );
    }
    if (latest == null) {
      return const _Banner(
        icon: Icons.request_quote_rounded,
        color: AppColors.info,
        text: 'No quotation yet. Prepare one and send it to the customer for approval. '
            'Documents collection can be completed only after the customer approves.',
      );
    }
    if (latest.isRejected) {
      return _Banner(
        icon: Icons.feedback_rounded,
        color: AppColors.error,
        text: 'Customer rejected ${latest.quoteNo} v${latest.version}: "${latest.clientRemark ?? ''}". '
            'Regenerate a new version that addresses their remark.',
      );
    }
    return _Banner(
      icon: Icons.hourglass_top_rounded,
      color: AppColors.warning,
      text: 'Waiting for the customer to approve or reject ${latest.quoteNo} v${latest.version}.',
    );
  }

  Widget _actionButton(Quotation? latest) {
    final (label, icon) = switch (latest) {
      null => ('Create quotation', Icons.add_rounded),
      Quotation(isRejected: true) => ('Regenerate quotation', Icons.autorenew_rounded),
      _ => ('Send a revised version', Icons.edit_note_rounded),
    };
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => _openForm(from: latest),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal500,
          foregroundColor: AppColors.fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Banner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.fg))),
          ],
        ),
      );
}
