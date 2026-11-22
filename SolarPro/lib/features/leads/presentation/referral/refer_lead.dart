import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Any employee (Discom, Structure, Wiring, Civil, Subsidy, Account …) can
/// refer a potential customer. The lead goes to the sales pool; admins are
/// notified and assign it to a salesman.
Future<bool> showReferLeadSheet(BuildContext context) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy800,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _ReferLeadSheet(),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Lead sent to the sales team. Track it under "My referrals".'),
      backgroundColor: AppColors.success,
    ));
  }
  return sent == true;
}

class _ReferLeadSheet extends StatefulWidget {
  const _ReferLeadSheet();

  @override
  State<_ReferLeadSheet> createState() => _ReferLeadSheetState();
}

class _ReferLeadSheetState extends State<_ReferLeadSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _kw = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _area, _kw, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final name = _name.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (name.length < 2) return setState(() => _error = 'Enter the customer\'s name.');
    if (phone.length != 10) return setState(() => _error = 'Enter a 10-digit mobile number.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient().createLead(
        name: name,
        phone: phone,
        area: _area.text.trim(),
        kw: double.tryParse(_kw.text.trim()) ?? 0,
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  InputDecoration _dec(String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Refer a customer', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text('Know someone who wants solar? Add them as a lead and the sales team will follow up.',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _dec('Customer name *', Icons.person_outline_rounded)),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('Mobile number *', Icons.phone_iphone_rounded),
            ),
            const SizedBox(height: 4),
            TextField(controller: _area, decoration: _dec('Area / address', Icons.location_on_outlined)),
            const SizedBox(height: 12),
            TextField(
              controller: _kw,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: _dec('Expected size (kW, optional)', Icons.solar_power_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: _dec('Notes (optional)', Icons.notes_rounded),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _send,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal500, foregroundColor: AppColors.fg),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: const Text('Send to sales'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The leads this employee referred and where each one stands.
class ReferredLeadsScreen extends StatefulWidget {
  const ReferredLeadsScreen({super.key});

  @override
  State<ReferredLeadsScreen> createState() => _ReferredLeadsScreenState();
}

class _ReferredLeadsScreenState extends State<ReferredLeadsScreen> {
  List<Map<String, dynamic>> _leads = [];
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
      final res = await ApiClient().get('/leads/referred');
      _leads = [for (final l in (res.data as List? ?? const [])) if (l is Map) Map<String, dynamic>.from(l)];
    } catch (e) {
      _error = ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  (String, Color) _status(String s) => switch (s) {
        'converted' || 'closed' => ('Became a customer 🎉', AppColors.success),
        'lost' => ('Not interested', AppColors.grey500),
        'new' => ('With sales — not contacted yet', AppColors.info),
        _ => ('Sales is following up', AppColors.warning),
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(title: const Text('My referrals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showReferLeadSheet(context)) _load();
        },
        backgroundColor: AppColors.teal500,
        foregroundColor: AppColors.fg,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Refer a customer'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 60), child: Text(_error!, textAlign: TextAlign.center))
            else if (_leads.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text('You haven\'t referred anyone yet.',
                    textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
              )
            else
              for (final l in _leads)
                Builder(builder: (context) {
                  final (label, color) = _status((l['status'] ?? 'new').toString());
                  final created = DateTime.tryParse((l['created_at'] ?? '').toString());
                  final salesman = (l['assigned_sales_name'] ?? '').toString();
                  return Card(
                    color: AppColors.navy800,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(Icons.person_rounded, color: color),
                      ),
                      title: Text(l['name']?.toString() ?? 'Lead'),
                      subtitle: Text(
                        [
                          label,
                          if (salesman.isNotEmpty) 'Salesman: $salesman',
                          if (created != null) 'Referred ${fmt.format(created.toLocal())}',
                        ].join('\n'),
                        style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                      ),
                      isThreeLine: true,
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }
}
