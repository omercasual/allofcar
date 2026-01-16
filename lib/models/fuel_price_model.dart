import 'package:flutter/foundation.dart';

class FuelProvince {
  final int code;
  final String name;

  FuelProvince({required this.code, required this.name});

  factory FuelProvince.fromJson(Map<String, dynamic> json) {
    return FuelProvince(
      code: json['code'] is int ? json['code'] : int.tryParse(json['code'].toString()) ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class FuelDistrict {
  final String code; // Sometimes sent as string in Opet API
  final String name;
  final bool isCenter;

  FuelDistrict({required this.code, required this.name, this.isCenter = false});

  factory FuelDistrict.fromJson(Map<String, dynamic> json) {
    return FuelDistrict(
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? '',
      isCenter: json['isCenter'] ?? false,
    );
  }
}

class FuelPrice {
  final String productName;
  final double amount;
  final String productCode;

  FuelPrice({required this.productName, required this.amount, this.productCode = ''});

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    return FuelPrice(
      productName: json['productName'] ?? json['ProductName'] ?? '',
      amount: (json['amount'] ?? json['Amount'] ?? 0.0).toDouble(),
      productCode: json['productCode'] ?? json['ProductCode'] ?? '',
    );
  }
}
