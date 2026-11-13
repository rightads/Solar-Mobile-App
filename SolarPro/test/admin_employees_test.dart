import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/features/admin/employees/models/admin_employee_model.dart';
import 'package:solar_pro/features/admin/employees/screens/admin_employees_screen.dart';
import 'package:solar_pro/features/admin/employees/widgets/assign_task_dialog.dart';
import 'package:solar_pro/features/admin/employees/widgets/employee_task_sheet.dart';

void main() {
  group('AdminEmployee & EmployeeTask Models Tests', () {
    test('AdminEmployee correctly deserializes from JSON and computes helpers', () {
      final json = {
        'id': 'emp-srv-104',
        'name': 'Vikram Singh',
        'phone': '9829054321',
        'email': 'vikram.singh@solarpro.in',
        'employee_no': 'EMP-SRV-104',
        'role': 'technician',
        'trade': 'service',
        'team': 'Service & Maintenance Team A',
        'task_count': 3,
        'is_active': true,
      };

      final emp = AdminEmployee.fromJson(json);
      expect(emp.id, 'emp-srv-104');
      expect(emp.name, 'Vikram Singh');
      expect(emp.employeeNo, 'EMP-SRV-104');
      expect(emp.roleDisplayName, 'Service');
      expect(emp.taskCount, 3);
      expect(emp.isActive, true);
    });

    test('EmployeeTask correctly deserializes from JSON', () {
      final json = {
        'id': 'task-001',
        'title': 'Inverter replacement & testing',
        'description': 'Replace faulty micro-inverter at customer site',
        'customer_name': 'Ramesh Kumar',
        'location': 'Mansarovar, Jaipur',
        'category': 'service',
        'status': 'in_progress',
        'priority': 'urgent',
        'start_date': '2026-10-28',
        'end_date': '2026-10-29',
        'assigned_to': 'Vikram Singh',
      };

      final task = EmployeeTask.fromJson(json);
      expect(task.id, 'task-001');
      expect(task.title, 'Inverter replacement & testing');
      expect(task.statusDisplayName, 'IN PROGRESS');
      expect(task.priority, 'urgent');
      expect(task.category, 'service');
    });
  });

  group('Admin Employees UI Tests', () {
    testWidgets('Renders AdminEmployeesScreen with header and search controls', (tester) async {
      const mockEmployees = [
        AdminEmployee(
          id: 'emp-srv-104',
          name: 'Vikram Singh',
          employeeNo: 'EMP-SRV-104',
          phone: '9829054321',
          role: 'technician',
          trade: 'service',
          team: 'Service & Maintenance Team A',
          taskCount: 3,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminEmployeesScreen(
            initialEmployees: mockEmployees,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Staff & Employees Directory'), findsOneWidget);
      expect(find.text('Total Staff'), findsOneWidget);
      expect(find.text('Active On Duty'), findsOneWidget);
      expect(find.text('Allocated Tasks'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Staff'), findsOneWidget);
      expect(find.text('Vikram Singh'), findsOneWidget);
    });

    testWidgets('Renders EmployeeTaskDetailSheet and handles interaction', (tester) async {
      const emp = AdminEmployee(
        id: 'emp-srv-104',
        name: 'Vikram Singh',
        employeeNo: 'EMP-SRV-104',
        phone: '9829054321',
        role: 'technician',
        trade: 'service',
        team: 'Service & Maintenance Team A',
        taskCount: 1,
      );

      const mockTasks = [
        EmployeeTask(
          id: 'task-001',
          title: 'Solar Inverter Checkup',
          category: 'service',
          status: 'in_progress',
          priority: 'high',
          assignedTo: 'Vikram Singh',
          customerName: 'Ramesh Kumar',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeTaskDetailSheet(
              employee: emp,
              onTasksChanged: () {},
              initialTasks: mockTasks,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('EMP-SRV-104'), findsOneWidget);
      expect(find.text('Assign New Task'), findsOneWidget);
      expect(find.text('Solar Inverter Checkup'), findsOneWidget);
    });

    testWidgets('AssignTaskDialog renders all required form controls', (tester) async {
      const emp = AdminEmployee(
        id: 'emp-site-015',
        name: 'Sunil Kumar',
        employeeNo: 'EMP-SITE-015',
        phone: '9829098765',
        role: 'labour',
        trade: 'structure',
        team: 'Structure & Mounting Team 1',
        taskCount: 0,
      );

      final mockCustomers = [
        {
          'id': 'cust-001',
          'full_name': 'Ramesh Kumar',
          'phone': '9876543210',
          'address': 'Mansarovar, Jaipur',
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssignTaskDialog(
              employee: emp,
              onTaskAssigned: () {},
              initialCustomers: mockCustomers,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Assign Task to Staff'), findsOneWidget);
      expect(find.textContaining('Sunil Kumar'), findsOneWidget);
      expect(find.text('Task Title *'), findsOneWidget);
      expect(find.text('Dispatch & Assign Task'), findsOneWidget);
    });
  });
}
