import 'dart:io'; // Added for Platform check
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../screens/post_detail_screen.dart';
import '../screens/news_detail_screen.dart';
import '../screens/support_screen.dart';
import '../models/forum_model.dart';
import '../models/news_model.dart';
import '../screens/admin_panel_screen.dart'; // Admin Panel


// This function must be a top-level function and cannot be a method of a class.
// It is used for handling background messages when the app is terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure to call `initializeApp` before using them.
  await Firebase.initializeApp(); 
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Setup Local Notifications (No network required)
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification tapped (Foreground): ${response.payload}");
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!); // Fixed: Decode JSON
              _handleNotificationTap(data);
            } catch (e) {
              debugPrint("Error parsing notification payload: $e");
            }
          }
        },
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'allofcar_main_channel',
        'General Notifications',
        description: 'This channel is used for general app notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 2. Firebase Messaging setup (Requires network)
      await _setupFCM(channel);

      // Subscribe to news topic
      await _fcm.subscribeToTopic('news_notifications');

      // 3. Listen to News & System Broadcasts (Firestore based fallback)
      _listenToBroadcasts(channel);
      
      _initialized = true;
    } catch (e) {
      debugPrint("Notification Service Local Initialization Error: $e");
    }
  }

  // Firebase Messaging setup (Requires network)
  Future<void> _setupFCM(AndroidNotificationChannel channel) async {
    try {
      // Android 13+ Permission Request via Local Notifications Plugin
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      }
      
      // Check if app ID opened from TERMINATED state
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("App opened from terminated state via notification: ${initialMessage.data}");
        _handleNotificationTap(initialMessage.data);
      }

      // Foreground Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message received: ${message.notification?.title}');
        _showLocalNotification(message, channel);
      });

      // Background -> Open Handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification caused app to open from background: ${message.data}');
         _handleNotificationTap(message.data);
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      String? apnsToken;
      // [FIX] iOS: Explicitly wait for APNs token before asking for FCM token
      if (Platform.isIOS) { 
        apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          debugPrint("APNs Token not ready, waiting...");
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _fcm.getAPNSToken();
          debugPrint("APNs Token after wait: $apnsToken");
        }
      }

      // [DEBUG] Show Token on Screen logic removed for release


      await _saveTokenToDatabase();
      
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(token: newToken);
      });
    } catch (e) {
      debugPrint("FCM Setup Error (Possibly network): $e");
    }
  }

  // Handle Notification Tap Logic
  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final type = data['type'];
    final navigator = navigatorKey.currentState;
    
    // Slight delay to ensure app is ready if coming from terminated
    if (navigator == null) {
       await Future.delayed(const Duration(milliseconds: 500));
    }
    
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint("Navigator State is null, cannot navigate");
      return;
    }

    debugPrint("Handling notification type: $type with data: $data"); // Added debug

    if (type == 'reply' || type == 'mention') {
      final postId = data['postId'];
      if (postId != null) {
        // Fetch Post Data
        try {
          final doc = await FirebaseFirestore.instance.collection('forum_posts').doc(postId).get();
          if (doc.exists) {
            final post = ForumPost.fromFirestore(doc);
            nav.push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
          }
        } catch (e) {
          debugPrint("Error navigating to post: $e");
        }
      }
    } else if (type == 'news') {
      // Check for both keys just in case
      final newsId = data['newsId'] ?? data['articleId'];
      if (newsId != null) {
         try { 
           final doc = await FirebaseFirestore.instance.collection('news').doc(newsId).get();
           if (doc.exists) {
             final article = NewsArticle.fromFirestore(doc);
             nav.push(MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)));
           }
         } catch (e) {
           debugPrint("Error navigating to news: $e");
         }
      }
    } else if (type == 'support_reply') {
       nav.push(MaterialPageRoute(builder: (_) => const SupportScreen()));
    } else if (type == 'support_request') {
       // For Admin: Navigate to Admin Panel Support Tab (Index 10)
       nav.push(MaterialPageRoute(builder: (_) => const AdminPanelScreen(initialIndex: 10)));
    }
  }

  Future<void> _saveTokenToDatabase({String? token}) async {
    String? fcmToken = token ?? await _fcm.getToken();
    String? uid = _authService.currentUser?.uid;
    
    if (fcmToken != null && uid != null) {
      debugPrint("Saving FCM Token: $fcmToken");
      await _firestoreService.updateUserFcmToken(uid, fcmToken);
    }
  }

  void _showLocalNotification(RemoteMessage message, AndroidNotificationChannel channel) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _showLocal(
        title: notification.title ?? '',
        body: notification.body ?? '',
        payload: jsonEncode(message.data), // Fixed: JSON Encode
        channel: channel,
      );
    }
  }


  void _showLocal({
    required String title,
    required String body,
    String? payload,
    required AndroidNotificationChannel channel,
  }) {
    _localNotifications.show(
      title.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload, 
    );
  }

  void _listenToBroadcasts(AndroidNotificationChannel channel) {
    _firestoreService.listenToBroadcastNotifications().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          
          // Don't show if older than 1 minute (prevent spam on restart)
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null && DateTime.now().difference(timestamp.toDate()).inMinutes > 2) {
             continue;
          }

          debugPrint("Broadcast Notification Received: ${data['title']}");

          _showLocal(
            title: data['title'] ?? 'AllofCar Duyuru',
            body: data['body'] ?? '',
            payload: data['data']?.toString(),
            channel: channel,
          );
        }
      }
    });
  }

  // Public methods for Settings Screen
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      debugPrint("Error subscribing to topic $topic: $e");
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint("Error unsubscribing from topic $topic: $e");
    }
  }
}
