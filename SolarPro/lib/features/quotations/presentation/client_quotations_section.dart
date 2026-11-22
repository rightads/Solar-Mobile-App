import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/quotations/data/quotation_api.dart';
import 'package:solar_pro/features/quotations/presentation/widgets/quotation_card.dart';

/// Client dashboard: the quotation waiting for an answer (Approve / Reject),
/// the approved one, and earlier rejected versions. Renders nothing until a
/// quotation has been sent.
class ClientQuotationsSection extends StatefulWidget {
  /// Called after the client approves or rejects (refreshes the dashboard).
  final Future<void> Function()? onDecided;
  const ClientQuotationsSection({super.key, this.onDecided});

  @override
  State<ClientQuotationsSection> createState() => ClientQuotationsSectionState();
}

class ClientQuotationsSectionState extends State<ClientQuotationsSection> {
  List<Quotation> _quotes = [];
  bool _busy = false;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final quotes = await QuotationApi.mine();
      if (mounted) setState(() => _quotes = quotes);
    } catch (_) {
      // No project linked yet, or offline: the section stays hidden.
    }
  }

  void _toast(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _approve(Quotation q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        title: const Text('Approve this quotation?'),
        content: Text(
          'You are approving ${q.quoteNo} for ${formatInr(q.total)}. '
          'This is final: once approved, its price and equipment can never be changed by anyone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.fg),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _decide(() => QuotationApi.approve(q.id), 'Quotation approved. Your project moves ahead!');
  }

  Future<void> _reject(Quotation q) async {
    final remark = await showDialog<String>(context: context, builder: (_) => const _RejectDialog());
    if (remark == null) return;
    await _decide(
        () => QuotationApi.reject(q.id, remark), 'Quotation rejected. Your salesman will send a revised one.');
  }

  Future<void> _decide(Future<Quotation> Function() call, String success) async {
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      _toast(success, AppColors.success);
      await reload();
      await widget.onDecided?.call();
    } catch (e) {
      if (!mounted) return;
      _toast(ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', ''), AppColors.error);
      await reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quotes.isEmpty) return const SizedBox.shrink();
    final pending = _quotes.where((q) => q.isPending).firstOrNull;
    final approved = _quotes.where((q) => q.isApproved).firstOrNull;
    final history = _quotes.where((q) => q != pending && q != approved).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your Quotation', style: AppTextStyles.headlineSmall)),
              if (pending != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold500.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ACTION NEEDED',
                      style: TextStyle(fontSize: 10, color: AppColors.gold400, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (pending != null)
            QuotationCard(
              quotation: pending,
              actions: [
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reject(pending),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approve(pending),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.fg,
                            minimumSize: const Size.fromHeight(46),
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          if (approved != null) QuotationCard(quotation: approved, initiallyExpanded: pending == null),
          if (pending == null && approved == null && history.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.navy600),
              ),
              child: Text(
                'You rejected the last quotation. Your salesman is preparing a revised one.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey300),
              ),
            ),
          if (history.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showHistory = !_showHistory),
                icon: Icon(_showHistory ? Icons.expand_less_rounded : Icons.history_rounded),
                label: Text(_showHistory ? 'Hide earlier versions' : 'Earlier versions (${history.length})'),
              ),
            ),
          if (_showHistory)
            for (final q in history) QuotationCard(quotation: q, initiallyExpanded: false),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.navy800,
      title: const Text('Reject quotation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us what should change. Your salesman will send a revised quotation based on this.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 4,
            maxLength: 2000,
            style: const TextStyle(color: AppColors.fg),
            decoration: InputDecoration(
              hintText: 'e.g. Price is too high, I want Tata panels…',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.fg),
          onPressed: () {
            final text = _ctrl.text.trim();
            if (text.length < 3) {
              setState(() => _error = 'Please give a reason (at least 3 characters).');
              return;
            }
            Navigator.pop(context, text);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
