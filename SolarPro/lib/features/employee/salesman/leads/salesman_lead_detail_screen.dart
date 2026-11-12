import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/salesman/customers/convert_lead_screen.dart';
import 'package:solar_pro/features/leads/data/lead_repository.dart';
import 'package:solar_pro/features/leads/data/models/lead_model.dart';

class SalesmanLeadDetailScreen extends StatefulWidget {
  final LeadModel lead;
  final String? currentUserId;
  final VoidCallback? onLeadUpdated;

  const SalesmanLeadDetailScreen({
    super.key,
    required this.lead,
    this.currentUserId,
    this.onLeadUpdated,
  });

  @override
  State<SalesmanLeadDetailScreen> createState() => _SalesmanLeadDetailScreenState();
}

class _SalesmanLeadDetailScreenState extends State<SalesmanLeadDetailScreen> {
  late LeadModel _lead;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return AppColors.info;
      case 'follow_up':
        return AppColors.gold500;

      case 'converted':
        return AppColors.teal500;
      case 'lost':
        return AppColors.error;
      default:
        return AppColors.grey500;
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.teal500,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _scheduleFollowUp() async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    final noteController = TextEditingController(text: _lead.notes ?? '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Schedule Follow-up',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.grey400),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    tileColor: AppColors.navy800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: const BorderSide(color: AppColors.navy600),
                    ),
                    leading: const Icon(Icons.calendar_today_rounded, color: AppColors.gold500),
                    title: const Text('Follow-up Date', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
                    subtitle: Text(
                      DateFormat('EEE, dd MMM yyyy').format(selectedDate),
                      style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_drop_down, color: AppColors.fg),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: AppColors.navy800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: const BorderSide(color: AppColors.navy600),
                    ),
                    leading: const Icon(Icons.access_time_rounded, color: AppColors.gold500),
                    title: const Text('Time', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
                    subtitle: Text(
                      selectedTime.format(ctx),
                      style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_drop_down, color: AppColors.fg),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.fg),
                    decoration: const InputDecoration(
                      labelText: 'Follow-up Agenda / Note',
                      hintText: 'Discuss roof measurement & financing quote',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold500,
                        foregroundColor: AppColors.ink900,
                        padding: const EdgeInsets.symmetric(vertical: 14),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Save Follow-up', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final finalDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      setState(() => _isLoading = true);
      try {
        final updated = await LeadRepository().updateLead(
          _lead.id,
          status: 'follow_up',
          followUpDate: finalDateTime,
          notes: noteController.text.trim(),
        );
        setState(() {
          _lead = updated;
          _isLoading = false;
        });
        widget.onLeadUpdated?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Follow-up scheduled successfully'), backgroundColor: AppColors.teal500),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _returnLead() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Return Lead', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please specify why this prospect was returned or lost:',
                style: TextStyle(color: AppColors.grey400, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.fg),
                decoration: const InputDecoration(
                  hintText: 'e.g. Roof shadow issue, Budget constraints, Relocated',
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Please enter a valid reason (min 3 chars)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.fg,
            ),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final updated = await LeadRepository().markLeadLost(
          _lead.id,
          reason: reasonController.text.trim(),
        );
        setState(() {
          _lead = updated;
          _isLoading = false;
        });
        widget.onLeadUpdated?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead marked as returned'), backgroundColor: AppColors.grey700),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _openConvertFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConvertLeadScreen(
          lead: _lead,
          onConverted: () {
            widget.onLeadUpdated?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_lead.status);
    final sourceTag = _lead.sourceLabel(widget.currentUserId);

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Lead Details'),
        backgroundColor: AppColors.navy800,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.navy600),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.gold500.withValues(alpha: 0.15),
                              child: Text(
                                _lead.name.isNotEmpty ? _lead.name[0].toUpperCase() : 'L',
                                style: const TextStyle(
                                  color: AppColors.gold500,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lead.name,
                                    style: AppTextStyles.headlineSmall.copyWith(
                                      color: AppColors.fg,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+91 ${_lead.phone}',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                _lead.uiStatusLabel.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.navy600),
                        const SizedBox(height: 12),
                        // Quick Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(_lead.phone, 'Phone number'),
                                icon: const Icon(Icons.call_rounded, size: 18, color: AppColors.teal500),
                                label: const Text('Call', style: TextStyle(color: AppColors.fg, fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.navy600),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyToClipboard('https://wa.me/91${_lead.phone}', 'WhatsApp Link'),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.green400),
                                label: const Text('WhatsApp', style: TextStyle(color: AppColors.fg, fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.navy600),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(_lead.address ?? 'Delhi NCR', 'Location query'),
                                icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.gold500),
                                label: const Text('Map', style: TextStyle(color: AppColors.fg, fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.navy600),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.navy600),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lead Specifications', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold500)),
                        const SizedBox(height: 12),
                        _buildMetaRow(Icons.location_on_outlined, 'Address / Area', _lead.address ?? 'Not specified'),
                        _buildMetaRow(Icons.bolt_rounded, 'Expected Capacity', _lead.expectedKw != null ? '${_lead.expectedKw} kW' : 'Not specified'),
                        _buildMetaRow(Icons.source_rounded, 'Lead Source', sourceTag),
                        if (_lead.source != null && _lead.source!.isNotEmpty)
                          _buildMetaRow(Icons.tag_rounded, 'Reference Details', _lead.source!),
                        if (_lead.notes != null && _lead.notes!.isNotEmpty)
                          _buildMetaRow(Icons.notes_rounded, 'Remarks / Notes', _lead.notes!),
                        if (_lead.lostReason != null && _lead.lostReason!.isNotEmpty)
                          _buildMetaRow(Icons.cancel_outlined, 'Return Reason', _lead.lostReason!, isAlert: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Follow-up Schedule Card
                  if (_lead.followUpDate != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _lead.isFollowUpOverdue
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.gold500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _lead.isFollowUpOverdue ? AppColors.error : AppColors.gold500,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.alarm_rounded,
                            color: _lead.isFollowUpOverdue ? AppColors.error : AppColors.gold500,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lead.isFollowUpOverdue
                                      ? 'Overdue Follow-up'
                                      : (_lead.isFollowUpToday ? "Today's Follow-up" : 'Scheduled Follow-up'),
                                  style: TextStyle(
                                    color: _lead.isFollowUpOverdue ? AppColors.error : AppColors.gold400,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEEE, dd MMM yyyy - hh:mm a').format(_lead.followUpDate!),
                                  style: const TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Outcome Action Buttons
                  Text('Lead Outcome Actions', style: AppTextStyles.labelLarge.copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scheduleFollowUp,
                          icon: const Icon(Icons.alarm_add_rounded, size: 18),
                          label: const Text('Follow-up'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold500,
                            foregroundColor: AppColors.ink900,
                            padding: const EdgeInsets.symmetric(vertical: 12),

                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _returnLead,
                          icon: const Icon(Icons.assignment_return_rounded, size: 18, color: AppColors.error),
                          label: const Text('Return', style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openConvertFlow,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Close & Convert to Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal500,
                        foregroundColor: AppColors.fg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isAlert ? AppColors.error : AppColors.grey400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isAlert ? AppColors.error : AppColors.fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
