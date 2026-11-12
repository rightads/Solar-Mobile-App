import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';
import 'package:solar_pro/features/tickets/data/repositories/ticket_repository.dart';

class ServiceSerialLookupTab extends StatefulWidget {
  final TicketRepository? repository;

  const ServiceSerialLookupTab({
    super.key,
    this.repository,
  });

  @override
  State<ServiceSerialLookupTab> createState() => _ServiceSerialLookupTabState();
}

class _ServiceSerialLookupTabState extends State<ServiceSerialLookupTab> {
  late TicketRepository _repo;
  final TextEditingController _serialController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  SerialDetailModel? _result;
  final List<String> _recentSearches = [];

  // Sample quick test serials
  final List<Map<String, String>> _sampleSerials = [
    {'serial': 'INV-GW-5K-9901', 'label': 'Growatt 5kW (Active)'},
    {'serial': 'PAN-AD-540-1011', 'label': 'Adani 540W (Active)'},
    {'serial': 'INV-LUM-3K-0012', 'label': 'Luminous 3kW (Expired)'},
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TicketRepository();
  }

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _performLookup(String serial) async {
    final query = serial.trim().toUpperCase();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final res = await _repo.lookupSerial(query);
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
          if (!_recentSearches.contains(query)) {
            _recentSearches.insert(0, query);
            if (_recentSearches.length > 5) _recentSearches.removeLast();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No equipment record found for serial "$query". Please verify the code.';
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.teal500,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.navy600),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reverse Equipment Serial Lookup',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Query backend registry to verify active warranty and customer installation profile.',
                    style: TextStyle(color: AppColors.grey400, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serialController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Serial (e.g. INV-GW-5K-9901)',
                            hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13, letterSpacing: 0),
                            prefixIcon: const Icon(Icons.qr_code_2_rounded, color: AppColors.gold500),
                            suffixIcon: _serialController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: AppColors.grey400),
                                    onPressed: () {
                                      _serialController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.navy900,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(color: AppColors.navy600),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(color: AppColors.navy600),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(color: AppColors.gold500),
                            ),
                          ),
                          onSubmitted: (val) => _performLookup(val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _performLookup(_serialController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold500,
                          foregroundColor: AppColors.ink900,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink900),
                              )
                            : const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick test sample chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Quick Test:',
                        style: TextStyle(color: AppColors.grey500, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      ..._sampleSerials.map(
                        (sample) => ActionChip(
                          label: Text(sample['label']!),
                          labelStyle: const TextStyle(fontSize: 11, color: AppColors.fg, fontWeight: FontWeight.w600),
                          backgroundColor: AppColors.navy900,
                          side: const BorderSide(color: AppColors.navy600),
                          onPressed: () {
                            _serialController.text = sample['serial']!;
                            _performLookup(sample['serial']!);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error Display
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.fg, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Result Display Card
            if (_result != null) ...[
              _buildResultCard(_result!),
              const SizedBox(height: 20),
            ],

            // Recent Searches History
            if (_recentSearches.isNotEmpty) ...[
              const Text(
                'Recent Lookups',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches.map(
                  (s) => InkWell(
                    onTap: () {
                      _serialController.text = s;
                      _performLookup(s);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.navy600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 14, color: AppColors.grey500),
                          const SizedBox(width: 6),
                          Text(s, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(SerialDetailModel item) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isUnderWarranty = item.isUnderWarranty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isUnderWarranty ? AppColors.success.withValues(alpha: 0.5) : AppColors.error.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUnderWarranty
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            child: Row(
              children: [
                Icon(
                  isUnderWarranty ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                  color: isUnderWarranty ? AppColors.success : AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isUnderWarranty ? 'ACTIVE WARRANTY COVERAGE' : 'WARRANTY EXPIRED',
                    style: TextStyle(
                      color: isUnderWarranty ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.navy900,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(color: AppColors.gold400, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Equipment Name & Model
                Text(
                  item.itemName,
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.brand} • ${item.model}',
                  style: const TextStyle(color: AppColors.grey400, fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Serial No Copy Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navy900,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.navy600),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SERIAL NUMBER', style: TextStyle(color: AppColors.grey500, fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            item.serialNo,
                            style: const TextStyle(
                              color: AppColors.gold400,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: AppColors.grey400, size: 18),
                        onPressed: () => _copyToClipboard(item.serialNo, 'Serial number'),
                        tooltip: 'Copy Serial',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Warranty Dates Grid
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navy900.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INSTALLED ON', style: TextStyle(color: AppColors.grey500, fontSize: 10, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              item.installedOn != null ? dateFormat.format(item.installedOn!) : 'N/A',
                              style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 30, width: 1, color: AppColors.navy600),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('WARRANTY UNTIL', style: TextStyle(color: AppColors.grey500, fontSize: 10, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              item.warrantyUntil != null ? dateFormat.format(item.warrantyUntil!) : 'N/A',
                              style: TextStyle(
                                color: isUnderWarranty ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Customer Profile Details
                const Text(
                  'Installed Customer Profile',
                  style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  Icons.person_rounded,
                  'Customer',
                  item.customerName ?? 'Direct Inventory',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.phone_rounded,
                  'Contact',
                  item.customerPhone ?? 'N/A',
                  trailing: item.customerPhone != null
                      ? IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.grey500, size: 16),
                          onPressed: () => _copyToClipboard(item.customerPhone!, 'Phone number'),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.location_on_rounded,
                  'Site Address',
                  item.customerAddress ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.store_mall_directory_rounded,
                  'Supplier',
                  '${item.supplierName ?? "OEM"} (${item.warrantyMonths} Months Terms)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.gold500),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.grey500, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
