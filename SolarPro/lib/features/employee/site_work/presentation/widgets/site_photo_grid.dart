import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';

class SitePhotoGrid extends StatelessWidget {
  final List<WorkPhotoModel> photos;
  final VoidCallback onAddPhotos;
  final bool readOnly;

  const SitePhotoGrid({
    super.key,
    required this.photos,
    required this.onAddPhotos,
    this.readOnly = false,
  });

  void _showPhotoDetail(BuildContext context, WorkPhotoModel photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_outlined, color: AppColors.gold500, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      photo.caption?.isNotEmpty == true ? photo.caption! : photo.fileKey,
                      style: const TextStyle(
                        color: AppColors.fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.grey400, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  height: 240,
                  width: double.infinity,
                  color: AppColors.navy900,
                  child: photo.downloadUrl != null && photo.downloadUrl!.isNotEmpty
                      ? Image.network(
                          photo.downloadUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackPhoto(photo),
                        )
                      : _buildFallbackPhoto(photo),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.grey400),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(photo.createdAt),
                    style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                  ),
                  const Spacer(),
                  if (photo.isLocal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Text(
                        'LOCAL PROOF',
                        style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPhoto(WorkPhotoModel photo) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy900,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navy900,
            AppColors.navy700.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: AppColors.gold500, size: 44),
            const SizedBox(height: 8),
            Text(
              photo.fileKey,
              style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              photo.isLocal ? 'Queued Local Photo Proof' : 'Installation Verification Proof',
              style: const TextStyle(color: AppColors.grey400, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_camera_rounded, color: AppColors.gold500, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Site Photo Proof',
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (photos.isEmpty ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${photos.length} uploaded',
                style: TextStyle(
                  color: photos.isEmpty ? AppColors.error : AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            if (!readOnly)
              TextButton.icon(
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: AppColors.gold500),
                label: const Text(
                  'Add Photo',
                  style: TextStyle(color: AppColors.gold500, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (photos.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.add_photo_alternate_outlined, color: AppColors.warning, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'No Photo Proof Uploaded Yet',
                  style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'At least 1 site verification photo is mandatory before marking this job complete.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey400, fontSize: 12),
                ),
                if (!readOnly) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onAddPhotos,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Capture Site Photo Proof'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold500,
                      foregroundColor: AppColors.ink900,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: photos.length + (readOnly ? 0 : 1),
            itemBuilder: (context, index) {
              if (!readOnly && index == photos.length) {
                // Add more tile
                return GestureDetector(
                  onTap: onAddPhotos,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.navy700.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4), style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: AppColors.gold500, size: 26),
                        SizedBox(height: 4),
                        Text(
                          'Add More',
                          style: TextStyle(color: AppColors.gold500, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final photo = photos[index];
              return GestureDetector(
                onTap: () => _showPhotoDetail(context, photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: AppColors.navy700,
                        child: photo.downloadUrl != null && photo.downloadUrl!.isNotEmpty
                            ? Image.network(
                                photo.downloadUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildFallbackPhoto(photo),
                              )
                            : _buildFallbackPhoto(photo),
                      ),
                      if (photo.isLocal)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Icon(Icons.sync_rounded, size: 10, color: AppColors.shadow),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          color: AppColors.shadow.withValues(alpha: 0.6),
                          child: Text(
                            photo.caption?.isNotEmpty == true ? photo.caption! : photo.fileKey,
                            style: const TextStyle(color: AppColors.fg, fontSize: 10, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
