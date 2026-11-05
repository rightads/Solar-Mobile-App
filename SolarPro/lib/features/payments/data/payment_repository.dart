import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/employee/salesman/payments/models/loan_details_model.dart';
import 'package:solar_pro/features/employee/salesman/payments/models/payment_plan_model.dart';
import 'package:solar_pro/features/payments/data/models/payment_model.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

class CustomerPaymentsResult {
  final List<PaymentModel> items;
  final PaymentSummaryModel summary;

  const CustomerPaymentsResult({
    required this.items,
    required this.summary,
  });
}

class PaymentRepository {
  final ApiClient _apiClient;

  PaymentRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  String _parseDioError(DioException de, String fallback) {
    final data = de.response?.data;
    if (data is Map) {
      if (data['error'] is Map && data['error']['message'] != null) {
        return data['error']['message'].toString();
      }
      if (data['detail'] != null) {
        return data['detail'].toString();
      }
    }
    return de.message ?? fallback;
  }

  /// Fetch all payments and financial summary for a customer
  Future<CustomerPaymentsResult> getCustomerPayments(String customerId) async {
    try {
      final res = await _apiClient.dio.get('/customers/$customerId/payments');
      final data = res.data as Map<String, dynamic>;

      final rawItems = data['items'] is List ? data['items'] as List : [];
      final items = rawItems
          .map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final summaryMap = data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};
      final summary = PaymentSummaryModel.fromJson(summaryMap);

      return CustomerPaymentsResult(items: items, summary: summary);
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to load customer payments');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error fetching payments: $e');
    }
  }

  /// Get pending payments queue for sales agent approval
  Future<List<PaymentModel>> getPendingPayments() async {
    try {
      final res = await _apiClient.dio.get('/payments/pending');
      final data = res.data;

      List<dynamic> items = [];
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      }

      return items
          .map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to load pending payments');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error loading pending payments: $e');
    }
  }

  /// Sales agent approves a submitted payment. Moves to "sales_approved" ("Waiting for Admin").
  /// Note: The salesman can NEVER verify; verification is Admin only.
  Future<PaymentModel> salesApprovePayment(String paymentId) async {
    try {
      final res = await _apiClient.dio.post('/payments/$paymentId/sales-approve');
      return PaymentModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to approve payment');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error approving payment: $e');
    }
  }

  /// Reject submitted payment with mandatory explanation
  Future<PaymentModel> rejectPayment(String paymentId, {required String reason}) async {
    try {
      final res = await _apiClient.dio.post(
        '/payments/$paymentId/reject',
        data: {'reason': reason.trim()},
      );
      return PaymentModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to reject payment');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error rejecting payment: $e');
    }
  }

  /// Record a payment submission with optional proof photo
  Future<PaymentModel> recordPayment({
    required String customerId,
    required int amountPaise,
    required String mode,
    String? referenceNo,
    String? remarks,
    List<int>? proofBytes,
    String? proofFileName,
    String? proofFilePath,
  }) async {
    try {
      MultipartFile? file;
      if (proofBytes != null && proofFileName != null) {
        file = MultipartFile.fromBytes(proofBytes, filename: proofFileName);
      } else if (proofFilePath != null && proofFileName != null) {
        file = await MultipartFile.fromFile(proofFilePath, filename: proofFileName);
      }

      final formDataMap = <String, dynamic>{
        'amount': amountPaise,
        'mode': mode,
        if (referenceNo != null && referenceNo.isNotEmpty) 'reference_no': referenceNo.trim(),
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks.trim(),
        if (file != null) 'file': file,
      };

      final formData = FormData.fromMap(formDataMap);

      final res = await _apiClient.dio.post(
        '/customers/$customerId/payments',
        data: formData,
      );

      return PaymentModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to record payment');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error recording payment: $e');
    }
  }

  // ── Payment Plan Local Persistence ──────────────────────────────────────────
  // TODO(backend-gap): Free-form payment plan per customer stored locally until backend endpoint is added
  static const String _kPlanPrefix = 'solar_payment_plan_';

  Future<PaymentPlanModel> getPaymentPlan(String customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_kPlanPrefix$customerId');
    if (jsonStr == null || jsonStr.isEmpty) {
      // Default initial plan: 3 flexible milestones
      return PaymentPlanModel(
        customerId: customerId,
        milestones: const [
          PaymentMilestone(id: 'm1', title: 'Booking Advance', isPercentage: true, percentage: 20.0, dueCondition: 'On contract confirmation'),
          PaymentMilestone(id: 'm2', title: 'Material Dispatch', isPercentage: true, percentage: 60.0, dueCondition: 'On panels & inverter dispatch to site'),
          PaymentMilestone(id: 'm3', title: 'Installation & Handover', isPercentage: true, percentage: 20.0, dueCondition: 'On testing and net-meter commissioning'),
        ],
      );
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PaymentPlanModel.fromJson(map);
    } catch (_) {
      return PaymentPlanModel(customerId: customerId);
    }
  }

  Future<void> savePaymentPlan(PaymentPlanModel plan) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(plan.toJson());
    await prefs.setString('$_kPlanPrefix${plan.customerId}', jsonStr);
  }

  // ── Loan Details Local Persistence ──────────────────────────────────────────
  // TODO(backend-gap): Loan details and installments stored locally until backend endpoint is added
  static const String _kLoanPrefix = 'solar_loan_details_';

  Future<LoanDetailsModel> getLoanDetails(String customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_kLoanPrefix$customerId');
    if (jsonStr == null || jsonStr.isEmpty) {
      return LoanDetailsModel(customerId: customerId);
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return LoanDetailsModel.fromJson(map);
    } catch (_) {
      return LoanDetailsModel(customerId: customerId);
    }
  }

  Future<void> saveLoanDetails(LoanDetailsModel loan) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(loan.toJson());
    await prefs.setString('$_kLoanPrefix${loan.customerId}', jsonStr);
  }
}
