import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Customer data model matching backend `CustomerRead` schema.
///
/// NOTE on Money: All monetary amounts (`finalPrice`, payment summaries) are
/// represented in integer paise (1 Rupee = 100 paise) as mandated by the architecture rules.
class CustomerModel {
  final String id;
  final String name;
  final String mobile;
  final String address;
  final double? latitude;
  final double? longitude;

  /// Final sale price in integer paise (e.g. 25000000 paise = ₹2,50,000)
  final int finalPrice;

  /// Solar capacity in kW
  final double capacityKw;

  /// System phase: "single" or "three"
  final String phase;

  final String panelBrand;
  final int panelWatt;
  final int panelCount;
  final String inverterBrand;
  final String structureType;

  /// Customer lifecycle stage
  final String stage;

  final String? salesId;
  final String? userId;
  final int documentsCount;
  final Map<String, dynamic>? paymentSummary;
  final DateTime? saleClosedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    this.latitude,
    this.longitude,
    required this.finalPrice,
    required this.capacityKw,
    required this.phase,
    required this.panelBrand,
    required this.panelWatt,
    required this.panelCount,
    required this.inverterBrand,
    required this.structureType,
    required this.stage,
    this.salesId,
    this.userId,
    this.documentsCount = 0,
    this.paymentSummary,
    this.saleClosedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Rupee value computed via integer division from paise
  int get finalPriceInRupees => finalPrice ~/ 100;

  /// Formatted price in Indian Rupees (e.g., ₹2,50,000)
  String get formattedPriceRupees {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(finalPriceInRupees);
  }

  /// Human-readable customer stage label
  String get stageDisplayLabel {
    switch (stage.toUpperCase()) {
      // The old sales / structure / electrical / civil stages are all part of
      // the single Site Installation stage now.
      case 'SALE_CONFIRMED':
      case 'DOCUMENTS_RECEIVED':
      case 'ADVANCE_VERIFIED':
      case 'STRUCTURE_WORK':
      case 'ELECTRICAL_WORK':
      case 'CIVIL_WORK':
      case 'INSTALLATION_COMPLETE':
        return 'Site Installation';
      case 'KEDL_PROCESS':
        return 'KEDL Process';
      case 'SYSTEM_LIVE':
      case 'NET_METER_INSTALLED':
        return 'System Live';
      case 'HANDED_OVER':
        return 'Handed Over';
      default:
        return stage.replaceAll('_', ' ');
    }
  }

  /// Theme color for the stage badge
  Color get stageColor {
    switch (stage.toUpperCase()) {
      case 'SALE_CONFIRMED':
      case 'DOCUMENTS_RECEIVED':
      case 'ADVANCE_VERIFIED':
      case 'STRUCTURE_WORK':
      case 'ELECTRICAL_WORK':
      case 'CIVIL_WORK':
      case 'INSTALLATION_COMPLETE':
        return AppColors.warning;
      case 'KEDL_PROCESS':
        return AppColors.purple500;
      case 'SYSTEM_LIVE':
      case 'NET_METER_INSTALLED':
        return AppColors.teal500;
      case 'HANDED_OVER':
        return AppColors.success;
      default:
        return AppColors.grey500;
    }
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      finalPrice: (json['final_price'] is num) ? (json['final_price'] as num).toInt() : 0,
      capacityKw: (json['capacity_kw'] is num)
          ? (json['capacity_kw'] as num).toDouble()
          : (json['kw'] is num)
              ? (json['kw'] as num).toDouble()
              : 0.0,
      phase: json['phase']?.toString() ?? 'single',
      panelBrand: json['panel_brand']?.toString() ?? '',
      panelWatt: (json['panel_watt'] is num) ? (json['panel_watt'] as num).toInt() : 0,
      panelCount: (json['panel_count'] is num) ? (json['panel_count'] as num).toInt() : 0,
      inverterBrand: json['inverter_brand']?.toString() ?? '',
      structureType: json['structure_type']?.toString() ?? '',
      stage: json['stage']?.toString() ?? 'INSTALLATION_COMPLETE',
      salesId: json['sales_id']?.toString(),
      userId: json['user_id']?.toString(),
      documentsCount: (json['documents_count'] is num) ? (json['documents_count'] as num).toInt() : 0,
      paymentSummary: json['payment_summary'] is Map ? Map<String, dynamic>.from(json['payment_summary'] as Map) : null,
      saleClosedAt: json['sale_closed_at'] != null ? DateTime.tryParse(json['sale_closed_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'final_price': finalPrice,
      'capacity_kw': capacityKw,
      'phase': phase,
      'panel_brand': panelBrand,
      'panel_watt': panelWatt,
      'panel_count': panelCount,
      'inverter_brand': inverterBrand,
      'structure_type': structureType,
      'stage': stage,
      'sales_id': salesId,
      'user_id': userId,
      'documents_count': documentsCount,
      'payment_summary': paymentSummary,
      'sale_closed_at': saleClosedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
