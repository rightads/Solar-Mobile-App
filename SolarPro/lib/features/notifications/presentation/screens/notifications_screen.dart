import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/notifications/data/models/notification_model.dart';
import 'package:solar_pro/features/notifications/data/repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationRepository? repository;

  const NotificationsScreen({
    super.key,
    this.repository,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationRepository _repo;
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? NotificationRepository();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(AppConstants.kUserRole)?.toLowerCase() ?? '';
    final list = await _repo.listNotifications();

    if (mounted) {
      setState(() {
        _userRole = role;
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _repo.markAllAsRead();
    if (mounted) {
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: AppColors.teal500,
        ),
      );
    }
  }

  Future<void> _onNotificationTap(NotificationModel n) async {
    if (!n.isRead) {
      await _repo.markAsRead(n.id);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((item) => item.id == n.id);
          if (idx != -1) {
            _notifications[idx] = n.copyWith(isRead: true);
          }
        });
      }
    }

    final targetRoute = NotificationRepository.resolveDeepLinkForRole(_userRole, n);
    if (mounted) {
      context.push(targetRoute);
    }
  }

  IconData _getIconForType(String type, {String? title}) {
    final t = type.toLowerCase();
    final ttl = (title ?? '').toLowerCase();
    if (t == 'user_approval' || t == 'approval' || ttl.contains('registration') || ttl.contains('applicant')) {
      return Icons.how_to_reg_rounded;
    }
    switch (t) {
      case 'lead':
        return Icons.person_add_alt_1_rounded;
      case 'job':
        return Icons.engineering_rounded;
      case 'kedl_file':
      case 'kedl_demand':
        return Icons.receipt_long_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'ticket':
        return Icons.confirmation_number_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type, {String? title}) {
    final t = type.toLowerCase();
    final ttl = (title ?? '').toLowerCase();
    if (t == 'user_approval' || t == 'approval' || ttl.contains('registration') || ttl.contains('applicant')) {
      return AppColors.orange500;
    }
    switch (t) {
      case 'lead':
        return AppColors.gold500;
      case 'job':
        return AppColors.teal500;
      case 'kedl_file':
      case 'kedl_demand':
        return Colors.purpleAccent;
      case 'payment':
        return AppColors.success;
      case 'ticket':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('dd MMM').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy800,
        elevation: 0,
        title: Text(
          'Notifications ${unreadCount > 0 ? "($unreadCount unread)" : ""}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold400),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.grey600),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.gold500,
                  backgroundColor: AppColors.navy800,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final color = _getColorForType(n.type, title: n.title);
                      final icon = _getIconForType(n.type, title: n.title);
                      final timeStr = _formatTime(n.createdAt);

                      return GestureDetector(
                        onTap: () => _onNotificationTap(n),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: n.isRead ? AppColors.navy800 : AppColors.navy700,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: n.isRead ? AppColors.navy600 : color.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: AppTextStyles.labelLarge.copyWith(
                                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (!n.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.body,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        height: 1.4,
                                        color: n.isRead ? AppColors.grey400 : AppColors.fg,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          timeStr,
                                          style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Tap to view →',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.gold400,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(delay: Duration(milliseconds: i * 40))
                          .fadeIn(duration: 300.ms)
                          .slideX(begin: 0.05, end: 0);
                    },
                  ),
                ),
    );
  }
}
