import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth_service;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import '../models/car_model.dart';
import '../models/forum_model.dart';
import '../models/news_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Kullanıcı Detaylarını Kaydet
  Future<void> saveUser(User user) async {
    try {
      await _db.collection('users').doc(user.id.toString()).set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // --- SYSTEM LOGS ---
  Future<void> logEvent(String type, String message, {Map<String, dynamic>? metadata}) async {
    try {
      await _db.collection('system_logs').add({
        'type': type,
        'message': message,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("❌ Failed to log event: $e");
    }
  }

  // Kullanıcı Detaylarını Getir
  Future<User?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  // Kullanıcı Stream (Anlık Takip için) [NEW]
  Stream<User?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return User.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // --- GARAJ İŞLEMLERİ ---

  // Arabaları Getir (Stream - Anlık Güncelleme)
  Stream<List<Car>> getGarage(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Car.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Araba Ekle
  Future<void> addCar(String uid, Car car) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .add(car.toMap());
  }

  // Araba Sil
  Future<void> deleteCar(String uid, String carId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .delete();
  }

  // Araba Güncelle (Genel)
  Future<void> updateCar(String uid, Car car) async {
    if (car.id == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(car.id)
        .update(car.toMap());
  }

  // KM Güncelle
  Future<void> updateCarKm(String uid, String carId, int newKm) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({'currentKm': newKm});
  }

  // Bakım Tarihi Güncelle
  Future<void> updateCarNextMaintenance(
      String uid, String carId, DateTime nextDate, int nextKm) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'nextMaintenanceDate': Timestamp.fromDate(nextDate),
      'nextMaintenanceKm': nextKm
    });
  }

  // Eski Metod (Sadece Tarih) - Backward Compatibility or removal
  Future<void> updateNextMaintenanceDate(
      String uid, String carId, DateTime? date) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'nextMaintenanceDate':
          date != null ? Timestamp.fromDate(date) : null
    });
  }

  // Bakım Ekle ve Opsiyonel Olarak Statü Güncelle
  Future<void> addMaintenance(String uid, String carId,
      Map<String, dynamic> maintenanceRecord, int maintenanceKm, DateTime maintenanceDate, bool shouldUpdateStatus) async {
    
    // 1. Geçmişe ekle
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'history': FieldValue.arrayUnion([maintenanceRecord])
    });

    // 2. Kilometre ve Tarihleri Güncelle (Sadece 'shouldUpdateStatus' ise)
    if (shouldUpdateStatus) {
      debugPrint("DEBUG: Updating status for car $carId. MaintenanceKM: $maintenanceKm");
      int nextKm = maintenanceKm + 10000;
      DateTime nextDate = DateTime(maintenanceDate.year + 1, maintenanceDate.month, maintenanceDate.day);
      debugPrint("DEBUG: NextKM: $nextKm, NextDate: $nextDate");

      try {
        await _db
            .collection('users')
            .doc(uid)
            .collection('garage')
            .doc(carId)
            .update({
              'nextMaintenanceKm': nextKm,
              'nextMaintenanceDate': Timestamp.fromDate(nextDate),
            });
         debugPrint("DEBUG: Status update success.");
      } catch (e) {
         debugPrint("DEBUG: Status update FAILED: $e");
         rethrow; // Hata fırlat ki UI yakalasın
      }
    } else {
      debugPrint("DEBUG: shouldUpdateStatus is FALSE. Skipping status update.");
    }
  }



  // Fetch Gemini Keys
  Stream<Map<String, String>> fetchGeminiKeys() {
    return _db.collection('app_config').doc('gemini_keys').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'key1': data['key1']?.toString() ?? '',
          'key2': data['key2']?.toString() ?? '',
        };
      }
      return {'key1': '', 'key2': ''};
    });
  }

  // Update Gemini Keys
  Future<void> setGeminiKeys(String key1, String key2) async {
    await _db.collection('app_config').doc('gemini_keys').set({
      'key1': key1,
      'key2': key2,
    }, SetOptions(merge: true));
  }
  Future<void> removeMaintenance(
      String uid, String carId, Map<String, dynamic> maintenanceRecord) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'history': FieldValue.arrayRemove([maintenanceRecord])
    });
  }

  // --- FAVORİ İŞLEMLERİ ---

  // Favorileri Getir
  Stream<List<Map<String, dynamic>>> getFavorites(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id; // ID'yi de map'e ekle
        return data;
      }).toList();
    });
  }

  // Favori Ekle
  Future<void> addFavorite(String uid, Map<String, dynamic> carData) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .add(carData);
  }

  // Favori Sil
  Future<void> removeFavorite(String uid, String docId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(docId)
        .delete();
  }
  // --- MUAYENE İŞLEMLERİ ---

  // Muayene Kaydı Ekle (Sadece geçmişe ekler)
  Future<void> addInspectionRecord(
      String uid, String carId, Map<String, dynamic> inspectionRecord) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'inspectionHistory': FieldValue.arrayUnion([inspectionRecord])
    });
  }

  // Muayene Tarihi Güncelle (Sadece tarihi günceller)
  Future<void> updateCarNextInspection(
      String uid, String carId, DateTime? nextDate) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'nextInspectionDate': nextDate != null ? Timestamp.fromDate(nextDate) : null,
    });
  }
  
  // Forward/Alias
  Future<void> updateCarInspectionDate(
      String uid, String carId, DateTime nextDate) async {
      await updateCarNextInspection(uid, carId, nextDate);
  }

  // Muayene Ekle (Hem geçmişe ekler, hem gelecek tarihi günceller - Eski metod)
  Future<void> addInspection(
      String uid, String carId, Map<String, dynamic> inspectionData) async {
    // 1. Add to history
    await addInspectionRecord(uid, carId, inspectionData);

    // 2. Update next inspection date if provided
    if (inspectionData['nextDate'] != null) {
      dynamic val = inspectionData['nextDate'];
      DateTime? nextDate;
      if (val is Timestamp) {
        nextDate = val.toDate();
      } else if (val is DateTime) {
        nextDate = val;
      }
      
      if (nextDate != null) {
        await updateCarInspectionDate(uid, carId, nextDate);
      }
    }
  }

  // Muayene Sil
  Future<void> deleteInspection(
      String uid, String carId, Map<String, dynamic> inspectionData) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'inspectionHistory': FieldValue.arrayRemove([inspectionData])
    });
  }

  // Tramer Kaydı Ekle
  Future<void> addTramerRecord(
      String uid, String carId, Map<String, dynamic> tramerRecord) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'tramerRecords': FieldValue.arrayUnion([tramerRecord])
    });
  }

  // Tramer Kaydı Sil
  Future<void> deleteTramerRecord(
      String uid, String carId, Map<String, dynamic> tramerRecord) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .update({
      'tramerRecords': FieldValue.arrayRemove([tramerRecord])
    });
  }

  // Tekil Araba Stream'i (Detay sayfasında canlı güncelleme için)
  Stream<Car> getCarStream(String uid, String carId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('garage')
        .doc(carId)
        .snapshots()
        .map((doc) {
           if (doc.exists) {
             return Car.fromMap(doc.data() as Map<String, dynamic>, doc.id);
           } else {
             throw Exception("Car not found");
           }
        });
  }
  // --- KARŞILAŞTIRMA FAVORİLERİ ---
  
  // Favori Karşılaştırmaları Getir
  Stream<List<Map<String, dynamic>>> getComparisonFavorites(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorite_comparisons')
        .orderBy('timestamp', descending: true) // En yeni en üstte
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Favori Karşılaştırma Ekle
  Future<String> addComparisonFavorite(String uid, Map<String, dynamic> comparisonData) async {
    // Add timestamp for sorting
    comparisonData['timestamp'] = FieldValue.serverTimestamp();
    
    DocumentReference ref = await _db
        .collection('users')
        .doc(uid)
        .collection('favorite_comparisons')
        .add(comparisonData);
    
    return ref.id;
  }

  // Favori Karşılaştırma Sil
  Future<void> removeComparisonFavorite(String uid, String docId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorite_comparisons')
        .doc(docId)
        .delete();
  }

  // Favori Karşılaştırma ID'sini Bul (Varsa)
  Future<String?> findComparisonFavoriteId(String uid, String car1, String car2) async {
    // Check Order 1: car1 vs car2
    var q1 = await _db
        .collection('users')
        .doc(uid)
        .collection('favorite_comparisons')
        .where('car1Name', isEqualTo: car1)
        .where('car2Name', isEqualTo: car2)
        .get();
    if (q1.docs.isNotEmpty) return q1.docs.first.id;

    // Check Order 2: car2 vs car1 (Swap)
    var q2 = await _db
        .collection('users')
        .doc(uid)
        .collection('favorite_comparisons')
        .where('car1Name', isEqualTo: car2)
        .where('car2Name', isEqualTo: car1)
        .get();
    if (q2.docs.isNotEmpty) return q2.docs.first.id;

    return null;
  }

  // --- YÖNETİCİ & SİSTEM AYARLARI ---

  // AI Yapılandırmasını Getir (Global Prompt)
  Future<String?> getAiConfig() async {
    try {
      DocumentSnapshot doc = await _db.collection('app_config').doc('ai_settings').get();
      if (doc.exists) {
        return doc.get('system_prompt') as String?;
      }
      return null;
    } catch (e) {
      debugPrint("AI Config Fetch Error: $e");
      return null;
    }
  }

  // AI Yapılandırmasını Güncelle (Arıza Tespiti)
  Future<void> updateAiConfig(String newPrompt) async {
    await _db.collection('app_config').doc('ai_settings').set({
      'system_prompt': newPrompt,
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  // --- KARŞILAŞTIRMA AI AYARLARI ---

  // Karşılaştırma AI Prompt'unu Getir
  Future<String?> getComparisonAiConfig() async {
    try {
      DocumentSnapshot doc = await _db.collection('app_config').doc('comparison_ai_settings').get();
      if (doc.exists) {
        return doc.get('system_prompt') as String?;
      }
      return null;
    } catch (e) {
      debugPrint("Comparison AI Config Fetch Error: $e");
      return null;
    }
  }

  // Karşılaştırma AI Prompt'unu Güncelle
  Future<void> updateComparisonAiConfig(String newPrompt) async {
    await _db.collection('app_config').doc('comparison_ai_settings').set({
      'system_prompt': newPrompt,
      'last_updated': FieldValue.serverTimestamp(),
    });
  } // End of updateComparisonAiConfig

  // --- ASİSTAN AI AYARLARI (OTO GURME) ---

  // Asistan Prompt'unu Getir
  Future<String?> getAssistantAiConfig() async {
    try {
      DocumentSnapshot doc = await _db.collection('app_config').doc('assistant_ai_settings').get();
      if (doc.exists) {
        return doc.get('system_prompt') as String?;
      }
      return null;
    } catch (e) {
      debugPrint("Assistant AI Config Fetch Error: $e");
      return null;
    }
  }

  // Asistan Prompt'unu Güncelle
  Future<void> updateAssistantAiConfig(String newPrompt) async {
    await _db.collection('app_config').doc('assistant_ai_settings').set({
      'system_prompt': newPrompt,
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  // --- BAKIM ASİSTANI AYARLARI ---
  
  // Yasaklı Kullanıcıları Getir
  Stream<List<User>> getBannedUsers() {
    return _db
        .collection('users')
        .where('isBanned', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => User.fromMap(doc.data())).toList();
    });
  }

  // --- KULLANICI YASAKLAMA / KALDIRMA ---
  // --- KULLANICI YASAKLAMA / KALDIRMA ---
  Future<void> setBanStatus(String uid, bool isBanned, {DateTime? expirationDate}) async {
    final Map<String, dynamic> data = {'isBanned': isBanned};
    
    if (isBanned) {
      if (expirationDate != null) {
        data['banExpiration'] = Timestamp.fromDate(expirationDate);
      } else {
        data['banExpiration'] = null; // Permanent
      }
    } else {
      data['banExpiration'] = null; // Clear expiration if unbanned
    }

    await _db.collection('users').doc(uid).update(data);
  }

  // Ban Süresi Kontrolü (Auto-Unban)
  Future<bool> checkBanStatus(User user) async {
    if (!user.isBanned) return false;

    // Check expiration
    if (user.banExpiration != null && DateTime.now().isAfter(user.banExpiration!)) {
      // Süre dolmuş, otomatik ban kaldır
      await setBanStatus(user.id!, false);
      return false; // Artık yasaklı değil
    }
    return true; // Hala yasaklı
  }
  
  // --- BAKIM ASİSTANI AYARLARI ---
  
  Future<String?> getMaintenanceAiConfig() async {
    try {
      DocumentSnapshot doc = await _db.collection('app_config').doc('maintenance_ai_settings').get();
      if (doc.exists) {
        return doc.get('system_prompt') as String?;
      }
      return null;
    } catch (e) {
      debugPrint("Maintenance AI Config Fetch Error: $e");
      return null;
    }
  }

  Future<void> updateMaintenanceAiConfig(String newPrompt) async {
    await _db.collection('app_config').doc('maintenance_ai_settings').set({
      'system_prompt': newPrompt,
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  // --- FORUM GENEL AYARLARI ---

  // Admin Rozet Yazısını Getir
  Future<String> getAdminBadgeLabel() async {
    try {
      DocumentSnapshot doc = await _db.collection('app_config').doc('forum_settings').get();
      if (doc.exists) {
        return doc.get('admin_badge_label') as String? ?? 'Admin';
      }
      return 'Admin';
    } catch (e) {
      debugPrint("Admin Badge Label Fetch Error: $e");
      return 'Admin';
    }
  }

  // Admin Rozet Yazısını Güncelle
  Future<void> updateAdminBadgeLabel(String newLabel) async {
    await _db.collection('app_config').doc('forum_settings').set({
      'admin_badge_label': newLabel,
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- HABER İŞLEMLERİ (AlofHABER) ---

  // Yayındaki Haberleri Getir (Gelecek tarihli olanlar gizlenir)
  Stream<List<NewsArticle>> getNewsArticles() {
    return _db.collection('news')
        .where('timestamp', isLessThanOrEqualTo: DateTime.now())
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NewsArticle.fromFirestore(doc)).toList();
    });
  }

  // Planlanmış Haberleri Getir (Sadece Gelecek Tarihliler)
  Stream<List<NewsArticle>> getPlannedNewsArticles() {
    return _db.collection('news')
        .where('timestamp', isGreaterThan: DateTime.now())
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NewsArticle.fromFirestore(doc)).toList();
    });
  }

  // --- RESİM YÜKLEME (Generic) ---
  Future<String?> uploadImage(File image, String folderPath) async {
    try {
      if (!await image.exists()) return null;
      
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final bytes = await image.readAsBytes();
      
      try {
        // Attempt 1: Default instance
        final ref = _storage.ref().child(folderPath).child(fileName);
        final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
        return await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Default Bucket Upload Failed: $e");
        
        // Attempt 2: Fallback to appspot.com bucket
        try {
          debugPrint("Attempting fallback to gs://allofcar-1.appspot.com");
          final fallbackStorage = FirebaseStorage.instanceFor(bucket: "gs://allofcar-1.appspot.com");
          final ref = fallbackStorage.ref().child(folderPath).child(fileName);
          final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
          return await uploadTask.ref.getDownloadURL();
        } catch (fallbackError) {
           debugPrint("Fallback Bucket Upload Failed: $fallbackError");
           rethrow; // Throw original or fallback error
        }
      }
    } catch (e) {
      debugPrint("Image Upload Error ($folderPath): $e");
      return null;
    }
  }

  // Haber Sil
  Future<void> deleteNewsArticle(String articleId) async {
    await _db.collection('news').doc(articleId).delete();
  }



  // Support Image Upload
  Future<String?> uploadSupportImage(File image) async {
      return await uploadImage(image, 'support_images');
  }

  // Haber Görseli Yükle
  Future<String?> uploadNewsImage(File image) async {
    try {
      if (!await image.exists()) {
        debugPrint("News Image Error: File does not exist");
        return null;
      }
      
      String extension = "jpg";
      try {
        extension = image.path.split('.').last.toLowerCase();
      } catch (_) {}
      
      String contentType = 'image/jpeg';
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
         contentType = 'image/jpeg';
      }

      final fileName = 'news_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = _storage.ref().child('news_images').child(fileName);
      
      debugPrint("Starting Upload: ${ref.fullPath} (Type: $contentType)");
      
      // Explicitly wait for the upload task
      final uploadTask = await ref.putFile(
        image,
        SettableMetadata(contentType: contentType),
      );
      
      debugPrint("Upload Success: ${uploadTask.state}");
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint("Download URL obtained: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("Detailed News Image Upload Error: $e");
      if (e is FirebaseException) {
        debugPrint("Firebase Error Code: ${e.code}");
        debugPrint("Firebase Error Message: ${e.message}");
        debugPrint("Firebase Error Bucket: ${e.plugin}");
      }
      return null;
    }
  }

  Future<void> addNewsArticle(NewsArticle article) async {
    final docRef = await _db.collection('news').add(article.toMap());
    // Auto-trigger notification record for new publications
    await sendBroadcastNotification(
      title: "Yeni Haber: ${article.title}",
      body: article.content.length > 100 ? "${article.content.substring(0, 97)}..." : article.content,
      type: 'news',
      data: {'articleId': docRef.id},
    );

    // [NEW] Automatically trigger FCM so users get push notification immediately
    try {
      await sendFcmNotification(
        topic: 'news_notifications',
        title: "Yeni Haber: ${article.title}",
        body: article.content.length > 100 ? "${article.content.substring(0, 97)}..." : article.content,
        data: {'articleId': docRef.id, 'type': 'news'},
      );
    } catch (e) {
      debugPrint("Warning: Auto-FCM failed for news article: $e");
      // Continue execution, do not throw
    }
  }

  // Haber Geri Çekme (Yayınlanmış haberi havuza taşı)
  Future<void> withdrawNews(String articleId) async {
    final doc = await _db.collection('news').doc(articleId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    // Generate a New Id for scraped pool to avoid conflicts if same original Id exists
    final news = NewsArticle.fromMap(data, articleId);
    
    // Add to pool
    await addScrapedNews(news);
    
    // Remote from live news
    await _db.collection('news').doc(articleId).delete();
  }

  // --- BROADCAST NOTIFICATIONS (FOR NEWS) ---
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    await _db.collection('broadcast_notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'data': data ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> listenToBroadcastNotifications() {
    // We only want notifications created AFTER now to avoid old notification spam
    return _db.collection('broadcast_notifications')
        .where('timestamp', isGreaterThan: Timestamp.now())
        .snapshots();
  }

  // Get FCM V1 Credentials (JSON string)
  Future<String?> getFcmCredentials() async {
    final doc = await _db.collection('app_config').doc('fcm_settings').get();
    String? storedJson = doc.data()?['serviceAccountJson'];
    
    // Fallback to the JSON provided by the user if Firestore is empty
    if (storedJson == null || storedJson.isEmpty) {
      return '''{
  "type": "service_account",
  "project_id": "allofcar-1",
  "private_key_id": "ba0c626e8b5eaf627e821d34de55d1d6951fa670",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDUNP0COzT/bwGq\\nbcm/6eJPkH2FD3hGiu2N0/MDOd2wp1bwp6o0ymwOh9P1e1GXS8Ftm9nRYIGAcFRq\\nOTiTQJI4vD1UhSpUM8ASoLeKxeft2NxyJinR1oWIb2H7NVILe+CKy102PkZV6wa9\\nhCNu5hegYJvLdpT/Xo5/FBX0Y5MPNJEGT63BR6Um4Y7ORp4oUYX66VbBY5vE0h+A\\nleiUYr4E0gQVCgb+1TQSemosakMhju/WdZsiUyiJTKAWDnLzVHKMHTyWV8Eok8E3\\nJRYCZpg6s4fmg0hSd5+5+9Dq7W2fG4/JgEZLCYg/LkcLb/lYp/d8FdtlTA9Q5fMO\\nB2fL18w/AgMBAAECggEADhe9cbzS29/YYXl3EOAMdTI9qReKP6Jm/P3wFpfCNELO\\nEEoM5gKcwyjxbPe/8byd35Sea5GYKBp4ULGfeJACO0hXs67q97qUF+iafS8qzu3m\\n/fcGMfb9g+kPExV1xGjOqbOwa14et61VvkJHRCHTEds4nX4w46C49Tw1P7dZLdo1\\n42CAMprSjXfRXiFoMqvFfu6o4YXCszv5ABixcOG23t0qyWV/0webhvjpKuSXvfXH\\nijDmmMij6Pnia07od8aZg4ALFDY/00cl2de6tm6sSbPg0tioXeOgSLlznvBErfDj\\n/yKGX7Rqlg03Y0/saHvldTjhsKtb26MXhdn2AAp0uQKBgQDqXxy0eLyAKufb6Nbc\\n6/TIRkt6XHWvs6FiP38Ltlxrj/qoDI82+meVjlO3l30FrqFqvbhW0LXcjFAXxbzp\\nTj3KwlWgHpTdXqSiE0RZaGpKc1pwiRR1PaJiJ86If1njhCjnvxZ0Q0hjaXyVS97K\\nYYXS0mI0N7gr4Opzva3FrLJBFQKBgQDnykCB7vD9euKSr6Fg9sz/RFdyKAiX4Lkg\\ndVGrdvbyGLBxHbJTIgwuoMAq9OTtxoSnyDCuqZ0FT3F2B4A7yX5WGjEZNTy9s661\\nDQCahCQZ/vEbhKMLFYoKPZdQM1oTfoO6NtmQ9oNi64wVRzmFNZTN9OlNF/z8krBH\\nKiXrpTUlAwKBgHpekrQ/3dvliw2s8pKCuFnhKgOHRwMn/Pk5QfIxkuuuTydy90uz\\nTmYt29Qdym8vEKSUziy16F5w/FiNK+d8rJKzCNYDYaJ7ieX9vVAZTnX06KGdUQst\\n1Rz+v71REPPTyy/E+8pUXvVY3G1vIbH1XVQH+LJe7VArrP4laReu5ZtJAoGAdxG8\\npYKbJXt03KmAGxFtKUxwJ2JNV8fHEddyhsRsAt2P9eutaWs6GtHVJbv7xfGOv6nk\\n6DSVRt8Sh/E+fHf7gDugMTTZ6RFek/8D6lwrN3dxYBN4tf7wlGYjTr2ybgU1ofj/\\nNqqLv8sEgQG/mKB3un0vQ70o5o5sI4KRTEXn0QUCgYEAvCiEBTctvitEc1Tak7ZX\\n0gPcyNG8mtYRJY1hXctJHjn33I1z5nxnFs4LqPvEhYxXtnnIScsOZgURmAk5Qfwg\\nceIp8Q33ZoTnlmQCZWGSkoXCOdVZkcNTV8VKz6+AoJFNBjMXuLJdp+k641KVJFpP\\naDAhpgOga/v/XsE4WNJLN60=\\n-----END PRIVATE KEY-----\\n",
  "client_email": "firebase-adminsdk-fbsvc@allofcar-1.iam.gserviceaccount.com",
  "client_id": "105134351310760681502",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40allofcar-1.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}''';
    }
    return storedJson;
  }

  Future<void> setFcmCredentials(String jsonString) async {
    await _db.collection('app_config').doc('fcm_settings').set({'serviceAccountJson': jsonString});
  }

  // Generate OAuth2 Token for FCM V1
  Future<String?> _getFcmAccessToken() async {
    try {
      final jsonString = await getFcmCredentials();
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint("FCM Error: No JSON credentials found.");
        return null;
      }

      // Sanitize JSON (remove potential spaces, \r, \n in private_key that break Base64)
      Map<String, dynamic> credentialsMap;
      try {
        credentialsMap = json.decode(jsonString);
        if (credentialsMap.containsKey('private_key')) {
          String key = credentialsMap['private_key'].toString();
          
          // Identify markers
          final List<Map<String, String>> markers = [
            {'start': '-----BEGIN PRIVATE KEY-----', 'end': '-----END PRIVATE KEY-----'},
            {'start': '-----BEGIN RSA PRIVATE KEY-----', 'end': '-----END RSA PRIVATE KEY-----'},
          ];

          String? foundStart;
          String? foundEnd;

          for (var marker in markers) {
            if (key.contains(marker['start']!) && key.contains(marker['end']!)) {
              foundStart = marker['start'];
              foundEnd = marker['end'];
              break;
            }
          }
          
          if (foundStart != null && foundEnd != null) {
            debugPrint("FCM Debug: Found key marker: $foundStart");
            final startIndex = key.indexOf(foundStart) + foundStart.length;
            final endIndex = key.indexOf(foundEnd);
            
            String body = key.substring(startIndex, endIndex);
            
            // 1. Remove literal escape sequence strings first (the characters '\' and 'n')
            body = body.replaceAll(r'\n', '').replaceAll(r'\r', '');
            
            // 2. Remove actual whitespace characters
            body = body.replaceAll('\n', '').replaceAll('\r', '').replaceAll('\t', '').replaceAll(' ', '');
            
            // 2b. Normalize URL-safe Base64 (RFC 4648)
            // Some keys might use '-' and '_' instead of '+' and '/'
            body = body.replaceAll('-', '+').replaceAll('_', '/');

            // 3. Keep ONLY valid Base64 characters for final safety
            body = body.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
            
            // 4. (Removed) Do not auto-pad. Let the decoder fail if length is wrong.
            // This helps identify truncation issues more clearly.
            
            // 5. Reconstruct standard PEM format - googleapis_auth prefers standard PEM
            // Wrap at 64 chars
            final sb = StringBuffer();
            sb.writeln(foundStart);
            for (int i = 0; i < body.length; i += 64) {
              int end = i + 64;
              if (end > body.length) end = body.length;
              sb.writeln(body.substring(i, end));
            }
            sb.writeln(foundEnd); // Ensure newline after footer
            
            credentialsMap['private_key'] = sb.toString();
            debugPrint("FCM Debug: Private key reconstructed and sanitized. Length: ${body.length}");
          } else {
             debugPrint("FCM Warning: Private key markers not found. Attempting raw sanitization.");
             // Fallback for cases where markers might be missing but format is otherwise okay
             String sanitizedKey = key.replaceAll(r'\n', '').replaceAll(r'\r', '')
                                     .replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
             credentialsMap['private_key'] = sanitizedKey;
          }
        }
      } catch (e) {
        debugPrint("FCM JSON Parse Error: $e");
        rethrow;
      }

      final credentials = auth.ServiceAccountCredentials.fromJson(json.encode(credentialsMap));
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      
      final client = await auth.clientViaServiceAccount(credentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      
      return accessToken;
    } catch (e) {
      // DEBUG: Capture the key length for diagnosis
      String debugInfo = "";
      try {
        final jsonString = await getFcmCredentials();
        if (jsonString != null) {
           final map = json.decode(jsonString);
           final key = map['private_key'].toString();
           debugInfo = "KeyLen: ${key.length}";
        }
      } catch (_) {}

      debugPrint("FCM OAuth2 Error Detail: $e");
      throw Exception("FCM Auth Error: $e ($debugInfo)"); 
    }
  }

  // Resolve Username to FCM Token
  Future<String?> getFcmTokenByUsername(String username) async {
    final snapshot = await _db.collection('users').where('username', isEqualTo: username).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data()['fcmToken'];
  }

  // Resolve Username to User ID
  Future<String?> getUserIdByUsername(String username) async {
    final snapshot = await _db.collection('users').where('username', isEqualTo: username).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  // Search Users for Mention
  Future<List<User>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final snapshot = await _db.collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + '\uf8ff') // Standard Firestore prefix search
          .limit(5)
          .get();
      
      return snapshot.docs.map((doc) => User.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint("User search error: $e");
      return [];
    }
  }

  // Send Notification via FCM HTTP v1 API
  Future<void> sendFcmNotification({
    String? token,
    String? topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final String? accessToken;
    try {
      accessToken = await _getFcmAccessToken();
    } catch (e) {
       throw Exception("OAuth2 Token Hatası: $e");
    }

    if (accessToken == null) {
      throw Exception("FCM Kimlik bilgileri bulunamadı veya geçersiz.");
    }

    // Get Project ID from JSON to build the URL
    String projectId = "allofcar-1"; // Fallback
    try {
      final jsonString = await getFcmCredentials();
      if (jsonString != null) {
        projectId = json.decode(jsonString)['project_id'] ?? projectId;
      }
    } catch (_) {}

    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            if (token != null) 'token': token,
            if (topic != null) 'topic': topic,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              ...?data,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'sound': 'default',
              }
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                },
              },
            },
          }
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("FCM V1 Sunucu Hatası (${response.statusCode}): ${response.body}");
      }
      debugPrint("FCM V1 Success: Notification sent.");
    } catch (e) {
      debugPrint("FCM V1 Exception: $e");
      rethrow;
    }
  }

  // NEWS INTERACTIONS (VIEWS & SENTIMENT)
  Future<void> incrementNewsViewCount(String articleId) async {
    await _db.collection('news').doc(articleId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  Future<void> toggleNewsLike(String articleId, String userId) async {
    final docRef = _db.collection('news').doc(articleId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final List<String> likes = List<String>.from(doc.data()?['likes'] ?? []);

    if (likes.contains(userId)) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([userId])
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([userId]),
        'dislikes': FieldValue.arrayRemove([userId])
      });
    }
  }

  Future<void> toggleNewsDislike(String articleId, String userId) async {
    final docRef = _db.collection('news').doc(articleId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final List<String> dislikes = List<String>.from(doc.data()?['dislikes'] ?? []);

    if (dislikes.contains(userId)) {
      await docRef.update({
        'dislikes': FieldValue.arrayRemove([userId])
      });
    } else {
      await docRef.update({
        'dislikes': FieldValue.arrayUnion([userId]),
        'likes': FieldValue.arrayRemove([userId])
      });
    }
  }

  // --- HABER BOTU VE SCRAPER ---

  // Bot Ayarlarını Getir
  Future<Map<String, dynamic>> getNewsBotConfig() async {
    final doc = await _db.collection('configs').doc('news_bot').get();
    if (doc.exists) return doc.data()!;
    return {
      'auto_share': false,
      'prompt': "Sen profesyonel bir otomobil editörüsün. Aşağıdaki haberi özetle, ilgi çekici bir başlık at ve AlofCar platformuna uygun, heyecanlı bir dille yeniden yaz. Teknik terimleri koru ama anlatımı sadeleştir.",
      'interval_hours': 24,
      'is_active': false,
    };
  }

  // Bot Ayarlarını Güncelle
  Future<void> updateNewsBotConfig(Map<String, dynamic> config) async {
    await _db.collection('configs').doc('news_bot').set(config, SetOptions(merge: true));
  }

  // Haber Havuzunu Getir (Scraped News)
  Stream<List<NewsArticle>> getScrapedNewsPool() {
    return _db.collection('scraped_news')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NewsArticle.fromFirestore(doc)).toList();
    });
  }

  // Havuza Haber Ekle
  Future<void> addScrapedNews(NewsArticle article) async {
    await _db.collection('scraped_news').add(article.toMap());
  }

  // Havuzdan Haber Sil
  Future<void> deleteScrapedNews(String id) async {
    await _db.collection('scraped_news').doc(id).delete();
  }

  // Haberi Onayla (Yayına al ve havuzdan sil)
  Future<void> approveScrapedNews(NewsArticle article) async {
    await addNewsArticle(article);
    await deleteScrapedNews(article.id);
  }

  // Haber Yorumlarını Getir
  Stream<List<ForumComment>> getNewsComments(String newsId, {bool showHidden = false}) {
    return _db.collection('news')
        .doc(newsId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      var comments = snapshot.docs.map((doc) => ForumComment.fromFirestore(doc)).toList();
      if (!showHidden) {
        comments = comments.where((c) => !c.isHidden).toList();
      }
      return comments;
    });
  }

  // Haber Yorumu Ekle
  Future<void> addNewsComment(ForumComment comment) async {
    final newsRef = _db.collection('news').doc(comment.postId); // we use postId as newsId here for compatibility
    WriteBatch batch = _db.batch();
    
    DocumentReference commentRef;
    if (comment.id.isNotEmpty) {
      commentRef = newsRef.collection('comments').doc(comment.id);
    } else {
      commentRef = newsRef.collection('comments').doc();
    }
    
    batch.set(commentRef, comment.toMap());
    batch.update(newsRef, {
      'commentCount': FieldValue.increment(1)
    });
    
    await batch.commit();
  }

  // --- FORUM İŞLEMLERİ (AlofFORUM) ---

  // Forum Fotoğrafları Yükle
  Future<List<String>> uploadForumImages(String postId, List<File> images) async {
    List<String> downloadUrls = [];
    for (int i = 0; i < images.length; i++) {
      try {
        String extension = "jpg";
        try {
          extension = images[i].path.split('.').last.toLowerCase();
        } catch (_) {}

        String contentType = 'image/jpeg';
        if (extension == 'png') {
          contentType = 'image/png';
        }

        final fileName = 'image_$i.$extension';
        final ref = _storage.ref().child('forum_images').child(postId).child(fileName);
        
        final uploadTask = await ref.putFile(
          images[i],
          SettableMetadata(contentType: contentType),
        );
        
        final url = await uploadTask.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e) {
        debugPrint("Forum Image Upload Error (index $i): $e");
      }
    }
    return downloadUrls;
  }

  // Gönderileri Getir (Stream) - Gizli olmayanlar
  Stream<List<ForumPost>> getForumPosts({bool showHidden = false}) {
    // Note: We use client-side filtering temporarily to avoid index errors.
    return _db.collection('forum_posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      var posts = snapshot.docs.map((doc) => ForumPost.fromFirestore(doc)).toList();
      if (!showHidden) {
        posts = posts.where((p) => !p.isHidden).toList();
      }
      return posts;
    });
  }

  // Gönderi Ekle
  Future<void> addForumPost(ForumPost post) async {
    final batch = _db.batch();
    final postRef = post.id.isNotEmpty 
        ? _db.collection('forum_posts').doc(post.id)
        : _db.collection('forum_posts').doc();
    
    batch.set(postRef, post.toMap());
    
    // Update user's last post time
    batch.update(_db.collection('users').doc(post.authorId), {
      'lastForumPostAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Kullanıcının Kendi Gönderilerini Getir
  Stream<ForumPost?> getPostStream(String postId) {
    return _db.collection('forum_posts').doc(postId).snapshots().map((doc) {
      if (doc.exists) {
        return ForumPost.fromFirestore(doc);
      }
      return null;
    });
  }

  // Kullanıcının Kendi Gönderilerini Getir
  Stream<List<ForumPost>> getUserForumPosts(String uid) {
    return _db.collection('forum_posts')
        .where('authorId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ForumPost.fromFirestore(doc)).toList();
    });
  }

  // Yorumları Getir (Stream)
  Stream<List<ForumComment>> getPostComments(String postId, {bool showHidden = false}) {
    return _db.collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      var comments = snapshot.docs.map((doc) => ForumComment.fromFirestore(doc)).toList();
      if (!showHidden) {
        comments = comments.where((c) => !c.isHidden).toList();
      }
      return comments;
    });
  }

  // Yorum Ekle (Ve yorum sayısını güncelle)
  Future<void> addForumComment(ForumComment comment) async {
    final postRef = _db.collection('forum_posts').doc(comment.postId);
    final userRef = _db.collection('users').doc(comment.authorId);
    
    // Batch write to add comment, increment count, and update cooldown atomically
    WriteBatch batch = _db.batch();
    
    DocumentReference commentRef;
    if (comment.id.isNotEmpty) {
      commentRef = postRef.collection('comments').doc(comment.id);
    } else {
      commentRef = postRef.collection('comments').doc();
    }
    
    batch.set(commentRef, comment.toMap());
    
    batch.update(postRef, {
      'commentCount': FieldValue.increment(1)
    });

    batch.update(userRef, {
      'lastCommentAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }
  // --- MODERASYON İŞLEMLERİ ---

  // Moderasyon Loglarını Getir
  Stream<List<Map<String, dynamic>>> getModerationLogs() {
    return _db.collection('moderation_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  // Moderasyon Logu Ekle
  Future<void> addModerationLog({
    required String type, // 'post' or 'comment'
    required String contentId,
    required String authorName,
    required String reason,
    required String content,
    String? postId, // Optional: for comments to find parent
  }) async {
    await _db.collection('moderation_logs').add({
      'type': type,
      'contentId': contentId,
      'postId': postId,
      'authorName': authorName,
      'reason': reason,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'aiDecision': 'pending', // Will be updated by AI logic if automated
      'status': 'pending',
    });
  }

  // Moderasyon Durumunu Güncelle
  Future<void> updateModerationLogStatus(String logId, String status) async {
    await _db.collection('moderation_logs').doc(logId).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // Gönderi Sil (Admin/Mod)
  Future<void> deleteForumPost(String postId) async {
    // 1. Delete comments subcollection? (Firestore doesn't auto-delete subcollections)
    // For now just delete the post doc.
    await _db.collection('forum_posts').doc(postId).delete();
  }

  // Yorum Sil (Admin/Mod)
  Future<void> deleteForumComment(String postId, String commentId) async {
    final postRef = _db.collection('forum_posts').doc(postId);
    await postRef.collection('comments').doc(commentId).delete();
    // Decrement comment count
    await postRef.update({'commentCount': FieldValue.increment(-1)});
  }

  // Yorum Oylama (Upvote/Downvote)
  Future<void> voteOnComment(String postId, String commentId, String userId, bool isUpvote) async {
    final commentRef = _db.collection('forum_posts').doc(postId).collection('comments').doc(commentId);
    
    // Simplistic Logic: Just toggle in array
    if (isUpvote) {
      await commentRef.update({
        'likes': FieldValue.arrayUnion([userId]),
        'dislikes': FieldValue.arrayRemove([userId])
      });
    } else {
      await commentRef.update({
        'dislikes': FieldValue.arrayUnion([userId]),
        'likes': FieldValue.arrayRemove([userId])
      });
    }
  }

  // Anket Oylama
  Future<void> voteOnPoll(String postId, String optionIndex) async {
    final user = auth_service.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postRef = _db.collection('forum_posts').doc(postId);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(postRef);
      if (!snapshot.exists) throw Exception("Post not found");

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      
      // Get current state
      Map<String, int> pollOptions = Map<String, int>.from(data['pollOptions'] ?? {});
      Map<String, String> pollVoters = Map<String, String>.from(data['pollVoters'] ?? {});
      
      String? previousVote = pollVoters[user.uid];

      if (previousVote == optionIndex) {
        // 1. Same option clicked -> Retract vote
        pollVoters.remove(user.uid);
        if (pollOptions.containsKey(optionIndex)) {
          pollOptions[optionIndex] = (pollOptions[optionIndex] ?? 1) - 1;
          if (pollOptions[optionIndex]! < 0) pollOptions[optionIndex] = 0; // Safety
        }
      } else {
        // 2. Different option clicked (or first vote)
        
        // Remove previous vote count if exists
        if (previousVote != null && pollOptions.containsKey(previousVote)) {
          pollOptions[previousVote] = (pollOptions[previousVote] ?? 1) - 1;
          if (pollOptions[previousVote]! < 0) pollOptions[previousVote] = 0;
        }

        // Add new vote
        pollVoters[user.uid] = optionIndex;
        pollOptions[optionIndex] = (pollOptions[optionIndex] ?? 0) + 1;
      }

      // Update
      transaction.update(postRef, {
        'pollOptions': pollOptions,
        'pollVoters': pollVoters,
      });
    });
  }
  
  // Bildirim Ekle
  // Usage in post_detail_screen.dart was: await _firestoreService.addNotification(userId: user.id, title: "...", message: "...", type: "comment");
  // Bildirim Ekle
  Future<void> addNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    String? postId,
    String? commentId,
  }) async {
    // 1. Save to Firestore (For notification center in app)
    await _db.collection('users').doc(targetUserId).collection('notifications').add({
      'title': title,
      'body': body,
      'message': body,
      'type': type,
      'postId': postId,
      'commentId': commentId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'isRead': false,
    });

    // 2. Trigger Push Notification via FCM
    try {
      final userDoc = await _db.collection('users').doc(targetUserId).get();
      final String? token = userDoc.data()?['fcmToken'];
      
      // Only send if user has notifications enabled for this type
      final bool notify = userDoc.data()?[type == 'reply' ? 'notifyReplies' : 'notifyMentions'] ?? true;

      if (token != null && notify) {
        await sendFcmNotification(
          token: token,
          title: title,
          body: body,
          data: {
            'type': type,
            'postId': postId,
            'commentId': commentId,
          },
        );
      }
    } catch (e) {
      debugPrint("FCM Trigger Error: $e");
    }
  }
  
  // İçerik Görünürlüğünü Ayarla (Gizle/Göster)
  Future<void> setContentVisibility(String type, String id, bool isHidden, {String? postId}) async {
    if (type == 'post') {
      await _db.collection('forum_posts').doc(id).update({'isHidden': isHidden});
    } else if (type == 'comment' && postId != null) {
      await _db.collection('forum_posts').doc(postId).collection('comments').doc(id).update({'isHidden': isHidden});
    }
  }

  // --- İSTATİSTİKLER (Admin Dashboard) ---

  Stream<int> getUserCount() {
    return _db.collection('users').snapshots().map((s) => s.size); // Not scalable for large apps, but fine for now
  }

  Stream<int> getTotalCarCount() {
    return _db.collectionGroup('garage').snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getPublishedNewsCount() {
    return _db.collection('news').snapshots().map((s) => s.size);
  }

  Stream<QuerySnapshot> getAllUsers() {
    return _db.collection('users').snapshots();
  }

  Stream<QuerySnapshot> getAllCars() {
    return _db.collectionGroup('garage').orderBy('createdAt', descending: true).snapshots();
  }

  Stream<int> getNewsPoolCount() {
    return _db.collection('scraped_news').snapshots().map((s) => s.size);
  }

  // --- VERİ KAYNAKLARI (Admin Panel) ---

  // Varsayılan Kaynakları Yükle (Migration)
  Future<void> restoreDefaultDataSources() async {
    final List<DataSourceItem> defaults = [
      // Kategori: Araç Bilgileri (Sıfır & İkinci El)
      DataSourceItem(
        title: "arabam.com",
        subtitle: "Sıfır ve İkinci el araç verileri, fiyat bilgisi",
        category: "Araç Bilgileri (Sıfır & İkinci El)",
        iconName: "link",
        colorName: "redAccent",
      ),
      DataSourceItem(
        title: "autotrader",
        subtitle: "Araç marka logoları ve simgeleri",
        category: "Araç Bilgileri (Sıfır & İkinci El)",
        iconName: "image",
        colorName: "redAccent",
      ),
      DataSourceItem(
        title: "sifiraracal.com",
        subtitle: "Sıfır araç teknik özellikleri ve görselleri",
        category: "Araç Bilgileri (Sıfır & İkinci El)",
        iconName: "photo_library",
        colorName: "redAccent",
      ),

      // Kategori: Otomobil ve Teknoloji Haberleri
      DataSourceItem(
        title: "donanimhaber",
        subtitle: "Otomobil teknolojisi haberleri",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "rss_feed",
        colorName: "blueAccent",
      ),
      DataSourceItem(
        title: "shiftdelete",
        subtitle: "Teknoloji ve otomobil gündemi",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "devices",
        colorName: "blueAccent",
      ),
      DataSourceItem(
        title: "motor1",
        subtitle: "Araç incelemeleri ve global haberler",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "rate_review",
        colorName: "blueAccent",
      ),
      DataSourceItem(
        title: "unsplash",
        subtitle: "Otomatik haber görselleri (Stok)",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "camera_alt",
        colorName: "blueAccent",
      ),

      // Kategori: Bakım ve Yedek Parça
      DataSourceItem(
        title: "lastik siparis",
        subtitle: "Lastik marka logoları ve ebat verileri",
        category: "Bakım ve Yedek Parça",
        iconName: "radio_button_checked",
        colorName: "orange",
      ),
      DataSourceItem(
        title: "turkoilmarket",
        subtitle: "Madeni yağ katalogları ve logoları",
        category: "Bakım ve Yedek Parça",
        iconName: "opacity",
        colorName: "orange",
      ),

      // Kategori: Allofcar Yapay Zeka Ekibi
      DataSourceItem(
        title: "Google Gemini",
        subtitle: "Tüm asistanların kullandığı ana dil modeli ve altyapı",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "cloud_circle",
        colorName: "purpleAccent",
      ),
      DataSourceItem(
        title: "Arıza Tespit Asistanı",
        subtitle: "Haynes Manuals, Şikayetvar ve Forum verileriyle eğitildi",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "build",
        colorName: "purpleAccent",
      ),
      DataSourceItem(
        title: "Bakım Asistanı",
        subtitle: "Turkoilmarket (Yağ) ve LastikSipariş (Lastik) kataloglarını baz alır",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "car_repair",
        colorName: "purpleAccent",
      ),
      DataSourceItem(
        title: "Araç Kıyaslama Asistanı",
        subtitle: "Motor1.com inceleme kriterleri ve kronik sorun analizleri",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "compare_arrows",
        colorName: "purpleAccent",
      ),
      DataSourceItem(
        title: "Oto Gurme Danışmanı",
        subtitle: "Genel piyasa analizi ve otomobil kültürü verileri",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "emoji_people",
        colorName: "purpleAccent",
      ),

      // Kategori: Benzin İstayon Verileri [NEW]
      DataSourceItem(
        title: "Benzin Fiyatları (Opet)",
        subtitle: "Opet API üzerinden sağlanan güncel yakıt fiyatları",
        category: "Benzin İstayon Verileri",
        iconName: "local_gas_station_rounded",
        colorName: "orange",
      ),
       DataSourceItem(
        title: "Opet API Status",
        subtitle: "Opet servislerinin anlık durum kontrolü",
        category: "Benzin İstayon Verileri",
        iconName: "api_rounded",
        colorName: "green",
      ),
      DataSourceItem(
        title: "Allofcar API Status",
        subtitle: "Allofcar backend servislerinin durumu",
        category: "Benzin İstayon Verileri",
        iconName: "monitor_heart_rounded",
        colorName: "green",
      ),
    ];

    WriteBatch batch = _db.batch();
    var colRef = _db.collection('data_sources');
    
    // Add items (Overwrite all logic of old method, but we should use addMissing for updates)
    // Keeping this for "Restore Defaults" button which implies reset/restore.
    for (var item in defaults) {
      batch.set(colRef.doc(), item.toMap());
    }
    
    await batch.commit();
  }

  // [NEW] Add only missing data sources (Sync)
  Future<void> addMissingDataSources() async {
     final List<DataSourceItem> defaults = [
      // Kategori: Araç Bilgileri (Sıfır & İkinci El)
      DataSourceItem(
        title: "arabam.com",
        subtitle: "Sıfır ve İkinci el araç verileri, fiyat bilgisi",
        category: "Araç Bilgileri (Sıfır & İkinci El)",
        iconName: "link",
        colorName: "redAccent",
      ),
      DataSourceItem(
        title: "autotrader",
        subtitle: "Araç marka logoları ve simgeleri",
        category: "Araç Bilgileri (Sıfır & İkinci El)",
        iconName: "image",
        colorName: "redAccent",
      ),
      DataSourceItem(
        title: "sifiraracal.com",
        subtitle: "Sıfır araç teknik özellikleri ve görselleri",
        category: "Araç Bilgileri (Sıfır & İkinci El)",
        iconName: "photo_library",
        colorName: "redAccent",
      ),

      // Kategori: Otomobil ve Teknoloji Haberleri
      DataSourceItem(
        title: "donanimhaber",
        subtitle: "Otomobil teknolojisi haberleri",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "rss_feed",
        colorName: "blueAccent",
      ),
      DataSourceItem(
        title: "shiftdelete",
        subtitle: "Teknoloji ve otomobil gündemi",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "devices",
        colorName: "blueAccent",
      ),
      DataSourceItem(
        title: "motor1",
        subtitle: "Araç incelemeleri ve global haberler",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "rate_review",
        colorName: "blueAccent",
      ),
      DataSourceItem(
        title: "unsplash",
        subtitle: "Otomatik haber görselleri (Stok)",
        category: "Otomobil ve Teknoloji Haberleri",
        iconName: "camera_alt",
        colorName: "blueAccent",
      ),

      // Kategori: Bakım ve Yedek Parça
      DataSourceItem(
        title: "lastik siparis",
        subtitle: "Lastik marka logoları ve ebat verileri",
        category: "Bakım ve Yedek Parça",
        iconName: "radio_button_checked",
        colorName: "orange",
      ),
      DataSourceItem(
        title: "turkoilmarket",
        subtitle: "Madeni yağ katalogları ve logoları",
        category: "Bakım ve Yedek Parça",
        iconName: "opacity",
        colorName: "orange",
      ),

      // Kategori: Allofcar Yapay Zeka Ekibi
      DataSourceItem(
        title: "Google Gemini",
        subtitle: "Tüm asistanların kullandığı ana dil modeli ve altyapı",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "cloud_circle",
        colorName: "purpleAccent",
      ),
      DataSourceItem(
        title: "Arıza Tespit Asistanı",
        subtitle: "Haynes Manuals, Şikayetvar ve Forum verileriyle eğitildi",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "build",
        colorName: "purpleAccent",
      ),
      DataSourceItem(
        title: "Bakım Asistanı",
        subtitle: "Turkoilmarket (Yağ) ve LastikSipariş (Lastik) kataloglarını baz alır",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "car_repair",
        colorName: "purpleAccent",
      ),
      DataSourceItem(
        title: "Araç Kıyaslama Asistanı",
        subtitle: "Motor1.com inceleme kriterleri ve kronik sorun analizleri",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "compare_arrows",
        colorName: "purpleAccent",
      ),
       DataSourceItem(
        title: "Oto Gurme Danışmanı",
        subtitle: "Genel piyasa analizi ve otomobil kültürü verileri",
        category: "Allofcar Yapay Zeka Ekibi",
        iconName: "emoji_people",
        colorName: "purpleAccent",
      ),

      // Kategori: Benzin İstayon Verileri [NEW]
      DataSourceItem(
        title: "Benzin Fiyatları (Opet)",
        subtitle: "Opet API üzerinden sağlanan güncel yakıt fiyatları",
        category: "Benzin İstayon Verileri",
        iconName: "local_gas_station_rounded",
        colorName: "orange",
      ),
       DataSourceItem(
        title: "Opet API Status",
        subtitle: "Opet servislerinin anlık durum kontrolü",
        category: "Benzin İstayon Verileri",
        iconName: "api_rounded",
        colorName: "green",
      ),
      DataSourceItem(
        title: "Allofcar API Status",
        subtitle: "Allofcar backend servislerinin durumu",
        category: "Benzin İstayon Verileri",
        iconName: "monitor_heart_rounded",
        colorName: "green",
      ),
    ];

    // 1. Get Existing Titles
    final snapshot = await _db.collection('data_sources').get();
    final existingTitles = snapshot.docs.map((d) => (d.data()['title'] as String).toLowerCase()).toSet();

    WriteBatch batch = _db.batch();
    var colRef = _db.collection('data_sources');
    bool added = false;

    for (var item in defaults) {
      if (!existingTitles.contains(item.title.toLowerCase())) {
         batch.set(colRef.doc(), item.toMap());
         added = true;
      }
    }

    if (added) {
      await batch.commit();
    }
  }

  // Veri Kaynaklarını Getir
  Stream<List<DataSourceItem>> getDataSources() {
    return _db.collection('data_sources').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DataSourceItem.fromFirestore(doc)).toList();
    });
  }

  // Veri Kaynağı Ekle
  Future<void> addDataSource(DataSourceItem item) async {
    await _db.collection('data_sources').add(item.toMap());
  }

  // Veri Kaynağı Güncelle
  Future<void> updateDataSource(DataSourceItem item) async {
    if (item.id == null || item.id!.isEmpty) return;
    await _db.collection('data_sources').doc(item.id).update(item.toMap());
  }

  // Veri Kaynağı Sil
  Future<void> deleteDataSource(String id) async {
    await _db.collection('data_sources').doc(id).delete();
  }
  // --- ARIZA TESPİT LOGLARI ---
  
  // Arıza Logu Ekle (Return Log ID)
  Future<String> addFaultLog(String uid, Map<String, dynamic> log) async {
    log['timestamp'] = FieldValue.serverTimestamp();
    // Default feedback fields
    log['isUseful'] = null; 
    log['correction'] = null;

    // 1. User Local Log
    DocumentReference ref = await _db
        .collection('users')
        .doc(uid)
        .collection('fault_logs')
        .add(log);
    
    // 2. Global Admin Log
    await _db.collection('fault_logs_global').doc(ref.id).set({
      ...log,
      'userId': uid,
      'originalDocId': ref.id,
    });

    return ref.id;
  }

  // Arıza Geri Bildirimi Güncelle
  Future<void> updateFaultFeedback(String uid, String logId, bool isUseful, {String? correction}) async {
    // 1. User collection güncelle (Bu kesinlikle var varsayıyoruz)
    await _db
        .collection('users')
        .doc(uid)
        .collection('fault_logs')
        .doc(logId)
        .update({
      'isUseful': isUseful,
      'correction': correction,
      'feedbackTimestamp': FieldValue.serverTimestamp(),
    });

    // 2. Global collection güncelle (Eski kayıtlarda olmayabilir)
    try {
      await _db.collection('fault_logs_global').doc(logId).update({
        'isUseful': isUseful,
        'correction': correction,
        'feedbackTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Eğer globalde yoksa (eski kayıt), önce user'dan okuyup sonra global'e yazalım
      debugPrint("Global log not found, creating from local... $e");
      
      try {
        DocumentSnapshot userLogSnap = await _db
            .collection('users')
            .doc(uid)
            .collection('fault_logs')
            .doc(logId)
            .get();
            
        if (userLogSnap.exists) {
          Map<String, dynamic> data = userLogSnap.data() as Map<String, dynamic>;
          // Add feedback fields
          data['isUseful'] = isUseful;
          data['correction'] = correction;
          data['feedbackTimestamp'] = FieldValue.serverTimestamp();
          data['userId'] = uid;
          data['originalDocId'] = logId;
          
          await _db.collection('fault_logs_global').doc(logId).set(data);
        }
      } catch (innerE) {
        debugPrint("Failed to backfill global log: $innerE");
      }
    }
  }

  // Admin Aksiyonunu Kaydet (AI Supervisor Sonrası)
  Future<void> updateAdminFaultAction(String logId, String action, {String? reasoning}) async {
    await _db.collection('fault_logs_global').doc(logId).update({
      'adminAction': action, // 'track' or 'ignore'
      'adminReasoning': reasoning,
      'adminActionTimestamp': FieldValue.serverTimestamp(),
    });
  }

  // Admin Aksiyonunu Geri Al (Yanlışlıkla basılırsa)
  Future<void> undoAdminFaultAction(String logId) async {
    await _db.collection('fault_logs_global').doc(logId).update({
      'adminAction': FieldValue.delete(),
      'adminReasoning': FieldValue.delete(),
      'adminActionTimestamp': FieldValue.delete(),
    });
  }

  // Arıza Geri Bildirimini Sıfırla (Geri Al)
  Future<void> resetFaultFeedback(String uid, String logId) async {
    // 1. User collection güncelle
    await _db
        .collection('users')
        .doc(uid)
        .collection('fault_logs')
        .doc(logId)
        .update({
      'isUseful': null,
      'correction': null,
      'feedbackTimestamp': null,
    });

    // 2. Global collection güncelle
    try {
      await _db.collection('fault_logs_global').doc(logId).update({
        'isUseful': null,
        'correction': null,
        'feedbackTimestamp': null,
      });
    } catch (e) {
      debugPrint("Global log reset error (might not exist): $e");
    }
  }

  // Arıza Loglarını Getir (Kullanıcı)
  Stream<List<Map<String, dynamic>>> getFaultLogs(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('fault_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Admin İçin Tüm Arıza Kayıtlarını Getir
  Stream<List<Map<String, dynamic>>> getAllFaultLogsForAdmin() {
    return _db
        .collection('fault_logs_global')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Arıza Loglarını Getir (Araca Özel)
  Stream<List<Map<String, dynamic>>> getFaultLogsForCar(String uid, String carId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('fault_logs')
        .where('carId', isEqualTo: carId)
        .snapshots()
        .map((snapshot) {
      var logs = snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Client-side Sort
      logs.sort((a, b) {
        Timestamp? t1 = a['timestamp'];
        Timestamp? t2 = b['timestamp'];
        if (t1 == null) return 1;
        if (t2 == null) return -1;
        return t2.compareTo(t1); // Descending
      });
      
      return logs;
    });
  }

  // Arıza Logu Sil
  Future<void> deleteFaultLog(String uid, String logId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('fault_logs')
        .doc(logId)
        .delete();
  }

  // --- MODERASYON & OYLAMA EKSTRALARI ---

  // Bekleyen Moderasyon Sayısı
  Stream<int> getPendingModerationCount() {
    return _db.collection('moderation_logs')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // Post Oylama (Faydalı/Faydasız)
  Future<void> voteOnPost(String postId, String userId, bool isHelpful) async {
    final postRef = _db.collection('forum_posts').doc(postId);
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      List<String> helpfulUids = List<String>.from(data['helpfulUids'] ?? []);
      List<String> unhelpfulUids = List<String>.from(data['unhelpfulUids'] ?? []);

      if (isHelpful) {
        if (helpfulUids.contains(userId)) {
          helpfulUids.remove(userId);
        } else {
          helpfulUids.add(userId);
          unhelpfulUids.remove(userId);
        }
      } else {
        if (unhelpfulUids.contains(userId)) {
          unhelpfulUids.remove(userId);
        } else {
          unhelpfulUids.add(userId);
          helpfulUids.remove(userId);
        }
      }

      transaction.update(postRef, {
        'helpfulUids': helpfulUids,
        'unhelpfulUids': unhelpfulUids,
      });
    });
  }

  // --- BLACKLIST (Geri Yüklenen) ---
   Future<void> addToBlacklist(String text, String type) async {
    final query = await _db.collection('blacklist')
        .where('text', isEqualTo: text)
        .where('type', isEqualTo: type)
        .get();

    if (query.docs.isEmpty) {
      await _db.collection('blacklist').add({
        'text': text,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeFromBlacklist(String docId) async {
    await _db.collection('blacklist').doc(docId).delete();
  }

  Stream<List<Map<String, dynamic>>> getBlacklist() {
    return _db.collection('blacklist')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<List<String>> getBlacklistSync() async {
    final snapshot = await _db.collection('blacklist').get();
    return snapshot.docs.map((doc) => doc.data()['text'] as String).toList();
  }

  // --- PLAKA KONTROL VE RAPORLAMA ---

  // Plaka Konrolü (Tüm Garajlarda)
  Future<Map<String, dynamic>?> checkPlateExists(String plate) async {
    try {
      // Boşlukları ve küçük harf farklarını temizleyerek arama yapabiliriz ama
      // şimdilik birebir eşleşme arıyoruz. Kaydederken formatlı kaydediyoruz.
      final querySnapshot = await _db
          .collectionGroup('garage')
          .where('plate', isEqualTo: plate)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        // doc.reference.parent.parent?.id -> User ID (owner)
        // doc.id -> Car ID
        final ownerId = doc.reference.parent.parent?.id;
        final carId = doc.id;
        
        return {
          'ownerId': ownerId,
          'carId': carId,
          'carData': doc.data(),
        };
      }
      return null;
    } catch (e) {
      debugPrint("Plate Check Error: $e");
      // Eğer index hatası varsa null dönebilir veya hatayı fırlatabiliriz.
      // Kullanıcıya engel olmamak adına hata durumunda false (bulunamadı) varsayabiliriz
      // ama production için riskli. Index hatası linkini logda görmek için rethrow diyelim şimdilik.
      debugPrint("Firestore Index Log: https://console.firebase.google.com/...");
      rethrow; // Rethrow to let UI know something went wrong
    }
  }

  Future<void> updateNotificationSettings(String uid, {
    bool? notifyMentions,
    bool? notifyReplies,
    bool? notifyNews,
    bool? notifySupport,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (notifyMentions != null) updates['notifyMentions'] = notifyMentions;
      if (notifyReplies != null) updates['notifyReplies'] = notifyReplies;
      if (notifyNews != null) updates['notifyNews'] = notifyNews;
      if (notifySupport != null) updates['notifySupport'] = notifySupport;

      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      debugPrint("Notification Update Error: $e");
    }
  }

  // Dil Güncelleme
  Future<void> updateLanguage(String uid, String languageCode) async {
    try {
      await _db.collection('users').doc(uid).update({'language': languageCode});
    } catch (e) {
      debugPrint("Language Update Error: $e");
    }
  }

  // Gizlilik Ayarları Güncelleme
  Future<void> updatePrivacySettings(String uid, {bool? hideCars, bool? hideName}) async {
    try {
      Map<String, dynamic> updates = {};
      if (hideCars != null) updates['hideCars'] = hideCars;
      if (hideName != null) updates['hideName'] = hideName;

      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      debugPrint("Privacy Update Error: $e");
    }
  }

  // Mükerrer Plaka Bildirimi
  Future<void> reportDuplicatePlate(String reporterUid, String plate, String? currentOwnerUid) async {
    try {
      await _db.collection('system_logs').add({
        'type': 'duplicate_plate_report',
        'reporterUid': reporterUid,
        'plate': plate,
        'currentOwnerUid': currentOwnerUid ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, resolved, dismissed
      });
    } catch (e) {
      debugPrint("Report Duplicate Error: $e");
    }
  }

  // Kullanıcı Şikayet Etme
  Future<void> reportUser(String reporterUid, String reportedUid, String reason, String description) async {
    try {
      await _db.collection('system_logs').add({
        'type': 'user_report',
        'reporterUid': reporterUid,
        'reportedUid': reportedUid,
        'reason': reason,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint("Support Request Error: $e");
      rethrow;
    }
  }

  // Profil Resmi Yükle (Robust with Fallback)
  Future<String?> uploadProfileImage(File image, String uid) async {
    try {
      // Use timestamp to ensure unique filename and URL, preventing caching issues
      final fileName = 'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folderPath = 'profile_images';
      
      try {
        // Attempt 1: Default instance
        final ref = _storage.ref().child(folderPath).child(fileName);
        final uploadTask = await ref.putFile(image);
        return await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Default Bucket Upload Failed (Profile): $e");
        
        // Attempt 2: Fallback to appspot.com bucket
        try {
          // Try alternative bucket name if default fails (common in some setups)
          final fallbackStorage = FirebaseStorage.instanceFor(bucket: "gs://allofcar-1.appspot.com");
          final ref = fallbackStorage.ref().child(folderPath).child(fileName);
          final uploadTask = await ref.putFile(image);
          return await uploadTask.ref.getDownloadURL();
        } catch (fallbackError) {
           debugPrint("Fallback Bucket Upload Failed (Profile): $fallbackError");
           rethrow; 
        }
      }
    } catch (e) {
      debugPrint("Profile Image Upload Error: $e");
      return null;
    }
  }

  // Kullanıcı Adı, İsim veya Profil Resmi Değişikliğini Senkronize Et
  Future<void> synchronizeUserData(String uid, String newName, String newUsername, {String? newProfileImageUrl}) async {
    try {
      WriteBatch batch = _db.batch();
      
      // 1. Forum Gönderilerini Güncelle
      final postsSnapshot = await _db
          .collection('forum_posts')
          .where('authorId', isEqualTo: uid)
          .get();
          
      for (var doc in postsSnapshot.docs) {
        final Map<String, dynamic> updates = {
          'authorName': newName,
          'authorUsername': newUsername,
        };
        if (newProfileImageUrl != null) {
          updates['authorAvatarUrl'] = newProfileImageUrl;
        }
        batch.update(doc.reference, updates);
      }

      int commentsCount = 0;

      // 2. Yorumları Güncelle (Collection Group Query - Optimized with Index)
      try {
        final commentsSnapshot = await _db
            .collectionGroup('comments')
            .where('authorId', isEqualTo: uid)
            .get();
        
        commentsCount = commentsSnapshot.size;
            
        for (var doc in commentsSnapshot.docs) {
           final Map<String, dynamic> updates = {
            'authorName': newName,
            'authorUsername': newUsername,
          };
          if (newProfileImageUrl != null) {
            updates['authorAvatarUrl'] = newProfileImageUrl;
          }
          batch.update(doc.reference, updates);
        }
      } catch (e) {
        debugPrint("Warning: Comments sync failed: $e");
      }
      
      int operationCount = postsSnapshot.size + commentsCount;
      if (operationCount > 450) {
         // Batch limit fallback (basit commit)
         await batch.commit();
      } else {
         await batch.commit();
      }
    } catch (e) {
      debugPrint("Synchronization Error: $e");
    }
  }

  // YÖNETİCİ METODLARI
  


  // Kullanıcıya Özel Destek Talepleri 
  // Kullanıcı Banla / Ban Kaldır

  // Sistem Loglarını Getir (Şikayetler vb.)
  Stream<QuerySnapshot> getSystemLogs({String? type}) {
    var query = _db.collection('system_logs').orderBy('timestamp', descending: true);
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    return query.snapshots();
  }
  
  // Log Durumunu Güncelle (Resolved / Dismissed)
  Future<void> updateLogStatus(String logId, String status) async {
     await _db.collection('system_logs').doc(logId).update({'status': status});
  }

  // Kullanıcı Adı Kontrolü (Unique)
  Future<bool> checkUsernameExists(String username) async {
    final snapshot = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Kullanıcı FCM Token Güncelleme
  Future<void> updateUserFcmToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("FCM Token Update Error: $e");
    }
  }


  // --- SUPPORT SYSTEM ---

  // 1. Submit a Request (User)
  Future<void> submitSupportRequest({
    required String uid,
    required String email,
    required String name,
    required String type, // 'support', 'suggestion', 'complaint'
    required String message,
  }) async {
    try {
      final docRef = await _db.collection('support_requests').add({
        'userId': uid,
        'userEmail': email,
        'userName': name,
        'type': type,
        'message': message,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'reply': null,
        'repliedAt': null,
        'imageUrl': null,
        'imagePath': null,
      });

      // Notify Admins
      await sendFcmNotification(
        topic: 'admin_notifications',
        title: "Yeni Destek Talebi: $type",
        body: "$name: ${message.length > 50 ? '${message.substring(0, 47)}...' : message}",
        data: {'requestId': docRef.id, 'type': 'support_request'},
      );
    } catch (e) {
      debugPrint("Error submitting support request: $e");
      rethrow;
    }
  }

  // Overloaded for Image Support
  Future<void> submitSupportRequestWithImage({
    required String uid,
    required String email,
    required String name,
    required String type,
    required String message,
    String? imageUrl,
    String? imagePath,
  }) async {
    try {
      final docRef = await _db.collection('support_requests').add({
        'userId': uid,
        'userEmail': email,
        'userName': name,
        'type': type,
        'message': message,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'reply': null,
        'repliedAt': null,
        'imageUrl': imageUrl,
        'imagePath': imagePath,
      });

      // Notify Admins
      await sendFcmNotification(
        topic: 'admin_notifications',
        title: "Yeni Destek Talebi: $type (Fotoğraflı)",
        body: "$name: ${message.length > 50 ? '${message.substring(0, 47)}...' : message}",
        data: {'requestId': docRef.id, 'type': 'support_request'},
      );
    } catch (e) {
      debugPrint("Error submitting support request: $e");
      rethrow;
    }
  }

  Future<void> deleteSupportRequest(String requestId) async {
    try {
      await _db.collection('support_requests').doc(requestId).delete();
    } catch (e) {
      debugPrint("Error deleting support request: $e");
      rethrow;
    }
  }

  // 2. Reply to Request (Admin)
  Future<void> replyToSupportRequest(String requestId, String replyMessage) async {
    try {
      // 1. Update Firestore
      await _db.collection('support_requests').doc(requestId).update({
        'reply': replyMessage,
        'status': 'replied',
        'repliedAt': FieldValue.serverTimestamp(),
      });

      // 2. Get User Token to Notify
      final doc = await _db.collection('support_requests').doc(requestId).get();
      final userId = doc.data()?['userId'];
      
      if (userId != null) {
        final userDoc = await _db.collection('users').doc(userId).get();
        final token = userDoc.data()?['fcmToken'];

        if (token != null) {
          // Send Notification to User
          await sendFcmNotification(
            token: token,
            title: "Destek Talebiniz Yanıtlandı",
            body: replyMessage.length > 100 ? "${replyMessage.substring(0, 97)}..." : replyMessage,
            data: {'requestId': requestId, 'type': 'support_reply'},
          );
        }
      }
    } catch (e) {
      debugPrint("Error replying to support request: $e");
      rethrow;
    }
  }

  // 3. Get All Requests (Admin)
  Stream<QuerySnapshot> getAllSupportRequests() {
    return _db.collection('support_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 4. Get User Requests (User History)
  Stream<QuerySnapshot> getUserSupportRequests(String uid) {
    return _db.collection('support_requests')
        .where('userId', isEqualTo: uid)
        // .orderBy('createdAt', descending: true) // Disable to avoid Index requirement for now
        .snapshots();

  }

} // End of FirestoreService

// --- MODEL SINIFLARI ---

class DataSourceItem {
  String? id;
  String title;
  String subtitle;
  String category;
  String iconName;
  String colorName;

  DataSourceItem({
    this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.iconName,
    required this.colorName,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'category': category,
      'iconName': iconName,
      'colorName': colorName,
    };
  }

  factory DataSourceItem.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return DataSourceItem(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      category: data['category'] ?? 'Genel',
      iconName: data['iconName'] ?? 'circle',
      colorName: data['colorName'] ?? 'blue',
    );
  }
}




