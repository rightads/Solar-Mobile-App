import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/site_work/presentation/screens/site_job_detail_screen.dart';
import 'package:solar_pro/features/employee/site_work/presentation/widgets/job_card.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';
import 'package:solar_pro/features/work_assignment/data/repositories/work_assignment_repository.dart';
import 'package:solar_pro/features/work_assignment/data/services/site_offline_queue_service.dart';

class SiteHomeTab extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final WorkAssignmentRepository? repository;

  const SiteHomeTab({
    super.key,
    this.onNavigateTab,
    this.repository,
  });

  @override
  State<SiteHomeTab> createState() => _SiteHomeTabState();
}

class _SiteHomeTabState extends State<SiteHomeTab> {
  late WorkAssignmentRepository _repo;
  final SiteOfflineQueueService _offlineQueue = SiteOfflineQueueService();

  WorkType _workerDiscipline = WorkType.electrical;
  String _workerName = 'Site Specialist';
  bool _isLoading = true;
  List<WorkAssignmentModel> _jobs = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? WorkAssignmentRepository();
    _initWorkerInfoAndLoad();
    _offlineQueue.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    _offlineQueue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initWorkerInfoAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(AppConstants.kUserRole)?.toLowerCase() ?? '';
    final name = prefs.getString(AppConstants.kUserName);
    final teamType = prefs.getString('user_team_type')?.toLowerCase();

    WorkType discipline = WorkType.electrical;
    if (role == 'structure' || teamType == 'structure') {
      discipline = WorkType.structure;
    } else if (role == 'civil' || teamType == 'civil') {
      discipline = WorkType.civil;
    } else if (role == 'electrician' || role == 'electrical' || teamType == 'electrical') {
      discipline = WorkType.electrical;
    }

    setState(() {
      _workerDiscipline = discipline;
      if (name != null && name.isNotEmpty) _workerName = name;
    });

    await _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.listWorkAssignments(workType: _workerDiscipline);
      if (mounted) {
        setState(() {
          _jobs = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSyncNow() async {
    final synced = await _repo.syncPendingQueue();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$synced pending offline action(s) synced to cloud successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final todayJobs = _jobs.where((j) {
      final s = DateTime(j.scheduledStart.year, j.scheduledStart.month, j.scheduledStart.day);
      final e = DateTime(j.scheduledEnd.year, j.scheduledEnd.month, j.scheduledEnd.day);
      return (s.isBefore(todayStart.add(const Duration(days: 1))) &&
          e.isAfter(todayStart.subtract(const Duration(days: 1))));
    }).toList();

    final inProgressCount = _jobs.where((j) => j.status == WorkStatus.inProgress).length;
    final completedCount = _jobs.where((j) => j.status == WorkStatus.completed).length;
    final pendingSyncCount = _offlineQueue.pendingCount;

    return RefreshIndicator(
      onRefresh: _loadJobs,
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy800,
                    _workerDiscipline.color.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: _workerDiscipline.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _workerDiscipline.color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_workerDiscipline.icon, color: _workerDiscipline.color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $_workerName',
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _workerDiscipline.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                '${_workerDiscipline.displayName} Team',
                                style: TextStyle(
                                  color: _workerDiscipline.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Site Operations',
                              style: TextStyle(color: AppColors.grey400, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pending Offline Sync Banner
            if (pendingSyncCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem_rounded, color: AppColors.warning, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$pendingSyncCount Offline Action(s) Pending',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Status changes or photos recorded locally.',
                            style: TextStyle(color: AppColors.grey300, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _offlineQueue.isSyncing ? null : _handleSyncNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.shadow,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      child: _offlineQueue.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.shadow),
                            )
                          : const Text('Sync Now'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Metrics Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: "Today's Jobs",
                    value: '${todayJobs.length}',
                    color: AppColors.gold500,
                    icon: Icons.today_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: 'In Progress',
                    value: '$inProgressCount',
                    color: AppColors.teal500,
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Completed',
                    value: '$completedCount',
                    color: AppColors.success,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Today's Priority Assignments Header
            Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.gold500, size: 20),
                const SizedBox(width: 6),
                const Text(
                  "Today's Priority Jobs",
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (widget.onNavigateTab != null)
                  TextButton(
                    onPressed: () => widget.onNavigateTab!(1), // Go to My Jobs
                    child: const Text(
                      'View All',
                      style: TextStyle(color: AppColors.gold500, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.gold500),
                ),
              )
            else if (todayJobs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.assignment_turned_in_outlined, color: AppColors.grey500, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'No site jobs scheduled for today',
                      style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Check the Upcoming tab or Calendar for future assignments.',
                      style: TextStyle(color: AppColors.grey400, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...todayJobs.map(
                (job) => SiteJobCard(
                  job: job,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SiteJobDetailScreen(
                          initialJob: job,
                          repository: _repo,
                        ),
                      ),
                    );
                    _loadJobs();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.navy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
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
