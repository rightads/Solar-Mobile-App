import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/site_work/presentation/screens/site_job_detail_screen.dart';
import 'package:solar_pro/features/employee/site_work/presentation/widgets/job_card.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';
import 'package:solar_pro/features/work_assignment/data/repositories/work_assignment_repository.dart';

class SiteMyJobsTab extends StatefulWidget {
  final WorkAssignmentRepository? repository;

  const SiteMyJobsTab({
    super.key,
    this.repository,
  });

  @override
  State<SiteMyJobsTab> createState() => _SiteMyJobsTabState();
}

class _SiteMyJobsTabState extends State<SiteMyJobsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late WorkAssignmentRepository _repo;

  WorkType _workerDiscipline = WorkType.electrical;
  bool _isLoading = true;
  String _searchQuery = '';
  List<WorkAssignmentModel> _allJobs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = widget.repository ?? WorkAssignmentRepository();
    _initWorkerDiscipline();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initWorkerDiscipline() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(AppConstants.kUserRole)?.toLowerCase() ?? '';
    final teamType = prefs.getString('user_team_type')?.toLowerCase();

    WorkType discipline = WorkType.electrical;
    if (role == 'structure' || teamType == 'structure') {
      discipline = WorkType.structure;
    } else if (role == 'civil' || teamType == 'civil') {
      discipline = WorkType.civil;
    } else if (role == 'electrician' || role == 'electrical' || teamType == 'electrical') {
      discipline = WorkType.electrical;
    }

    setState(() => _workerDiscipline = discipline);
    await _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      // Strict role isolation: list only own discipline jobs
      final list = await _repo.listWorkAssignments(workType: _workerDiscipline);
      if (mounted) {
        setState(() {
          _allJobs = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkAssignmentModel> _filterJobs(List<WorkAssignmentModel> list) {
    if (_searchQuery.trim().isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((j) {
      final name = j.customer?.name.toLowerCase() ?? '';
      final address = j.customer?.address.toLowerCase() ?? '';
      final notes = j.notes?.toLowerCase() ?? '';
      return name.contains(query) || address.contains(query) || notes.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Today: scheduled includes today and not completed
    final todayList = _filterJobs(
      _allJobs.where((j) {
        if (j.status == WorkStatus.completed) return false;
        final s = DateTime(j.scheduledStart.year, j.scheduledStart.month, j.scheduledStart.day);
        final e = DateTime(j.scheduledEnd.year, j.scheduledEnd.month, j.scheduledEnd.day);
        return (s.isBefore(todayStart.add(const Duration(days: 1))) &&
            e.isAfter(todayStart.subtract(const Duration(days: 1))));
      }).toList(),
    );

    // Upcoming: scheduled in future (> today) and not completed
    final upcomingList = _filterJobs(
      _allJobs.where((j) {
        if (j.status == WorkStatus.completed) return false;
        final s = DateTime(j.scheduledStart.year, j.scheduledStart.month, j.scheduledStart.day);
        return s.isAfter(todayStart);
      }).toList(),
    );

    // Completed: status == completed
    final completedList = _filterJobs(
      _allJobs.where((j) => j.status == WorkStatus.completed).toList(),
    );

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with discipline badge & tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'My Work Jobs',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _workerDiscipline.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: _workerDiscipline.color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_workerDiscipline.icon, size: 14, color: _workerDiscipline.color),
                        const SizedBox(width: 4),
                        Text(
                          _workerDiscipline.displayName,
                          style: TextStyle(
                            color: _workerDiscipline.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppColors.fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search customer name or site location...',
                  hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.grey400, size: 20),
                  filled: true,
                  fillColor: AppColors.navy800,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.navy700),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.navy700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.gold500,
                indicatorWeight: 3,
                labelColor: AppColors.gold500,
                unselectedLabelColor: AppColors.grey400,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(text: 'Today (${todayList.length})'),
                  Tab(text: 'Upcoming (${upcomingList.length})'),
                  Tab(text: 'Completed (${completedList.length})'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildJobsList(todayList, 'No jobs scheduled for today.'),
                        _buildJobsList(upcomingList, 'No upcoming site jobs found.'),
                        _buildJobsList(completedList, 'No completed jobs yet.'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList(List<WorkAssignmentModel> list, String emptyMessage) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadJobs,
        color: AppColors.gold500,
        backgroundColor: AppColors.navy800,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.assignment_outlined, size: 48, color: AppColors.grey500),
                const SizedBox(height: 12),
                Text(
                  emptyMessage,
                  style: const TextStyle(color: AppColors.grey400, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJobs,
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final job = list[index];
          return SiteJobCard(
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
          );
        },
      ),
    );
  }
}
