import 'package:flutter/material.dart';
import 'package:solar_pro/core/constants/project_stages.dart';
import 'package:solar_pro/core/constants/staff_departments.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:solar_pro/features/employee/common/employee_empty_placeholder.dart';

/// Subsidy and Account / Bill employees: the projects assigned to them (plus
/// unassigned ones waiting on their stage). Opening a project shows its
/// timeline, where they mark their own stage Done with a remark.
class DeskProjectsTab extends StatefulWidget {
  final String role;
  const DeskProjectsTab({super.key, required this.role});

  @override
  State<DeskProjectsTab> createState() => _DeskProjectsTabState();
}

class _DeskProjectsTabState extends State<DeskProjectsTab> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  bool _showDone = false;

  String get _department => departmentOf(widget.role) ?? widget.role;

  ProjectStage? get _myStage {
    for (final s in kProjectStages) {
      if (s.department == _department) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await ApiClient().getCustomers();
    if (mounted) {
      setState(() {
        _projects = items;
        _loading = false;
      });
    }
  }

  bool _isWaitingOnMe(Map<String, dynamic> c) => (c['stage'] ?? '').toString() == _myStage?.key;

  bool _isPastMe(Map<String, dynamic> c) {
    final mine = projectStageIndex(_myStage?.key);
    return mine > 0 && projectStageIndex(c['stage']?.toString()) > mine;
  }

  @override
  Widget build(BuildContext context) {
    final stage = _myStage;
    final waiting = _projects.where(_isWaitingOnMe).toList();
    final done = _projects.where(_isPastMe).toList();
    final upcoming = _projects.where((c) => !_isWaitingOnMe(c) && !_isPastMe(c)).toList();
    final shown = _showDone ? done : [...waiting, ...upcoming];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(stage?.label ?? 'My Projects', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${waiting.length} waiting on you · ${upcoming.length} upcoming · ${done.length} done',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Open'), icon: Icon(Icons.pending_actions_rounded)),
              ButtonSegment(value: true, label: Text('Done'), icon: Icon(Icons.task_alt_rounded)),
            ],
            selected: {_showDone},
            onSelectionChanged: (v) => setState(() => _showDone = v.first),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else if (shown.isEmpty)
            SizedBox(
              height: 320,
              child: EmployeeEmptyPlaceholder(
                title: _showDone ? 'Nothing finished yet' : 'No projects for you right now',
                description: _showDone
                    ? 'Projects you complete will appear here.'
                    : 'Projects appear here when an admin or salesman assigns you, '
                        'or when one reaches the ${stage?.label ?? 'your'} stage.',
                icon: Icons.inbox_rounded,
              ),
            )
          else
            for (final c in shown) _ProjectCard(project: c, waitingOnMe: _isWaitingOnMe(c), onOpen: () => _open(c)),
        ],
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> c) async {
    final id = (c['id'] ?? c['_id'] ?? '').toString();
    if (id.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: id)));
    if (mounted) _load();
  }
}

class _ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final bool waitingOnMe;
  final VoidCallback onOpen;
  const _ProjectCard({required this.project, required this.waitingOnMe, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final stage = project['stage']?.toString();
    final color = projectStageColor(stage);
    final kw = project['capacity_kw'] ?? project['kw'];
    return Card(
      color: AppColors.navy800,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: waitingOnMe ? AppColors.gold500 : AppColors.navy600),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(projectStage(stage)?.icon ?? Icons.solar_power_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project['name']?.toString() ?? 'Customer', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (kw != null) '$kw kW',
                        if ((project['address'] ?? '').toString().isNotEmpty) project['address'].toString(),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      waitingOnMe ? 'Waiting on you' : projectStageLabel(stage),
                      style: AppTextStyles.caption.copyWith(
                        color: waitingOnMe ? AppColors.gold500 : color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
            ],
          ),
        ),
      ),
    );
  }
}
