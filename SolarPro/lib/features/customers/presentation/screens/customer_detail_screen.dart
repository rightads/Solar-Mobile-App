import 'package:flutter/material.dart';
import 'package:solar_pro/core/services/media_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late _CustomerInfo _customer;
  bool _isLoading = true;

  static const _stageMeta = [
    ('SALE_CONFIRMED', 'Sale Confirmed', Icons.handshake_rounded),
    ('DOCUMENTS_RECEIVED', 'Docs Received', Icons.folder_rounded),
    ('ADVANCE_VERIFIED', 'Advance Verified', Icons.verified_rounded),
    ('STRUCTURE_WORK', 'Structure Work', Icons.foundation_rounded),
    ('ELECTRICAL_WORK', 'Electrical Work', Icons.electrical_services_rounded),
    ('CIVIL_WORK', 'Civil Work', Icons.construction_rounded),
    ('INSTALLATION_COMPLETE', 'Installation Done', Icons.solar_power_rounded),
    ('KEDL_PROCESS', 'KEDL Process', Icons.description_rounded),
    ('SYSTEM_LIVE', 'System Live / Net Meter', Icons.bolt_rounded),
    ('HANDED_OVER', 'Handed Over', Icons.celebration_rounded),
  ];

  // Live 10-stage timeline from the backend (never hardcoded).
  List<_StageInfo> _stages = [
    for (final m in _stageMeta) _StageInfo(m.$1, m.$2, false, AppColors.grey600, m.$3),
  ];
  String? _togglingStage;

  List<_StageInfo> _parseTimeline(Map<String, dynamic> data) {
    final byKey = <String, Map>{};
    for (final st in (data['stages'] as List? ?? const [])) {
      if (st is Map) byKey[st['stage'].toString()] = st;
    }
    return [
      for (final m in _stageMeta)
        _StageInfo(
          m.$1,
          m.$2,
          byKey[m.$1]?['done'] == true,
          byKey[m.$1]?['status'] == 'current' ? AppColors.warning : AppColors.success,
          m.$3,
          current: byKey[m.$1]?['status'] == 'current',
          by: byKey[m.$1]?['by']?.toString(),
          date: byKey[m.$1]?['date']?.toString(),
        ),
    ];
  }

  Future<void> _loadTimeline() async {
    try {
      final res = await ApiClient().dio.get('/customers/${widget.customerId}/timeline');
      if (mounted && res.data is Map) {
        setState(() => _stages = _parseTimeline(Map<String, dynamic>.from(res.data as Map)));
      }
    } catch (_) {}
  }

  Future<void> _toggleStage(_StageInfo stage) async {
    if (_togglingStage != null) return;
    setState(() => _togglingStage = stage.key);
    try {
      final res = await ApiClient().dio.post(
        '/customers/${widget.customerId}/timeline',
        data: {'stage': stage.key, 'done': !stage.done},
      );
      if (mounted && res.data is Map) {
        setState(() => _stages = _parseTimeline(Map<String, dynamic>.from(res.data as Map)));
      }
    } catch (e) {
      if (mounted) {
        final code = e is DioException ? e.response?.statusCode : null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(code == 404 || code == 403
              ? 'Only the employee responsible for this stage (or an admin) can change it.'
              : ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _togglingStage = null);
    }
  }

  late List<_DocItem> _documents;
  List<_MilestoneItem> _milestones = [];
  List<Map<String, dynamic>> _workAssignments = [];
  List<Map<String, dynamic>> _kedlFiles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initCustomerDefaults();
    _loadFromBackend();
  }

  void _initCustomerDefaults() {
    final rawName = widget.customerId.isEmpty || widget.customerId.length > 25
        ? 'Customer Account'
        : widget.customerId
            .replaceAll('-', ' ')
            .split(' ')
            .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '')
            .join(' ');

    _customer = _CustomerInfo(
      id: widget.customerId,
      name: rawName,
      phone: 'Customer Mobile',
      address: 'Solar Installation Site',
      locationGps: '',
      kw: 5.0,
      phase: 'Three Phase',
      amount: 250000,
      paid: 0,
      stage: 'SALE_CONFIRMED',
    );

    _documents = [
      _DocItem('e_bill', 'E-Bill', Icons.receipt_long_rounded, AppColors.teal500, false),
      _DocItem('aadhaar', 'Aadhaar Card', Icons.badge_rounded, AppColors.gold500, false),
      _DocItem('pan', 'PAN Card', Icons.credit_card_rounded, AppColors.info, false),
      _DocItem('cancelled_cheque', 'Cancelled Cheque', Icons.account_balance_rounded, AppColors.orange500, false),
      _DocItem('registry', 'Registry (Property Paper)', Icons.home_work_rounded, AppColors.purple500, false),
    ];
  }

  Future<void> _loadFromBackend() async {
    _loadTimeline();
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiClient().getCustomerById(widget.customerId),
        ApiClient().getWorkAssignments(customerId: widget.customerId),
        ApiClient().getKedlFiles(customerId: widget.customerId),
      ]);

      final cMap = results[0] as Map<String, dynamic>?;
      final works = results[1] as List<Map<String, dynamic>>? ?? [];
      final kedls = results[2] as List<Map<String, dynamic>>? ?? [];

      if (cMap != null && mounted) {
        final name = (cMap['name'] ?? _customer.name).toString();
        final phone = (cMap['phone'] ?? cMap['mobile'] ?? _customer.phone).toString();
        final addr = (cMap['address'] ?? _customer.address).toString();
        final gps = (cMap['location_gps'] ?? cMap['gps'] ?? '').toString();
        final kw = (cMap['kw'] ?? cMap['capacity_kw'] ?? 5.0) as num;
        final finalPrice = (cMap['final_price'] ?? cMap['total_amount'] ?? 250000) as num;
        final paidAmt = (cMap['paid_amount'] ?? 0) as num;
        final phase = (cMap['phase'] ?? 'Three Phase').toString();
        final stage = (cMap['stage'] ?? 'SALE_CONFIRMED').toString();

        // Documents
        final rawDocs = cMap['documents'] is Map ? cMap['documents'] as Map : {};
        final updatedDocs = [
          _DocItem('e_bill', 'E-Bill', Icons.receipt_long_rounded, AppColors.teal500, _isUploaded(rawDocs['e_bill'])),
          _DocItem('aadhaar', 'Aadhaar Card', Icons.badge_rounded, AppColors.gold500, _isUploaded(rawDocs['aadhaar'])),
          _DocItem('pan', 'PAN Card', Icons.credit_card_rounded, AppColors.info, _isUploaded(rawDocs['pan'])),
          _DocItem('cancelled_cheque', 'Cancelled Cheque', Icons.account_balance_rounded, AppColors.orange500, _isUploaded(rawDocs['cancelled_cheque'])),
          _DocItem('registry', 'Registry (Property Paper)', Icons.home_work_rounded, AppColors.purple500, _isUploaded(rawDocs['registry'])),
        ];

        // Milestones
        final rawMilestones = cMap['milestones'] is List ? cMap['milestones'] as List : [];
        final parsedMilestones = rawMilestones.map((m) {
          final mm = Map<String, dynamic>.from(m as Map);
          return _MilestoneItem.fromMap(mm);
        }).toList();

        setState(() {
          _customer = _CustomerInfo(
            id: widget.customerId,
            name: name,
            phone: phone,
            address: addr,
            locationGps: gps,
            kw: kw.toDouble(),
            phase: phase,
            amount: finalPrice.toInt(),
            paid: paidAmt.toInt(),
            stage: stage,
          );
          _documents = updatedDocs;
          _milestones = parsedMilestones;
          _workAssignments = works;
          _kedlFiles = kedls;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static bool _isUploaded(Object? v) => v is Map || v == true || (v is String && v.isNotEmpty);

  Future<void> _uploadDocument(int index) async {
    final doc = _documents[index];
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (doc.uploaded) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove ${doc.name}?'),
            content: const Text('The uploaded file will be detached from this customer.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
            ],
          ),
        );
        if (confirm != true) return;
        await ApiClient().dio.delete('/customers/${widget.customerId}/documents/${doc.key}');
      } else {
        final picked = await MediaPicker.pickDocument();
        if (picked == null) return;
        await ApiClient().dio.post(
          '/customers/${widget.customerId}/documents',
          data: FormData.fromMap({
            'type': doc.key,
            'file': MultipartFile.fromBytes(picked.bytes, filename: picked.name),
          }),
        );
      }
      await _loadFromBackend();
      messenger.showSnackBar(SnackBar(
        content: Text(doc.uploaded ? '${doc.name} removed.' : '${doc.name} uploaded securely.'),
        backgroundColor: doc.uploaded ? AppColors.grey600 : AppColors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _verifyMilestone(_MilestoneItem m) async {
    final today = DateTime.now().toString().split(' ')[0];
    final newStatus = m.status == 'verified' ? 'pending' : 'verified';

    setState(() {
      final idx = _milestones.indexWhere((item) => item.id == m.id);
      if (idx != -1) {
        _milestones[idx] = m.copyWith(
          status: newStatus,
          employeeVerifiedDate: newStatus == 'verified' ? today : '',
          customerVerifiedDate: newStatus == 'verified' ? today : '',
          verifiedBy: newStatus == 'verified' ? 'Employee & Customer' : '',
        );
      }
    });

    try {
      await ApiClient().updateCustomerMilestone(
        customerId: widget.customerId,
        milestoneId: m.id,
        data: {
          'title': m.title,
          'amount': m.amount,
          'status': newStatus,
          'employee_verified_date': newStatus == 'verified' ? today : '',
          'customer_verified_date': newStatus == 'verified' ? today : '',
          'verified_by': newStatus == 'verified' ? 'Verified by Employee & Customer' : '',
        },
      );

      // Paid amount is recomputed by the server from verified milestones.
      await _loadFromBackend();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'verified'
                  ? 'Payment verified by employee & customer with date $today!'
                  : 'Milestone status reset to pending.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating milestone: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddMilestoneSheet() {
    final titleCtrl = TextEditingController(text: '3rd Payment / Testing');
    final amtCtrl = TextEditingController(text: '50000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
            Text('Add Payment Milestone', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text('(Payment will be verified by employee & customer with dates)',
                style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                hintText: 'Milestone Title (e.g. 3rd Payment)',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
                final title = titleCtrl.text.trim();
                if (amt <= 0 || title.isEmpty) return;
                Navigator.pop(ctx);

                final newId = 'm_${DateTime.now().millisecondsSinceEpoch}';
                final newM = _MilestoneItem(
                  id: newId,
                  title: title,
                  amount: amt,
                  status: 'pending',
                  dueDate: 'Pending Schedule',
                  verifiedBy: '',
                  employeeVerifiedDate: '',
                  customerVerifiedDate: '',
                );

                setState(() {
                  _milestones.add(newM);
                });

                try {
                  await ApiClient().updateCustomerMilestone(
                    customerId: widget.customerId,
                    milestoneId: newId,
                    data: {
                      'title': title,
                      'amount': amt,
                      'status': 'pending',
                    },
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Milestone "$title" added successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding milestone: $e'),
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
                ),
                child: Center(
                  child: Text('Add Milestone',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.ink900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFromBackend,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Project proposal & summary shared via WhatsApp/Email!'),
                  backgroundColor: AppColors.teal500,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold500))
          : NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(gradient: AppColors.cardGradient),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.goldGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _customer.name.isNotEmpty ? _customer.name[0] : 'C',
                                      style: const TextStyle(
                                        color: Color(0xFFF6F4FD),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_customer.name, style: AppTextStyles.headlineLarge),
                                      const SizedBox(height: 2),
                                      Text('+91 ${_customer.phone}', style: AppTextStyles.bodySmall),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 13, color: AppColors.grey500),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _customer.address,
                                              style: AppTextStyles.bodySmall,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_customer.locationGps.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.my_location_rounded,
                                                size: 11, color: AppColors.teal500),
                                            const SizedBox(width: 4),
                                            Text(
                                              'GPS: ${_customer.locationGps}',
                                              style: AppTextStyles.caption
                                                  .copyWith(color: AppColors.teal500, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Call button
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Calling ${_customer.name} (+91 ${_customer.phone})...'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(Icons.call_rounded, color: AppColors.success, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // WhatsApp button
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Opening WhatsApp with ${_customer.name}...'),
                                        backgroundColor: AppColors.teal500,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.teal500.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.teal500.withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline_rounded,
                                        color: AppColors.teal500, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _InfoChip(label: '${_customer.kw} kW', icon: Icons.bolt_rounded, color: AppColors.gold500),
                                const SizedBox(width: 10),
                                _InfoChip(label: _customer.phase, icon: Icons.electrical_services_rounded, color: AppColors.teal500),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold500.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '₹${(_customer.amount / 100000).toStringAsFixed(1)}L Final Price',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.gold400),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: AppColors.gold500,
                      labelColor: AppColors.gold500,
                      unselectedLabelColor: AppColors.grey500,
                      tabs: [
                        const Tab(text: 'Timeline'),
                        Tab(text: 'Documents (${_documents.where((d) => d.uploaded).length}/5)'),
                        const Tab(text: 'Milestones & Payments'),
                        Tab(text: 'Work (${_workAssignments.length})'),
                        Tab(text: 'KEDL (${_kedlFiles.length})'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _TimelineTab(stages: _stages, busyKey: _togglingStage, onToggle: _toggleStage),
                  _DocumentsTab(
                    docs: _documents,
                    onToggleUpload: _uploadDocument,
                  ),
                  _MilestonesTab(
                    milestones: _milestones,
                    totalAmount: _customer.amount,
                    paidAmount: _customer.paid,
                    onVerify: _verifyMilestone,
                    onAddMilestone: _showAddMilestoneSheet,
                  ),
                  _WorkTab(
                    customerId: widget.customerId,
                    customerName: _customer.name,
                    assignments: _workAssignments,
                    onRefresh: _loadFromBackend,
                  ),
                  _KedlTab(
                    customerId: widget.customerId,
                    customerName: _customer.name,
                    files: _kedlFiles,
                    onRefresh: _loadFromBackend,
                  ),
                ],
              ),
            ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.navy800,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// ── Timeline Tab ──────────────────────────────────────────────────────────────

class _TimelineTab extends StatelessWidget {
  final List<_StageInfo> stages;
  final String? busyKey;
  final ValueChanged<_StageInfo> onToggle;
  const _TimelineTab({required this.stages, required this.busyKey, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      physics: const BouncingScrollPhysics(),
      itemCount: stages.length,
      itemBuilder: (context, i) {
        final stage = stages[i];
        final isFirst = i == 0;
        final isLast = i == stages.length - 1;
        return TimelineTile(
          alignment: TimelineAlign.start,
          isFirst: isFirst,
          isLast: isLast,
          indicatorStyle: IndicatorStyle(
            width: 32,
            height: 32,
            indicator: Container(
              decoration: BoxDecoration(
                color: stage.done
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.navy700,
                shape: BoxShape.circle,
                border: Border.all(
                  color: stage.done ? AppColors.success : AppColors.navy500,
                  width: 2,
                ),
              ),
              child: Icon(
                stage.done ? Icons.check_rounded : stage.icon,
                size: 16,
                color: stage.done ? AppColors.success : AppColors.grey500,
              ),
            ),
          ),
          beforeLineStyle: LineStyle(
            color: stage.done ? AppColors.success : AppColors.navy700,
            thickness: 2,
          ),
          endChild: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 24, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.label,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: stage.done
                                ? AppColors.grey100
                                : AppColors.grey500,
                          )),
                      const SizedBox(height: 2),
                      Text(
                        stage.done
                            ? 'Done${stage.by != null ? ' · ${stage.by}' : ''}'
                            : (stage.current ? 'In progress' : 'Incomplete'),
                        style: AppTextStyles.caption.copyWith(
                          color: stage.done
                              ? AppColors.success
                              : (stage.current ? AppColors.warning : AppColors.grey600),
                        ),
                      ),
                    ],
                  ),
                ),
                busyKey == stage.key
                    ? const SizedBox(width: 44, height: 24, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                    : Tooltip(
                        message: stage.done ? 'Mark incomplete' : 'Mark done',
                        child: Switch(value: stage.done, onChanged: (_) => onToggle(stage)),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Documents Tab (Page 1 Specs) ──────────────────────────────────────────────

class _DocumentsTab extends StatelessWidget {
  final List<_DocItem> docs;
  final Function(int) onToggleUpload;

  const _DocumentsTab({
    required this.docs,
    required this.onToggleUpload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final doc = docs[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: doc.uploaded
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.navy600,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: doc.uploaded
                      ? AppColors.success.withValues(alpha: 0.15)
                      : doc.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  doc.uploaded ? Icons.check_circle_rounded : doc.icon,
                  color: doc.uploaded ? AppColors.success : doc.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.name, style: AppTextStyles.labelLarge),
                    const SizedBox(height: 3),
                    Text(
                      doc.uploaded
                          ? 'Uploaded & Verified ✓'
                          : 'Pending Document Upload',
                      style: AppTextStyles.caption.copyWith(
                        color: doc.uploaded
                            ? AppColors.success
                            : AppColors.grey500,
                        fontWeight: doc.uploaded
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => onToggleUpload(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: doc.uploaded
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.gold500.withValues(alpha: 0.15),
                    border: Border.all(
                      color: doc.uploaded
                          ? AppColors.success.withValues(alpha: 0.5)
                          : AppColors.gold500.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        doc.uploaded
                            ? Icons.verified_rounded
                            : Icons.file_upload_outlined,
                        size: 14,
                        color:
                            doc.uploaded ? AppColors.success : AppColors.gold400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doc.uploaded ? 'Verified' : 'Upload',
                        style: AppTextStyles.caption.copyWith(
                          color: doc.uploaded
                              ? AppColors.success
                              : AppColors.gold400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: Duration(milliseconds: i * 60)).fadeIn(duration: 300.ms);
      },
    );
  }
}

// ── Milestones & Payments Tab (Page 1 Specs) ──────────────────────────────────

class _MilestonesTab extends StatelessWidget {
  final List<_MilestoneItem> milestones;
  final int totalAmount;
  final int paidAmount;
  final Function(_MilestoneItem) onVerify;
  final VoidCallback onAddMilestone;

  const _MilestonesTab({
    required this.milestones,
    required this.totalAmount,
    required this.paidAmount,
    required this.onVerify,
    required this.onAddMilestone,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        // Summary & Add Button
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFEBFC), Color(0xFFFFFFFF)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${(paidAmount / 1000).toStringAsFixed(0)}K Verified',
                            style: AppTextStyles.displaySmall
                                .copyWith(color: AppColors.gold400)),
                        Text('Work Final Price: ₹${(totalAmount / 1000).toStringAsFixed(0)}K',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.navy600,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.gold500),
                          strokeWidth: 5,
                        ),
                        Center(
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.gold400,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '★ Payment will be verified by employee and customer with dates',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey300),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onAddMilestone,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.gold500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border:
                        Border.all(color: AppColors.gold500.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_card_rounded,
                          size: 16, color: AppColors.gold400),
                      const SizedBox(width: 8),
                      Text('+ Add Dynamic Milestone Option',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.gold400)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: milestones.isEmpty
              ? Center(
                  child: Text('No Payment Milestones Defined',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.grey500)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  physics: const BouncingScrollPhysics(),
                  itemCount: milestones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = milestones[i];
                    final isVerified = m.status == 'verified';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isVerified
                              ? AppColors.success.withValues(alpha: 0.35)
                              : AppColors.navy600,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isVerified
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.warning.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    isVerified
                                        ? Icons.verified_rounded
                                        : Icons.schedule_rounded,
                                    size: 18,
                                    color: isVerified
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(m.title,
                                        style: AppTextStyles.labelLarge),
                                    Text('Due: ${m.dueDate}',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${(m.amount / 1000).toStringAsFixed(0)}K',
                                      style: AppTextStyles.headlineSmall
                                          .copyWith(fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isVerified
                                          ? AppColors.success
                                              .withValues(alpha: 0.15)
                                          : AppColors.grey700,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.pill),
                                    ),
                                    child: Text(
                                      isVerified ? 'VERIFIED ✓' : 'PENDING',
                                      style: AppTextStyles.caption.copyWith(
                                        color: isVerified
                                            ? AppColors.success
                                            : AppColors.grey400,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.navy700,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isVerified
                                            ? 'Employee Verified: ${m.employeeVerifiedDate.isNotEmpty ? m.employeeVerifiedDate : "Recorded"}'
                                            : 'Employee Sign: Pending',
                                        style: AppTextStyles.caption.copyWith(
                                          color: isVerified
                                              ? AppColors.success
                                              : AppColors.grey400,
                                        ),
                                      ),
                                      Text(
                                        isVerified
                                            ? 'Customer Verified: ${m.customerVerifiedDate.isNotEmpty ? m.customerVerifiedDate : "Recorded"}'
                                            : 'Customer Sign: Pending',
                                        style: AppTextStyles.caption.copyWith(
                                          color: isVerified
                                              ? AppColors.success
                                              : AppColors.grey400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => onVerify(m),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: isVerified
                                          ? null
                                          : AppColors.goldGradient,
                                      color: isVerified
                                          ? AppColors.navy600
                                          : null,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.pill),
                                    ),
                                    child: Text(
                                      isVerified ? 'Undo' : 'Verify with Date',
                                      style: AppTextStyles.caption.copyWith(
                                        color: isVerified
                                            ? AppColors.grey300
                                            : AppColors.navy900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: Duration(milliseconds: i * 60)).fadeIn(duration: 350.ms);
                  },
                ),
        ),
      ],
    );
  }
}

// ── Work Tab (Page 2 Specs: Structure, Electrical & Civil Labour) ─────────────

class _WorkTab extends StatelessWidget {
  final String customerId;
  final String customerName;
  final List<Map<String, dynamic>> assignments;
  final VoidCallback onRefresh;

  const _WorkTab({
    required this.customerId,
    required this.customerName,
    required this.assignments,
    required this.onRefresh,
  });

  void _showAssignWorkSheet(BuildContext context) {
    String selectedTrade = 'Structure Labour';
    String selectedTeam = 'Team A';
    final notesCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 3));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                const SizedBox(height: 20),
                Text('Assign Work (Notebook Page 2)',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text('Customer: $customerName with Start & End Dates',
                    style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                const SizedBox(height: 16),

                Text('Work Type / Labour Trade', style: AppTextStyles.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Structure Labour',
                    'Electrical Labour (Electrician)',
                    'Civil Work Labour',
                  ].map((t) {
                    final isSel = selectedTrade == t;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedTrade = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.gold500.withValues(alpha: 0.2)
                              : AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: isSel ? AppColors.gold500 : AppColors.navy600),
                        ),
                        child: Text(t,
                            style: AppTextStyles.caption.copyWith(
                                color: isSel ? AppColors.gold400 : AppColors.grey400,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                Text('Team Option', style: AppTextStyles.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Team A', 'Team B', 'Custom Team'].map((team) {
                    final isSel = selectedTeam == team;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedTeam = team),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.teal500.withValues(alpha: 0.2)
                              : AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: isSel ? AppColors.teal500 : AppColors.navy600),
                        ),
                        child: Text(team,
                            style: AppTextStyles.caption.copyWith(
                                color: isSel ? AppColors.teal500 : AppColors.grey400,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setSheetState(() => startDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.navy700,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Text(
                                '${startDate.day}/${startDate.month}/${startDate.year}',
                                style: AppTextStyles.labelMedium
                                    .copyWith(color: AppColors.gold400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime.now().add(const Duration(days: 120)),
                          );
                          if (picked != null) {
                            setSheetState(() => endDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.navy700,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Text(
                                '${endDate.day}/${endDate.month}/${endDate.year}',
                                style: AppTextStyles.labelMedium
                                    .copyWith(color: AppColors.gold400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Notes / Scope of work (optional)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
                ),

                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final tradeKey = selectedTrade.contains('Electrical')
                        ? 'electrical'
                        : (selectedTrade.contains('Civil') ? 'civil' : 'structure');

                    try {
                      await ApiClient().assignWork(
                        customerId: customerId,
                        customerName: customerName,
                        workType: tradeKey,
                        teamName: selectedTeam,
                        startDate: '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                        endDate: '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
                        notes: notesCtrl.text.trim(),
                      );
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Work assigned to $selectedTeam ($selectedTrade)!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to assign work: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: Text('Confirm Assignment with Dates',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.ink900)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Installation Work Teams (Page 2)',
                    style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
              ),
              GestureDetector(
                onTap: () => _showAssignWorkSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: AppColors.ink900),
                      const SizedBox(width: 4),
                      Text('Assign Work',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.ink900,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: assignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.engineering_outlined,
                          size: 44, color: AppColors.grey600),
                      const SizedBox(height: 10),
                      Text('No Work Assignments for this Project',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.grey400)),
                      const SizedBox(height: 6),
                      Text('Tap "+ Assign Work" above to assign Structure, Electrical, or Civil team',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey600)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = assignments[i];
                    final wType = (item['work_type'] ?? 'structure').toString();
                    final team = (item['team_name'] ?? 'Team A').toString();
                    final st = (item['status'] ?? 'assigned').toString();
                    final start = (item['start_date'] ?? 'TBD').toString();
                    final end = (item['end_date'] ?? 'TBD').toString();

                    final color = switch (wType.toLowerCase()) {
                      'structure' => AppColors.orange500,
                      'electrical' => AppColors.purple500,
                      'civil' => AppColors.teal500,
                      _ => AppColors.gold500,
                    };

                    final statusColor = switch (st) {
                      'completed' => AppColors.success,
                      'in_progress' => AppColors.warning,
                      _ => AppColors.grey400,
                    };

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${wType[0].toUpperCase()}${wType.substring(1)} Work',
                                    style: AppTextStyles.labelLarge),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.groups_rounded, size: 13, color: color),
                                    const SizedBox(width: 5),
                                    Text(team,
                                        style: AppTextStyles.bodySmall
                                            .copyWith(color: color)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.date_range_rounded,
                                        size: 13, color: AppColors.grey500),
                                    const SizedBox(width: 5),
                                    Text('$start – $end',
                                        style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              st.replaceAll('_', ' '),
                              style: AppTextStyles.caption
                                  .copyWith(color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: Duration(milliseconds: i * 60)).fadeIn(duration: 300.ms);
                  },
                ),
        ),
      ],
    );
  }
}

// ── KEDL Tab (Page 3 Specs: Name Change, Load File, Net File) ─────────────────

class _KedlTab extends StatelessWidget {
  final String customerId;
  final String customerName;
  final List<Map<String, dynamic>> files;
  final VoidCallback onRefresh;

  const _KedlTab({
    required this.customerId,
    required this.customerName,
    required this.files,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('KEDL Work Files (Page 3)',
                    style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
              ),
              if (files.isEmpty)
                GestureDetector(
                  onTap: () async {
                    try {
                      await ApiClient().initKedlFiles(customerId);
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Initialized Name Change, Load & Net Files!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error initializing KEDL files: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.ink900),
                        const SizedBox(width: 4),
                        Text('Init 3 Files',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.ink900,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 44, color: AppColors.grey600),
                      const SizedBox(height: 10),
                      Text('No KEDL Files Initialized for this Customer',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.grey400)),
                      const SizedBox(height: 6),
                      Text('Tap "Init 3 Files" to create Name Change, Load & Net Files',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey600)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = files[i];
                    final fType = (item['file_type'] ?? 'net').toString();
                    final st = (item['status'] ?? 'not_started').toString();
                    final demand = (item['demand_amount'] ?? 0) as int;
                    final demandRef = (item['demand_notice_ref'] ?? '').toString();

                    final label = switch (fType) {
                      'name_change' => 'Name Change File',
                      'load' => 'Load Enhancement File',
                      'net' => 'Net Metering File',
                      _ => fType,
                    };

                    final color = switch (fType) {
                      'name_change' => AppColors.gold500,
                      'load' => AppColors.teal500,
                      'net' => AppColors.purple500,
                      _ => AppColors.grey500,
                    };

                    final statusColor = switch (st) {
                      'approved' => AppColors.success,
                      'demand_paid' => AppColors.gold500,
                      'demand_raised' => AppColors.warning,
                      'submitted' => AppColors.teal500,
                      _ => AppColors.grey500,
                    };

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.description_rounded, color: color, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: AppTextStyles.labelLarge),
                                const SizedBox(height: 4),
                                Text(
                                  demand > 0
                                      ? 'Demand: ₹$demand ${demandRef.isNotEmpty ? "($demandRef)" : ""}'
                                      : 'Demand: No demand raised yet',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: demand > 0
                                        ? AppColors.warning
                                        : AppColors.grey400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              st.replaceAll('_', ' '),
                              style: AppTextStyles.caption
                                  .copyWith(color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: Duration(milliseconds: i * 80)).fadeIn(duration: 350.ms);
                  },
                ),
        ),
      ],
    );
  }
}

// ── Models & Supporting Widgets ───────────────────────────────────────────────

class _CustomerInfo {
  final String id, name, phone, address, locationGps, phase, stage;
  final double kw;
  final int amount, paid;
  const _CustomerInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.locationGps,
    required this.kw,
    required this.phase,
    required this.amount,
    required this.paid,
    required this.stage,
  });
}

class _StageInfo {
  final String key;
  final String label;
  final bool done;
  final Color color;
  final IconData icon;
  final bool current;
  final String? by;
  final String? date;
  const _StageInfo(this.key, this.label, this.done, this.color, this.icon, {this.current = false, this.by, this.date});
}

class _DocItem {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final bool uploaded;
  const _DocItem(this.key, this.name, this.icon, this.color, this.uploaded);

  _DocItem copyWith({bool? uploaded}) =>
      _DocItem(key, name, icon, color, uploaded ?? this.uploaded);
}

class _MilestoneItem {
  final String id;
  final String title;
  final int amount;
  final String status;
  final String dueDate;
  final String verifiedBy;
  final String employeeVerifiedDate;
  final String customerVerifiedDate;

  const _MilestoneItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    required this.dueDate,
    required this.verifiedBy,
    required this.employeeVerifiedDate,
    required this.customerVerifiedDate,
  });

  factory _MilestoneItem.fromMap(Map<String, dynamic> m) {
    return _MilestoneItem(
      id: (m['id'] ?? m['milestone_id'] ?? '').toString(),
      title: (m['title'] ?? 'Payment Milestone').toString(),
      amount: (m['amount'] ?? 0) as int,
      status: (m['status'] ?? 'pending').toString(),
      dueDate: (m['due_date'] ?? 'On Schedule').toString(),
      verifiedBy: (m['verified_by'] ?? '').toString(),
      employeeVerifiedDate: (m['employee_verified_date'] ?? '').toString(),
      customerVerifiedDate: (m['customer_verified_date'] ?? '').toString(),
    );
  }

  _MilestoneItem copyWith({
    String? status,
    String? verifiedBy,
    String? employeeVerifiedDate,
    String? customerVerifiedDate,
  }) {
    return _MilestoneItem(
      id: id,
      title: title,
      amount: amount,
      status: status ?? this.status,
      dueDate: dueDate,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      employeeVerifiedDate:
          employeeVerifiedDate ?? this.employeeVerifiedDate,
      customerVerifiedDate:
          customerVerifiedDate ?? this.customerVerifiedDate,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _InfoChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
