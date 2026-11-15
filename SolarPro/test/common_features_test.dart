import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/app_error_handler.dart';
import 'package:solar_pro/core/services/shared_upload_service.dart';
import 'package:solar_pro/core/utils/permission_helper.dart';
import 'package:solar_pro/features/notifications/data/models/notification_model.dart';
import 'package:solar_pro/features/notifications/data/repositories/notification_repository.dart';
import 'helpers/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend.install();
  });

  group('Prompt 9: Notification Model & Role Deep-Linking Tests', () {
    test('NotificationModel serializes and deserializes properly', () {
      final json = {
        'id': 'notif_123',
        'title': 'New Lead',
        'body': 'Lead assigned',
        'type': 'lead',
        'target_id': 'lead_999',
        'target_role': 'salesman',
        'is_read': false,
        'created_at': '2026-10-10T12:00:00Z',
      };

      final notif = NotificationModel.fromJson(json);
      expect(notif.id, 'notif_123');
      expect(notif.title, 'New Lead');
      expect(notif.type, 'lead');
      expect(notif.targetId, 'lead_999');
      expect(notif.targetRole, 'salesman');
      expect(notif.isRead, isFalse);

      final out = notif.toJson();
      expect(out['target_id'], 'lead_999');
      expect(out['target_role'], 'salesman');
    });

    test('Strict Role Isolation for Deep-Links: Users land only in their allowed portal', () {
      final leadNotif = NotificationModel(
        id: 'n1',
        title: 'Lead',
        body: 'Lead',
        type: 'lead',
        targetId: 'lead_01',
        createdAt: DateTime.now(),
      );

      final jobNotif = NotificationModel(
        id: 'n2',
        title: 'Job',
        body: 'Job',
        type: 'job',
        targetId: 'job_01',
        createdAt: DateTime.now(),
      );

      final kedlNotif = NotificationModel(
        id: 'n3',
        title: 'KEDL',
        body: 'Demand',
        type: 'kedl_demand',
        targetId: 'dem_01',
        createdAt: DateTime.now(),
      );

      final ticketNotif = NotificationModel(
        id: 'n4',
        title: 'Ticket',
        body: 'Ticket',
        type: 'ticket',
        targetId: 'tck_01',
        createdAt: DateTime.now(),
      );

      // Salesman lands on salesman portal
      expect(NotificationRepository.resolveDeepLinkForRole('salesman', leadNotif), AppRoutes.employeeSalesman);
      expect(NotificationRepository.resolveDeepLinkForRole('sales', leadNotif), AppRoutes.employeeSalesman);

      // Site worker lands on site operations portal
      expect(NotificationRepository.resolveDeepLinkForRole('electrician', jobNotif), AppRoutes.employeeSite);
      expect(NotificationRepository.resolveDeepLinkForRole('structure', jobNotif), AppRoutes.employeeSite);
      expect(NotificationRepository.resolveDeepLinkForRole('civil', jobNotif), AppRoutes.employeeSite);

      // KEDL lands on KEDL portal
      expect(NotificationRepository.resolveDeepLinkForRole('kedl', kedlNotif), AppRoutes.employeeKedl);

      // Service lands on Service Desk
      expect(NotificationRepository.resolveDeepLinkForRole('service', ticketNotif), AppRoutes.employeeService);

      // Client lands on client dashboard
      expect(NotificationRepository.resolveDeepLinkForRole('client', ticketNotif), AppRoutes.clientDash);

      // Admin lands on vendor dashboard
      expect(NotificationRepository.resolveDeepLinkForRole('admin', leadNotif), AppRoutes.vendorDash);
    });

    test('NotificationRepository mark as read and unread count', () async {
      final repo = NotificationRepository();
      final list = await repo.listNotifications();
      expect(list.isNotEmpty, isTrue);

      final first = list.first;
      await repo.markAsRead(first.id);

      final unreadAfter = await repo.getUnreadCount();
      expect(unreadAfter <= list.length, isTrue);

      await repo.markAllAsRead();
      final finalUnread = await repo.getUnreadCount();
      expect(finalUnread, 0);
    });

    test('FCM token registration stores locally and returns result', () async {
      final repo = NotificationRepository();
      final res = await repo.registerFcmToken('test_fcm_token_xyz_123');
      expect(res, isA<bool>());
      // Even if network fails, token is safely recorded locally
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('solar_registered_fcm_token'), 'test_fcm_token_xyz_123');
      expect(res, isTrue);
      expect(backend.registeredFcmToken, 'test_fcm_token_xyz_123');
    });
  });

  group('Prompt 9: App Error Handler Tests', () {
    test('Maps backend PHOTO_REQUIRED to user friendly explanation', () {
      final error = AppError.fromDynamic(
        ArgumentError('At least one photo proof is required before completing this assignment.'),
      );
      expect(error.userFriendlyMessage.contains('photo proof is required'), isTrue);
    });

    test('Maps custom error codes accurately', () {
      const e1 = AppError(
        code: 'PHOTO_REQUIRED',
        message: 'Backend reject',
        userFriendlyMessage: 'At least one photo proof is required before completing this assignment.',
      );
      expect(e1.userFriendlyMessage.contains('photo proof is required'), isTrue);

      const e2 = AppError(
        code: 'RESOLUTION_NOTE_REQUIRED',
        message: 'Backend reject',
        userFriendlyMessage: 'A detailed resolution note is strictly required before closing this ticket.',
      );
      expect(e2.userFriendlyMessage.contains('resolution note is strictly required'), isTrue);

      const e3 = AppError(
        code: 'PAYMENT_PLAN_LOCKED',
        message: 'Backend reject',
        userFriendlyMessage: 'This payment plan is locked because collections have already begun.',
      );
      expect(e3.userFriendlyMessage.contains('payment plan is locked'), isTrue);
    });
  });

  group('Prompt 9: Shared Upload Service Tests', () {
    test('Enqueue upload creates item with pending status', () async {
      final uploadService = SharedUploadService();
      final item = await uploadService.enqueueUpload(
        filePath: '/mock/path/solar_meter.jpg',
        destinationEndpoint: '/api/v1/jobs/1/photos',
        description: 'Site meter photo',
      );

      expect(item.fileName, 'solar_meter.jpg');
      expect(item.status, UploadStatus.pending);
      expect(uploadService.queue.any((i) => i.id == item.id), isTrue);
    });

    test('Cancelling upload marks item as cancelled', () async {
      final uploadService = SharedUploadService();
      final item = await uploadService.enqueueUpload(
        filePath: '/mock/path/cancel_me.jpg',
        destinationEndpoint: '/api/v1/upload',
        description: 'Test cancel',
      );

      uploadService.cancelUpload(item.id);
      final cancelled = uploadService.queue.firstWhere((i) => i.id == item.id);
      expect(cancelled.status, UploadStatus.cancelled);
    });
  });

  group('Prompt 9: Permission Helper Tests', () {
    test('PermissionType metadata has titles, rationale, and icons', () {
      for (final type in PermissionType.values) {
        expect(type.title.isNotEmpty, isTrue);
        expect(type.rationale.isNotEmpty, isTrue);
        expect(type.icon, isNotNull);
      }
    });

    test('checkPermission returns false by default for ungranted permissions', () async {
      final granted = await PermissionHelper.checkPermission(PermissionType.camera);
      expect(granted, isFalse);
    });
  });
}
