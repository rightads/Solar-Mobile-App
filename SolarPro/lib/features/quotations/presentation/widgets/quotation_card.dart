import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/quotations/data/quotation_api.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _date = DateFormat('d MMM yyyy, h:mm a');

String formatInr(num v) => _inr.format(v);

/// Status chip colours and labels.
(String, Color, IconData) quotationStatusStyle(String status) => switch (status) {
      'approved' => ('Approved · Locked', AppColors.success, Icons.lock_rounded),
      'rejected' => ('Rejected', AppColors.error, Icons.cancel_rounded),
      'superseded' => ('Replaced by newer version', AppColors.grey500, Icons.history_rounded),
      _ => ('Awaiting client approval', AppColors.warning, Icons.hourglass_top_rounded),
    };

/// Full read-only view of one quotation: price breakdown, equipment lines,
/// remarks and (when decided) the client's answer.
class QuotationCard extends StatelessWidget {
  final Quotation quotation;
  final bool initiallyExpanded;

  /// Extra widgets under the card (e.g. the client's Approve / Reject buttons).
  final List<Widget> actions;

  const QuotationCard({super.key, required this.quotation, this.initiallyExpanded = true, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final q = quotation;
    final (statusLabel, statusColor, statusIcon) = quotationStatusStyle(q.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: q.isApproved ? AppColors.success.withValues(alpha: 0.6) : AppColors.navy600),
      ),
      // Transparent Material so the tile's ink draws above the card colour.
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Expanded(
                  child: Text('${q.quoteNo.isEmpty ? 'Quotation' : q.quoteNo} · v${q.version}',
                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(formatInr(q.total), style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold500)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(statusLabel,
                        style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text('${q.capacityKw.toStringAsFixed(q.capacityKw % 1 == 0 ? 0 : 1)} kW',
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                ],
              ),
            ),
            children: [
              if (q.isRejected && (q.clientRemark ?? '').isNotEmpty)
                _Note(
                  color: AppColors.error,
                  icon: Icons.feedback_rounded,
                  title: 'Client\'s reason for rejecting',
                  text: q.clientRemark!,
                ),
              if (q.isApproved)
                const _Note(
                  color: AppColors.success,
                  icon: Icons.lock_rounded,
                  title: 'Approved by the client',
                  text: 'This quotation is final. Its values can no longer be changed by anyone.',
                ),
              const SizedBox(height: 4),
              _SectionTitle('Project'),
              _Row('Project capacity', '${q.capacityKw} kW'),
              if (q.loadKw > 0) _Row('Sanctioned load', '${q.loadKw} kW'),
              _Row('Project cost', formatInr(q.projectCost)),
              if (q.discomCharges > 0) _Row('Discom charges', formatInr(q.discomCharges)),
              if (q.fileCharges > 0) _Row('File charges', formatInr(q.fileCharges)),
              const Divider(color: AppColors.navy600, height: 18),
              _Row('Total payable', formatInr(q.total), bold: true),
              const SizedBox(height: 12),
              _SectionTitle('Equipment'),
              for (final def in kQuoteItems)
                if (_hasValues(q.item(def.key))) _ItemBlock(def: def, values: q.item(def.key)),
              if (kQuoteItems.every((d) => !_hasValues(q.item(d.key))))
                Text('No equipment lines.', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
              if (q.otherItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionTitle('Other'),
                for (final o in q.otherItems) _Row(o['title']?.toString() ?? '', o['details']?.toString() ?? ''),
              ],
              const SizedBox(height: 10),
              _SectionTitle('Remark'),
              Text(q.remark, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 10),
              Text(
                [
                  if (q.createdBy.isNotEmpty) 'Prepared by ${q.createdBy}',
                  if (q.sentAt != null) 'sent ${_date.format(q.sentAt!)}',
                  if (q.decidedAt != null) '${q.isApproved ? 'approved' : 'answered'} ${_date.format(q.decidedAt!)}',
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
              ),
              if (actions.isNotEmpty) ...[const SizedBox(height: 14), ...actions],
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasValues(Map<String, dynamic> item) => item.entries
      .any((e) => e.value != null && '${e.value}'.trim().isNotEmpty && '${e.value}' != '0' && '${e.value}' != '0.0');
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: AppTextStyles.caption
                .copyWith(color: AppColors.grey500, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: (bold ? AppTextStyles.labelLarge : AppTextStyles.bodySmall).copyWith(
                      color: bold ? AppColors.gold500 : AppColors.fg, fontWeight: bold ? FontWeight.w700 : null)),
            ),
          ],
        ),
      );
}

class _ItemBlock extends StatelessWidget {
  final QuoteItemDef def;
  final Map<String, dynamic> values;
  const _ItemBlock({required this.def, required this.values});

  @override
  Widget build(BuildContext context) {
    String fmt(String field) {
      final v = values[field];
      if (v is num) return v % 1 == 0 ? v.toInt().toString() : v.toString();
      return (v ?? '').toString().trim();
    }

    final parts = [
      for (final f in def.fields)
        if (fmt(f).isNotEmpty && fmt(f) != '0') '${kQuoteFieldLabels[f]}: ${fmt(f)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(def.label, style: AppTextStyles.labelMedium.copyWith(color: AppColors.fg, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(parts.join('  ·  '), style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String text;
  const _Note({required this.color, required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.fg)),
                ],
              ),
            ),
          ],
        ),
      );
}
