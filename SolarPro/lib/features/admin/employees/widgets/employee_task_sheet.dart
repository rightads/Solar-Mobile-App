import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/admin/employees/models/admin_employee_model.dart';
import 'package:solar_pro/features/admin/employees/widgets/assign_task_dialog.dart';

class EmployeeTaskDetailSheet extends StatefulWidget {
  final AdminEmployee employee;
  final VoidCallback onTasksChanged;
  final ApiClient? apiClient;
  final List<EmployeeTask>? initialTasks;

  const EmployeeTaskDetailSheet({
    super.key,
    required this.employee,
    required this.onTasksChanged,
    this.apiClient,
    this.initialTasks,
  });

  static Future<void> show(
    BuildContext context, {
    required AdminEmployee employee,
    required VoidCallback onTasksChanged,
    ApiClient? apiClient,
    List<EmployeeTask>? initialTasks,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmployeeTaskDetailSheet(
        employee: employee,
        onTasksChanged: onTasksChanged,
        apiClient: apiClient,
        initialTasks: initialTasks,
      ),
    );
  }

  @override
  State<EmployeeTaskDetailSheet> createState() => _EmployeeTaskDetailSheetState();
}

class _EmployeeTaskDetailSheetState extends State<EmployeeTaskDetailSheet> {
  bool _isLoading = true;
  List<EmployeeTask> _tasks = [];
  String _filter = 'all'; // all, active, completed
  late ApiClient _client;

  @override
  void initState() {
    super.initState();
    _client = widget.apiClient ?? ApiClient();
    if (widget.initialTasks != null) {
      _tasks = List.from(widget.initialTasks!);
      _isLoading = false;
    } else {
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final rawList = await _client.getEmployeeTasks(widget.employee.id);
      if (mounted) {
        setState(() {
          _tasks = rawList.map((e) => EmployeeTask.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EmployeeTask> get _filteredTasks {
    if (_filter == 'active') {
      return _tasks.where((t) => t.status.toLowerCase() != 'completed' && t.status.toLowerCase() != 'resolved').toList();
    }
    if (_filter == 'completed') {
      return _tasks.where((t) => t.status.toLowerCase() == 'completed' || t.status.toLowerCase() == 'resolved').toList();
    }
    return _tasks;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _tasks.where((t) => t.status.toLowerCase() != 'completed' && t.status.toLowerCase() != 'resolved').length;
    final completedCount = _tasks.where((t) => t.status.toLowerCase() == 'completed' || t.status.toLowerCase() == 'resolved').length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
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
          const SizedBox(height: 14),

          // Employee Profile Header Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: widget.employee.roleColor.withValues(alpha: 0.2),
                  child: Text(
                    widget.employee.name.isNotEmpty
                        ? widget.employee.name.substring(0, 1).toUpperCase()
                        : 'E',
                    style: TextStyle(
                      color: widget.employee.roleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.name,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.fg,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.employee.roleColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: widget.employee.roleColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              widget.employee.roleDisplayName.toUpperCase(),
                              style: TextStyle(
                                color: widget.employee.roleColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.employee.employeeNo,
                            style: AppTextStyles.caption.copyWith(color: AppColors.gold400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.employee.team} • ${widget.employee.phone}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          ),
          const SizedBox(height: 16),

          // Primary Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Assign Task Button (Prominent)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AssignTaskDialog.show(
                        context,
                        employee: widget.employee,
                        onTaskAssigned: () {
                          _loadTasks();
                          widget.onTasksChanged();
                        },
                      );
                    },
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text(
                      'Assign New Task',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold500,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Refresh Button
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.navy800,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.navy700),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.grey300),
                    tooltip: 'Refresh tasks',
                    onPressed: _loadTasks,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterTab('all', 'All (${_tasks.length})'),
                const SizedBox(width: 8),
                _buildFilterTab('active', 'Active ($activeCount)'),
                const SizedBox(width: 8),
                _buildFilterTab('completed', 'Done ($completedCount)'),
              ],
            ),
          ),
          const Divider(color: AppColors.navy700, height: 20),

          // Tasks List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold500),
                  )
                : _filteredTasks.isEmpty
                    ? Center(
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
                                  Icons.assignment_turned_in_outlined,
                                  size: 40,
                                  color: AppColors.grey500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filter == 'all'
                                    ? 'No Tasks Assigned Yet'
                                    : _filter == 'active'
                                        ? 'No Active Tasks'
                                        : 'No Completed Tasks',
                                style: const TextStyle(
                                  color: AppColors.fg,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap "Assign New Task" above to allocate tasks to ${widget.employee.name}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.grey400,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        color: AppColors.gold500,
                        backgroundColor: AppColors.navy800,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: _filteredTasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final task = _filteredTasks[index];
                            return _TaskCard(task: task);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSel = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppColors.gold500.withValues(alpha: 0.15) : AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSel ? AppColors.gold500 : AppColors.navy700,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? AppColors.gold400 : AppColors.grey400,
            fontSize: 12,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final EmployeeTask task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: task.priority.toLowerCase() == 'urgent'
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.navy700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category Icon & Status Chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navy700,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(task.categoryIcon, size: 16, color: AppColors.gold500),
              ),
              const SizedBox(width: 8),
              Text(
                task.category.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.grey400,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              if (task.priority.toLowerCase() == 'urgent' || task.priority.toLowerCase() == 'high')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: TextStyle(
                      color: task.priorityColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: task.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  task.statusDisplayName,
                  style: TextStyle(
                    color: task.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            task.title,
            style: const TextStyle(
              color: AppColors.fg,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Customer & Location
          if (task.customerName.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.gold400),
                const SizedBox(width: 4),
                Text(
                  task.customerName,
                  style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (task.location.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '• ${task.location}',
                      style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Description / Scope
          if (task.description.isNotEmpty) ...[
            Text(
              task.description,
              style: const TextStyle(color: AppColors.grey400, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],

          // Footer: Timeline Dates
          if (task.startDate.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 13, color: AppColors.grey500),
                const SizedBox(width: 4),
                Text(
                  task.endDate.isNotEmpty && task.endDate != task.startDate
                      ? '${task.startDate} to ${task.endDate}'
                      : 'Scheduled: ${task.startDate}',
                  style: const TextStyle(color: AppColors.grey500, fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
