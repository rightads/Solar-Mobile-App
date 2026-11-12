import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class KedlScreen extends StatefulWidget {
  const KedlScreen({super.key});

  @override
  State<KedlScreen> createState() => _KedlScreenState();
}

class _KedlScreenState extends State<KedlScreen> {
  String _filterType = 'All';
  final _types = ['All', 'Name Change', 'Load File', 'Net File'];

  List<_KedlFile> _files = [];
  List<Map<String, dynamic>> _registeredCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiClient().getKedlFiles(),
        ApiClient().getCustomers(),
      ]);
      final fileMaps = results[0];
      final custMaps = results[1];

      if (mounted) {
        setState(() {
          _files = fileMaps.map((m) => _KedlFile.fromMap(m)).toList();
          _registeredCustomers = custMaps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _statusColor(String s) => switch (s) {
        'approved' => AppColors.success,
        'demand_paid' => AppColors.gold500,
        'demand_raised' => AppColors.warning,
        'submitted' => AppColors.teal500,
        _ => AppColors.grey500,
      };

  String _statusLabel(String s) => switch (s) {
        'approved' => 'Approved ✓',
        'demand_paid' => 'Demand Paid',
        'demand_raised' => 'Demand Raised',
        'submitted' => 'Submitted',
        'not_started' => 'Not Started',
        _ => s,
      };

  String _typeLabel(String t) => switch (t) {
        'name_change' => 'Name Change',
        'load' => 'Load File',
        'net' => 'Net File',
        _ => t,
      };

  Color _typeColor(String t) => switch (t) {
        'name_change' => AppColors.gold500,
        'load' => AppColors.teal500,
        'net' => AppColors.purple500,
        _ => AppColors.grey500,
      };

  List<_KedlFile> get _filteredFiles {
    if (_filterType == 'All') return _files;
    final map = {
      'Name Change': 'name_change',
      'Load File': 'load',
      'Net File': 'net',
    };
    final key = map[_filterType];
    return _files.where((f) => f.type == key).toList();
  }

  void _showAddFileSheet(BuildContext context) {
    final custCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final demandCtrl = TextEditingController();
    final demandRefCtrl = TextEditingController();
    String type = 'name_change'; // Notebook Page 3 order: Name Change, Load, Net
    bool initAllThree = false;
    String? selectedCustId;

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
                Text('KEDL Work Employee File',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text('After Work Assign — Track Name Change, Load & Net Files',
                    style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                const SizedBox(height: 16),

                // Customer selection dropdown if customers exist
                if (_registeredCustomers.isNotEmpty) ...[
                  Text('Select Customer (Assigned Project)',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.navy700,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.navy600),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCustId,
                        hint: Text('Choose Existing Customer',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.grey400)),
                        isExpanded: true,
                        dropdownColor: AppColors.navy800,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Custom / New Customer Name',
                                style: TextStyle(color: AppColors.grey400)),
                          ),
                          ..._registeredCustomers.map((c) {
                            final cId = (c['id'] ?? c['_id'] ?? '').toString();
                            final cName = (c['name'] ?? 'Customer').toString();
                            final cLoc = (c['address'] ?? '').toString();
                            return DropdownMenuItem<String>(
                              value: cId,
                              child: Text('$cName (${cLoc.isNotEmpty ? cLoc : 'Site'})',
                                  style: const TextStyle(color: AppColors.fg)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setSheetState(() {
                            selectedCustId = val;
                            if (val != null) {
                              final found = _registeredCustomers.firstWhere(
                                (c) => (c['id'] ?? c['_id'] ?? '').toString() == val,
                                orElse: () => {},
                              );
                              if (found.isNotEmpty) {
                                custCtrl.text = found['name']?.toString() ?? '';
                                locCtrl.text = found['address']?.toString() ?? '';
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: custCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Customer Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Area / Substation / Discom Division',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 14),

                // Option to initialize all 3 files
                GestureDetector(
                  onTap: () {
                    setSheetState(() => initAllThree = !initAllThree);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: initAllThree
                          ? AppColors.gold500.withValues(alpha: 0.15)
                          : AppColors.navy700,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: initAllThree ? AppColors.gold500 : AppColors.navy600,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          initAllThree
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: initAllThree ? AppColors.gold500 : AppColors.grey500,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Create All 3 Files for this Customer (Name Change + Load + Net File)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: initAllThree ? AppColors.fg : AppColors.grey300,
                              fontWeight: initAllThree ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (!initAllThree) ...[
                  Text('Application File Type', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ('name_change', 'Name Change File'),
                      ('load', 'Load File'),
                      ('net', 'Net File'),
                    ].map((t) {
                      final isSel = type == t.$1;
                      return GestureDetector(
                        onTap: () => setSheetState(() => type = t.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.gold500.withValues(alpha: 0.2)
                                : AppColors.navy700,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                                color: isSel
                                    ? AppColors.gold500
                                    : AppColors.navy600),
                          ),
                          child: Text(t.$2,
                              style: AppTextStyles.caption.copyWith(
                                  color: isSel
                                      ? AppColors.gold400
                                      : AppColors.grey400,
                                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: demandCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Discom Demand Amount (₹) - Optional',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: demandRefCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Demand Notice No. / Reference (e.g. DN-1092)',
                      prefixIcon: Icon(Icons.receipt_outlined),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                  ),
                ],

                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    final cust = custCtrl.text.trim();
                    final loc = locCtrl.text.trim();
                    final dem = int.tryParse(demandCtrl.text.trim()) ?? 0;
                    final ref = demandRefCtrl.text.trim();
                    if (cust.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter or select a customer name'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      if (initAllThree) {
                        // Create all 3 files
                        final cId = selectedCustId ?? DateTime.now().millisecondsSinceEpoch.toString();
                        await ApiClient().initKedlFiles(cId);
                      } else {
                        await ApiClient().saveKedlFile({
                          'customer_id': selectedCustId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          'customer_name': cust,
                          'location': loc.isEmpty ? 'Substation Area' : loc,
                          'file_type': type,
                          'status': dem > 0 ? 'demand_raised' : 'submitted',
                          'demand_amount': dem,
                          'demand_notice_ref': ref,
                          'assigned_employee_name': 'KEDL Liaison',
                        });
                      }

                      await _fetchData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(initAllThree
                                ? 'Initialized all 3 KEDL files (Name Change, Load, Net) for $cust!'
                                : 'Created KEDL ${_typeLabel(type)} for $cust!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating KEDL file: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: Text(
                        initAllThree
                            ? 'Initialize All 3 Files (Name Change, Load, Net)'
                            : 'Save KEDL File Application',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.ink900),
                      ),
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

  void _showRaiseDemandSheet(BuildContext context, _KedlFile f) {
    final amtCtrl = TextEditingController(text: f.demand > 0 ? '${f.demand}' : '');
    final refCtrl = TextEditingController(text: f.demandRef);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
            Text('Raise / Update Demand Notice',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text('${f.customer} • ${_typeLabel(f.type)}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.gold400)),
            const SizedBox(height: 16),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Discom Demand Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                hintText: 'Demand Notice No. / Ref (e.g. DN-5091)',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid demand amount'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await ApiClient().updateKedlDemand(
                    fileId: f.id,
                    demandAmount: amt,
                    status: 'demand_raised',
                    demandRef: refCtrl.text.trim(),
                  );
                  await _fetchData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Demand of ₹$amt recorded for ${f.customer}!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update demand: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Center(
                  child: Text('Confirm Demand Notice',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.ink900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKedlDetail(BuildContext context, _KedlFile f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
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
                Expanded(
                  child: Text('${f.customer} — ${_typeLabel(f.type)}',
                      style: AppTextStyles.headlineMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(f.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _statusLabel(f.status),
                    style: AppTextStyles.caption.copyWith(color: _statusColor(f.status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Discom Officer: ${f.assignedTo} • ${f.location}',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 20),

            // Stepper stages
            Text('Paperwork Progression Lifecycle', style: AppTextStyles.caption),
            const SizedBox(height: 12),
            ...['not_started', 'submitted', 'demand_raised', 'demand_paid', 'approved']
                .map((s) {
              final stages = [
                'not_started',
                'submitted',
                'demand_raised',
                'demand_paid',
                'approved'
              ];
              final active = stages.indexOf(f.status) >= stages.indexOf(s);
              final isCurrent = s == f.status;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? AppColors.success.withValues(alpha: 0.2)
                            : AppColors.navy700,
                        border: Border.all(
                          color: active ? AppColors.success : AppColors.navy500,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        active ? Icons.check_rounded : Icons.circle_outlined,
                        size: 14,
                        color: active ? AppColors.success : AppColors.grey600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _statusLabel(s),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: active ? AppColors.grey200 : AppColors.grey600,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('CURRENT',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.gold400, fontSize: 9)),
                      ),
                    ],
                  ],
                ),
              );
            }),

            // Demand Notice box
            if (f.demand > 0 || f.demandRef.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded,
                            color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Text('Discom Demand Notice',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.warning)),
                        const Spacer(),
                        if (f.status == 'demand_paid')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text('PAID ✓',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Amount: ₹${f.demand}',
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.fg)),
                    if (f.demandRef.isNotEmpty)
                      Text('Notice Ref: ${f.demandRef}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.grey300)),
                    if (f.demandPaidDate.isNotEmpty)
                      Text('Paid Date: ${f.demandPaidDate}',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.grey400)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action row 1: Call Officer & Raise Demand
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling Discom Officer ${f.assignedTo}...'),
                          backgroundColor: AppColors.teal500,
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.teal500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.teal500.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_rounded,
                              color: AppColors.teal500, size: 18),
                          const SizedBox(width: 6),
                          Text('Call Officer',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.teal500)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRaiseDemandSheet(context, f);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.currency_rupee_rounded,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 6),
                          Text(f.demand > 0 ? 'Edit Demand' : 'Raise Demand',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.warning)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Action row 2: Mark Paid & Advance Stage
            Row(
              children: [
                if (f.status == 'demand_raised') ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);
                        try {
                          await ApiClient().updateKedlDemand(
                            fileId: f.id,
                            demandAmount: f.demand,
                            status: 'demand_paid',
                            demandRef: f.demandRef,
                          );
                          await _fetchData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Demand marked as PAID ✓!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating status: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: Center(
                          child: Text('Mark Demand Paid ✓',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.success)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final next = switch (f.status) {
                        'not_started' => 'submitted',
                        'submitted' => 'demand_raised',
                        'demand_raised' => 'demand_paid',
                        'demand_paid' => 'approved',
                        _ => 'approved',
                      };
                      setState(() => _isLoading = true);
                      try {
                        await ApiClient().updateKedlDemand(
                          fileId: f.id,
                          demandAmount: f.demand,
                          status: next,
                          demandRef: f.demandRef,
                        );
                        await _fetchData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Stage advanced to ${_statusLabel(next)}!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error advancing stage: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: Text(
                          f.status == 'demand_paid' ? 'Approve File ✓' : 'Advance Stage →',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.ink900),
                        ),
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
    final list = _filteredFiles;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('KEDL Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchData,
          ),
          IconButton(
            tooltip: 'Add File',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: () => _showAddFileSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold500))
          : RefreshIndicator(
              color: AppColors.gold500,
              backgroundColor: AppColors.navy800,
              onRefresh: _fetchData,
              child: Column(
                children: [
                  // Summary cards
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _KedlSummaryCard(
                          label: 'Name Change',
                          done: _files
                              .where((f) =>
                                  f.type == 'name_change' &&
                                  (f.status == 'approved' ||
                                      f.status == 'demand_paid'))
                              .length,
                          total: _files
                              .where((f) => f.type == 'name_change')
                              .length,
                          color: AppColors.gold500,
                        ),
                        const SizedBox(width: 10),
                        _KedlSummaryCard(
                          label: 'Load Files',
                          done: _files
                              .where((f) =>
                                  f.type == 'load' &&
                                  (f.status == 'approved' ||
                                      f.status == 'demand_paid'))
                              .length,
                          total: _files.where((f) => f.type == 'load').length,
                          color: AppColors.teal500,
                        ),
                        const SizedBox(width: 10),
                        _KedlSummaryCard(
                          label: 'Net Files',
                          done: _files
                              .where((f) =>
                                  f.type == 'net' &&
                                  (f.status == 'approved' ||
                                      f.status == 'demand_paid'))
                              .length,
                          total: _files.where((f) => f.type == 'net').length,
                          color: AppColors.purple500,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

                  // Filter
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _types.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final selected = _filterType == _types[i];
                        return GestureDetector(
                          onTap: () => setState(() => _filterType = _types[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.gold500.withValues(alpha: 0.15)
                                  : AppColors.navy800,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: selected
                                    ? AppColors.gold500
                                    : AppColors.navy600,
                              ),
                            ),
                            child: Text(
                              _types[i],
                              style: AppTextStyles.labelMedium.copyWith(
                                color: selected
                                    ? AppColors.gold400
                                    : AppColors.grey400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 4),

                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.description_outlined,
                                    size: 48, color: AppColors.grey600),
                                const SizedBox(height: 12),
                                Text('No KEDL Files in this category',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: AppColors.grey400)),
                                const SizedBox(height: 6),
                                Text(
                                    'Tap "+" above to add Name Change, Load, or Net Files',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.grey600)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                            physics: const BouncingScrollPhysics(),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final f = list[i];
                              final statusColor = _statusColor(f.status);
                              final typeColor = _typeColor(f.type);
                              return GestureDetector(
                                onTap: () => _showKedlDetail(context, f),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.navy800,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xl),
                                    border: Border.all(
                                        color: typeColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color:
                                              typeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.md),
                                        ),
                                        child: Icon(Icons.description_rounded,
                                            color: typeColor, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(f.customer,
                                                      style: AppTextStyles
                                                          .labelLarge,
                                                      overflow:
                                                          TextOverflow.ellipsis),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(
                                                        alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            AppRadius.pill),
                                                  ),
                                                  child: Text(
                                                    _statusLabel(f.status),
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                            color: statusColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(_typeLabel(f.type),
                                                    style: AppTextStyles
                                                        .bodySmall
                                                        .copyWith(
                                                            color: typeColor)),
                                                const SizedBox(width: 8),
                                                if (f.demand > 0)
                                                  Text(
                                                    'Demand: ₹${f.demand ~/ 1000}K',
                                                    style: AppTextStyles
                                                        .bodySmall
                                                        .copyWith(
                                                            color: AppColors
                                                                .warning),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                    Icons.person_outline_rounded,
                                                    size: 12,
                                                    color: AppColors.grey500),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '${f.assignedTo} • ${f.location}',
                                                    style: AppTextStyles.caption,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: AppColors.grey600),
                                    ],
                                  ),
                                ),
                              )
                                  .animate(
                                      delay: Duration(milliseconds: i * 70))
                                  .fadeIn(duration: 350.ms)
                                  .slideX(begin: 0.05, end: 0);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _KedlSummaryCard extends StatelessWidget {
  final String label;
  final int done, total;
  final Color color;
  const _KedlSummaryCard(
      {required this.label,
      required this.done,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$done',
                  style: AppTextStyles.headlineLarge
                      .copyWith(color: color, fontSize: 28)),
              Text('/$total',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: color.withValues(alpha: 0.5))),
            ],
          ),
        ],
      ),
    );
  }
}

class _KedlFile {
  final String id, customerId, customer, type, status, location, assignedTo;
  final int demand;
  final String demandRef;
  final String demandPaidDate;

  const _KedlFile({
    required this.id,
    required this.customerId,
    required this.customer,
    required this.type,
    required this.status,
    required this.demand,
    this.demandRef = '',
    this.demandPaidDate = '',
    this.location = '',
    this.assignedTo = 'KEDL Liaison',
  });

  factory _KedlFile.fromMap(Map<String, dynamic> m) {
    return _KedlFile(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      customerId: (m['customer_id'] ?? '').toString(),
      customer: (m['customer_name'] ?? m['customer'] ?? 'Customer').toString(),
      type: (m['file_type'] ?? m['type'] ?? 'net').toString(),
      status: (m['status'] ?? 'not_started').toString(),
      demand: (m['demand_amount'] ?? m['demand'] ?? 0) as int,
      demandRef: (m['demand_notice_ref'] ?? m['demand_ref'] ?? '').toString(),
      demandPaidDate: (m['demand_paid_date'] ?? '').toString(),
      location: (m['location'] ?? '').toString(),
      assignedTo: (m['assigned_employee_name'] ?? m['assignedTo'] ?? 'KEDL Liaison').toString(),
    );
  }
}
