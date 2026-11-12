import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';

class ResolveTicketDialog extends StatefulWidget {
  final TicketModel ticket;

  const ResolveTicketDialog({super.key, required this.ticket});

  @override
  State<ResolveTicketDialog> createState() => _ResolveTicketDialogState();
}

class _ResolveTicketDialogState extends State<ResolveTicketDialog> {
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.navy800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success),
          SizedBox(width: 8),
          Text(
            'Resolve Service Ticket',
            style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket: ${widget.ticket.ticketNo} - ${widget.ticket.title}',
              style: const TextStyle(color: AppColors.grey300, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Resolution Note (Mandatory) *',
              style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              style: const TextStyle(color: AppColors.fg, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the action taken (e.g. Replaced MC4 connector, tested grid voltage, inverter restarted).',
                hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 12),
                filled: true,
                fillColor: AppColors.navy700,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'A resolution note is strictly required to resolve this ticket.';
                }
                if (val.trim().length < 5) {
                  return 'Please provide at least 5 characters describing the fix.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_noteController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.fg,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Confirm Resolution'),
        ),
      ],
    );
  }
}
