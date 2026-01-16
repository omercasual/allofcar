import 'package:cloud_firestore/cloud_firestore.dart';

class Car {
  String? id; // Firestore Document ID
  String name;
  int currentKm;
  int nextMaintenanceKm;
  DateTime? nextMaintenanceDate; // Existing
  DateTime? trafficReleaseDate; // New field
  DateTime? nextInspectionDate;
  DateTime? ownershipDate; // New field
  List<Map<String, dynamic>> history;
  List<Map<String, dynamic>> inspectionHistory; 
  List<Map<String, dynamic>> tramerRecords; // [NEW] Tramer History
  List<Map<String, dynamic>> expertiseHistory; // [NEW] Repair/Expertise History

  String? plate;
  int? modelYear;
  String? brand; 
  String? model; 
  String? hardware; 

  bool isCommercial;
  Map<String, String> expertiseReport;
  List<String> photos; 
  Map<String, String> technicalSpecs; 

  Car({
    this.id,
    required this.name,
    required this.currentKm,
    required this.nextMaintenanceKm,
    this.nextMaintenanceDate,
    this.trafficReleaseDate,
    this.nextInspectionDate,
    this.ownershipDate,
    required this.history,
    this.inspectionHistory = const [],
    this.tramerRecords = const [], // [NEW]
    this.expertiseHistory = const [], // [NEW]
    this.isCommercial = false,
    this.plate,
    this.modelYear,
    this.brand,
    this.model,
    this.hardware,
    this.expertiseReport = const {},
    this.photos = const [],
    this.technicalSpecs = const {},
  });

  // Veritabanına yazarken
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'currentKm': currentKm,
      'nextMaintenanceKm': nextMaintenanceKm,
      'isCommercial': isCommercial, 
      'plate': plate,
      'modelYear': modelYear,
      'brand': brand,
      'model': model,
      'hardware': hardware,
      'nextMaintenanceDate': nextMaintenanceDate != null
          ? Timestamp.fromDate(nextMaintenanceDate!)
          : null,
      'trafficReleaseDate': trafficReleaseDate != null
          ? Timestamp.fromDate(trafficReleaseDate!)
          : null, 
      'nextInspectionDate': nextInspectionDate != null
          ? Timestamp.fromDate(nextInspectionDate!)
          : null,
      'ownershipDate': ownershipDate != null
          ? Timestamp.fromDate(ownershipDate!)
          : null, 
      'history': history,
      'inspectionHistory': inspectionHistory, 
      'tramerRecords': tramerRecords, // [NEW]
      'expertiseHistory': expertiseHistory, // [NEW]
      'expertiseReport': expertiseReport, 
      'photos': photos,
      'technicalSpecs': technicalSpecs, 
    };
  }

  // Veritabanından okurken
  factory Car.fromMap(Map<String, dynamic> map, String docId) {
    return Car(
      id: docId,
      name: map['name'] ?? '',
      currentKm: map['currentKm']?.toInt() ?? 0,
      nextMaintenanceKm: map['nextMaintenanceKm']?.toInt() ?? 0,
      isCommercial: map['isCommercial'] ?? false,
      plate: map['plate'],
      modelYear: map['modelYear'],
      brand: map['brand'],
      model: map['model'],
      hardware: map['hardware'],
      nextMaintenanceDate: _parseDate(map['nextMaintenanceDate']),
      trafficReleaseDate: _parseDate(map['trafficReleaseDate']),
      nextInspectionDate: _parseDate(map['nextInspectionDate']),
      ownershipDate: _parseDate(map['ownershipDate']),
      history: List<Map<String, dynamic>>.from(map['history'] ?? []),
      inspectionHistory: List<Map<String, dynamic>>.from(map['inspectionHistory'] ?? []),
      tramerRecords: List<Map<String, dynamic>>.from(map['tramerRecords'] ?? []), // [NEW]
      expertiseHistory: List<Map<String, dynamic>>.from(map['expertiseHistory'] ?? []), // [NEW]
      expertiseReport: Map<String, String>.from(map['expertiseReport'] ?? {}),
      photos: List<String>.from(map['photos'] ?? []),
      technicalSpecs: Map<String, String>.from(map['technicalSpecs'] ?? {}),
    );
  }

  // Tarih Çevirme Helper (Timestamp veya String gelebilir)
  static DateTime? _parseDate(dynamic dateVal) {
    if (dateVal == null) return null;
    if (dateVal is Timestamp) return dateVal.toDate();
    if (dateVal is String) {
       // String gelirse parse etmeyi dene (örn: "2025-12-20")
       try {
         return DateTime.parse(dateVal);
       } catch (e) {
         return null;
       }
    }
    return null;
  }
}
