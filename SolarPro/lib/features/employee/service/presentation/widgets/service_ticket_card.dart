import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';

class ServiceTicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;

  const ServiceTicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: ticket.priority == TicketPriority.urgent
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.navy700,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Type badge & Status chip
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ticket.type.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(ticket.type.icon, size: 13, color: ticket.type.color),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                ticket.type.displayName.toUpperCase(),
                                style: TextStyle(
                                  color: ticket.type.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (ticket.priority == TicketPriority.urgent || ticket.priority == TicketPriority.high) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: ticket.priority.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          ticket.priority.displayName.toUpperCase(),
                          style: TextStyle(
                            color: ticket.priority.color,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ticket.status.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        ticket.status.displayName.toUpperCase(),
                        style: TextStyle(
                          color: ticket.status.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Ticket Number & Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.ticketNo,
                      style: const TextStyle(
                        color: AppColors.gold500,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.title,
                        style: const TextStyle(
                          color: AppColors.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Customer Name & Location
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Text(
                      ticket.customerName,
                      style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '• ${ticket.customerAddress}',
                        style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Error code banner if present
                if (ticket.errorCode?.isNotEmpty == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_rounded, color: AppColors.error, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Fault Code: ${ticket.errorCode!}',
                            style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Bottom row: Date & Comments Count
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        dateFormat.format(ticket.createdAt),
                        style: const TextStyle(color: AppColors.grey400, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ticket.images.isNotEmpty) ...[
                          const Icon(Icons.photo_library_outlined, size: 13, color: AppColors.grey400),
                          const SizedBox(width: 4),
                          Text('${ticket.images.length}', style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                          const SizedBox(width: 8),
                        ],
                        if (ticket.comments.isNotEmpty) ...[
                          const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.teal500),
                          const SizedBox(width: 4),
                          Text(
                            '${ticket.comments.length} replies',
                            style: const TextStyle(color: AppColors.teal500, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
