import 'package:cloud_firestore/cloud_firestore.dart';

class ForumPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername; // [NEW]
  final String? authorAvatarUrl; // [NEW] Persist avatar in post
  final String? carInfo; // e.g. "Passat 1.4 TSI Trendlline"
  final String title;
  final String content;
  final DateTime timestamp;
  final int commentCount;
  
  // New Features
  final List<String> images; // URLs or Base64
  final Map<String, int> pollOptions; // Option : VoteCount
  final Map<String, String> pollVoters; // UserId : Option (To prevent double voting & allow updates)
  final bool isHidden; // For moderation
  final String? moderationReason;

  final List<String> helpfulUids;
  final List<String> unhelpfulUids;
  final bool isNameHidden; 
  final bool isAdmin; // [NEW] Admin badge flag

  ForumPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl, // [NEW]
    this.carInfo,
    required this.title,
    required this.content,
    required this.timestamp,
    this.commentCount = 0,
    this.images = const [],
    this.pollOptions = const {},
    this.pollVoters = const {},
    this.isHidden = false,
    this.moderationReason,
    this.helpfulUids = const [],
    this.unhelpfulUids = const [],
    this.isNameHidden = false,
    this.isAdmin = false,
  });

  factory ForumPost.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ForumPost(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonim',
      authorUsername: data['authorUsername'] ?? '',
      authorAvatarUrl: data['authorAvatarUrl'], // [NEW]
      carInfo: data['carInfo'],
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentCount: data['commentCount'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      pollOptions: Map<String, int>.from(data['pollOptions'] ?? {}),
      pollVoters: Map<String, String>.from(data['pollVoters'] ?? {}),
      isHidden: data['isHidden'] ?? false,
      helpfulUids: List<String>.from(data['helpfulUids'] ?? []),
      unhelpfulUids: List<String>.from(data['unhelpfulUids'] ?? []),
      isNameHidden: data['isNameHidden'] ?? false,
      isAdmin: data['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl, // [NEW]
      'carInfo': carInfo,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'commentCount': commentCount,
      'images': images,
      'pollOptions': pollOptions,
      'pollVoters': pollVoters,
      'isHidden': isHidden,
      'moderationReason': moderationReason,
      'helpfulUids': helpfulUids,
      'unhelpfulUids': unhelpfulUids,
      'isNameHidden': isNameHidden,
      'isAdmin': isAdmin,
    };
  }
}

class ForumComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorUsername; // [NEW]
  final String? authorAvatarUrl; // [NEW] Persist avatar in comment
  final String content;
  final DateTime timestamp;
  final bool isAdmin; 
  
  // Moderation
  final bool isHidden;
  final String? moderationReason;

  final List<String> likeUids;
  final List<String> dislikeUids;
  final bool isNameHidden; // [NEW]

  ForumComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl, // [NEW]
    required this.content,
    required this.timestamp,
    this.isAdmin = false,
    this.isHidden = false,
    this.moderationReason,
    this.likeUids = const [],
    this.dislikeUids = const [],
    this.isNameHidden = false,
  });

  factory ForumComment.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ForumComment(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonim',
      authorUsername: data['authorUsername'] ?? '',
      authorAvatarUrl: data['authorAvatarUrl'], // [NEW]
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAdmin: data['isAdmin'] ?? false,
      isHidden: data['isHidden'] ?? false,
      moderationReason: data['moderationReason'],
      likeUids: List<String>.from(data['likeUids'] ?? []),
      dislikeUids: List<String>.from(data['dislikeUids'] ?? []),
      isNameHidden: data['isNameHidden'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl, // [NEW]
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isAdmin': isAdmin,
      'isHidden': isHidden,
      'moderationReason': moderationReason,
      'likeUids': likeUids,
      'dislikeUids': dislikeUids,
      'isNameHidden': isNameHidden,
    };
  }
}
