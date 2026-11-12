import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Searchable brand picker dropdown with support for adding custom brands.
class BrandSelectorField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> presetBrands;
  final ValueChanged<String> onSelected;
  final String? hintText;
  final bool isRequired;

  const BrandSelectorField({
    super.key,
    required this.label,
    required this.value,
    required this.presetBrands,
    required this.onSelected,
    this.hintText,
    this.isRequired = false,
  });

  void _openBrandSelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BrandSelectionSheet(
        title: label,
        presetBrands: presetBrands,
        currentValue: value,
        onSelected: (val) {
          Navigator.of(ctx).pop();
          onSelected(val);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.grey300,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openBrandSelectorModal(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: hasValue ? AppColors.teal500.withValues(alpha: 0.5) : AppColors.navy700,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : (hintText ?? 'Select or add $label'),
                    style: TextStyle(
                      color: hasValue ? AppColors.fg : AppColors.grey500,
                      fontSize: 14,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.grey400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandSelectionSheet extends StatefulWidget {
  final String title;
  final List<String> presetBrands;
  final String? currentValue;
  final ValueChanged<String> onSelected;

  const _BrandSelectionSheet({
    required this.title,
    required this.presetBrands,
    this.currentValue,
    required this.onSelected,
  });

  @override
  State<_BrandSelectionSheet> createState() => _BrandSelectionSheetState();
}

class _BrandSelectionSheetState extends State<_BrandSelectionSheet> {
  final _searchController = TextEditingController();
  final _customBrandController = TextEditingController();
  late List<String> _filteredBrands;
  bool _isAddingCustom = false;

  @override
  void initState() {
    super.initState();
    _filteredBrands = List.from(widget.presetBrands);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBrands = List.from(widget.presetBrands);
      } else {
        _filteredBrands = widget.presetBrands
            .where((b) => b.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customBrandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey700,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select ${widget.title}',
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.grey400),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search box
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.fg, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search or filter brands...',
              hintStyle: const TextStyle(color: AppColors.grey500),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
              filled: true,
              fillColor: AppColors.navy800,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Custom brand input toggle
          if (_isAddingCustom) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.teal500.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Custom Brand Name',
                    style: TextStyle(
                      color: AppColors.teal500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customBrandController,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.fg, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Enter new brand name',
                            hintStyle: const TextStyle(color: AppColors.grey500),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: const BorderSide(color: AppColors.navy700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final text = _customBrandController.text.trim();
                          if (text.isNotEmpty) {
                            widget.onSelected(text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal500,
                          foregroundColor: AppColors.fg,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            InkWell(
              onTap: () => setState(() => _isAddingCustom = true),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.teal500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.teal500.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppColors.teal500, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '+ Add New / Custom Brand',
                      style: TextStyle(
                        color: AppColors.teal500,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Brands List
          Expanded(
            child: _filteredBrands.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: AppColors.grey600, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'No matching brands found',
                          style: TextStyle(color: AppColors.grey500, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            if (_searchController.text.trim().isNotEmpty) {
                              widget.onSelected(_searchController.text.trim());
                            } else {
                              setState(() => _isAddingCustom = true);
                            }
                          },
                          child: Text(
                            'Use "${_searchController.text.trim()}"',
                            style: const TextStyle(color: AppColors.teal500),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredBrands.length,
                    itemBuilder: (context, index) {
                      final brand = _filteredBrands[index];
                      final isSelected = brand.toLowerCase() == (widget.currentValue ?? '').toLowerCase();

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        tileColor: isSelected ? AppColors.teal500.withValues(alpha: 0.15) : null,
                        title: Text(
                          brand,
                          style: TextStyle(
                            color: isSelected ? AppColors.teal500 : AppColors.fg,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.teal500, size: 20)
                            : null,
                        onTap: () => widget.onSelected(brand),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
