import 'package:flutter/material.dart';
import 'package:solar_pro/core/services/shared_upload_service.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class PendingSyncScreen extends StatefulWidget {
  final SharedUploadService? uploadService;

  const PendingSyncScreen({
    super.key,
    this.uploadService,
  });

  @override
  State<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends State<PendingSyncScreen> {
  late SharedUploadService _uploadService;

  @override
  void initState() {
    super.initState();
    _uploadService = widget.uploadService ?? SharedUploadService();
    _uploadService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _uploadService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return AppColors.gold500;
      case UploadStatus.uploading:
        return AppColors.info;
      case UploadStatus.completed:
        return AppColors.success;
      case UploadStatus.failed:
        return AppColors.error;
      case UploadStatus.cancelled:
        return AppColors.grey500;
    }
  }

  IconData _getStatusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return Icons.hourglass_top_rounded;
      case UploadStatus.uploading:
        return Icons.cloud_upload_rounded;
      case UploadStatus.completed:
        return Icons.check_circle_rounded;
      case UploadStatus.failed:
        return Icons.error_outline_rounded;
      case UploadStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = _uploadService.queue;
    final pendingCount = _uploadService.pendingCount;
    final isProcessing = _uploadService.isProcessing;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy800,
        elevation: 0,
        title: const Text('Offline Sync & Uploads', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (queue.any((i) => i.status == UploadStatus.completed || i.status == UploadStatus.cancelled))
            TextButton(
              onPressed: () => _uploadService.clearCompleted(),
              child: const Text('Clear Done', style: TextStyle(color: AppColors.gold400, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Sync Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.navy800,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? AppColors.gold500.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    pendingCount > 0 ? Icons.sync_problem_rounded : Icons.cloud_done_rounded,
                    color: pendingCount > 0 ? AppColors.gold500 : AppColors.success,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pendingCount > 0 ? '$pendingCount Item(s) Pending Cloud Sync' : 'All Changes Synchronized',
                        style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pendingCount > 0
                            ? 'Queued items survive restarts and upload automatically.'
                            : 'All documents, photos, and offline logs are backed up.',
                        style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (pendingCount > 0)
                  ElevatedButton.icon(
                    onPressed: isProcessing ? null : () => _uploadService.processQueue(),
                    icon: isProcessing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink900))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(isProcessing ? 'Syncing...' : 'Sync Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold500,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // Upload List
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_done_outlined, size: 64, color: AppColors.grey600),
                        SizedBox(height: 16),
                        Text(
                          'Upload Queue Empty',
                          style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'No pending offline operations or file uploads.',
                          style: TextStyle(color: AppColors.grey500, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: queue.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final color = _getStatusColor(item.status);
                      final icon = _getStatusIcon(item.status);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.navy800,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.navy600),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(icon, color: color, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.fileName,
                                    style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    item.status.displayName.toUpperCase(),
                                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Destination: ${item.destinationEndpoint}',
                              style: const TextStyle(color: AppColors.grey500, fontSize: 11),
                            ),
                            if (item.status == UploadStatus.uploading) ...[
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: item.progress,
                                backgroundColor: AppColors.navy900,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold500),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(item.progress * 100).toInt()}% uploaded',
                                    style: const TextStyle(color: AppColors.grey400, fontSize: 11),
                                  ),
                                  GestureDetector(
                                    onTap: () => _uploadService.cancelUpload(item.id),
                                    child: const Text(
                                      'CANCEL',
                                      style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (item.status == UploadStatus.failed) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.errorMessage ?? 'Upload failed.',
                                        style: const TextStyle(color: AppColors.error, fontSize: 11),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _uploadService.retryUpload(item.id),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('RETRY', style: TextStyle(color: AppColors.gold400, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
