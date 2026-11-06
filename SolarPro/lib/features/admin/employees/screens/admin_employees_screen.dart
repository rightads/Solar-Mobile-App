import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/admin/employees/models/admin_employee_model.dart';
import 'package:solar_pro/features/admin/employees/widgets/employee_task_sheet.dart';

class AdminEmployeesScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final List<AdminEmployee>? initialEmployees;

  const AdminEmployeesScreen({
    super.key,
    this.apiClient,
    this.initialEmployees,
  });

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<AdminEmployee> _employees = [];
  List<Map<String, dynamic>> _pendingApprovals = [];
  final Map<String, bool> _processingApprovals = {};
  String _selectedTrade = 'all';
  late ApiClient _client;

  List<(String, String)> get _tradeFilters => [
    ('all', 'All Staff'),
    if (_pendingApprovals.isNotEmpty)
      ('pending', 'Pending Approval (${_pendingApprovals.length})'),
    ('sales', 'Sales'),
    ('service', 'Service & Maintenance'),
    ('structure', 'Structure'),
    ('electrical', 'Electrical'),
    ('civil', 'Civil'),
    ('kedl', 'KEDL Liaison'),
  ];

  @override
  void initState() {
    super.initState();
    _client = widget.apiClient ?? ApiClient();
    if (widget.initialEmployees != null) {
      _employees = List.from(widget.initialEmployees!);
      _isLoading = false;
      _loadPendingApprovals();
    } else {
      _loadEmployees();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingApprovals() async {
    try {
      final pending = await _client.getPendingApprovals(status: 'pending');
      if (mounted) {
        setState(() => _pendingApprovals = pending);
      }
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final rawList = await _client.getEmployees(
        trade: _selectedTrade == 'all' || _selectedTrade == 'pending' ? null : _selectedTrade,
      );
      List<Map<String, dynamic>> pending = [];
      try {
        pending = await _client.getPendingApprovals(status: 'pending');
      } catch (_) {}

      if (mounted) {
        setState(() {
          _employees = rawList.map((e) => AdminEmployee.fromJson(e)).toList();
          _pendingApprovals = pending;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleQuickApprove(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name'] ?? 'User';
    if (userId.isEmpty) return;

    setState(() => _processingApprovals[userId] = true);
    try {
      await _client.approveRegistration(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$userName accepted! Official employee record created.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.navy700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadEmployees();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approval failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingApprovals.remove(userId));
    }
  }

  Future<void> _handleQuickReject(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name'] ?? 'User';
    if (userId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Application?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to decline registration request for $userName?',
          style: const TextStyle(color: AppColors.grey300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingApprovals[userId] = true);
    try {
      await _client.rejectRegistration(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName\'s registration was declined.'),
            backgroundColor: AppColors.navy700,
          ),
        );
        _loadEmployees();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejection failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingApprovals.remove(userId));
    }
  }

  List<Map<String, dynamic>> get _filteredPendingApprovals {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _pendingApprovals;
    return _pendingApprovals.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final phone = (p['phone'] ?? '').toString();
      final email = (p['email'] ?? '').toString().toLowerCase();
      final role = (p['role'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query) || email.contains(query) || role.contains(query);
    }).toList();
  }

  List<AdminEmployee> get _filteredEmployees {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _employees;
    return _employees.where((e) {
      return e.name.toLowerCase().contains(query) ||
          e.employeeNo.toLowerCase().contains(query) ||
          e.phone.contains(query) ||
          e.role.toLowerCase().contains(query) ||
          e.team.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalStaff = _employees.length;
    final totalTasks = _employees.fold(0, (acc, e) => acc + e.taskCount);
    final displayedList = _filteredEmployees;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff & Employees Directory',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '$totalStaff employee${totalStaff == 1 ? '' : 's'} registered in database',
              style: const TextStyle(fontSize: 11, color: AppColors.gold400),
            ),
          ],
        ),
        actions: [
          if (_pendingApprovals.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.how_to_reg_rounded, color: AppColors.orange400),
                  tooltip: '${_pendingApprovals.length} Pending Approval(s)',
                  onPressed: () async {
                    await context.push(AppRoutes.adminApprovals);
                    _loadEmployees();
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.orange500,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${_pendingApprovals.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh staff list',
            onPressed: _loadEmployees,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top KPI Summary Cards Row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.navy800,
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Staff',
                    value: '$totalStaff',
                    icon: Icons.groups_rounded,
                    color: AppColors.gold500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Active On Duty',
                    value: '${_employees.where((e) => e.isActive).length}',
                    icon: Icons.verified_user_rounded,
                    color: AppColors.teal500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Allocated Tasks',
                    value: '$totalTasks',
                    icon: Icons.assignment_turned_in_rounded,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),

          // Pending Approvals Alert Banner
          if (_pendingApprovals.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.orange500.withValues(alpha: 0.18),
                    AppColors.navy800,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.orange500.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.orange500.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_rounded, color: AppColors.orange400, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_pendingApprovals.length} Employee Registration${_pendingApprovals.length > 1 ? "s" : ""} Pending',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Staff cannot access tasks until approved by Admin.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() => _selectedTrade = 'pending');
                    },
                    child: const Text('Review Now'),
                  ),
                ],
              ),
            ),

          // Search and Filters Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.navy800,
              border: Border(bottom: BorderSide(color: AppColors.navy700)),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by employee name, ID, phone, role...',
                    hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.grey400, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.navy900,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
                ),
                const SizedBox(height: 10),

                // Horizontal Discipline Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _tradeFilters.map((tf) {
                      final isSel = _selectedTrade == tf.$1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            tf.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? Colors.black : AppColors.grey400,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: AppColors.gold500,
                          backgroundColor: AppColors.navy900,
                          side: BorderSide(
                            color: isSel ? AppColors.gold500 : AppColors.navy700,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedTrade = tf.$1);
                            _loadEmployees();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Main Employees Column / List View
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold500),
                  )
                : _selectedTrade == 'pending'
                    ? _buildPendingApprovalsView()
                    : _buildEmployeesListView(displayedList),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsView() {
    final pendingList = _filteredPendingApprovals;
    if (pendingList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy700),
                ),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  size: 44,
                  color: AppColors.green400,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Pending Registration Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'All employee registration applications have been reviewed and processed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.grey400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmployees,
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: pendingList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = pendingList[index];
          final userId = user['id']?.toString() ?? '';
          final isProcessing = _processingApprovals[userId] == true;
          return _PendingApprovalCard(
            user: user,
            isProcessing: isProcessing,
            onApprove: () => _handleQuickApprove(user),
            onReject: () => _handleQuickReject(user),
          );
        },
      ),
    );
  }

  Widget _buildEmployeesListView(List<AdminEmployee> displayedList) {
    if (displayedList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy700),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  size: 44,
                  color: AppColors.grey500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Employees Found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No staff member matched "${_searchController.text}".'
                    : 'No employees found under this trade filter.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.grey400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmployees,
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: displayedList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final emp = displayedList[index];
          return _EmployeeListCard(
            employee: emp,
            onTap: () {
              EmployeeTaskDetailSheet.show(
                context,
                employee: emp,
                onTasksChanged: _loadEmployees,
              );
            },
          );
        },
      ),
    );
  }
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.navy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.grey400,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeListCard extends StatelessWidget {
  final AdminEmployee employee;
  final VoidCallback onTap;

  const _EmployeeListCard({
    required this.employee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.navy700),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: employee.roleColor.withValues(alpha: 0.15),
                child: Text(
                  employee.name.isNotEmpty
                      ? employee.name.substring(0, 1).toUpperCase()
                      : 'E',
                  style: TextStyle(
                    color: employee.roleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            employee.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.navy700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            employee.employeeNo,
                            style: const TextStyle(
                              color: AppColors.gold400,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(employee.roleIcon, size: 12, color: employee.roleColor),
                        const SizedBox(width: 4),
                        Text(
                          employee.roleDisplayName,
                          style: TextStyle(
                            color: employee.roleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• ${employee.team}',
                            style: const TextStyle(
                              color: AppColors.grey400,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.phone,
                      style: const TextStyle(color: AppColors.grey500, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Task Count Badge & Action Hint
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: employee.taskCount > 0
                          ? AppColors.gold500.withValues(alpha: 0.15)
                          : AppColors.navy700,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: employee.taskCount > 0
                            ? AppColors.gold500.withValues(alpha: 0.4)
                            : AppColors.navy600,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 11,
                          color: employee.taskCount > 0 ? AppColors.gold400 : AppColors.grey400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          employee.taskCount > 0 ? '${employee.taskCount} Tasks' : 'No tasks',
                          style: TextStyle(
                            color: employee.taskCount > 0 ? AppColors.gold400 : AppColors.grey400,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Tasks',
                        style: TextStyle(color: AppColors.grey400, fontSize: 10),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.grey400),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingApprovalCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingApprovalCard({
    required this.user,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'Applicant';
    final role = (user['role']?.toString() ?? 'employee').toUpperCase();
    final phone = user['phone']?.toString() ?? 'N/A';
    final email = user['email']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.orange500.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.orange500.withValues(alpha: 0.15),
                child: const Icon(Icons.person_add_rounded, color: AppColors.orange400, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.orange500.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.orange500.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: AppColors.orange400,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PENDING APPROVAL',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.navy700, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone_rounded, color: AppColors.grey400, size: 14),
              const SizedBox(width: 6),
              Text(
                phone,
                style: const TextStyle(color: AppColors.grey300, fontSize: 12),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(Icons.email_outlined, color: AppColors.grey400, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(color: AppColors.grey300, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isProcessing ? null : onReject,
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isProcessing ? null : onApprove,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    isProcessing ? 'Activating...' : 'Accept & Approve',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
