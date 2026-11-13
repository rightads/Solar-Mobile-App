import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _filterStage = 'All';
  String _searchQuery = '';

  final _stages = ['All', 'Site Installation', 'KEDL Process', 'Live'];

  /// Stages from the old 10-step flow all belong to Site Installation now.
  static const _installStages = {
    'SALE_CONFIRMED', 'DOCUMENTS_RECEIVED', 'ADVANCE_VERIFIED',
    'STRUCTURE_WORK', 'ELECTRICAL_WORK', 'CIVIL_WORK', 'INSTALLATION_COMPLETE',
  };

  List<_Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final raw = await ApiClient().getCustomers();
      final List<_Customer> parsed = [];
      for (final item in raw) {
        int docCnt = 0;
        if (item['documents'] is Map) {
          docCnt = (item['documents'] as Map).values.where((v) => v != null).length;
        } else if (item['documents_count'] is num) {
          docCnt = (item['documents_count'] as num).toInt();
        }
        parsed.add(_Customer(
          id: item['id']?.toString() ?? item['_id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Unnamed Customer',
          address: item['address']?.toString() ?? 'Site Location',
          locationGps: item['location_gps']?.toString(),
          kw: (item['kw'] is num) ? (item['kw'] as num).toInt() : 5,
          stage: item['stage']?.toString() ?? 'INSTALLATION_COMPLETE',
          amount: (item['total_amount'] is num) ? (item['total_amount'] as num).toInt() : 250000,
          paid: (item['paid_amount'] is num) ? (item['paid_amount'] as num).toInt() : 0,
          phone: item['phone']?.toString() ?? item['mobile']?.toString() ?? '',
          documentsCount: docCnt,
        ));
      }

      if (mounted) {
        setState(() {
          _customers = parsed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _stageColor(String stage) {
    if (_installStages.contains(stage)) return AppColors.orange500;
    return switch (stage) {
      'KEDL_PROCESS' => AppColors.gold500,
      'SYSTEM_LIVE' => AppColors.green400,
      'HANDED_OVER' => AppColors.teal500,
      _ => AppColors.grey500,
    };
  }

  String _stageLabel(String stage) {
    if (_installStages.contains(stage)) return 'Site Installation';
    return switch (stage) {
      'KEDL_PROCESS' => 'KEDL Process',
      'SYSTEM_LIVE' => 'System Live',
      'HANDED_OVER' => 'Handed Over ✓',
      _ => stage,
    };
  }

  List<_Customer> get _filteredCustomers {
    return _customers.where((c) {
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery) ||
          c.address.toLowerCase().contains(_searchQuery) ||
          c.phone.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_filterStage == 'All') return true;
      if (_filterStage == 'Site Installation') {
        return _installStages.contains(c.stage);
      }
      if (_filterStage == 'KEDL Process') {
        return c.stage == 'KEDL_PROCESS';
      }
      if (_filterStage == 'Live') {
        return c.stage == 'SYSTEM_LIVE' || c.stage == 'HANDED_OVER';
      }
      return true;
    }).toList();
  }

  void _showAddCustomerSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final locationGpsCtrl = TextEditingController();
    final kwCtrl = TextEditingController(text: '5');
    final finalPriceCtrl = TextEditingController(text: '250000');

    // 5 Documents as requested in Notebook Page 1
    final Map<String, bool> docsUploaded = {
      'E-Bill': false,
      'Aadhaar': false,
      'Pan': false,
      'Cancelled Cheque': false,
      'Registry (Property Paper)': false,
    };

    // Payment milestones: 1st Payment, 2nd Payment, + many options
    final List<Map<String, TextEditingController>> milestoneControllers = [
      {
        'title': TextEditingController(text: '1st Payment (Booking / Token)'),
        'amount': TextEditingController(text: '25000'),
      },
      {
        'title': TextEditingController(text: '2nd Payment (Structure Dispatch)'),
        'amount': TextEditingController(text: '100000'),
      },
    ];

    bool isSubmitting = false;

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
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sales Data / New Customer',
                        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.fg)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('Page 1 Spec',
                          style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer Name
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Customer Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),

                // Mobile No.
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Mobile No. (10 Digits)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 12),

                // Address + Location Option (GPS)
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Site Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),
                const SizedBox(height: 8),

                // Current Location Button
                GestureDetector(
                  onTap: () {
                    // Capture site GPS
                    final mockGps = '28.6139° N, 77.2090° E (Site Auto-Detected)';
                    locationGpsCtrl.text = mockGps;
                    setSheetState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📍 Current Location GPS captured successfully!'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.navy700,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: locationGpsCtrl.text.isNotEmpty
                            ? AppColors.success
                            : AppColors.gold500.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 18,
                          color: locationGpsCtrl.text.isNotEmpty
                              ? AppColors.success
                              : AppColors.gold400,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locationGpsCtrl.text.isEmpty
                                ? '+ Add Current Location (GPS Option)'
                                : 'Location: ${locationGpsCtrl.text}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: locationGpsCtrl.text.isNotEmpty
                                  ? AppColors.success
                                  : AppColors.gold400,
                            ),
                          ),
                        ),
                        if (locationGpsCtrl.text.isNotEmpty)
                          const Icon(Icons.check_circle_rounded,
                              size: 16, color: AppColors.success),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Capacity kW
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: kwCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Solar kW',
                          prefixIcon: Icon(Icons.bolt_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Documents Upload Section
                Text(
                  'Documents Upload (Page 1):',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.grey200),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.navy700,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.navy600),
                  ),
                  child: Column(
                    children: docsUploaded.keys.map((docName) {
                      final isUp = docsUploaded[docName]!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isUp ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                              size: 18,
                              color: isUp ? AppColors.success : AppColors.grey400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                docName,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isUp ? AppColors.fg : AppColors.grey300,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  docsUploaded[docName] = !isUp;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUp
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.gold500.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  isUp ? 'Uploaded ✓' : '+ Upload',
                                  style: AppTextStyles.caption.copyWith(
                                    color: isUp
                                        ? AppColors.success
                                        : AppColors.gold400,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Work Final Price & Dynamic Milestone Payments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Work Final Price & Milestones:',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.grey200),
                    ),
                    Text(
                      '(many + option)',
                      style: AppTextStyles.caption.copyWith(color: AppColors.gold400),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Final Price (₹)
                TextField(
                  controller: finalPriceCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Work Final Price (₹)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.gold400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Milestones list
                ...milestoneControllers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final m = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: m['title'],
                            decoration: InputDecoration(
                              hintText: 'Payment Milestone ${idx + 1}',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                            ),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.fg),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: m['amount'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '₹ Amount',
                              prefixIcon: Icon(Icons.currency_rupee_rounded, size: 14),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                            ),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.fg),
                          ),
                        ),
                        if (idx >= 2) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.error),
                            onPressed: () {
                              setSheetState(() {
                                milestoneControllers.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                // + Add Milestone Option Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setSheetState(() {
                        final num = milestoneControllers.length + 1;
                        milestoneControllers.add({
                          'title': TextEditingController(text: '${num}th Payment Milestone'),
                          'amount': TextEditingController(text: '50000'),
                        });
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        size: 18, color: AppColors.gold400),
                    label: Text(
                      '+ Add Payment Option (many + option)',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold400),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navy900.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.teal500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment will be verified by employee and customer with dates.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final address = addressCtrl.text.trim();
                          final kw = double.tryParse(kwCtrl.text.trim()) ?? 5.0;
                          final finalPrice =
                              int.tryParse(finalPriceCtrl.text.trim()) ?? 250000;

                          if (name.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter name and mobile number'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setSheetState(() => isSubmitting = true);

                          // Build milestones
                          final List<Map<String, dynamic>> builtMilestones = [];
                          for (int i = 0; i < milestoneControllers.length; i++) {
                            final m = milestoneControllers[i];
                            builtMilestones.add({
                              'id': 'm_${i + 1}',
                              'title': m['title']!.text.trim(),
                              'amount': int.tryParse(m['amount']!.text.trim()) ?? 25000,
                              'status': i == 0 ? 'verified' : 'pending',
                              'due_date': DateTime.now()
                                  .add(Duration(days: i * 7))
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              'verified_by': i == 0 ? 'Sales Staff' : null,
                              'verified_at': i == 0
                                  ? DateTime.now().toIso8601String().split('T').first
                                  : null,
                            });
                          }

                          // Build documents map
                          final Map<String, dynamic> builtDocs = {};
                          docsUploaded.forEach((key, isUp) {
                            final slug = key.toLowerCase().replaceAll(' ', '_');
                            builtDocs[slug] = isUp ? {'uploaded': true, 'name': key} : null;
                          });

                          try {
                            await ApiClient().createCustomer(
                              name: name,
                              phone: phone,
                              address: address.isEmpty ? 'Site Location' : address,
                              locationGps: locationGpsCtrl.text.trim(),
                              kw: kw,
                              finalPrice: finalPrice,
                              milestones: builtMilestones,
                              documents: builtDocs,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Customer "$name" saved to MongoDB!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _fetchCustomers();
                            }
                          } catch (e) {
                            setSheetState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save customer: $e'),
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
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold500.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.navy900),
                            )
                          : Text(
                              'Save Customer & Sales Data',
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

  @override
  Widget build(BuildContext context) {
    final list = _filteredCustomers;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Add Customer',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.person_add_rounded,
                  color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: () => _showAddCustomerSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
              decoration: InputDecoration(
                hintText: 'Search by name, address, phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),

          // Stage filter chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: _stages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isSelected = _filterStage == _stages[i];
                return GestureDetector(
                  onTap: () => setState(() => _filterStage = _stages[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold500.withValues(alpha: 0.15)
                          : AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isSelected ? AppColors.gold500 : AppColors.navy600,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      _stages[i],
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected ? AppColors.gold400 : AppColors.grey400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 8),

          // Customer list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold500),
                  )
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 48, color: AppColors.grey600),
                            const SizedBox(height: 12),
                            Text('No customers found',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.grey500)),
                          ],
                        ),
                      )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      final color = _stageColor(c.stage);
                      final progress = c.amount > 0 ? (c.paid / c.amount).clamp(0.0, 1.0) : 0.0;
                      return _CustomerCard(
                        customer: c,
                        stageColor: color,
                        stageLabel: _stageLabel(c.stage),
                        progress: progress,
                        delay: i * 70,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final _Customer customer;
  final Color stageColor;
  final String stageLabel;
  final double progress;
  final int delay;

  const _CustomerCard({
    required this.customer,
    required this.stageColor,
    required this.stageLabel,
    required this.progress,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/vendor/customers/${customer.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.navy600),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      customer.name[0],
                      style: AppTextStyles.headlineSmall.copyWith(color: stageColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, style: AppTextStyles.labelLarge),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.grey500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.address,
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (customer.locationGps?.isNotEmpty ?? false) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.my_location_rounded, size: 10, color: AppColors.success),
                                  const SizedBox(width: 3),
                                  Text('GPS', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontSize: 10)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.teal500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_rounded, size: 10, color: AppColors.teal500),
                                const SizedBox(width: 3),
                                Text('${customer.documentsCount}/5 Docs',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.teal400, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stageColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        stageLabel,
                        style: AppTextStyles.caption.copyWith(color: stageColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, size: 12, color: AppColors.gold500),
                        Text(
                          ' ${customer.kw} kW',
                          style: AppTextStyles.caption.copyWith(color: AppColors.gold400),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Payment progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${_formatAmount(customer.paid)} / ₹${_formatAmount(customer.amount)}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey300),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% paid',
                  style: AppTextStyles.caption.copyWith(
                    color: progress >= 1 ? AppColors.success : AppColors.gold400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.navy600,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1 ? AppColors.success : AppColors.gold500,
                ),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 12),
            // Quick Call & WhatsApp bar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling ${customer.name} (+91 ${customer.phone})...'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_rounded, size: 13, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Call',
                            style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening WhatsApp chat with ${customer.name}...'),
                        backgroundColor: AppColors.teal500,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.teal500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 13, color: AppColors.teal500),
                        const SizedBox(width: 4),
                        Text('Chat',
                            style: AppTextStyles.caption.copyWith(color: AppColors.teal500)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'View Details →',
                  style: AppTextStyles.caption.copyWith(color: AppColors.gold400),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.08, end: 0);
  }

  String _formatAmount(int amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return '$amount';
  }
}

class _Customer {
  final String id, name, address, stage, phone;
  final String? locationGps;
  final int kw, amount, paid, documentsCount;

  const _Customer({
    required this.id,
    required this.name,
    required this.address,
    this.locationGps,
    required this.kw,
    required this.stage,
    required this.amount,
    required this.paid,
    required this.phone,
    this.documentsCount = 0,
  });
}

