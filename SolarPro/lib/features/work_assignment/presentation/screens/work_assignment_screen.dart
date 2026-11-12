import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class WorkAssignmentScreen extends StatefulWidget {
  const WorkAssignmentScreen({super.key});

  @override
  State<WorkAssignmentScreen> createState() => _WorkAssignmentScreenState();
}

class _WorkAssignmentScreenState extends State<WorkAssignmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_WorkJob> _structureJobs = [];
  final List<_WorkJob> _electricalJobs = [];
  final List<_WorkJob> _civilJobs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onJobStatusChange(_WorkJob job, String type, String newStatus) {
    setState(() {
      final list = switch (type) {
        'Structure' => _structureJobs,
        'Electrical' => _electricalJobs,
        _ => _civilJobs,
      };
      final idx = list.indexWhere((it) => it.id == job.id);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(status: newStatus);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Job for ${job.customer} updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}'),
        backgroundColor: newStatus == 'completed' ? AppColors.success : AppColors.warning,
      ),
    );
  }

  void _showJobDetailSheet(BuildContext context, _WorkJob job, String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.grey600,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.customer, style: AppTextStyles.headlineSmall),
                      Text('$type Work • ${job.location}',
                          style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (job.status == 'completed'
                            ? AppColors.success
                            : AppColors.warning)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    job.status.replaceAll('_', ' ').toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                        color: job.status == 'completed'
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navy700,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded,
                          size: 16, color: AppColors.gold500),
                      const SizedBox(width: 8),
                      Text('Assigned: ', style: AppTextStyles.caption),
                      Text(job.team, style: AppTextStyles.labelMedium),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.navy600),
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded,
                          size: 16, color: AppColors.teal500),
                      const SizedBox(width: 8),
                      Text('Schedule: ', style: AppTextStyles.caption),
                      Text('${job.start} to ${job.end}',
                          style: AppTextStyles.labelMedium),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling Team Lead for ${job.team}...'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_rounded,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 6),
                          Text('Call Team Lead',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _onJobStatusChange(job, type, 'completed');
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: Text('Mark Done ✓',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.ink900)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignSheet(BuildContext context) async {
    String selectedType = 'Structure';
    String selectedTeam = 'Team A';
    final customTeamCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 3));
    final locCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    // Fetch live customers for selection
    List<Map<String, dynamic>> customers = [];
    try {
      customers = await ApiClient().getCustomers();
    } catch (_) {}

    String selectedCustId = customers.isNotEmpty
        ? (customers.first['id']?.toString() ?? customers.first['_id']?.toString() ?? '')
        : '';
    String selectedCustName =
        customers.isNotEmpty ? (customers.first['name']?.toString() ?? '') : '';
    if (customers.isNotEmpty && locCtrl.text.isEmpty) {
      locCtrl.text = customers.first['address']?.toString() ?? 'Site Location';
    }

    final customCustCtrl = TextEditingController(text: selectedCustName);
    bool isSaving = false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final teamOptions = selectedType == 'Structure'
              ? ['Team A (Structure)', 'Team B (Structure)', 'Custom Team']
              : selectedType == 'Electrical'
                  ? ['Team A (Electrician)', 'Team B (Wireman)', 'Custom Team']
                  : ['Team A (Civil)', 'Team B (Foundation)', 'Custom Team'];

          if (!teamOptions.contains(selectedTeam)) {
            selectedTeam = teamOptions.first;
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.grey600,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Work Assign (Notebook Page 2)',
                          style: AppTextStyles.headlineSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orange500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('Teams & Dates',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.orange400)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Work Type Tabs
                  Text('Work Trade (Labour & Electrician):',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Structure', 'Electrical', 'Civil'].map((t) {
                      final colors = {
                        'Structure': AppColors.orange500,
                        'Electrical': AppColors.purple500,
                        'Civil': AppColors.teal500
                      };
                      final isSel = selectedType == t;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedType = t;
                              selectedTeam = t == 'Structure'
                                  ? 'Team A (Structure)'
                                  : t == 'Electrical'
                                      ? 'Team A (Electrician)'
                                      : 'Team A (Civil)';
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? colors[t]!.withValues(alpha: 0.25)
                                  : AppColors.navy700,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                  color: isSel ? colors[t]! : AppColors.navy600,
                                  width: isSel ? 1.5 : 1),
                            ),
                            child: Center(
                              child: Text(
                                t == 'Structure'
                                    ? '★ Structure'
                                    : t == 'Electrical'
                                        ? '★ Electrical'
                                        : '★ Civil Work',
                                style: AppTextStyles.caption.copyWith(
                                    color: isSel ? colors[t] : AppColors.grey400,
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Customer selection
                  Text('Select Customer (with dates):',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 8),
                  if (customers.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.navy700,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.navy600),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCustId.isNotEmpty ? selectedCustId : null,
                          isExpanded: true,
                          dropdownColor: AppColors.navy800,
                          hint: Text('Select Customer', style: AppTextStyles.bodyMedium),
                          items: customers.map((c) {
                            final cid = c['id']?.toString() ?? c['_id']?.toString() ?? '';
                            final cname = c['name']?.toString() ?? 'Unnamed';
                            final ckw = c['kw'] ?? 5;
                            return DropdownMenuItem<String>(
                              value: cid,
                              child: Text('$cname ($ckw kW)',
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: AppColors.fg)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedCustId = val;
                                final match = customers.firstWhere((c) =>
                                    (c['id']?.toString() ?? c['_id']?.toString()) == val);
                                selectedCustName = match['name']?.toString() ?? '';
                                customCustCtrl.text = selectedCustName;
                                locCtrl.text = match['address']?.toString() ?? '';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    TextField(
                      controller: customCustCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Customer Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Site Location / Area',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                  ),

                  const SizedBox(height: 16),

                  // Team selector (Page 2: Team A, Team B, + many opt)
                  Text('Assign Team (Team A, Team B, + many opt):',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: teamOptions.map((tm) {
                      final isSel = selectedTeam == tm;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedTeam = tm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.gold500.withValues(alpha: 0.2)
                                : AppColors.navy700,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: isSel ? AppColors.gold500 : AppColors.navy600),
                          ),
                          child: Text(
                            tm,
                            style: AppTextStyles.caption.copyWith(
                              color: isSel ? AppColors.gold400 : AppColors.grey300,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedTeam == 'Custom Team') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customTeamCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Enter Custom Team Name (e.g. Team C)',
                        prefixIcon: Icon(Icons.group_add_rounded),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Dates Pickers (Page 2: and customer with dates)
                  Text('Schedule Dates (Start & End):',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                                if (endDate.isBefore(startDate)) {
                                  endDate = startDate.add(const Duration(days: 2));
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.navy700,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.navy600),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: AppColors.gold400),
                                const SizedBox(width: 8),
                                Text(
                                  startDate.toIso8601String().split('T').first,
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: AppColors.fg),
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
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => endDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.navy700,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.navy600),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available_rounded,
                                    size: 16, color: AppColors.teal400),
                                const SizedBox(width: 8),
                                Text(
                                  endDate.toIso8601String().split('T').first,
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: AppColors.fg),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Scope / Technical Instructions (Optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                  ),

                  const SizedBox(height: 24),

                  // Submit button
                  GestureDetector(
                    onTap: isSaving
                        ? null
                        : () async {
                            final custName = selectedCustName.isNotEmpty
                                ? selectedCustName
                                : customCustCtrl.text.trim();
                            final loc = locCtrl.text.trim();
                            final team = selectedTeam == 'Custom Team'
                                ? customTeamCtrl.text.trim()
                                : selectedTeam;

                            if (custName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select or enter customer name'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);
                            final startStr =
                                startDate.toIso8601String().split('T').first;
                            final endStr =
                                endDate.toIso8601String().split('T').first;

                            try {
                              await ApiClient().assignWork(
                                customerId: selectedCustId,
                                customerName: custName,
                                workType: selectedType.toLowerCase(),
                                teamName: team.isEmpty ? 'Team A' : team,
                                startDate: startStr,
                                endDate: endStr,
                                location: loc.isEmpty ? 'Site' : loc,
                                notes: notesCtrl.text.trim(),
                              );

                              final newJob = _WorkJob(
                                DateTime.now().millisecondsSinceEpoch.toString(),
                                custName,
                                team.isEmpty ? 'Team A' : team,
                                'assigned',
                                startStr,
                                endStr,
                                loc.isEmpty ? 'Site' : loc,
                              );

                              setState(() {
                                if (selectedType == 'Structure') {
                                  _structureJobs.insert(0, newJob);
                                  _tabController.index = 0;
                                } else if (selectedType == 'Electrical') {
                                  _electricalJobs.insert(0, newJob);
                                  _tabController.index = 1;
                                } else {
                                  _civilJobs.insert(0, newJob);
                                  _tabController.index = 2;
                                }
                              });

                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '★ $selectedType work assigned to $team for $custName ($startStr to $endStr)!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to assign work: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold500.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.navy900),
                              )
                            : Text(
                                'Confirm & Dispatch Work Team',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.ink900),
                              ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Work Assignment'),
        actions: [
          IconButton(
            tooltip: 'Assign Work',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFFF6F4FD), size: 18),
            ),
            onPressed: () => _showAssignSheet(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold500,
          labelColor: AppColors.gold500,
          unselectedLabelColor: AppColors.grey500,
          tabs: [
            Tab(text: 'Structure (${_structureJobs.length})'),
            Tab(text: 'Electrical (${_electricalJobs.length})'),
            Tab(text: 'Civil (${_civilJobs.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WorkList(
            type: 'Structure',
            color: AppColors.orange500,
            jobs: _structureJobs,
            onJobTap: (j) => _showJobDetailSheet(context, j, 'Structure'),
          ),
          _WorkList(
            type: 'Electrical',
            color: AppColors.purple500,
            jobs: _electricalJobs,
            onJobTap: (j) => _showJobDetailSheet(context, j, 'Electrical'),
          ),
          _WorkList(
            type: 'Civil',
            color: AppColors.teal500,
            jobs: _civilJobs,
            onJobTap: (j) => _showJobDetailSheet(context, j, 'Civil'),
          ),
        ],
      ),
    );
  }
}

class _WorkList extends StatelessWidget {
  final String type;
  final Color color;
  final List<_WorkJob> jobs;
  final ValueChanged<_WorkJob> onJobTap;

  const _WorkList({
    required this.type,
    required this.color,
    required this.jobs,
    required this.onJobTap,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(
        child: Text('No $type assignments',
            style:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final job = jobs[i];
        final statusColor = switch (job.status) {
          'completed' => AppColors.success,
          'in_progress' => AppColors.warning,
          'pending' => AppColors.grey500,
          _ => AppColors.grey500,
        };
        return GestureDetector(
          onTap: () => onJobTap(job),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(job.customer, style: AppTextStyles.labelLarge),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        job.status.replaceAll('_', ' '),
                        style:
                            AppTextStyles.caption.copyWith(color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 14, color: color),
                    const SizedBox(width: 5),
                    Text(job.team,
                        style: AppTextStyles.bodySmall.copyWith(color: color)),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.grey500),
                    const SizedBox(width: 5),
                    Text(job.location, style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.date_range_rounded,
                        size: 14, color: AppColors.grey500),
                    const SizedBox(width: 5),
                    Text('${job.start} – ${job.end}',
                        style: AppTextStyles.bodySmall),
                    const Spacer(),
                    Text('Tap to manage →',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.gold400, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: i * 80))
            .fadeIn(duration: 380.ms)
            .slideX(begin: 0.05, end: 0);
      },
    );
  }
}

class _WorkJob {
  final String id, customer, team, status, start, end, location;
  const _WorkJob(this.id, this.customer, this.team, this.status, this.start, this.end, this.location);

  _WorkJob copyWith({String? status}) {
    return _WorkJob(
      id,
      customer,
      team,
      status ?? this.status,
      start,
      end,
      location,
    );
  }
}
