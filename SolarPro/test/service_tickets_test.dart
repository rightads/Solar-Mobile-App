import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';
import 'package:solar_pro/features/tickets/data/repositories/ticket_repository.dart';
import 'helpers/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeBackend.install();
  });

  group('Service Ticket Models & Enums Tests', () {
    test('TicketType properly serializes and deserializes', () {
      expect(TicketType.fromBackendString('structure'), TicketType.structure);
      expect(TicketType.fromBackendString('wiring'), TicketType.wiring);
      expect(TicketType.fromBackendString('inverter'), TicketType.inverter);

      expect(TicketType.structure.toBackendString(), 'structure');
      expect(TicketType.wiring.toBackendString(), 'wiring');
      expect(TicketType.inverter.toBackendString(), 'inverter');

      expect(TicketType.structure.displayName, 'Structure Issue');
      expect(TicketType.wiring.displayName, 'Wiring Issue');
      expect(TicketType.inverter.displayName, 'Inverter Fault');
    });

    test('TicketStatus properly serializes and deserializes', () {
      expect(TicketStatus.fromBackendString('open'), TicketStatus.open);
      expect(TicketStatus.fromBackendString('assigned'), TicketStatus.assigned);
      expect(TicketStatus.fromBackendString('in_progress'), TicketStatus.inProgress);
      expect(TicketStatus.fromBackendString('resolved'), TicketStatus.resolved);
      expect(TicketStatus.fromBackendString('closed'), TicketStatus.closed);

      expect(TicketStatus.inProgress.toBackendString(), 'in_progress');
      expect(TicketStatus.resolved.displayName, 'Resolved');
    });

    test('TicketPriority properly serializes and deserializes', () {
      expect(TicketPriority.fromBackendString('urgent'), TicketPriority.urgent);
      expect(TicketPriority.fromBackendString('high'), TicketPriority.high);
      expect(TicketPriority.fromBackendString('normal'), TicketPriority.normal);
      expect(TicketPriority.fromBackendString('low'), TicketPriority.low);

      expect(TicketPriority.urgent.toBackendString(), 'urgent');
      expect(TicketPriority.urgent.displayName, 'Urgent');
    });

    test('TicketModel parses full json properly', () {
      final json = {
        'id': 'tck_999',
        'ticket_no': 'TCK-2026-9999',
        'customer_id': 'cust_555',
        'customer_name': 'Ramesh Kumar',
        'customer_phone': '9829011111',
        'customer_address': 'Jaipur',
        'type': 'inverter',
        'title': 'No AC Output',
        'description': 'Inverter shows error E-029',
        'error_code': 'E-029',
        'status': 'assigned',
        'priority': 'urgent',
        'created_at': '2026-10-10T10:00:00Z',
        'images': [
          {'id': 'img_1', 'ticket_id': 'tck_999', 'file_key': 'display.jpg'}
        ],
        'comments': [
          {'id': 'cmt_1', 'ticket_id': 'tck_999', 'author_name': 'Ramesh', 'author_role': 'client', 'message': 'Urgent help'}
        ]
      };

      final ticket = TicketModel.fromJson(json);
      expect(ticket.id, 'tck_999');
      expect(ticket.ticketNo, 'TCK-2026-9999');
      expect(ticket.type, TicketType.inverter);
      expect(ticket.priority, TicketPriority.urgent);
      expect(ticket.status, TicketStatus.assigned);
      expect(ticket.errorCode, 'E-029');
      expect(ticket.images.length, 1);
      expect(ticket.comments.length, 1);
    });
  });

  group('TicketRepository & Business Logic Tests', () {
    test('Listing tickets returns the tickets from the API', () async {
      final repo = TicketRepository();
      final tickets = await repo.listTickets();
      expect(tickets.isNotEmpty, isTrue);
      expect(tickets.any((t) => t.type == TicketType.inverter), isTrue);
    });

    test('Filter tickets by type and priority works properly', () async {
      final repo = TicketRepository();
      final inverterTickets = await repo.listTickets(type: TicketType.inverter);
      expect(inverterTickets.every((t) => t.type == TicketType.inverter), isTrue);

      final urgentTickets = await repo.listTickets(priority: TicketPriority.urgent);
      expect(urgentTickets.every((t) => t.priority == TicketPriority.urgent), isTrue);
    });

    test('Starting work transitions status to inProgress', () async {
      final repo = TicketRepository();
      final tickets = await repo.listTickets();
      final target = tickets.firstWhere((t) => t.status == TicketStatus.assigned);

      final updated = await repo.updateTicketStatus(target.id, TicketStatus.inProgress);
      expect(updated.status, TicketStatus.inProgress);
    });

    test('CRITICAL RULE: Resolving ticket without a note is strictly BLOCKED', () async {
      final repo = TicketRepository();
      final tickets = await repo.listTickets();
      final target = tickets.first;

      // Passing null or empty resolution note must throw ArgumentError
      expect(
        () async => await repo.updateTicketStatus(target.id, TicketStatus.resolved, resolutionNote: null),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () async => await repo.updateTicketStatus(target.id, TicketStatus.resolved, resolutionNote: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Resolving ticket WITH a note succeeds and records note', () async {
      final repo = TicketRepository();
      final tickets = await repo.listTickets();
      final target = tickets.first;

      final updated = await repo.updateTicketStatus(
        target.id,
        TicketStatus.resolved,
        resolutionNote: 'Replaced DC fuse and reset inverter parameters.',
      );

      expect(updated.status, TicketStatus.resolved);
      expect(updated.resolutionNote, 'Replaced DC fuse and reset inverter parameters.');
      expect(updated.resolvedAt, isNotNull);
    });

    test('Adding comment appends to ticket comments thread', () async {
      final repo = TicketRepository();
      final tickets = await repo.listTickets();
      final target = tickets.first;

      final comment = await repo.addTicketComment(target.id, 'Arriving on site in 20 minutes.');
      expect(comment.message, 'Arriving on site in 20 minutes.');

      final refreshed = await repo.getTicketById(target.id);
      expect(refreshed.comments.any((c) => c.message == 'Arriving on site in 20 minutes.'), isTrue);
    });

    test('Adding visit photos returns photo records for the ticket', () async {
      final repo = TicketRepository();
      final tickets = await repo.listTickets();
      final target = tickets.first;

      // Visit photos are kept on the device; the API has no ticket photo
      // upload endpoint yet, so the server copy is not expected to change.
      final added = await repo.addVisitPhotos(target.id, ['/mock/path/visit_rectified.jpg']);
      expect(added.length, 1);
      expect(added.single.ticketId, target.id);
      expect(added.single.fileKey, 'visit_rectified.jpg');
    });

    test('Reverse serial lookup returns correct warranty and customer profile', () async {
      final repo = TicketRepository();

      // Test active warranty inverter
      final activeInv = await repo.lookupSerial('inv-active-001'); // normalised to upper case
      expect(activeInv.serialNo, 'INV-ACTIVE-001');
      expect(activeInv.brand, 'Growatt');
      expect(activeInv.isUnderWarranty, isTrue);
      expect(activeInv.customerName, 'Test Customer A');
      expect(activeInv.customerPhone, '9000000101');

      // Test expired warranty inverter
      final expiredInv = await repo.lookupSerial('INV-EXPIRED-002');
      expect(expiredInv.serialNo, 'INV-EXPIRED-002');
      expect(expiredInv.isUnderWarranty, isFalse);
      expect(expiredInv.customerName, 'Test Customer B');

      // Unknown serials surface a friendly error
      expect(() => repo.lookupSerial('NOPE-404'), throwsA(isA<Exception>()));
    });
  });
}
