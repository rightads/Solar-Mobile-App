import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class DesktopHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAddLead;
  final VoidCallback? onRecordPayment;

  const DesktopHeader({
    super.key,
    required this.title,
    this.subtitle = 'Enterprise Solar Management Console',
    this.onAddLead,
    this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF091424),
        border: Border(
          bottom: BorderSide(
            color: AppColors.fg.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Title & Breadcrumb ─────────────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headlineMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fg,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.gold400,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(width: 32),

          // ── Global Search Bar ──────────────────────────────────────────────
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1EEFB),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.fg.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, size: 18, color: AppColors.grey500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: AppColors.fg, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search leads, customers, serial numbers, paperwork...',
                        hintStyle: TextStyle(
                          color: AppColors.grey500.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.fg.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Ctrl K',
                      style: TextStyle(color: AppColors.grey400, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),

          // ── Local API Badge ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Local API: Connected',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          if (onAddLead != null) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold500,
                foregroundColor: AppColors.ink900,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Add Lead', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              onPressed: onAddLead,
            ),
            const SizedBox(width: 10),
          ],

          if (onRecordPayment != null) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF162942),
                foregroundColor: AppColors.gold400,
                elevation: 0,
                side: BorderSide(color: AppColors.gold500.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.currency_rupee_rounded, size: 15),
              label: const Text('Record Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
              onPressed: onRecordPayment,
            ),
            const SizedBox(width: 10),
          ],


          // ── Notifications Icon ─────────────────────────────────────────────
          IconButton(
            icon: const Badge(
              label: Text('3'),
              backgroundColor: AppColors.warning,
              child: Icon(Icons.notifications_outlined, color: AppColors.grey400, size: 22),
            ),
            tooltip: 'Alerts & Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
    );
  }
}
