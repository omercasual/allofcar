import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/news_model.dart';
import '../models/forum_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import '../widgets/translatable_text.dart'; // [NEW]
import 'package:cached_network_image/cached_network_image.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  const NewsDetailScreen({super.key, required this.article});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  
  bool _isSending = false;
  bool _isAdmin = false;
  bool _isNameHidden = false;

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _incrementViews();
  }

  void _incrementViews() {
    _firestoreService.incrementNewsViewCount(widget.article.id);
  }

  void _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _firestoreService.getUser(user.uid);
      if (mounted) {
        setState(() {
          _isAdmin = userData?.isAdmin ?? false;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final userData = await _firestoreService.getUser(user.uid);
      final authorName = userData?.name ?? _t('anonymous');
      final authorUsername = userData?.username ?? "user";

      final comment = ForumComment(
        id: '',
        postId: widget.article.id, // we use news article id as postId
        authorId: user.uid,
        authorName: authorName,
        authorUsername: authorUsername,
        content: text,
        timestamp: DateTime.now(),
        isAdmin: _isAdmin,
        isNameHidden: _isNameHidden,
      );

      await _firestoreService.addNewsComment(comment);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.article.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.article.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.blueGrey[900]),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.blueGrey[900], 
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 50))
                          ),
                        )
                      : Container(color: Colors.blueGrey[900]),
                  // Gradient Overlay for readability of back button and status bar
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                        stops: [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              transform: Matrix4.translationValues(0, -30, 0),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.article.category.toUpperCase(),
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMMM yyyy', LanguageService().currentLanguage == 'tr' ? 'tr_TR' : 'en_US').format(widget.article.timestamp),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TranslatableText(
                    widget.article.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.2),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  TranslatableText(
                    widget.article.content,
                    style: TextStyle(fontSize: 17, height: 1.8, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87, fontWeight: FontWeight.normal),
                  ),
                   const SizedBox(height: 24),
                   const Divider(),
                   const SizedBox(height: 24),
                   
                   // News Sentiment & Views Section
                   StreamBuilder<DocumentSnapshot>(
                     stream: FirebaseFirestore.instance.collection('news').doc(widget.article.id).snapshots(),
                     builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        if (data == null) return const SizedBox.shrink();
                        
                        final viewCount = data['viewCount'] ?? 0;
                        final likes = List<String>.from(data['likes'] ?? []);
                        final dislikes = List<String>.from(data['dislikes'] ?? []);
                        final userId = _auth.currentUser?.uid;
                        final isLiked = userId != null && likes.contains(userId);
                        final isDisliked = userId != null && dislikes.contains(userId);

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildSentimentButton(
                                      icon: Icons.thumb_up_rounded,
                                      activeColor: Colors.green,
                                      count: likes.length,
                                      isActive: isLiked,
                                      onTap: () {
                                        if (userId != null) _firestoreService.toggleNewsLike(widget.article.id, userId);
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    _buildSentimentButton(
                                      icon: Icons.thumb_down_rounded,
                                      activeColor: Colors.red,
                                      count: dislikes.length,
                                      isActive: isDisliked,
                                      onTap: () {
                                        if (userId != null) _firestoreService.toggleNewsDislike(widget.article.id, userId);
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.remove_red_eye_rounded, size: 18, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      NumberFormat("#,###", LanguageService().currentLanguage == 'tr' ? 'tr_TR' : 'en_US').format(viewCount),
                                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                          ],
                        );
                     }
                   ),
                   
                   const SizedBox(height: 16),
                   Row(
                     children: [
                       Text(
                         _t('comments_title'),
                         style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                       ),
                       const SizedBox(width: 8),
                       Container(
                         padding: const EdgeInsets.all(6),
                         decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                         child: StreamBuilder<List<ForumComment>>(
                           stream: _firestoreService.getNewsComments(widget.article.id),
                           builder: (context, snapshot) => Text(
                             "${snapshot.data?.length ?? 0}",
                             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          StreamBuilder<List<ForumComment>>(
            stream: _firestoreService.getNewsComments(widget.article.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(_t('no_comments_yet'), style: const TextStyle(color: Colors.grey))),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCommentTile(comments[index]),
                  childCount: comments.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomSheet: _buildCommentInput(),
    );
  }

  Widget _buildCommentTile(ForumComment comment) {
    final authorDisplay = comment.isNameHidden ? "@${comment.authorUsername}" : comment.authorName;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            radius: 18,
            child: Text(authorDisplay[0].toUpperCase(), style: TextStyle(color: Colors.blue[800], fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(authorDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (comment.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue[800], borderRadius: BorderRadius.circular(4)),
                        child: Text(_t('admin_tag'), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                TranslatableText(comment.content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM HH:mm').format(comment.timestamp),
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Checkbox(
                value: _isNameHidden,
                onChanged: (v) => setState(() => _isNameHidden = v ?? false),
                activeColor: Colors.blue[800],
               ),
              Text(_t('hide_my_name'), style: const TextStyle(fontSize: 12)),
              const Spacer(),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _t('write_comment_hint'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  maxLines: null,
                ),
              ),
              if (_isSending)
                const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              else
                IconButton(
                  onPressed: _submitComment,
                  icon: Icon(Icons.send_rounded, color: Colors.blue[800]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentButton({
    required IconData icon,
    required Color activeColor,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? activeColor.withOpacity(0.3) : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? activeColor : Colors.grey[400], size: 20),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: TextStyle(
                color: isActive ? activeColor : Colors.grey[600],
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
