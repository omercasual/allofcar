import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/fuel_price_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpetService {
  static const String _baseUrl = 'https://api.opet.com.tr/api/fuelprices';

  // Cache Keys
  static const String _placesKey = 'opet_provinces_cache';
  static const String _placesTimeKey = 'opet_provinces_time';
  static const String _pricesCachePrefix = 'opet_prices_';
  static const String _pricesTimePrefix = 'opet_prices_time_';
  static const Duration _cacheDuration = Duration(hours: 1);
  static const Duration _timeoutDuration = Duration(seconds: 5);

  List<FuelProvince>? _cachedProvinces;

  Future<List<FuelProvince>> getProvinces() async {
    if (_cachedProvinces != null) return _cachedProvinces!;

    final prefs = await SharedPreferences.getInstance();
    
    // Check Cache Validity
    final lastTimeStr = prefs.getString(_placesTimeKey);
    if (lastTimeStr != null) {
       final lastTime = DateTime.parse(lastTimeStr);
       if (DateTime.now().difference(lastTime) < _cacheDuration) {
          final cachedJson = prefs.getString(_placesKey);
          if (cachedJson != null) {
             try {
               final List<dynamic> data = json.decode(cachedJson);
               _cachedProvinces = data.map((e) => FuelProvince.fromJson(e)).toList();
               return _cachedProvinces!;
             } catch (e) {
               debugPrint("Cache Parse Error: $e");
             }
          }
       }
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/provinces')).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cachedProvinces = data.map((e) => FuelProvince.fromJson(e)).toList();
        
        // Sort alphabetically
        _cachedProvinces!.sort((a, b) => a.name.compareTo(b.name));
        
        // Save to Cache
        prefs.setString(_placesKey, response.body);
        prefs.setString(_placesTimeKey, DateTime.now().toIso8601String());

        return _cachedProvinces!;
      } else {
        throw Exception('Failed to load provinces');
      }
    } catch (e) {
      debugPrint("OpetService Province Error: $e");
      // Fallback to cache even if expired
      final cachedJson = prefs.getString(_placesKey);
      if (cachedJson != null) {
          final List<dynamic> data = json.decode(cachedJson);
          return data.map((e) => FuelProvince.fromJson(e)).toList();
      }
      return [];
    }
  }


  Future<List<FuelDistrict>> getDistricts(int provinceCode) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/provinces/$provinceCode/districts'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => FuelDistrict.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load districts');
      }
    } catch (e) {
      debugPrint("OpetService District Error: $e");
      return [];
    }
  }

  Future<List<FuelPrice>> getFuelPrices(int provinceCode, String districtCode) async {
    try {
      // The API returns a list of districts for the province, each containing prices.
      // We need to fetch the list and find the specific district.
      final url = '$_baseUrl/prices?provinceCode=$provinceCode&districtCode=$districtCode';
      debugPrint("Fetching Prices: $url");
      
      final cacheKey = '$_pricesCachePrefix${provinceCode}_$districtCode';
      final cacheTimeKey = '$_pricesTimePrefix${provinceCode}_$districtCode';
      final prefs = await SharedPreferences.getInstance();

      // Check Cache First
      final lastTimeStr = prefs.getString(cacheTimeKey);
      if (lastTimeStr != null) {
         final lastTime = DateTime.parse(lastTimeStr);
         if (DateTime.now().difference(lastTime) < _cacheDuration) {
             final cachedJson = prefs.getString(cacheKey);
             if (cachedJson != null) {
                final List<dynamic> data = json.decode(cachedJson);
                return data.map((e) => FuelPrice.fromJson(e)).toList();
             }
         }
      }
      
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Find the district in the response list
        // Note: The API seems to return all districts for the province even if districtCode is in the query.
        // We'll iterate to find the matching one.
        final districtData = data.firstWhere(
          (element) => element['districtCode']?.toString() == districtCode,
          orElse: () => null,
        );

        if (districtData != null && districtData['prices'] != null) {
          final List<dynamic> prices = districtData['prices'];
          
          // Save valid response to cache
          final priceList = prices.map((e) => FuelPrice.fromJson(e)).toList();
          prefs.setString(cacheKey, json.encode(prices));
          prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());
          
          return priceList;
        } else {
           debugPrint("District not found in response or no prices available.");
           // Fallback to first item if specific district not found safely? 
           // Better to return mock or empty.
           if (data.isNotEmpty && data.first['prices'] != null) {
             debugPrint("Fallback to first available district prices.");
             return (data.first['prices'] as List).map((e) => FuelPrice.fromJson(e)).toList();
           }
           return _getMockPrices();
        }
      } else {
         debugPrint("Price API error ${response.statusCode}, returning mock data");
         return _getMockPrices();
      }
    } catch (e) {
      debugPrint("OpetService Price Error: $e");
      // Fallback to cache (even expired)
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_pricesCachePrefix${provinceCode}_$districtCode';
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
          final List<dynamic> data = json.decode(cachedJson);
          return data.map((e) => FuelPrice.fromJson(e)).toList();
      }
      return _getMockPrices();
    }
  }
  
  // Mock Data Fallback (If API is protected/changed)
  List<FuelPrice> _getMockPrices() {
    return [
      FuelPrice(productName: "Kurşunsuz Benzin 95", amount: 43.15),
      FuelPrice(productName: "Ultra Force Motorin", amount: 44.20),
      FuelPrice(productName: "Eco Force Motorin", amount: 44.15),
      FuelPrice(productName: "LPG (Otogaz)", amount: 25.50),
    ];
  }
  
  // Preference Storage
  Future<void> saveLocationPreference(int provinceCode, String provinceName, String districtCode, String districtName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fuel_province_code', provinceCode);
    await prefs.setString('fuel_province_name', provinceName);
    await prefs.setString('fuel_district_code', districtCode);
    await prefs.setString('fuel_district_name', districtName);
  }
  
  Future<Map<String, dynamic>?> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('fuel_province_code')) return null;
    
    return {
      'provinceCode': prefs.getInt('fuel_province_code'),
      'provinceName': prefs.getString('fuel_province_name'),
      'districtCode': prefs.getString('fuel_district_code'),
      'districtName': prefs.getString('fuel_district_name'),
    };
  }
}
