import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/admin/employees/models/admin_employee_model.dart';

class AssignTaskDialog extends StatefulWidget {
  final AdminEmployee employee;
  final VoidCallback onTaskAssigned;
  final ApiClient? apiClient;
  final List<Map<String, dynamic>>? initialCustomers;

  const AssignTaskDialog({
    super.key,
    required this.employee,
    required this.onTaskAssigned,
    this.apiClient,
    this.initialCustomers,
  });

  static Future<void> show(
    BuildContext context, {
    required AdminEmployee employee,
    required VoidCallback onTaskAssigned,
    ApiClient? apiClient,
    List<Map<String, dynamic>>? initialCustomers,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AssignTaskDialog(
        employee: employee,
        onTaskAssigned: onTaskAssigned,
        apiClient: apiClient,
        initialCustomers: initialCustomers,
      ),
    );
  }

  @override
  State<AssignTaskDialog> createState() => _AssignTaskDialogState();
}

class _AssignTaskDialogState extends State<AssignTaskDialog> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCustomerController = TextEditingController();

  String _selectedCategory = 'general';
  String _selectedPriority = 'normal';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));

  List<Map<String, dynamic>> _customers = [];
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  bool _isLoadingCustomers = true;
  bool _isSubmitting = false;
  late ApiClient _client;

  final List<String> _categories = [
    'structure',
    'electrical',
    'civil',
    'service',
    'sales',
    'kedl',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    _client = widget.apiClient ?? ApiClient();
    _initDefaultCategory();
    if (widget.initialCustomers != null) {
      _customers = List.from(widget.initialCustomers!);
      _isLoadingCustomers = false;
    } else {
      _loadCustomers();
    }
  }

  void _initDefaultCategory() {
    final role = widget.employee.role.toLowerCase();
    if (role.contains('elec')) {
      _selectedCategory = 'electrical';
    } else if (role.contains('struc')) {
      _selectedCategory = 'structure';
    } else if (role.contains('civil')) {
      _selectedCategory = 'civil';
    } else if (role.contains('tech') || role.contains('serv')) {
      _selectedCategory = 'service';
    } else if (role.contains('sales')) {
      _selectedCategory = 'sales';
    } else if (role.contains('kedl')) {
      _selectedCategory = 'kedl';
    } else {
      _selectedCategory = 'general';
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final custs = await _client.getCustomers();
      if (mounted) {
        setState(() {
          _customers = custs;
          _isLoadingCustomers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _customCustomerController.dispose();
    super.dispose();
  }

  Future<void> _submitAssignment() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final custName = _selectedCustomerName?.trim().isNotEmpty == true
        ? _selectedCustomerName!
        : (_customCustomerController.text.trim().isNotEmpty
            ? _customCustomerController.text.trim()
            : 'Direct Assignment');

    setState(() => _isSubmitting = true);

    try {
      final startStr = _startDate.toIso8601String().split('T').first;
      final endStr = _endDate.toIso8601String().split('T').first;

      await _client.assignTaskToEmployee(
        employeeId: widget.employee.id,
        title: title,
        customerId: _selectedCustomerId,
        customerName: custName,
        location: _locationController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
        startDate: startStr,
        endDate: endStr,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onTaskAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task assigned to ${widget.employee.name} successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign task: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.employee.roleColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_task_rounded,
                  color: widget.employee.roleColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Task to Staff',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.employee.name} • ${widget.employee.employeeNo}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gold400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.grey400),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: AppColors.navy700, height: 24),

          // Form fields
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Title
                  Text(
                    'Task Title *',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: AppColors.fg, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Structure foundation layout & grouting',
                      hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                      prefixIcon: const Icon(Icons.task_alt_rounded, color: AppColors.gold500, size: 18),
                      filled: true,
                      fillColor: AppColors.navy800,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
                        borderSide: const BorderSide(color: AppColors.gold500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category selector
                  Text(
                    'Task Category / Discipline',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _categories.map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              cat.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel ? AppColors.shadow : AppColors.grey400,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: AppColors.gold500,
                            backgroundColor: AppColors.navy800,
                            side: BorderSide(
                              color: isSel ? AppColors.gold500 : AppColors.navy700,
                            ),
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Selector
                  Text(
                    'Client / Customer',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300),
                  ),
                  const SizedBox(height: 6),
                  if (_isLoadingCustomers)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold500),
                        ),
                      ),
                    )
                  else if (_customers.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.navy700),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCustomerId,
                          isExpanded: true,
                          dropdownColor: AppColors.navy800,
                          hint: const Text(
                            'Select Registered Customer',
                            style: TextStyle(color: AppColors.grey500, fontSize: 13),
                          ),
                          items: _customers.map((c) {
                            final cid = c['id']?.toString() ?? c['_id']?.toString() ?? '';
                            final name = c['name']?.toString() ?? 'Customer';
                            final kw = c['system_size_kw'] ?? c['kw'] ?? 5;
                            return DropdownMenuItem<String>(
                              value: cid,
                              child: Text(
                                '$name ($kw kW)',
                                style: const TextStyle(color: AppColors.fg, fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final match = _customers.firstWhere(
                                (c) => (c['id']?.toString() ?? c['_id']?.toString()) == val,
                                orElse: () => {},
                              );
                              setState(() {
                                _selectedCustomerId = val;
                                _selectedCustomerName = match['name']?.toString();
                                _locationController.text = match['address']?.toString() ??
                                    match['city']?.toString() ??
                                    '';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    TextField(
                      controller: _customCustomerController,
                      style: const TextStyle(color: AppColors.fg, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter Customer or Project Name',
                        hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.grey400, size: 18),
                        filled: true,
                        fillColor: AppColors.navy800,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.navy700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.navy700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Site Location
                  Text(
                    'Site Location / Address',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _locationController,
                    style: const TextStyle(color: AppColors.fg, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Plot 42, Industrial Area, Jaipur',
                      hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.grey400, size: 18),
                      filled: true,
                      fillColor: AppColors.navy800,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.navy700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.navy700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dates Row
                  Text(
                    'Schedule Timeline',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 7)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) {
                              setState(() {
                                _startDate = d;
                                if (_endDate.isBefore(_startDate)) {
                                  _endDate = _startDate.add(const Duration(days: 2));
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.navy800,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.navy700),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gold500),
                                const SizedBox(width: 8),
                                Text(
                                  _startDate.toIso8601String().split('T').first,
                                  style: const TextStyle(color: AppColors.fg, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) {
                              setState(() => _endDate = d);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.navy800,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.navy700),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available_rounded, size: 16, color: AppColors.teal500),
                                const SizedBox(width: 8),
                                Text(
                                  _endDate.toIso8601String().split('T').first,
                                  style: const TextStyle(color: AppColors.fg, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Priority
                  Text(
                    'Priority Level',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPriorityChip('normal', 'Normal', AppColors.teal500),
                      const SizedBox(width: 8),
                      _buildPriorityChip('high', 'High', Colors.orangeAccent),
                      const SizedBox(width: 8),
                      _buildPriorityChip('urgent', 'Urgent', AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notes / Instructions
                  Text(
                    'Scope & Technical Instructions (Optional)',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter specific checklist items or site safety guidelines...',
                      hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.navy800,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.navy700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.navy700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold500,
                foregroundColor: AppColors.ink900,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 2,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ink900,
                      ),
                    )
                  : const Text(
                      'Dispatch & Assign Task',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String val, String label, Color color) {
    final isSel = _selectedPriority == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? color.withValues(alpha: 0.2) : AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSel ? color : AppColors.navy700,
              width: isSel ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? color : AppColors.grey400,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
