import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Vendor inventory: items, stock ledger and serial-numbered units, all backed
/// by the `/inventory`, `/suppliers` and `/serials` APIs.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

const _categories = [
  ('panel', 'Panel'),
  ('inverter', 'Inverter'),
  ('structure', 'Structure'),
  ('cable', 'Cable'),
  ('electrical', 'Electrical'),
  ('civil', 'Civil'),
  ('meter', 'Meter'),
  ('other', 'Other'),
];
const _units = ['pcs', 'meter', 'kg', 'set', 'bag'];

String _err(Object e, String fallback) =>
    ApiClient.toFriendly(e, fallback: fallback).toString().replaceFirst('Exception: ', '');

String _fmtDate(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '');
  return d == null ? '—' : DateFormat('dd MMM yyyy, h:mm a').format(d.toLocal());
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiClient();

  List<_InventoryItem> _items = [];
  List<_MoveItem> _movements = [];
  List<_SerialItem> _serials = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _api.dio.get('/inventory/items', queryParameters: {'limit': 500}),
        _api.dio.get('/inventory/movements', queryParameters: {'limit': 200}),
        _api.dio.get('/inventory/serials', queryParameters: {'limit': 500}),
      ]);
      List<Map<String, dynamic>> rows(dynamic d) =>
          (d is List ? d : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _items = rows(res[0].data).map(_InventoryItem.fromJson).toList();
        _movements = rows(res[1].data).map(_MoveItem.fromJson).toList();
        _serials = rows(res[2].data).map(_SerialItem.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e, 'Could not load inventory.');
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  /// Runs an API action, then reloads; returns true on success.
  Future<bool> _run(Future<void> Function() action, String ok, String fallback) async {
    try {
      await action();
      _snack(ok);
      await _load();
      return true;
    } catch (e) {
      _snack(_err(e, fallback), error: true);
      return false;
    }
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  Future<T?> _sheet<T>(Widget Function(BuildContext ctx, StateSetter setSheet) builder) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(child: builder(ctx, setSheet)),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.grey600, borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _field(TextEditingController c, String hint, IconData icon,
          {TextInputType? keyboard, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
        ),
      );

  Widget _chips<T>(List<(T, String)> options, T selected, ValueChanged<T> onTap) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onTap(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: o.$1 == selected ? AppColors.gold500.withValues(alpha: 0.2) : AppColors.navy700,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: o.$1 == selected ? AppColors.gold500 : AppColors.navy600),
                ),
                child: Text(o.$2,
                    style: AppTextStyles.caption
                        .copyWith(color: o.$1 == selected ? AppColors.gold400 : AppColors.grey400)),
              ),
            ),
        ],
      );

  Widget _primary(String label, bool busy, VoidCallback onTap) => GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Center(
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(label, style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900)),
          ),
        ),
      );

  Future<void> _showAddItemSheet() async {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '5');
    String cat = 'panel', unit = 'pcs';
    bool hasSerial = true, busy = false;

    await _sheet((ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            Text('Add Inventory Item', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
            _field(nameCtrl, 'Item name (e.g. Mono Panel 550W)', Icons.inventory_2_outlined),
            _field(brandCtrl, 'Brand / manufacturer', Icons.branding_watermark_outlined),
            _field(modelCtrl, 'Model (optional)', Icons.tag_rounded),
            Text('Category', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            _chips(_categories, cat, (v) => setSheet(() {
                  cat = v;
                  hasSerial = v == 'panel' || v == 'inverter' || v == 'meter';
                })),
            const SizedBox(height: 14),
            Text('Unit', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            _chips([for (final u in _units) (u, u)], unit, (v) => setSheet(() => unit = v)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: hasSerial,
              onChanged: (v) => setSheet(() => hasSerial = v),
              title: Text('Track serial numbers', style: AppTextStyles.bodyMedium),
              subtitle: Text('Each unit is scanned in and issued by serial (panels, inverters)',
                  style: AppTextStyles.caption),
            ),
            _field(minCtrl, 'Minimum stock alert level', Icons.warning_amber_rounded,
                keyboard: TextInputType.number),
            if (!hasSerial)
              _field(qtyCtrl, 'Opening stock (optional)', Icons.numbers_rounded, keyboard: TextInputType.number),
            if (hasSerial)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Add units with Stock In after saving, so each serial number is recorded.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
              ),
            const SizedBox(height: 8),
            _primary('Save Item', busy, () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return _snack('Enter the item name.', error: true);
              setSheet(() => busy = true);
              try {
                final res = await _api.dio.post('/inventory/items', data: {
                  'name': name,
                  'category': cat,
                  'unit': unit,
                  'has_serial': hasSerial,
                  'min_stock': int.tryParse(minCtrl.text.trim()) ?? 0,
                  if (brandCtrl.text.trim().isNotEmpty) 'brand': brandCtrl.text.trim(),
                  if (modelCtrl.text.trim().isNotEmpty) 'model': modelCtrl.text.trim(),
                });
                final opening = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (!hasSerial && opening > 0) {
                  await _api.dio.post('/inventory/stock-in', data: {
                    'item_id': (res.data as Map)['id'],
                    'qty': opening,
                    'note': 'Opening stock',
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('"$name" added to inventory.');
                await _load();
              } catch (e) {
                setSheet(() => busy = false);
                _snack(_err(e, 'Item could not be saved.'), error: true);
              }
            }),
          ],
        ));
  }

  Future<void> _showItemActions(_InventoryItem item) async {
    await _sheet((ctx, _) {
      Widget action(IconData icon, String label, Color color, VoidCallback onTap) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: color),
            title: Text(label, style: AppTextStyles.bodyMedium),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          Text(item.name, style: AppTextStyles.headlineSmall),
          Text(
              '${item.brand} • ${item.qty} ${item.unit} in stock'
              '${item.hasSerial ? ' • serial tracked' : ''}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.gold400)),
          const SizedBox(height: 12),
          action(Icons.add_box_rounded, 'Stock in (delivery)', AppColors.success, () => _showStockInSheet(item)),
          action(Icons.local_shipping_rounded, 'Issue to a customer project', AppColors.warning,
              () => _showIssueSheet(item)),
          if (!item.hasSerial)
            action(Icons.tune_rounded, 'Correct stock count', AppColors.info, () => _showAdjustSheet(item)),
          if (item.qty == 0)
            action(Icons.delete_outline_rounded, 'Delete item', AppColors.error, () => _confirmDelete(item)),
        ],
      );
    });
  }

  Future<void> _showStockInSheet(_InventoryItem item) async {
    List<Map<String, dynamic>> suppliers = [];
    try {
      final res = await _api.dio.get('/suppliers', queryParameters: {'is_active': true, 'limit': 200});
      suppliers = (res.data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    if (!mounted) return;
    final qtyCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    final invoiceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final warrantyCtrl = TextEditingController(text: item.category == 'panel' ? '300' : '60');
    String? supplierId;
    bool busy = false;

    await _sheet((ctx, setSheet) {
      final serials = serialCtrl.text
          .split(RegExp(r'[\n,]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          Text('Stock In • ${item.name}', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          if (item.hasSerial) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: serialCtrl,
                maxLines: 5,
                onChanged: (_) => setSheet(() {}),
                decoration: InputDecoration(
                  hintText: 'Serial numbers, one per line',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  helperText: '${serials.length} unit${serials.length == 1 ? '' : 's'}',
                ),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
              ),
            ),
            _field(warrantyCtrl, 'Warranty (months)', Icons.verified_user_outlined, keyboard: TextInputType.number),
          ] else
            _field(qtyCtrl, 'Quantity received (${item.unit})', Icons.numbers_rounded, keyboard: TextInputType.number),
          DropdownButtonFormField<String?>(
            initialValue: supplierId,
            isExpanded: true,
            dropdownColor: AppColors.navy700,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.store_rounded)),
            hint: const Text('Supplier (optional)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('No supplier')),
              for (final s in suppliers)
                DropdownMenuItem<String?>(value: s['id'].toString(), child: Text(s['name'].toString())),
            ],
            onChanged: (v) => setSheet(() => supplierId = v),
          ),
          const SizedBox(height: 12),
          _field(invoiceCtrl, 'Invoice / bill no. (optional)', Icons.receipt_long_outlined),
          _field(costCtrl, 'Unit cost ₹ (optional)', Icons.currency_rupee_rounded, keyboard: TextInputType.number),
          const SizedBox(height: 8),
          _primary('Record Delivery', busy, () async {
            final qty = item.hasSerial ? serials.length : (int.tryParse(qtyCtrl.text.trim()) ?? 0);
            if (qty <= 0) {
              return _snack(item.hasSerial ? 'Enter at least one serial number.' : 'Enter the quantity.',
                  error: true);
            }
            final cost = int.tryParse(costCtrl.text.trim());
            setSheet(() => busy = true);
            final ok = await _run(
              () => _api.dio.post('/inventory/stock-in', data: {
                'item_id': item.id,
                'qty': qty,
                if (supplierId != null) 'supplier_id': supplierId,
                if (invoiceCtrl.text.trim().isNotEmpty) 'invoice_no': invoiceCtrl.text.trim(),
                if (cost != null) 'unit_cost': cost * 100,
                if (item.hasSerial) 'serial_numbers': serials,
                if (item.hasSerial) 'warranty_months': int.tryParse(warrantyCtrl.text.trim()) ?? 0,
              }),
              '$qty ${item.unit} of ${item.name} added to stock.',
              'Delivery could not be recorded.',
            );
            if (ok && ctx.mounted) {
              Navigator.pop(ctx);
            } else {
              setSheet(() => busy = false);
            }
          }),
        ],
      );
    });
  }

  Future<void> _showIssueSheet(_InventoryItem item) async {
    final customers = await _api.getCustomers();
    List<String> available = [];
    if (item.hasSerial) {
      try {
        final res = await _api.dio.get('/inventory/serials',
            queryParameters: {'status': 'in_stock', 'item_id': item.id, 'limit': 500});
        available = (res.data as List).whereType<Map>().map((e) => e['serial_no'].toString()).toList()..sort();
      } catch (_) {}
    }
    if (!mounted) return;
    if (customers.isEmpty) return _snack('No customers to issue stock to.', error: true);
    if (item.qty <= 0) return _snack('${item.name} is out of stock.', error: true);
    String custId = (customers.first['id'] ?? customers.first['_id']).toString();
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final picked = <String>{};
    bool busy = false;

    await _sheet((ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            Text('Issue • ${item.name}', style: AppTextStyles.headlineSmall),
            Text('${item.qty} ${item.unit} available', style: AppTextStyles.caption),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: custId,
              isExpanded: true,
              dropdownColor: AppColors.navy700,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
              items: [
                for (final c in customers)
                  DropdownMenuItem(
                    value: (c['id'] ?? c['_id']).toString(),
                    child: Text('${c['name'] ?? 'Customer'} · ${c['phone'] ?? ''}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setSheet(() => custId = v ?? custId),
            ),
            const SizedBox(height: 12),
            if (item.hasSerial) ...[
              Text('Select serial numbers (${picked.length} selected)', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              if (available.isEmpty)
                Text('No serials in stock.', style: AppTextStyles.caption.copyWith(color: AppColors.error))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in available)
                          FilterChip(
                            label: Text(s, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            selected: picked.contains(s),
                            onSelected: (v) => setSheet(() => v ? picked.add(s) : picked.remove(s)),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ] else
              _field(qtyCtrl, 'Quantity (${item.unit})', Icons.numbers_rounded, keyboard: TextInputType.number),
            _field(noteCtrl, 'Note (optional)', Icons.notes_rounded),
            _primary('Issue Stock', busy, () async {
              final qty = item.hasSerial ? picked.length : (int.tryParse(qtyCtrl.text.trim()) ?? 0);
              if (qty <= 0) return _snack('Choose what to issue.', error: true);
              setSheet(() => busy = true);
              final ok = await _run(
                () => _api.dio.post('/inventory/stock-out', data: {
                  'item_id': item.id,
                  'qty': qty,
                  'customer_id': custId,
                  if (item.hasSerial) 'serial_numbers': picked.toList(),
                  if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
                }),
                'Issued $qty ${item.unit} of ${item.name}.',
                'Stock could not be issued.',
              );
              if (ok && ctx.mounted) {
                Navigator.pop(ctx);
              } else {
                setSheet(() => busy = false);
              }
            }),
          ],
        ));
  }

  Future<void> _showAdjustSheet(_InventoryItem item) async {
    final qtyCtrl = TextEditingController(text: '${item.qty}');
    final noteCtrl = TextEditingController();
    bool busy = false;
    await _sheet((ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            Text('Correct Count • ${item.name}', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 16),
            _field(qtyCtrl, 'Actual quantity (${item.unit})', Icons.numbers_rounded, keyboard: TextInputType.number),
            _field(noteCtrl, 'Reason (required, e.g. physical recount)', Icons.notes_rounded),
            _primary('Save Count', busy, () async {
              final q = int.tryParse(qtyCtrl.text.trim());
              if (q == null || q < 0) return _snack('Enter a valid quantity.', error: true);
              if (noteCtrl.text.trim().length < 3) return _snack('Enter a reason.', error: true);
              setSheet(() => busy = true);
              final ok = await _run(
                () => _api.dio.post('/inventory/adjust',
                    data: {'item_id': item.id, 'new_qty': q, 'note': noteCtrl.text.trim()}),
                'Stock of ${item.name} set to $q.',
                'Count could not be saved.',
              );
              if (ok && ctx.mounted) {
                Navigator.pop(ctx);
              } else {
                setSheet(() => busy = false);
              }
            }),
          ],
        ));
  }

  Future<void> _confirmDelete(_InventoryItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        title: Text('Delete ${item.name}?'),
        content: const Text('The item is removed from the catalogue. Its stock history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (yes == true) {
      await _run(() => _api.dio.delete('/inventory/items/${item.id}'), '${item.name} deleted.',
          'Item could not be deleted.');
    }
  }

  Future<void> _showAddSupplierSheet() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    bool busy = false;
    await _sheet((ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            Text('Add Supplier', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
            _field(nameCtrl, 'Supplier name', Icons.store_rounded),
            _field(phoneCtrl, 'Phone (optional)', Icons.phone_rounded, keyboard: TextInputType.phone),
            _field(gstCtrl, 'GST no. (optional)', Icons.badge_outlined),
            _field(addrCtrl, 'Address (optional)', Icons.location_on_outlined),
            _primary('Save Supplier', busy, () async {
              if (nameCtrl.text.trim().isEmpty) return _snack('Enter the supplier name.', error: true);
              setSheet(() => busy = true);
              final ok = await _run(
                () => _api.dio.post('/suppliers', data: {
                  'name': nameCtrl.text.trim(),
                  if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
                  if (gstCtrl.text.trim().isNotEmpty) 'gst_no': gstCtrl.text.trim(),
                  if (addrCtrl.text.trim().isNotEmpty) 'address': addrCtrl.text.trim(),
                }),
                'Supplier ${nameCtrl.text.trim()} added.',
                'Supplier could not be saved.',
              );
              if (ok && ctx.mounted) {
                Navigator.pop(ctx);
              } else {
                setSheet(() => busy = false);
              }
            }),
          ],
        ));
  }

  Future<void> _showSerialActions(_SerialItem s) async {
    final targets = <(String, String, Color)>[
      if (s.status != 'defective') ('defective', 'Mark defective', AppColors.error),
      if (s.status != 'returned') ('returned', 'Mark returned', AppColors.warning),
      if (s.status != 'in_stock') ('in_stock', 'Put back in stock', AppColors.success),
    ];
    final noteCtrl = TextEditingController();
    await _sheet((ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            Text(s.serial, style: AppTextStyles.headlineSmall.copyWith(fontFamily: 'monospace')),
            Text('${s.name} • ${s.status.replaceAll('_', ' ')}', style: AppTextStyles.caption),
            if (s.customer != '—')
              Text('Installed at ${s.customer}', style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
            if (s.warrantyUntil != null)
              Text('Warranty until ${DateFormat('dd MMM yyyy').format(s.warrantyUntil!.toLocal())}',
                  style: AppTextStyles.caption),
            const SizedBox(height: 12),
            _field(noteCtrl, 'Reason (optional)', Icons.notes_rounded),
            for (final t in targets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.circle, size: 12, color: t.$3),
                title: Text(t.$2, style: AppTextStyles.bodyMedium),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _run(
                    () => _api.dio.patch('/serials/${s.id}/status', data: {
                      'status': t.$1,
                      if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
                    }),
                    '${s.serial} updated.',
                    'Serial could not be updated.',
                  );
                },
              ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => v == 'supplier' ? _showAddSupplierSheet() : _load(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'supplier', child: Text('Add supplier')),
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            ],
          ),
          IconButton(
            tooltip: 'Add Stock Item',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Icon(Icons.add_rounded, color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: _showAddItemSheet,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold500,
          labelColor: AppColors.gold500,
          unselectedLabelColor: AppColors.grey500,
          tabs: [
            Tab(text: 'Items (${_items.length})'),
            Tab(text: 'Movements (${_movements.length})'),
            Tab(text: 'Serials (${_serials.length})'),
          ],
        ),
      ),
      body: _loading && _items.isEmpty && _movements.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(onRefresh: _load, child: _ItemsView(items: _items, onItemTap: _showItemActions)),
                    RefreshIndicator(onRefresh: _load, child: _StockMovementsView(movements: _movements)),
                    RefreshIndicator(onRefresh: _load, child: _SerialItemsView(serials: _serials, onTap: _showSerialActions)),
                  ],
                ),
    );
  }
}

Widget _empty(IconData icon, String title, String subtitle) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 48, color: AppColors.grey600),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.labelLarge),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
      ],
    );

class _ItemsView extends StatelessWidget {
  final List<_InventoryItem> items;
  final ValueChanged<_InventoryItem> onItemTap;

  const _ItemsView({required this.items, required this.onItemTap});

  Color _categoryColor(String cat) => switch (cat) {
        'panel' => AppColors.gold500,
        'inverter' => AppColors.teal500,
        'structure' => AppColors.orange500,
        'cable' => AppColors.purple500,
        'electrical' => AppColors.info,
        'civil' => AppColors.grey400,
        _ => AppColors.grey500,
      };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _empty(Icons.inventory_2_outlined, 'No Inventory Items', 'Tap + to register components');
    }
    final lowCount = items.where((it) => it.qty <= it.minStock).length;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: items.length + (lowCount > 0 ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (lowCount > 0 && index == 0) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('$lowCount item${lowCount > 1 ? 's' : ''} at or below minimum stock',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
              ),
            ]),
          ).animate().fadeIn(duration: 300.ms);
        }
        final i = index - (lowCount > 0 ? 1 : 0);
        final item = items[i];
        final color = _categoryColor(item.category);
        final isLow = item.qty <= item.minStock;
        return GestureDetector(
          onTap: () => onItemTap(item),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: isLow ? AppColors.error.withValues(alpha: 0.4) : AppColors.navy600),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(item.hasSerial ? Icons.qr_code_rounded : Icons.inventory_2_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey100)),
                  const SizedBox(height: 2),
                  Text('${item.brand} • min ${item.minStock} • tap for actions',
                      style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${item.qty} ${item.unit}',
                    style: AppTextStyles.labelLarge.copyWith(color: isLow ? AppColors.error : AppColors.fg)),
                if (isLow)
                  Text('LOW STOCK',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
        ).animate(delay: Duration(milliseconds: (i * 40).clamp(0, 400))).fadeIn(duration: 300.ms);
      },
    );
  }
}

class _StockMovementsView extends StatelessWidget {
  final List<_MoveItem> movements;
  const _StockMovementsView({required this.movements});

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return _empty(Icons.swap_horiz_rounded, 'No Stock Movements Recorded', 'Deliveries and dispatches will appear here');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final m = movements[i];
        final (icon, color, label) = switch (m.type) {
          'in' => (Icons.arrow_downward_rounded, AppColors.success, 'Stock in'),
          'out' => (Icons.arrow_upward_rounded, AppColors.error, 'Issued'),
          'return' => (Icons.undo_rounded, AppColors.warning, 'Return'),
          _ => (Icons.tune_rounded, AppColors.info, 'Adjustment'),
        };
        final signed = m.type == 'out' ? '-${m.qty}' : (m.qty > 0 ? '+${m.qty}' : '${m.qty}');
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.navy600),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey100)),
                Text('$label • ${m.ref}', style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('by ${m.by}', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(signed, style: AppTextStyles.labelLarge.copyWith(color: color)),
              Text(m.date, style: AppTextStyles.caption),
            ]),
          ]),
        );
      },
    );
  }
}

class _SerialItemsView extends StatefulWidget {
  final List<_SerialItem> serials;
  final ValueChanged<_SerialItem> onTap;
  const _SerialItemsView({required this.serials, required this.onTap});

  @override
  State<_SerialItemsView> createState() => _SerialItemsViewState();
}

class _SerialItemsViewState extends State<_SerialItemsView> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    if (widget.serials.isEmpty) {
      return _empty(Icons.qr_code_2_rounded, 'No Serial-Numbered Units', 'Panels and inverters added by Stock In appear here');
    }
    final q = _q.toLowerCase();
    final list = widget.serials
        .where((s) => q.isEmpty || '${s.serial} ${s.name} ${s.customer}'.toLowerCase().contains(q))
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: list.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: const InputDecoration(hintText: 'Search serial, item or customer', prefixIcon: Icon(Icons.search)),
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
          );
        }
        final s = list[i - 1];
        final color = switch (s.status) {
          'installed' => AppColors.success,
          'defective' => AppColors.error,
          'returned' => AppColors.warning,
          _ => AppColors.teal500,
        };
        return GestureDetector(
          onTap: () => widget.onTap(s),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(Icons.qr_code_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey100)),
                  Text(s.serial, style: AppTextStyles.caption.copyWith(fontFamily: 'monospace', letterSpacing: 1)),
                  if (s.customer != '—')
                    Text('Installed: ${s.customer}', style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(s.status.replaceAll('_', ' '), style: AppTextStyles.caption.copyWith(color: color)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _InventoryItem {
  final String id, name, category, brand, unit;
  final int qty, minStock;
  final bool hasSerial;
  const _InventoryItem(this.id, this.name, this.category, this.brand, this.qty, this.minStock, this.unit, this.hasSerial);

  factory _InventoryItem.fromJson(Map<String, dynamic> j) {
    final brand = [j['brand'], j['model']].where((v) => v != null && v.toString().isNotEmpty).join(' ');
    return _InventoryItem(
      j['id'].toString(),
      (j['name'] ?? 'Item').toString(),
      (j['category'] ?? 'other').toString(),
      brand.isEmpty ? 'Generic' : brand,
      ((j['stock_qty'] ?? 0) as num).toInt(),
      ((j['min_stock'] ?? 0) as num).toInt(),
      (j['unit'] ?? 'pcs').toString(),
      j['has_serial'] == true,
    );
  }
}

class _MoveItem {
  final String name, type, ref, date, by;
  final int qty;
  const _MoveItem(this.name, this.type, this.qty, this.ref, this.date, this.by);

  factory _MoveItem.fromJson(Map<String, dynamic> j) {
    final serials = (j['serial_numbers'] is List) ? (j['serial_numbers'] as List).length : 0;
    final ref = [
      if (j['customer_name'] != null) 'to ${j['customer_name']}',
      if (j['supplier_name'] != null) 'from ${j['supplier_name']}',
      if (j['invoice_no'] != null) 'inv ${j['invoice_no']}',
      if (serials > 0) '$serials serial${serials == 1 ? '' : 's'}',
      if (j['note'] != null) j['note'].toString(),
    ].join(' • ');
    return _MoveItem(
      (j['item_name'] ?? 'Item').toString(),
      (j['type'] ?? 'adjust').toString(),
      ((j['qty'] ?? 0) as num).toInt(),
      ref.isEmpty ? '—' : ref,
      _fmtDate(j['moved_at']),
      (j['mover_name'] ?? 'Staff').toString(),
    );
  }
}

class _SerialItem {
  final String id, name, serial, status, customer;
  final DateTime? warrantyUntil;
  const _SerialItem(this.id, this.name, this.serial, this.status, this.customer, this.warrantyUntil);

  factory _SerialItem.fromJson(Map<String, dynamic> j) => _SerialItem(
        j['id'].toString(),
        (j['item_name'] ?? 'Unit').toString(),
        (j['serial_no'] ?? '').toString(),
        (j['status'] ?? 'in_stock').toString(),
        (j['customer_name'] ?? '—').toString(),
        DateTime.tryParse(j['warranty_until']?.toString() ?? ''),
      );
}
