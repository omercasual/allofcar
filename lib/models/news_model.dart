import 'package:cloud_firestore/cloud_firestore.dart';

class NewsArticle {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final String category;
  final int commentCount;
  final int viewCount;
  final List<String> likes;
  final List<String> dislikes;

  NewsArticle({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    required this.category,
    this.commentCount = 0,
    this.viewCount = 0,
    this.likes = const [],
    this.dislikes = const [],
  });

  factory NewsArticle.fromFirestore(DocumentSnapshot doc) {
    return NewsArticle.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory NewsArticle.fromMap(Map<String, dynamic> data, String id) {
    return NewsArticle(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      category: data['category'] ?? 'Genel',
      commentCount: data['commentCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      likes: List<String>.from(data['likes'] ?? []),
      dislikes: List<String>.from(data['dislikes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'category': category,
      'commentCount': commentCount,
      'viewCount': viewCount,
      'likes': likes,
      'dislikes': dislikes,
    };
  }
}
