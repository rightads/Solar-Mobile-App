import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_InventoryItem> _items = [];
  final List<_MoveItem> _movements = [];
  final List<_SerialItem> _serials = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddItemSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    String cat = 'panel';

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
                Text('Add Inventory Item', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Item Name (e.g. Solar Panel 550W)',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: brandCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Brand / Manufacturer',
                    prefixIcon: Icon(Icons.branding_watermark_outlined),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Unit (pcs, m, kg)',
                          prefixIcon: Icon(Icons.straighten_rounded),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Minimum Alert Level',
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 14),
                Text('Category', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ('panel', 'Panel'),
                    ('inverter', 'Inverter'),
                    ('structure', 'Structure'),
                    ('cable', 'Cable'),
                    ('electrical', 'Electrical'),
                  ].map((c) {
                    final isSel = cat == c.$1;
                    return GestureDetector(
                      onTap: () => setSheetState(() => cat = c.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.gold500.withValues(alpha: 0.2) : AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: isSel ? AppColors.gold500 : AppColors.navy600),
                        ),
                        child: Text(c.$2,
                            style: AppTextStyles.caption.copyWith(
                                color: isSel ? AppColors.gold400 : AppColors.grey400)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    final name = nameCtrl.text.trim();
                    final brand = brandCtrl.text.trim();
                    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    final min = int.tryParse(minCtrl.text.trim()) ?? 5;
                    final unit = unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim();

                    if (name.isEmpty) return;

                    final newItem = _InventoryItem(
                      DateTime.now().millisecondsSinceEpoch.toString(),
                      name,
                      cat,
                      brand.isEmpty ? 'Generic' : brand,
                      qty,
                      min,
                      unit,
                    );

                    setState(() {
                      _items.insert(0, newItem);
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Item "$name" added to inventory!'),
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
                      child: Text('Save Item',
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

  void _showAdjustStockSheet(BuildContext context, _InventoryItem item) {
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
            Text(item.name, style: AppTextStyles.headlineSmall),
            Text('${item.brand} • Current Stock: ${item.qty} ${item.unit}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.gold400)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        final idx = _items.indexWhere((it) => it.id == item.id);
                        if (idx != -1) {
                          _items[idx] = _items[idx].copyWith(qty: item.qty + 10);
                          _movements.insert(
                              0, _MoveItem(item.name, 'in', 10, 'Manual Adjustment', 'Today'));
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added +10 ${item.unit} to ${item.name}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, color: AppColors.success, size: 20),
                          const SizedBox(width: 6),
                          Text('+10 Stock In',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (item.qty <= 0) return;
                      Navigator.pop(ctx);
                      setState(() {
                        final idx = _items.indexWhere((it) => it.id == item.id);
                        if (idx != -1) {
                          final newQty = (item.qty - 5).clamp(0, 999999);
                          _items[idx] = _items[idx].copyWith(qty: newQty);
                          _movements.insert(
                              0, _MoveItem(item.name, 'out', 5, 'Site Dispatch', 'Today'));
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Issued 5 ${item.unit} from ${item.name}'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.remove_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 6),
                          Text('-5 Dispatch',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.error)),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Add Stock Item',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: () => _showAddItemSheet(context),
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
            Tab(text: 'Stock Movements (${_movements.length})'),
            Tab(text: 'Serial Items (${_serials.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ItemsView(
            items: _items,
            onItemTap: (it) => _showAdjustStockSheet(context, it),
          ),
          _StockMovementsView(movements: _movements),
          _SerialItemsView(serials: _serials),
        ],
      ),
    );
  }
}

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
    final lowCount = items.where((it) => it.qty <= it.minStock).length;

    return Column(
      children: [
        if (lowCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Text(
                  '$lowCount item${lowCount > 1 ? 's' : ''} below minimum stock level!',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 48, color: AppColors.grey600),
                      const SizedBox(height: 12),
                      Text('No Inventory Items',
                          style: AppTextStyles.labelLarge),
                      const SizedBox(height: 4),
                      Text('Tap "+ Add Stock Item" to register components',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.grey500)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
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
                    border: Border.all(
                      color: isLow
                          ? AppColors.error.withValues(alpha: 0.4)
                          : AppColors.navy600,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(Icons.inventory_2_rounded,
                            color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.grey100)),
                            const SizedBox(height: 2),
                            Text(
                              '${item.brand} • Tap to adjust stock',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.gold400),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.qty} ${item.unit}',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isLow ? AppColors.error : AppColors.fg,
                            ),
                          ),
                          if (isLow)
                            Text(
                              'LOW STOCK',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.error,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
                  .animate(delay: Duration(milliseconds: i * 60))
                  .fadeIn(duration: 350.ms)
                  .slideX(begin: 0.05, end: 0);
            },
          ),
        ),
      ],
    );
  }
}

class _StockMovementsView extends StatelessWidget {
  final List<_MoveItem> movements;
  const _StockMovementsView({required this.movements});

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz_rounded,
                size: 48, color: AppColors.grey600),
            const SizedBox(height: 12),
            Text('No Stock Movements Recorded', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text('Dispatches and arrivals will appear here',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final m = movements[i];
        final isIn = m.type == 'in';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.navy600),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isIn ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIn
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isIn ? AppColors.success : AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.grey100)),
                    Text(m.ref, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIn ? '+' : '-'}${m.qty}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isIn ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text(m.date, style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
        ).animate(delay: Duration(milliseconds: i * 60)).fadeIn(duration: 350.ms);
      },
    );
  }
}

class _SerialItemsView extends StatelessWidget {
  final List<_SerialItem> serials;
  const _SerialItemsView({required this.serials});

  @override
  Widget build(BuildContext context) {
    if (serials.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_rounded,
                size: 48, color: AppColors.grey600),
            const SizedBox(height: 12),
            Text('No Barcoded Serial Items', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text('Tracked panel and inverter serials will appear here',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: serials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = serials[i];
        final color =
            s.status == 'installed' ? AppColors.success : AppColors.teal500;
        return GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Serial ${s.serial}: ${s.name} is ${s.status.replaceAll('_', ' ')} (${s.customer})'),
                backgroundColor: color,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.qr_code_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.grey100)),
                      Text(s.serial,
                          style: AppTextStyles.caption.copyWith(
                              fontFamily: 'monospace', letterSpacing: 1)),
                      if (s.customer != '—')
                        Text('Installed: ${s.customer}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.gold400)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    s.status.replaceAll('_', ' '),
                    style: AppTextStyles.caption.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: i * 60)).fadeIn(duration: 350.ms);
      },
    );
  }
}

class _InventoryItem {
  final String id, name, category, brand, unit;
  final int qty, minStock;
  const _InventoryItem(this.id, this.name, this.category, this.brand, this.qty, this.minStock, this.unit);

  _InventoryItem copyWith({int? qty}) {
    return _InventoryItem(
      id,
      name,
      category,
      brand,
      qty ?? this.qty,
      minStock,
      unit,
    );
  }
}

class _MoveItem {
  final String name, type, ref, date;
  final int qty;
  const _MoveItem(this.name, this.type, this.qty, this.ref, this.date);
}

class _SerialItem {
  final String name, serial, status, customer;
  const _SerialItem(this.name, this.serial, this.status, this.customer);
}
