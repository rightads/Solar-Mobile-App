import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/service/presentation/widgets/resolve_ticket_dialog.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';
import 'package:solar_pro/features/tickets/data/repositories/ticket_repository.dart';

class ServiceTicketDetailScreen extends StatefulWidget {
  final TicketModel initialTicket;
  final TicketRepository? repository;

  const ServiceTicketDetailScreen({
    super.key,
    required this.initialTicket,
    this.repository,
  });

  @override
  State<ServiceTicketDetailScreen> createState() => _ServiceTicketDetailScreenState();
}

class _ServiceTicketDetailScreenState extends State<ServiceTicketDetailScreen> {
  late TicketRepository _repo;
  late TicketModel _ticket;
  bool _isLoading = false;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TicketRepository();
    _ticket = widget.initialTicket;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _refreshTicket() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repo.getTicketById(_ticket.id);
      if (mounted) {
        setState(() {
          _ticket = updated;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startWork() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repo.updateTicketStatus(_ticket.id, TicketStatus.inProgress);
      if (mounted) {
        setState(() {
          _ticket = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket marked In Progress!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _resolveTicket() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => ResolveTicketDialog(ticket: _ticket),
    );

    if (note == null || note.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final updated = await _repo.updateTicketStatus(
        _ticket.id,
        TicketStatus.resolved,
        resolutionNote: note,
      );
      if (mounted) {
        setState(() {
          _ticket = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket successfully resolved with note!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _sendComment() async {
    final msg = _commentController.text.trim();
    if (msg.isEmpty) return;

    _commentController.clear();
    try {
      await _repo.addTicketComment(_ticket.id, msg);
      await _refreshTicket();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reply: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _addVisitPhotos() async {
    final newPath = 'service_visit_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _repo.addVisitPhotos(_ticket.id, [newPath]);
      await _refreshTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit photo added!'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {}
  }

  void _showImageZoom(TicketImageModel image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.fg, size: 24),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 300,
                color: AppColors.navy900,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_outlined, color: AppColors.gold500, size: 48),
                      const SizedBox(height: 10),
                      Text(image.fileKey, style: const TextStyle(color: AppColors.fg, fontSize: 13)),
                    ],
                  ),
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
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy800,
        elevation: 0,
        title: Text(
          _ticket.ticketNo,
          style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Banner: Type & Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: _ticket.type.color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _ticket.type.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_ticket.type.icon, color: _ticket.type.color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _ticket.type.displayName,
                                    style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Priority: ${_ticket.priority.displayName}',
                                    style: TextStyle(color: _ticket.priority.color, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _ticket.status.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                _ticket.status.displayName.toUpperCase(),
                                style: TextStyle(
                                  color: _ticket.status.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _ticket.title,
                          style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _ticket.description,
                          style: const TextStyle(color: AppColors.grey300, fontSize: 13, height: 1.4),
                        ),
                        if (_ticket.errorCode?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Fault Error Code: ${_ticket.errorCode!}',
                                  style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Contact Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.navy700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_pin_circle_rounded, color: AppColors.gold500, size: 18),
                            SizedBox(width: 8),
                            Text('Customer & Site Information', style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(_ticket.customerName, style: const TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: AppColors.grey400),
                            const SizedBox(width: 6),
                            Text(_ticket.customerPhone.isNotEmpty ? _ticket.customerPhone : 'No Phone', style: const TextStyle(color: AppColors.grey300, fontSize: 13)),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Calling ${_ticket.customerPhone}...'), backgroundColor: AppColors.success),
                                );
                              },
                              icon: const Icon(Icons.call, size: 14),
                              label: const Text('Call'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.teal500,
                                foregroundColor: AppColors.fg,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16, color: AppColors.navy700),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.place, size: 14, color: AppColors.grey400),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_ticket.customerAddress, style: const TextStyle(color: AppColors.grey300, fontSize: 13))),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Opening Google Maps navigation...'), backgroundColor: AppColors.navy700),
                                );
                              },
                              icon: const Icon(Icons.navigation_outlined, size: 14),
                              label: const Text('Directions'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gold500,
                                side: const BorderSide(color: AppColors.gold500),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // System & Warranty Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.navy700),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: AppColors.teal500, size: 18),
                            SizedBox(width: 8),
                            Text('System & Warranty Coverage', style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Equipment:', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Growatt 5kW Grid-Tie Inverter',
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Text('System Status:', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SYSTEM_LIVE',
                                textAlign: TextAlign.end,
                                style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Text('Warranty Status:', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Active (4.2 yrs remaining)',
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.gold500, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resolution Note (if resolved)
                  if (_ticket.status == TicketStatus.resolved && _ticket.resolutionNote != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.task_alt_rounded, color: AppColors.success, size: 18),
                              SizedBox(width: 8),
                              Text('Resolution Note', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(_ticket.resolutionNote!, style: const TextStyle(color: AppColors.fg, fontSize: 13, height: 1.4)),
                          if (_ticket.resolvedAt != null) ...[
                            const SizedBox(height: 6),
                            Text('Resolved on ${dateFormat.format(_ticket.resolvedAt!)}', style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Photo Gallery
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, color: AppColors.gold500, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Photo Gallery (${_ticket.images.length})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_ticket.status != TicketStatus.resolved)
                        TextButton.icon(
                          onPressed: _addVisitPhotos,
                          icon: const Icon(Icons.add_a_photo, size: 16, color: AppColors.gold500),
                          label: const Text('Add Visit Photo', style: TextStyle(color: AppColors.gold500, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_ticket.images.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.navy800, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: const Center(child: Text('No photos uploaded for this ticket.', style: TextStyle(color: AppColors.grey400, fontSize: 12))),
                    )
                  else
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _ticket.images.length,
                        itemBuilder: (context, idx) {
                          final img = _ticket.images[idx];
                          return GestureDetector(
                            onTap: () => _showImageZoom(img),
                            child: Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: AppColors.navy700,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.navy600),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.image, color: AppColors.gold500, size: 28),
                                  SizedBox(height: 4),
                                  Text('View Photo', style: TextStyle(color: AppColors.grey300, fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Comment Thread
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.teal500, size: 18),
                      const SizedBox(width: 8),
                      Text('Conversation Thread (${_ticket.comments.length})', style: const TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._ticket.comments.map(
                    (c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.authorRole == 'client' ? AppColors.navy800 : AppColors.navy700.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: c.authorRole == 'client' ? AppColors.teal500.withValues(alpha: 0.3) : AppColors.navy600),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.authorName, style: TextStyle(color: c.authorRole == 'client' ? AppColors.teal500 : AppColors.gold500, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.navy600, borderRadius: BorderRadius.circular(AppRadius.pill)),
                                child: Text(c.authorRole.toUpperCase(), style: const TextStyle(color: AppColors.fg, fontSize: 9)),
                              ),
                              const Spacer(),
                              Text(dateFormat.format(c.createdAt), style: const TextStyle(color: AppColors.grey500, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(c.message, style: const TextStyle(color: AppColors.fg, fontSize: 13, height: 1.3)),
                        ],
                      ),
                    ),
                  ),

                  // Reply Input Box
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: AppColors.fg, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type a message to customer...',
                            hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                            filled: true,
                            fillColor: AppColors.navy800,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sendComment,
                        icon: const Icon(Icons.send_rounded, color: AppColors.gold500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          border: Border(top: BorderSide(color: AppColors.navy700)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (_ticket.status == TicketStatus.assigned)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startWork,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Work On-Site'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold500,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                )
              else if (_ticket.status == TicketStatus.inProgress)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _resolveTicket,
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Resolve Ticket (Note Required)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.fg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                )
              else if (_ticket.status == TicketStatus.resolved)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Ticket Resolved & Handed Over',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
