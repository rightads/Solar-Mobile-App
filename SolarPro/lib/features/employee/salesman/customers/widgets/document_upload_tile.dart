import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Single document attachment and upload tile with progress, status badge, and retry.
class DocumentUploadTile extends StatelessWidget {
  final String title;
  final String description;
  final String docType;
  final IconData icon;
  final String? attachedFileName;
  final bool isUploading;
  final double uploadProgress; // 0.0 to 1.0
  final bool hasError;
  final String? errorMessage;
  final bool isUploaded;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const DocumentUploadTile({
    super.key,
    required this.title,
    required this.description,
    required this.docType,
    required this.icon,
    this.attachedFileName,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.hasError = false,
    this.errorMessage,
    this.isUploaded = false,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
    required this.onRetry,
  });

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.navy900,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey700,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Attach $title',
              style: const TextStyle(
                color: AppColors.fg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a high-contrast photo or choose an existing document/PDF.',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.teal500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.teal500),
              ),
              title: const Text('Capture with Camera', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600)),
              subtitle: const Text('Direct photo capture with auto-compression', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                onPickCamera();
              },
            ),
            const Divider(color: AppColors.navy700, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppColors.gold500),
              ),
              title: const Text('Select from Gallery / Storage', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600)),
              subtitle: const Text('JPG, PNG, or PDF file (up to 10 MB)', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                onPickGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAttached = attachedFileName != null && attachedFileName!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: hasError
              ? AppColors.error
              : isUploaded
                  ? AppColors.success.withValues(alpha: 0.5)
                  : isAttached
                      ? AppColors.teal500.withValues(alpha: 0.5)
                      : AppColors.navy700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUploaded
                      ? AppColors.success.withValues(alpha: 0.15)
                      : isAttached
                          ? AppColors.teal500.withValues(alpha: 0.15)
                          : AppColors.navy900,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color: isUploaded
                      ? AppColors.success
                      : isAttached
                          ? AppColors.teal500
                          : AppColors.grey400,
                  size: 22,
                ),
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
                            title,
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Status badge
                        if (isUploaded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Text(
                              'Uploaded',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else if (hasError)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Text(
                              'Failed',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else if (isAttached)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.teal500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Text(
                              'Ready',
                              style: TextStyle(
                                color: AppColors.teal500,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Text(
                              'Missing',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                    ),
                    if (isAttached) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.attach_file_rounded, color: AppColors.teal500, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              attachedFileName!,
                              style: const TextStyle(
                                color: AppColors.fg70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '(Compressed)',
                            style: TextStyle(color: AppColors.grey500, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Upload progress bar
          if (isUploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: uploadProgress > 0 ? uploadProgress : null,
                minHeight: 4,
                backgroundColor: AppColors.navy900,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal500),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Uploading document...',
                  style: TextStyle(color: AppColors.grey400, fontSize: 11),
                ),
                Text(
                  '${(uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: AppColors.teal500, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],

          // Error message + retry
          if (hasError) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorMessage ?? 'Upload failed. Please check network or file format.',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.gold500,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],

          // Action row
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isAttached && !isUploading) ...[
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                  label: const Text('Remove', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
                const SizedBox(width: 8),
              ],
              if (!isUploaded && !isUploading)
                OutlinedButton.icon(
                  onPressed: () => _showSourceSheet(context),
                  icon: Icon(
                    isAttached ? Icons.change_circle_outlined : Icons.add_photo_alternate_outlined,
                    color: AppColors.teal500,
                    size: 16,
                  ),
                  label: Text(
                    isAttached ? 'Replace File' : 'Attach File',
                    style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.teal500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
