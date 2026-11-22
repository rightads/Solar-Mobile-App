import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/quotations/data/quotation_api.dart';
import 'package:solar_pro/features/quotations/presentation/widgets/quotation_card.dart';

/// Salesman / admin: prepare a quotation and send it to one customer.
///
/// Pass [previous] to regenerate after a rejection: the form starts from that
/// version and shows the client's reason at the top. Quotations are never
/// edited; submitting always sends a new version.
class QuotationFormScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final Quotation? previous;

  const QuotationFormScreen({super.key, required this.customerId, required this.customerName, this.previous});

  /// Opens the form; resolves to the sent quotation, or null if cancelled.
  static Future<Quotation?> open(BuildContext context,
      {required String customerId, required String customerName, Quotation? previous}) {
    return Navigator.of(context).push<Quotation>(MaterialPageRoute(
      builder: (_) => QuotationFormScreen(customerId: customerId, customerName: customerName, previous: previous),
    ));
  }

  @override
  State<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _OtherRow {
  final TextEditingController title;
  final TextEditingController details;
  _OtherRow([String t = '', String d = ''])
      : title = TextEditingController(text: t),
        details = TextEditingController(text: d);
  void dispose() {
    title.dispose();
    details.dispose();
  }
}

class _QuotationFormScreenState extends State<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _capacity = TextEditingController();
  final _load = TextEditingController();
  final _cost = TextEditingController();
  final _discom = TextEditingController();
  final _file = TextEditingController();
  final _remark = TextEditingController();
  final Map<String, Map<String, TextEditingController>> _items = {};
  final List<_OtherRow> _others = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    for (final def in kQuoteItems) {
      _items[def.key] = {for (final f in def.fields) f: TextEditingController()};
    }
    final p = widget.previous;
    if (p != null) {
      String n(double v) => v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());
      _capacity.text = n(p.capacityKw);
      _load.text = n(p.loadKw);
      _cost.text = n(p.projectCost);
      _discom.text = n(p.discomCharges);
      _file.text = n(p.fileCharges);
      _remark.text = p.remark;
      for (final def in kQuoteItems) {
        final values = p.item(def.key);
        for (final f in def.fields) {
          final v = values[f];
          if (v == null) continue;
          _items[def.key]![f]!.text = v is num ? n(v.toDouble()) : v.toString();
        }
      }
      for (final o in p.otherItems) {
        _others.add(_OtherRow(o['title']?.toString() ?? '', o['details']?.toString() ?? ''));
      }
    }
    for (final c in [_cost, _discom, _file]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_capacity, _load, _cost, _discom, _file, _remark]) {
      c.dispose();
    }
    for (final m in _items.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    for (final o in _others) {
      o.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  double get _total => _num(_cost) + _num(_discom) + _num(_file);

  Map<String, dynamic> _payload() {
    final items = <String, dynamic>{};
    for (final def in kQuoteItems) {
      final line = <String, dynamic>{};
      for (final f in def.fields) {
        final text = _items[def.key]![f]!.text.trim();
        if (text.isEmpty) continue;
        line[f] = f == 'quantity' ? (double.tryParse(text) ?? 0) : text;
      }
      if (line.isNotEmpty) items[def.key] = line;
    }
    return {
      'customer_id': widget.customerId,
      'capacity_kw': _num(_capacity),
      'load_kw': _num(_load),
      'project_cost': _num(_cost),
      'discom_charges': _num(_discom),
      'file_charges': _num(_file),
      'items': items,
      'other_items': [
        for (final o in _others)
          if (o.title.text.trim().isNotEmpty) {'title': o.title.text.trim(), 'details': o.details.text.trim()},
      ],
      'remark': _remark.text.trim(),
      if (widget.previous != null) 'revision_of': widget.previous!.id,
    };
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        title: const Text('Send quotation?'),
        content: Text(
          'Send this ${formatInr(_total)} quotation to ${widget.customerName}? '
          'They will be asked to approve or reject it. Once approved it can never be changed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      final q = await QuotationApi.create(_payload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Quotation ${q.quoteNo} sent to ${widget.customerName}'),
        backgroundColor: AppColors.success,
      ));
      Navigator.of(context).pop(q);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  InputDecoration _dec(String label, {String? hint, String? prefix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        labelStyle: const TextStyle(color: AppColors.grey400, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.grey600, fontSize: 13),
        filled: true,
        fillColor: AppColors.navy800,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.navy700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.navy700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.teal500),
        ),
      );

  Widget _numberField(TextEditingController c, String label,
      {bool required = false, String? prefix, bool positive = false}) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: const TextStyle(color: AppColors.fg),
      decoration: _dec(required ? '$label *' : label, prefix: prefix),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return required ? 'Required' : null;
        final n = double.tryParse(text);
        if (n == null) return 'Enter a number';
        if (positive && n <= 0) return 'Must be more than 0';
        return null;
      },
    );
  }

  Widget _pair(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
      );

  Widget _section(String title, {String? subtitle, required List<Widget> children}) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
            ],
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _itemTile(QuoteItemDef def) {
    final ctrls = _items[def.key]!;
    final filled = ctrls.values.any((c) => c.text.trim().isNotEmpty);
    Widget field(String f) {
      final c = ctrls[f]!;
      final label = f == 'capacity' && def.capacityHint != null ? def.capacityHint! : kQuoteFieldLabels[f]!;
      if (f == 'quantity') {
        return TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(color: AppColors.fg),
          decoration: _dec(label),
          onChanged: (_) => setState(() {}),
          validator: (v) => (v ?? '').trim().isEmpty || double.tryParse(v!.trim()) != null ? null : 'Enter a number',
        );
      }
      return TextFormField(
        controller: c,
        maxLength: f == 'other' ? 300 : 80,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        style: const TextStyle(color: AppColors.fg),
        decoration: _dec(label),
        onChanged: (_) => setState(() {}),
      );
    }

    final fields = def.fields;
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: i + 1 < fields.length ? _pair(field(fields[i]), field(fields[i + 1])) : field(fields[i]),
      ));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: filled ? AppColors.teal500.withValues(alpha: 0.5) : AppColors.navy700),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            // Keep collapsed fields alive so the form still validates them.
            maintainState: true,
            initiallyExpanded: filled,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            leading: Icon(filled ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                color: filled ? AppColors.teal500 : AppColors.grey500, size: 20),
            title: Text(def.label, style: AppTextStyles.labelLarge),
            children: rows,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prev = widget.previous;
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: Text(prev == null ? 'New Quotation' : 'Regenerate Quotation'),
      ),
      // A fully built scroll view (not a lazy ListView) so every field,
      // including ones scrolled off-screen, is validated on submit.
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('For ${widget.customerName}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
              const SizedBox(height: 14),
              if (prev != null && (prev.clientRemark ?? '').isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client rejected ${prev.quoteNo} v${prev.version}',
                          style:
                              AppTextStyles.labelMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('"${prev.clientRemark}"', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 4),
                      Text('Adjust the values below to address their remark, then send the new version.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                    ],
                  ),
                ),
              _section('Project', children: [
                _pair(
                  _numberField(_capacity, 'Project capacity (kW)', required: true, positive: true),
                  _numberField(_load, 'Load (kW)'),
                ),
                const SizedBox(height: 10),
                _numberField(_cost, 'Project cost', required: true, prefix: '₹ ', positive: true),
                const SizedBox(height: 10),
                _pair(
                  _numberField(_discom, 'Discom charges', prefix: '₹ '),
                  _numberField(_file, 'File charges', prefix: '₹ '),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gold500.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('Total payable', style: AppTextStyles.labelLarge)),
                      Text(formatInr(_total),
                          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.gold500, fontSize: 18)),
                    ],
                  ),
                ),
              ]),
              _section('Equipment',
                  subtitle: 'Fill in the lines this project needs; leave the rest empty.',
                  children: [for (final def in kQuoteItems) _itemTile(def)]),
              _section('Other', subtitle: 'Anything not covered above.', children: [
                for (var i = 0; i < _others.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _others[i].title,
                            style: const TextStyle(color: AppColors.fg),
                            decoration: _dec('Item'),
                            validator: (v) => (v ?? '').trim().isEmpty && _others[i].details.text.trim().isNotEmpty
                                ? 'Name it'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _others[i].details,
                            style: const TextStyle(color: AppColors.fg),
                            decoration: _dec('Details'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close_rounded, color: AppColors.grey500),
                          onPressed: () {
                            final row = _others.removeAt(i);
                            setState(() {});
                            // Dispose after the frame: its fields are still mounted until then.
                            WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
                          },
                        ),
                      ],
                    ),
                  ),
                if (_others.length < 10)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _others.add(_OtherRow())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add other item'),
                    ),
                  ),
              ]),
              _section('Remark', children: [
                TextFormField(
                  controller: _remark,
                  maxLines: 3,
                  maxLength: 2000,
                  style: const TextStyle(color: AppColors.fg),
                  decoration: _dec('Remark *', hint: 'Warranty, AMC, timelines, payment terms…'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'A remark is required' : null,
                ),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal500,
                foregroundColor: AppColors.fg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Sending…' : 'Submit & send to customer  ·  ${formatInr(_total)}'),
            ),
          ),
        ),
      ),
    );
  }
}
