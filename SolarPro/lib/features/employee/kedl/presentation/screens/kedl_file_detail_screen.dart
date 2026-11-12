import 'package:flutter/material.dart';
import 'package:solar_pro/core/services/media_picker.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/kedl_demand_card.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/pay_demand_sheet.dart';
import 'package:solar_pro/features/employee/kedl/presentation/widgets/raise_demand_sheet.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';

class KedlFileDetailScreen extends StatefulWidget {
  final KedlFileModel initialFile;
  final KedlRepository? repository;

  const KedlFileDetailScreen({
    super.key,
    required this.initialFile,
    this.repository,
  });

  @override
  State<KedlFileDetailScreen> createState() => _KedlFileDetailScreenState();
}

class _KedlFileDetailScreenState extends State<KedlFileDetailScreen> {
  late KedlRepository _repo;
  late KedlFileModel _file;
  bool _isLoading = false;

  final _appNoCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? KedlRepository();
    _file = widget.initialFile;
    _appNoCtrl.text = _file.applicationNo ?? '';
    _remarksCtrl.text = _file.remarks ?? '';
  }

  @override
  void dispose() {
    _appNoCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshFile() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repo.getKedlFileById(_file.id);
      if (mounted) {
        setState(() {
          _file = updated;
          _appNoCtrl.text = updated.applicationNo ?? '';
          _remarksCtrl.text = updated.remarks ?? '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMetadata() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repo.updateKedlFile(
        _file.id,
        applicationNo: _appNoCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _file = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File details updated successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _changeStatus(KedlFileStatus newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Move to ${newStatus.displayName}?', style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
        content: Text(
          newStatus == KedlFileStatus.approved && _file.fileType == KedlFileType.net
              ? 'Approving the Net Metering file will automatically advance the customer project stage to SYSTEM LIVE.'
              : 'Update the paperwork status of this ${_file.fileType.displayName} file to ${newStatus.displayName}?',
          style: const TextStyle(color: AppColors.grey300, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == KedlFileStatus.approved ? AppColors.success : AppColors.gold500,
              foregroundColor: AppColors.fg,
            ),
            child: const Text('Confirm Transition'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final updated = await _repo.updateFileStatus(_file.id, newStatus);
      if (mounted) {
        setState(() {
          _file = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == KedlFileStatus.approved && _file.fileType == KedlFileType.net
                  ? 'Net file approved! Customer moved to SYSTEM LIVE.'
                  : 'File status updated to ${newStatus.displayName}',
            ),
            backgroundColor: AppColors.success,
          ),
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

  void _showRaiseDemandSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => RaiseDemandSheet(
        file: _file,
        repository: _repo,
        onDemandRaised: (demand) {
          _refreshFile();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demand raised! Status moved to Demand Raised.'), backgroundColor: AppColors.warning),
          );
        },
      ),
    );
  }

  void _showPayDemandSheet(KedlDemandModel demand) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => PayDemandSheet(
        demand: demand,
        repository: _repo,
        onDemandUpdated: (updated) {
          _refreshFile();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Demand marked as ${updated.status.displayName}!'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleWaiveDemand(KedlDemandModel demand) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Waive this Demand?', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to waive "${demand.description}"?',
          style: const TextStyle(color: AppColors.grey300),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: AppColors.shadow),
            child: const Text('Waive Demand'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.updateDemand(demand.id, status: KedlDemandStatus.waived);
      _refreshFile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error waiving demand: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleUploadDocument() async {
    final docTypeCtrl = TextEditingController(text: 'Application Copy');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Upload Paperwork Document', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: docTypeCtrl,
              style: const TextStyle(color: AppColors.fg),
              decoration: InputDecoration(
                labelText: 'Document Tag / Type',
                labelStyle: const TextStyle(color: AppColors.grey400),
                filled: true,
                fillColor: AppColors.navy700,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final picked = await MediaPicker.pickDocument();
              if (picked == null || picked.path == null) return;
              final fileName = picked.name;
              await _repo.uploadDocument(
                _file.id,
                docType: docTypeCtrl.text.trim(),
                filePath: picked.path!,
                fileName: fileName,
              );
              _refreshFile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold500, foregroundColor: AppColors.navy900),
            child: const Text('Attach File'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy800,
        elevation: 0,
        title: Text(
          '${_file.fileType.displayName} Details',
          style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & Step Flow Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: _file.fileType.color.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _file.fileType.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_file.fileType.icon, color: _file.fileType.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _file.fileType.displayName,
                                    style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Customer: ${_file.customerName}',
                                    style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _file.status.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                _file.status.displayName.toUpperCase(),
                                style: TextStyle(
                                  color: _file.status.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stepper visual indicators
                        _buildStatusStepper(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Transitions Actions Row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.navy700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Paperwork Status',
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_file.status == KedlFileStatus.notStarted)
                              ElevatedButton.icon(
                                onPressed: () => _changeStatus(KedlFileStatus.submitted),
                                icon: const Icon(Icons.send_rounded, size: 14),
                                label: const Text('Mark Submitted'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal500, foregroundColor: AppColors.fg),
                              ),
                            if (_file.status == KedlFileStatus.submitted || _file.status == KedlFileStatus.demandPaid)
                              ElevatedButton.icon(
                                onPressed: () => _changeStatus(KedlFileStatus.approved),
                                icon: const Icon(Icons.check_circle_rounded, size: 14),
                                label: const Text('Approve File'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.fg),
                              ),
                            if (_file.status != KedlFileStatus.rejected && _file.status != KedlFileStatus.approved)
                              OutlinedButton.icon(
                                onPressed: () => _changeStatus(KedlFileStatus.rejected),
                                icon: const Icon(Icons.cancel_outlined, size: 14),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Application Number & Remarks Edit
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
                        Row(
                          children: [
                            const Icon(Icons.edit_note_rounded, color: AppColors.gold500, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Discom Reference & Remarks',
                              style: TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _saveMetadata,
                              child: const Text('Save', style: TextStyle(color: AppColors.gold500, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _appNoCtrl,
                          style: const TextStyle(color: AppColors.fg, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Discom Application Number',
                            labelStyle: const TextStyle(color: AppColors.grey400),
                            hintText: 'e.g. NET-JPR-2026-1120',
                            filled: true,
                            fillColor: AppColors.navy700,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _remarksCtrl,
                          style: const TextStyle(color: AppColors.fg, fontSize: 14),
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes / Remarks',
                            labelStyle: const TextStyle(color: AppColors.grey400),
                            hintText: 'Discom feedback or pending checklist note',
                            filled: true,
                            fillColor: AppColors.navy700,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                          ),
                        ),
                        if (_file.submittedOn != null || _file.approvedOn != null) ...[
                          const Divider(height: 24, color: AppColors.navy700),
                          Row(
                            children: [
                              if (_file.submittedOn != null)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Submitted Date:', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                                      Text(dateFormat.format(_file.submittedOn!), style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              if (_file.approvedOn != null)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Approved Date:', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                                      Text(dateFormat.format(_file.approvedOn!), style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Demands Section
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.gold500, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'File Demands & Fees',
                        style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.navy700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${_file.demands.length}',
                          style: const TextStyle(color: AppColors.fg, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showRaiseDemandSheet,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Raise Demand'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold500,
                          foregroundColor: AppColors.ink900,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_file.demands.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Center(
                        child: Text(
                          'No fee demands raised on this file.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._file.demands.map(
                      (d) => KedlDemandCard(
                        demand: d,
                        onMarkPaid: () => _showPayDemandSheet(d),
                        onWaive: () => _handleWaiveDemand(d),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Uploaded Documents Section
                  Row(
                    children: [
                      const Icon(Icons.folder_open_rounded, color: AppColors.gold500, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Discom Paperwork Documents',
                        style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _handleUploadDocument,
                        icon: const Icon(Icons.upload_file, size: 16, color: AppColors.gold500),
                        label: const Text('Upload Doc', style: TextStyle(color: AppColors.gold500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_file.documents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Center(
                        child: Text(
                          'No documents uploaded yet. Tap "Upload Doc" to add.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._file.documents.map(
                      (doc) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.navy800,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_outlined, color: AppColors.error, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.originalName, style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(doc.docType, style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusStepper() {
    final steps = [
      KedlFileStatus.notStarted,
      KedlFileStatus.submitted,
      KedlFileStatus.demandRaised,
      KedlFileStatus.demandPaid,
      KedlFileStatus.approved,
    ];

    final currentIdx = _file.status.stepIndex;

    return Row(
      children: List.generate(steps.length, (idx) {
        final step = steps[idx];
        final isDone = idx < currentIdx;
        final isCurrent = idx == currentIdx;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (idx > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isDone || isCurrent ? AppColors.gold500 : AppColors.navy600,
                      ),
                    ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppColors.success
                          : (isCurrent ? AppColors.gold500 : AppColors.navy700),
                      border: Border.all(
                        color: isCurrent ? AppColors.gold500 : AppColors.navy600,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 12, color: AppColors.fg)
                          : Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: isCurrent ? AppColors.navy900 : AppColors.grey400,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (idx < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isDone ? AppColors.gold500 : AppColors.navy600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                step.displayName,
                style: TextStyle(
                  color: isCurrent ? AppColors.fg : AppColors.grey500,
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }),
    );
  }
}
