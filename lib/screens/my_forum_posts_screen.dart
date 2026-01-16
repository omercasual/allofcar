import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/forum_model.dart';
import 'post_detail_screen.dart';
import 'home_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class MyForumPostsScreen extends StatelessWidget {
  const MyForumPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final AuthService authService = AuthService();
    final String uid = authService.currentUser?.uid ?? '';

    String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.grey[50], // Consistent background
      appBar: AppBar(
        title: Text(
          _t('my_posts'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<ForumPost>>(
        stream: firestoreService.getUserForumPosts(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "${_t('error')}: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? [];
          
          // Client-side sorting (newest first) to avoid Firestore Index requirement
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.forum_outlined, size: 80, color: Colors.grey[300]),
                   const SizedBox(height: 20),
                    Text(
                      _t('no_posts_yet'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                   const SizedBox(height: 20),
                   ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to HomeScreen and select Forum tab (index 2)
                         // Check if we can pop to root or push replacment
                         Navigator.of(context).pushAndRemoveUntil(
                           MaterialPageRoute(
                             builder: (context) => const HomeScreen(initialIndex: 2),
                           ),
                           (route) => false,
                         );
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                       label: Text(
                        _t('new_post_button'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0059BC),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              String dateStr = DateFormat('dd.MM.yyyy HH:mm').format(post.timestamp);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(post: post),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                       BoxShadow(
                         color: Colors.grey.withValues(alpha: 0.05),
                         blurRadius: 10,
                         offset: const Offset(0, 4),
                       ),
                    ],
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(10),
                             decoration: BoxDecoration(
                               color: const Color(0xFF0059BC).withValues(alpha: 0.1),
                               borderRadius: BorderRadius.circular(10),
                             ),
                             child: const Icon(
                               Icons.article_rounded, 
                               color: Color(0xFF0059BC),
                               size: 20,
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Text(
                               post.title,
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                                 color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
                               ),
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                           // Optional: Status Indicator (Hidden/Visible)
                           if(post.isHidden)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text("Gizli", style: TextStyle(color: Colors.red[700], fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                         ],
                       ),
                       const Padding(
                         padding: EdgeInsets.symmetric(vertical: 12),
                         child: Divider(height: 1),
                       ),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                                Text(
                                  dateStr,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.message_outlined, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                                 Text(
                                  "${post.commentCount} ${_t('comments_label')}",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                         ],
                       )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
