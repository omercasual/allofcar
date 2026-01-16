import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String? id; // Firebase UID
  final String name;
  final String username;
  final String email;
  final String password;
  final String? phone;
  final bool isAdmin; // Admin role
  final bool isBanned; // [NEW] Ban status
  final DateTime? banExpiration; // [NEW] Timed Ban Expiration
  final bool hideCars; // [NEW] Privacy
  final bool hideName; // [NEW] Privacy
  // Notifications
  final bool notifyMentions;
  final bool notifyReplies;
  final bool notifyNews;
  final bool notifySupport;
  final String language; // [NEW] Language code
  
  final DateTime? lastForumPostAt;
  final DateTime? lastCommentAt;
  final DateTime? createdAt; // [NEW] Registration Date
  final String? profileImageUrl; // [NEW] Profile Picture URL

  User({
    this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    this.phone,
    this.isAdmin = false, // Default to false
    this.isBanned = false, // [NEW] Default to false
    this.banExpiration, // [NEW]
    this.hideCars = false, // [NEW] Default to false
    this.hideName = false, // [NEW] Default to false
    this.notifyMentions = true, // [NEW] Default true
    this.notifyReplies = true, // [NEW] Default true
    this.notifyNews = true, // [NEW] Default true
    this.notifySupport = true, // [NEW] Default true
    this.language = 'tr', // [NEW] Default Turkish
    this.lastForumPostAt,
    this.lastCommentAt,
    this.createdAt, // [NEW]
    this.profileImageUrl, // [NEW]
  });

  // Veritabanına kaydederken Map'e çevir
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'phone': phone,
      'isAdmin': isAdmin,
      'isBanned': isBanned,
      'banExpiration': banExpiration != null ? Timestamp.fromDate(banExpiration!) : null, // [NEW]
      'hideCars': hideCars, // [NEW]
      'hideName': hideName, // [NEW]
      'notifyMentions': notifyMentions,
      'notifyReplies': notifyReplies,
      'notifyNews': notifyNews,
      'notifySupport': notifySupport,
      'language': language, // [NEW]
      'lastForumPostAt': lastForumPostAt?.toIso8601String(),
      'lastCommentAt': lastCommentAt?.toIso8601String(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null, // [NEW] Store as Timestamp
      'profileImageUrl': profileImageUrl, // [NEW]
    };
  }

  // Veritabanından okurken Nesneye çevir
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      phone: map['phone'],
      isAdmin: map['isAdmin'] ?? false,
      isBanned: map['isBanned'] ?? false,
      banExpiration: _parseDateTime(map['banExpiration']), // [NEW]
      hideCars: map['hideCars'] ?? false, // [NEW]
      hideName: map['hideName'] ?? false, // [NEW]
      notifyMentions: map['notifyMentions'] ?? true, // Default true
      notifyReplies: map['notifyReplies'] ?? true, // Default true
      notifyNews: map['notifyNews'] ?? true, // Default true
      notifySupport: map['notifySupport'] ?? true, // Default true
      language: map['language'] ?? 'tr', // [NEW]
      lastForumPostAt: _parseDateTime(map['lastForumPostAt']),
      lastCommentAt: _parseDateTime(map['lastCommentAt']),
      createdAt: _parseDateTime(map['createdAt']), // [NEW]
      profileImageUrl: map['profileImageUrl'], // [NEW]
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

