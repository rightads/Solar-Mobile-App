import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _approvals = [];
  String _selectedFilter = 'pending'; // 'pending', 'approved', 'all'
  final Map<String, bool> _processingUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchApprovals();
  }

  Future<void> _fetchApprovals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiClient().getPendingApprovals(status: _selectedFilter);
      if (mounted) {
        setState(() {
          _approvals = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) return;

    setState(() => _processingUserIds[userId] = true);

    try {
      await ApiClient().approveRegistration(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${user['name'] ?? 'User'} approved! Account is now active.',
                    style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.navy700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _fetchApprovals();
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
      if (mounted) {
        setState(() => _processingUserIds.remove(userId));
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject Registration?', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to reject registration access for ${user['name'] ?? 'this applicant'}?',
          style: const TextStyle(color: AppColors.grey300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.fg,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingUserIds[userId] = true);

    try {
      await ApiClient().rejectRegistration(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user['name'] ?? 'Applicant'} registration rejected.'),
            backgroundColor: AppColors.navy700,
          ),
        );
        _fetchApprovals();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingUserIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F4FD),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.orange500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.orange500.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppColors.orange500, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Super Admin Authorization',
                  style: TextStyle(color: AppColors.fg, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Review Employee & Admin Sign-up Requests',
                  style: TextStyle(color: AppColors.grey400, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.grey400),
            onPressed: _fetchApprovals,
            tooltip: 'Refresh list',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F4FD),
              border: Border(bottom: BorderSide(color: AppColors.fg.withValues(alpha: 0.06))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
              children: [
                _buildFilterChip('pending', 'Pending Review', Icons.pending_actions_rounded, AppColors.orange500),
                const SizedBox(width: 8),
                _buildFilterChip('approved', 'Approved', Icons.check_circle_outline_rounded, AppColors.green400),
                const SizedBox(width: 8),
                _buildFilterChip('all', 'All Records', Icons.list_alt_rounded, AppColors.grey400),
              ],
            ),
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _approvals.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            color: AppColors.gold500,
                            backgroundColor: AppColors.navy800,
                            onRefresh: _fetchApprovals,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _approvals.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final user = _approvals[index];
                                return _buildApprovalCard(user)
                                    .animate()
                                    .fadeIn(duration: 200.ms, delay: (index * 40).ms)
                                    .slideY(begin: 0.1, end: 0);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, Color activeColor) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        if (_selectedFilter != key) {
          setState(() => _selectedFilter = key);
          _fetchApprovals();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : AppColors.navy800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.navy600,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? activeColor : AppColors.grey400),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.fg : AppColors.grey400,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> user) {
    final userId = user['id']?.toString() ?? '';
    final role = (user['requested_role'] ?? user['role'] ?? 'employee').toString().toUpperCase();
    final status = (user['approval_status'] ?? 'pending').toString().toLowerCase();
    final isProcessing = _processingUserIds[userId] == true;

    final isEmployee = role == 'EMPLOYEE' || role == 'VENDOR';
    final roleColor = isEmployee ? AppColors.teal400 : AppColors.orange400;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy800.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'pending'
              ? AppColors.orange500.withValues(alpha: 0.35)
              : AppColors.fg.withValues(alpha: 0.08),
          width: status == 'pending' ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Avatar + Name + Role Badge
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                child: Icon(
                  isEmployee ? Icons.badge_rounded : Icons.admin_panel_settings_rounded,
                  color: roleColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? 'Unnamed Applicant',
                      style: const TextStyle(
                        color: AppColors.fg,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.fg12, height: 1),
          const SizedBox(height: 12),

          // Contact Details
          Row(
            children: [
              const Icon(Icons.phone_rounded, color: AppColors.grey400, size: 15),
              const SizedBox(width: 8),
              Text(
                '+91 ${user['phone'] ?? 'N/A'}',
                style: const TextStyle(color: AppColors.fg70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.email_outlined, color: AppColors.grey400, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user['email'] ?? 'No email provided',
                  style: const TextStyle(color: AppColors.fg70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Action Buttons (Only for Pending)
          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green500,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink900),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      isProcessing ? 'Approving...' : 'Approve Access',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: isProcessing ? null : () => _handleApprove(user),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: isProcessing ? null : () => _handleReject(user),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = AppColors.green400;
        label = 'APPROVED';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'REJECTED';
        break;
      default:
        color = AppColors.orange400;
        label = 'PENDING APPROVAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navy800,
                border: Border.all(color: AppColors.fg.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.fact_check_outlined, size: 48, color: AppColors.gold400),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Pending Registrations',
              style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'All employee and admin applications have been processed.\nNew sign-ups requiring authorization will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey400, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Failed to load approvals.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.fg, fontSize: 14),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _fetchApprovals,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy700),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
