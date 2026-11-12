import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/site_work/presentation/screens/site_job_detail_screen.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';
import 'package:solar_pro/features/work_assignment/data/repositories/work_assignment_repository.dart';

class SiteCalendarTab extends StatefulWidget {
  final WorkAssignmentRepository? repository;

  const SiteCalendarTab({
    super.key,
    this.repository,
  });

  @override
  State<SiteCalendarTab> createState() => _SiteCalendarTabState();
}

class _SiteCalendarTabState extends State<SiteCalendarTab> {
  late WorkAssignmentRepository _repo;
  WorkType _workerDiscipline = WorkType.electrical;
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = true;
  CalendarScheduleModel? _schedule;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? WorkAssignmentRepository();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
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
    await _loadCalendarSchedule();
  }

  Future<void> _loadCalendarSchedule() async {
    setState(() => _isLoading = true);
    final fromDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final toDate = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    try {
      final schedule = await _repo.getCalendarSchedule(
        fromDate,
        toDate,
        workType: _workerDiscipline,
      );
      if (mounted) {
        setState(() {
          _schedule = schedule;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
      _selectedDate = _currentMonth;
    });
    _loadCalendarSchedule();
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy');
    final selectedDateKey = _selectedDate.toIso8601String().split('T').first;
    final dayItems = _schedule?.byDate[selectedDateKey] ?? [];

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SafeArea(
        child: Column(
          children: [
            // Calendar Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Work Calendar',
                    style: TextStyle(color: AppColors.fg, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _workerDiscipline.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: _workerDiscipline.color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _workerDiscipline.displayName,
                      style: TextStyle(
                        color: _workerDiscipline.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Month navigation bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.navy700),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.gold500),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    monthFormat.format(_currentMonth),
                    style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.gold500),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Horizontal date strip for the month
            _buildDaysStrip(),
            const SizedBox(height: 12),

            // Daily Agenda Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.event_note_rounded, color: AppColors.gold500, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.navy700,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${dayItems.length} jobs',
                      style: const TextStyle(color: AppColors.grey300, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Day's Assignments List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
                  : dayItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.event_available_rounded, size: 48, color: AppColors.grey500),
                              SizedBox(height: 10),
                              Text(
                                'No assignments scheduled for this day',
                                style: TextStyle(color: AppColors.grey400, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: dayItems.length,
                          itemBuilder: (context, index) {
                            final item = dayItems[index];
                            return _buildScheduleItemCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysStrip() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final today = DateTime.now();

    return SizedBox(
      height: 75,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: daysInMonth,
        itemBuilder: (context, index) {
          final day = index + 1;
          final date = DateTime(_currentMonth.year, _currentMonth.month, day);
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
          final dateKey = date.toIso8601String().split('T').first;
          final hasJobs = (_schedule?.byDate[dateKey]?.isNotEmpty ?? false);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold500
                    : (isToday ? AppColors.navy700 : AppColors.navy800),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold500
                      : (isToday ? AppColors.gold500.withValues(alpha: 0.5) : AppColors.navy700),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? AppColors.navy900 : AppColors.grey400,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? AppColors.navy900 : AppColors.fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasJobs
                          ? (isSelected ? AppColors.navy900 : _workerDiscipline.color)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleItemCard(CalendarScheduleItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.navy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.workType.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  item.workType.displayName.toUpperCase(),
                  style: TextStyle(
                    color: item.workType.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  item.status.displayName.toUpperCase(),
                  style: TextStyle(
                    color: item.status.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.customerName,
            style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.grey400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.customerAddress,
                  style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final job = await _repo.getWorkAssignmentById(item.assignmentId);
                  if (!mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SiteJobDetailScreen(
                        initialJob: job,
                        repository: _repo,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  _loadCalendarSchedule();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error opening job: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View Job Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold500,
                side: const BorderSide(color: AppColors.gold500),
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
