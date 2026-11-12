import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/kedl/presentation/screens/kedl_file_detail_screen.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/kedl_file_card.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';

class KedlFilesTab extends StatefulWidget {
  final KedlRepository? repository;

  const KedlFilesTab({
    super.key,
    this.repository,
  });

  @override
  State<KedlFilesTab> createState() => _KedlFilesTabState();
}

class _KedlFilesTabState extends State<KedlFilesTab> {
  late KedlRepository _repo;
  bool _isLoading = true;
  String _searchQuery = '';
  KedlFileType? _selectedFileType;
  KedlFileStatus? _selectedStatus;
  bool _onlyOpenDemands = false;

  List<KedlFileModel> _files = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? KedlRepository();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.listKedlFiles(
        fileType: _selectedFileType,
        status: _selectedStatus,
        hasOpenDemand: _onlyOpenDemands ? true : null,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _files = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerGroups = _repo.groupFilesByCustomer(_files);

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Discom Files',
                    style: TextStyle(color: AppColors.fg, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.teal500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.teal500.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${_files.length} Files',
                      style: const TextStyle(color: AppColors.teal500, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (val) {
                  _searchQuery = val;
                  _loadFiles();
                },
                style: const TextStyle(color: AppColors.fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search customer name, app #, or area...',
                  hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.grey400, size: 20),
                  filled: true,
                  fillColor: AppColors.navy800,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Filter Chips Horizontal Scroll
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Open Demands Toggle Chip
                  FilterChip(
                    label: const Text('Has Open Demand'),
                    selected: _onlyOpenDemands,
                    onSelected: (val) {
                      setState(() => _onlyOpenDemands = val);
                      _loadFiles();
                    },
                    selectedColor: AppColors.warning.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.warning,
                    labelStyle: TextStyle(
                      color: _onlyOpenDemands ? AppColors.warning : AppColors.grey400,
                      fontWeight: _onlyOpenDemands ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.navy800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  const SizedBox(width: 8),

                  // File Type: Name Change
                  FilterChip(
                    label: const Text('Name Change'),
                    selected: _selectedFileType == KedlFileType.nameChange,
                    onSelected: (val) {
                      setState(() => _selectedFileType = val ? KedlFileType.nameChange : null);
                      _loadFiles();
                    },
                    selectedColor: KedlFileType.nameChange.color.withValues(alpha: 0.25),
                    checkmarkColor: KedlFileType.nameChange.color,
                    labelStyle: TextStyle(
                      color: _selectedFileType == KedlFileType.nameChange ? KedlFileType.nameChange.color : AppColors.grey400,
                      fontSize: 12,
                      fontWeight: _selectedFileType == KedlFileType.nameChange ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.navy800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  const SizedBox(width: 8),

                  // File Type: Load Increase
                  FilterChip(
                    label: const Text('Load Increase'),
                    selected: _selectedFileType == KedlFileType.loadIncrease,
                    onSelected: (val) {
                      setState(() => _selectedFileType = val ? KedlFileType.loadIncrease : null);
                      _loadFiles();
                    },
                    selectedColor: KedlFileType.loadIncrease.color.withValues(alpha: 0.25),
                    checkmarkColor: KedlFileType.loadIncrease.color,
                    labelStyle: TextStyle(
                      color: _selectedFileType == KedlFileType.loadIncrease ? KedlFileType.loadIncrease.color : AppColors.grey400,
                      fontSize: 12,
                      fontWeight: _selectedFileType == KedlFileType.loadIncrease ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.navy800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  const SizedBox(width: 8),

                  // File Type: Net Metering
                  FilterChip(
                    label: const Text('Net Metering'),
                    selected: _selectedFileType == KedlFileType.net,
                    onSelected: (val) {
                      setState(() => _selectedFileType = val ? KedlFileType.net : null);
                      _loadFiles();
                    },
                    selectedColor: KedlFileType.net.color.withValues(alpha: 0.25),
                    checkmarkColor: KedlFileType.net.color,
                    labelStyle: TextStyle(
                      color: _selectedFileType == KedlFileType.net ? KedlFileType.net.color : AppColors.grey400,
                      fontSize: 12,
                      fontWeight: _selectedFileType == KedlFileType.net ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.navy800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Customer Groups List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
                  : customerGroups.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadFiles,
                          color: AppColors.gold500,
                          backgroundColor: AppColors.navy800,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: const [
                                  SizedBox(height: 40),
                                  Icon(Icons.folder_off_outlined, size: 48, color: AppColors.grey500),
                                  SizedBox(height: 12),
                                  Text(
                                    'No Discom files matching criteria.',
                                    style: TextStyle(color: AppColors.grey400, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadFiles,
                          color: AppColors.gold500,
                          backgroundColor: AppColors.navy800,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: customerGroups.length,
                            itemBuilder: (context, index) {
                              final group = customerGroups[index];
                              return _buildCustomerGroupCard(group);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerGroupCard(KedlCustomerGroupModel group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: group.hasOverdueDemand
              ? AppColors.error.withValues(alpha: 0.5)
              : (group.hasOpenDemand
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.navy700),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Name & Location Header
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.gold500, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.customerName,
                  style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (group.hasOverdueDemand)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text('OVERDUE DEMAND', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else if (group.hasOpenDemand)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text('OPEN DEMAND', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (group.customerAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.grey400, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.customerAddress,
                    style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.navy700),
          const SizedBox(height: 12),

          // 3 Discom Files for this Customer
          ...group.files.map(
            (file) => KedlFileCard(
              file: file,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => KedlFileDetailScreen(
                      initialFile: file,
                      repository: _repo,
                    ),
                  ),
                );
                _loadFiles();
              },
            ),
          ),
        ],
      ),
    );
  }
}
