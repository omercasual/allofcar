import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/forum_model.dart';
import '../services/firestore_service.dart';
import '../services/moderation_service.dart';
import '../widgets/user_avatar.dart'; // [NEW]
import '../widgets/translatable_text.dart'; // [NEW]
import 'public_profile_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

import 'dart:async';
import '../models/user_model.dart' as model;
class PostDetailScreen extends StatefulWidget {
  final ForumPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ModerationService _moderationService = ModerationService();
  bool _isSending = false;
  bool _isAdmin = false;
  bool _isNameHidden = false; // [NEW]
  int _currentImageIndex = 0;
  
  // Mention System
  List<model.User> _mentionSuggestions = []; 
  bool _showMentionSuggestions = false;
  Timer? _debounce;
  String _currentMentionQuery = "";
  
  String? _fetchedAuthorAvatar; // [NEW] Fallback for main post

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _commentController.addListener(_onCommentChanged);
    
    // [NEW] Fetch Avatar if missing (Fix for existing posts + robustness)
    if (widget.post.authorAvatarUrl == null) {
      _fetchPostAuthorAvatar();
    }
  }

  // [NEW]
  void _fetchPostAuthorAvatar() async {
    try {
      final userDoc = await _firestoreService.getUser(widget.post.authorId);
      if (mounted && userDoc?.profileImageUrl != null) {
        setState(() => _fetchedAuthorAvatar = userDoc!.profileImageUrl);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCommentChanged() {
    String text = _commentController.text;
    int cursorPosition = _commentController.selection.baseOffset;
    
    if (cursorPosition < 0) return;
    
    String textBeforeCursor = text.substring(0, cursorPosition);
    int atIndex = textBeforeCursor.lastIndexOf('@');
    
    if (atIndex != -1) {
       if (atIndex == 0 || textBeforeCursor[atIndex - 1] == ' ' || textBeforeCursor[atIndex - 1] == '\n') {
          String query = textBeforeCursor.substring(atIndex + 1);
          if (!query.contains(' ')) {
             _currentMentionQuery = query;
             if (_debounce?.isActive ?? false) _debounce!.cancel();
             _debounce = Timer(const Duration(milliseconds: 300), () {
               _searchUsersForMention(query);
             });
             return; 
          }
       }
    }
    
    if (_showMentionSuggestions) {
      setState(() => _showMentionSuggestions = false);
    }
  }

  Future<void> _searchUsersForMention(String query) async {
     if (query.isEmpty) {
       if (mounted) setState(() => _showMentionSuggestions = false);
       return;
     }

     final users = await _firestoreService.searchUsers(query);
     if (mounted) {
       setState(() {
         _mentionSuggestions = users;
         _showMentionSuggestions = users.isNotEmpty;
       });
     }
  }

  void _selectMention(String username) {
      String text = _commentController.text;
      int cursorPosition = _commentController.selection.baseOffset;
      String textBeforeCursor = text.substring(0, cursorPosition);
      int atIndex = textBeforeCursor.lastIndexOf('@');
      
      if (atIndex != -1) {
          String newText = text.substring(0, atIndex) + "@$username " + text.substring(cursorPosition);
          _commentController.text = newText;
          _commentController.selection = TextSelection.fromPosition(TextPosition(offset: atIndex + username.length + 2)); 
      }
      
      setState(() => _showMentionSuggestions = false);
  }

  void _handleMentionTap(String username) async {
      final userId = await _firestoreService.getUserIdByUsername(username);
      if (userId != null && mounted) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(
             userId: userId,
             displayName: username, 
           )));
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kullanıcı bulunamadı: $username")));
         }
      }
  }

  void _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestoreService.getUser(user.uid);
      if (mounted) {
        setState(() {
          _isAdmin = userDoc?.isAdmin ?? false;
        });
      }
    }
  }

  Future<void> _handleSendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('login_to_comment'))),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Check Cooldown (10 seconds)
      final userDocForCooldown = await _firestoreService.getUser(user.uid);
      if (userDocForCooldown?.lastCommentAt != null) {
        final diff = DateTime.now().difference(userDocForCooldown!.lastCommentAt!);
        if (diff.inSeconds < 10) {
          final remaining = 10 - diff.inSeconds;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_t('cooldown_msg').replaceFirst('{}', remaining.toString())),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isSending = false);
          return;
        }
      }

      // MODERASYON KONTROLÜ
      final moderationResult = await _moderationService.checkText(text);
      bool isHidden = !moderationResult.isSafe;
      String? reason = moderationResult.reason;

      String authorName = user.displayName ?? user.email?.split('@')[0] ?? _t('anonymous');
      String authorUsername = user.email?.split('@')[0] ?? '';
      
      bool isAdmin = false; 
      final userDoc = await _firestoreService.getUser(user.uid);
      String? authorAvatarUrl;
      if (userDoc != null) {
        isAdmin = userDoc.isAdmin;
        authorName = userDoc.name;
        if (userDoc.username.isNotEmpty) authorUsername = userDoc.username;
        authorAvatarUrl = userDoc.profileImageUrl;
      }

      final realCommentId = FirebaseFirestore.instance.collection('forum_posts').doc(widget.post.id).collection('comments').doc().id;

      final comment = ForumComment(
        id: realCommentId, 
        postId: widget.post.id,
        authorId: user.uid,
        authorName: authorName,
        authorUsername: authorUsername,
        authorAvatarUrl: authorAvatarUrl,
        content: text,
        timestamp: DateTime.now(),
        isAdmin: _isAdmin, // FIX: Use the class-level _isAdmin flag
        isHidden: isHidden,
        moderationReason: reason,
        likeUids: [],
        dislikeUids: [],
        isNameHidden: _isNameHidden,
      );

      await _firestoreService.addForumComment(comment);

      // 1. Send Notification to Post Author
      if (widget.post.authorId != user.uid) {
        await _firestoreService.addNotification(
          targetUserId: widget.post.authorId,
          title: "Yeni Yorum",
          body: "$authorName konunuza yorum yaptı: ${text.length > 50 ? text.substring(0, 47) + '...' : text}",
          type: "reply",
          postId: widget.post.id,
          commentId: realCommentId,
        );
      }

      // 2. Handle Mentions (@username)
      final mentionRegex = RegExp(r'@(\w+)');
      final mentions = mentionRegex.allMatches(text).map((m) => m.group(1)).where((u) => u != null).toSet();
      
      for (var username in mentions) {
        if (username == null) continue;
        debugPrint("Mention detected in comment: $username");
        
        // Find User By Username
        final fcmToken = await _firestoreService.getFcmTokenByUsername(username);
        if (fcmToken != null) {
          await _firestoreService.sendFcmNotification(
            token: fcmToken,
            title: "Bir yorumda senden bahsedildi",
            body: "$authorName: ${text.length > 50 ? text.substring(0, 47) + '...' : text}",
            data: {
              'type': 'mention',
              'postId': widget.post.id,
              'commentId': realCommentId,
            },
          );
        }
      }

      if (isHidden) {
        await _firestoreService.addModerationLog(
          type: 'comment',
          contentId: realCommentId,
          postId: widget.post.id,
          authorName: authorName,
          reason: reason ?? "AI tarafından engellendi",
          content: text,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Yorumunuz kurallara aykırı bulundu ve gizlendi."), backgroundColor: Colors.orange)
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Yorumunuz gönderildi ✅"), backgroundColor: Colors.green)
          );
        }
      }

      _commentController.clear();
      FocusScope.of(context).unfocus(); 
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.grey[100],
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text("AlofFORUM 💬"),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          elevation: 1,
        ),
      body: Column(
        children: [
          // POST CONTENT
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector( // [NEW] Clickable Profile
                        onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(
                              userId: widget.post.authorId,
                              displayName: widget.post.authorName,
                            )));
                        },
                        child: Row(
                          children: [
                            UserAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue[100],
                              imageUrl: widget.post.authorAvatarUrl ?? _fetchedAuthorAvatar, // [NEW] Use fetched if missing
                              fallbackContent: Text(
                                (widget.post.authorName.isNotEmpty ? widget.post.authorName[0] : "?").toUpperCase(),
                                style: TextStyle(color: Colors.blue[800]),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!widget.post.isNameHidden)
                                    Text(widget.post.authorName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  Text(
                                    "@${widget.post.authorUsername.isNotEmpty ? widget.post.authorUsername : widget.post.authorName.toLowerCase().replaceAll(' ', '')}",
                                    style: TextStyle(
                                      color: widget.post.isNameHidden ? Colors.blue[800] : Colors.blue[600], 
                                      fontSize: widget.post.isNameHidden ? 14 : 13,
                                      fontWeight: widget.post.isNameHidden ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.post.isAdmin) ...[
                                    const SizedBox(height: 2),
                                    FutureBuilder<String>(
                                      future: _firestoreService.getAdminBadgeLabel(),
                                      builder: (context, labelSnap) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[800],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            labelSnap.data ?? "Admin",
                                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }
                                    ),
                                  ],
                                  if (widget.post.carInfo != null)
                                    Text("${widget.post.carInfo} Sahibi", style: TextStyle(fontSize: 11, color: Colors.blue[700], fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(dateFormatter.format(widget.post.timestamp), style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.post.authorId == _auth.currentUser?.uid || _isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _confirmDeletePost(),
                          ),
                        IconButton(
                          icon: const Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
                          onPressed: () => _handleReportPost(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TranslatableText(widget.post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), onMentionTap: _handleMentionTap),
                const SizedBox(height: 8),
                TranslatableText(widget.post.content, style: const TextStyle(fontSize: 15), onMentionTap: _handleMentionTap),
                
                // IMAGE CAROUSEL (Instagram style)
                if (widget.post.images.isNotEmpty) ...[
                   const SizedBox(height: 16),
                   if (widget.post.images.length == 1)
                     ClipRRect(
                       borderRadius: BorderRadius.circular(12),
                       child: Image.network(
                         widget.post.images.first,
                         width: double.infinity,
                         fit: BoxFit.cover,
                       ),
                     )
                   else
                     SizedBox(
                       height: 300,
                       child: Stack(
                         children: [
                           PageView.builder(
                             itemCount: widget.post.images.length,
                             onPageChanged: (index) => setState(() => _currentImageIndex = index),
                             itemBuilder: (context, index) {
                               return ClipRRect(
                                 borderRadius: BorderRadius.circular(12),
                                 child: Image.network(
                                   widget.post.images[index],
                                   width: double.infinity,
                                   fit: BoxFit.cover,
                                 ),
                               );
                             },
                           ),
                           Positioned(
                             bottom: 12,
                             left: 0,
                             right: 0,
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: List.generate(widget.post.images.length, (index) {
                                 return Container(
                                   margin: const EdgeInsets.symmetric(horizontal: 3),
                                   width: 6,
                                   height: 6,
                                   decoration: BoxDecoration(
                                     shape: BoxShape.circle,
                                     color: _currentImageIndex == index ? Colors.blue : Colors.grey[400],
                                   ),
                                 );
                               }),
                             ),
                           ),
                         ],
                       ),
                     ),
                ],

                // POLL
                if (widget.post.pollOptions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<ForumPost?>(
                    stream: _firestoreService.getPostStream(widget.post.id),
                    builder: (context, snapshot) {
                      final currentPost = snapshot.data ?? widget.post;
                      final pollOptions = currentPost.pollOptions;
                      
                      // Check what user voted for
                      String? userVote;
                      final user = _auth.currentUser;
                      if (user != null) {
                        userVote = currentPost.pollVoters[user.uid];
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📊 Anket", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                            const SizedBox(height: 12),
                            ...pollOptions.keys.map((option) {
                              int votes = pollOptions[option] ?? 0;
                              bool isSelected = userVote == option;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected ? Colors.orange.shade100 : Colors.white,
                                    foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black87 : Colors.black87,
                                    elevation: 0,
                                    side: BorderSide(
                                      color: isSelected ? Colors.orange : Colors.orange.shade200, 
                                      width: isSelected ? 2 : 1
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: () async {
                                    if (user == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('login_to_vote'))));
                                      return;
                                    }
                                    await _firestoreService.voteOnPoll(widget.post.id, option);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked, 
                                            size: 18, 
                                            color: isSelected ? Colors.orange : Colors.grey
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            option, 
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: Theme.of(context).brightness == Brightness.dark ? Colors.black87 : Colors.black87
                                            )
                                          ),
                                        ],
                                      ),
                                      Text("$votes Oy", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // COMMENTS LIST
          Expanded(
            child: StreamBuilder<List<ForumComment>>(
              stream: _firestoreService.getPostComments(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final comments = snapshot.data!;
                if (comments.isEmpty) return const Center(child: Text("Henüz yorum yok. İlk yorumu sen yaz! 👇"));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: comment.isAdmin ? (Theme.of(context).brightness == Brightness.dark ? Colors.red.withOpacity(0.1) : Colors.red[50]) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: comment.isAdmin ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Row(
                                 children: [
                                    GestureDetector(
                                      onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(
                                              userId: comment.authorId,
                                              displayName: comment.authorName,
                                            )));
                                      },
                                      child: _CommentUserAvatar(
                                        comment: comment,
                                        firestoreService: _firestoreService,
                                      ),
                                   ),
                                   const SizedBox(width: 8),
                                   if (comment.isAdmin) 
                                      const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.verified, size: 16, color: Colors.red)),
                                   Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       if (!comment.isNameHidden)
                                         Text(comment.authorName, style: TextStyle(
                                           fontWeight: FontWeight.bold, 
                                           color: comment.isAdmin ? Colors.red[800] : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)
                                         )),
                                       Row(
                                         children: [
                                           Text(
                                             "@${comment.authorUsername.isNotEmpty ? comment.authorUsername : comment.authorName.toLowerCase().replaceAll(' ', '')}",
                                             style: TextStyle(
                                               color: comment.isNameHidden ? (comment.isAdmin ? Colors.red[800] : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)) : Colors.grey[600], 
                                               fontSize: 12,
                                               fontWeight: comment.isNameHidden ? FontWeight.bold : FontWeight.normal
                                             ),
                                           ),
                                           if (comment.isAdmin) ...[
                                             const SizedBox(width: 6),
                                             FutureBuilder<String>(
                                               future: _firestoreService.getAdminBadgeLabel(),
                                               builder: (context, labelSnap) {
                                                 return Container(
                                                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                   decoration: BoxDecoration(
                                                     color: Colors.red[800],
                                                     borderRadius: BorderRadius.circular(4),
                                                   ),
                                                   child: Text(
                                                     labelSnap.data ?? "Admin",
                                                     style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                                   ),
                                                 );
                                               }
                                             ),
                                           ],
                                         ],
                                       ),
                                     ],
                                   ),
                                 ],
                               ),
                               Text(DateFormat('HH:mm').format(comment.timestamp), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                               if (comment.authorId == _auth.currentUser?.uid || _isAdmin)
                                 Padding(
                                   padding: const EdgeInsets.only(left: 8),
                                   child: GestureDetector(
                                     onTap: () => _deleteComment(comment),
                                     child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                   ),
                                 ),
                               Padding(
                                 padding: const EdgeInsets.only(left: 8),
                                 child: GestureDetector(
                                   onTap: () => _handleReportComment(comment),
                                   child: const Icon(Icons.report_problem_outlined, size: 16, color: Colors.orangeAccent),
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 6),
                           TranslatableText(comment.content, style: const TextStyle(fontSize: 14), onMentionTap: _handleMentionTap),
                           const SizedBox(height: 8),
                           Row(
                             children: [
                               _buildCommentVoteButton(
                                 icon: Icons.thumb_up_outlined,
                                 activeIcon: Icons.thumb_up,
                                 count: comment.likeUids.length,
                                 isActive: comment.likeUids.contains(_auth.currentUser?.uid),
                                 onTap: () => _firestoreService.voteOnComment(widget.post.id, comment.id, _auth.currentUser!.uid, true),
                                 activeColor: Colors.blue[700]!,
                               ),
                               const SizedBox(width: 12),
                               _buildCommentVoteButton(
                                 icon: Icons.thumb_down_outlined,
                                 activeIcon: Icons.thumb_down,
                                 count: comment.dislikeUids.length,
                                 isActive: comment.dislikeUids.contains(_auth.currentUser?.uid),
                                 onTap: () => _firestoreService.voteOnComment(widget.post.id, comment.id, _auth.currentUser!.uid, false),
                                 activeColor: Colors.red[700]!,
                               ),
                               const Spacer(),
                               TextButton(
                                 onPressed: () {
                                   _commentController.text = "@${comment.authorName} ";
                                   FocusScope.of(context).requestFocus();
                                 },
                                 style: TextButton.styleFrom(
                                   minimumSize: Size.zero,
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                 ),
                                 child: const Text("Yanıtla", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                               ),
                             ],
                           ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // INPUT AREA
           SafeArea(
             bottom: true,
             child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showMentionSuggestions)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, 
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _mentionSuggestions.length,
                          separatorBuilder: (_,__) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _mentionSuggestions[index];
                            return ListTile(
                              tileColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                              dense: true,
                              leading: UserAvatar(imageUrl: user.profileImageUrl, radius: 14),
                              title: Text(user.username.isNotEmpty ? user.username : user.name),
                              onTap: () => _selectMention(user.username.isNotEmpty ? user.username : user.name.toLowerCase().replaceAll(' ', '')),
                            );
                          },
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.person_off_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text("İsmimi Gizle", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        SizedBox(
                          height: 30,
                          child: Transform.scale(
                            scale: 0.7,
                            child: Switch(
                              activeColor: Colors.blue[800],
                              value: _isNameHidden,
                              onChanged: (val) => setState(() => _isNameHidden = val),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: "Yorum yaz...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            onSubmitted: (_) => _handleSendComment(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _isSending 
                          ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          : CircleAvatar(
                             backgroundColor: Colors.blue[800],
                             child: IconButton(
                               icon: const Icon(Icons.send, color: Colors.white, size: 20),
                               onPressed: _handleSendComment,
                             ),
                          )
                      ],
                    ),
                  ],
                ),
             ),
           ),
        ],
      ),
    ),
  );
}

  Widget _buildCommentVoteButton({
    required IconData icon,
    required IconData activeIcon,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: () {
        if (_auth.currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('login_to_vote'))));
          return;
        }
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: activeColor.withOpacity(0.2)) : null,
        ),
        child: Row(
          children: [
            Icon(isActive ? activeIcon : icon, size: 16, color: isActive ? activeColor : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? activeColor : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReportPost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('report')),
        content: Text(_t('report_confirm_post')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('report'), style: const TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şikayet iletildi, yapay zeka inceliyor...")));
      
      try {
        final content = "${widget.post.title} ${widget.post.content}";
        final result = await _moderationService.checkText(content);
        
        if (!result.isSafe) {
          await _firestoreService.setContentVisibility('post', widget.post.id, true);
          await _firestoreService.addModerationLog(
            type: 'post_report_auto',
            contentId: widget.post.id,
            authorName: widget.post.authorName,
            reason: "Kullanıcı şikayeti & AI Kararı: ${result.reason}",
            content: content,
          );
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('violation_found')), backgroundColor: Colors.red));
             Navigator.pop(context); // Go back to feed
          }
        } else {
          await _firestoreService.addModerationLog(
            type: 'post_report_manual',
            contentId: widget.post.id,
            authorName: widget.post.authorName,
            reason: "Kullanıcı şikayeti (AI 'Güvenli' dedi ama inceleme gerekiyor)",
            content: content,
          );
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('report_queued'))));
          }
        }
      } catch (e) {
        debugPrint("Report error: $e");
      }
    }
  }

  void _handleReportComment(ForumComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('report_confirm_comment')),
        content: Text(_t('report_confirm_comment')), // Wait, title and content? Let's check original.
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('report'), style: const TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şikayet iletildi, yapay zeka inceliyor...")));
      
      try {
        final result = await _moderationService.checkText(comment.content);
        
        if (!result.isSafe) {
          await _firestoreService.setContentVisibility('comment', comment.id, true, postId: widget.post.id);
          await _firestoreService.addModerationLog(
            type: 'comment_report_auto',
            contentId: comment.id,
            postId: widget.post.id,
            authorName: comment.authorName,
            reason: "Kullanıcı şikayeti & AI Kararı: ${result.reason}",
            content: comment.content,
          );
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Yorum kurallara aykırı bulundu ve gizlendi."), backgroundColor: Colors.red));
          }
        } else {
          await _firestoreService.addModerationLog(
            type: 'comment_report_manual',
            contentId: comment.id,
            postId: widget.post.id,
            authorName: comment.authorName,
            reason: "Kullanıcı şikayeti (AI 'Güvenli' dedi ama inceleme gerekiyor)",
            content: comment.content,
          );
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şikayetiniz inceleme sırasına alındı.")));
          }
        }
      } catch (e) {
        debugPrint("Report error: $e");
      }
    }
  }

  void _confirmDeletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_post')),
        content: Text(_t('delete_post_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () async {
              await _firestoreService.deleteForumPost(widget.post.id);
              if (mounted) {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Screen
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('post_deleted'))));
              }
            },
            child: Text(_t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteComment(ForumComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_comment')),
        content: Text(_t('delete_comment_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteForumComment(widget.post.id, comment.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('comment_deleted'))));
      }
    }
  }
}

class _CommentUserAvatar extends StatefulWidget {
  final ForumComment comment;
  final FirestoreService firestoreService;

  const _CommentUserAvatar({
    required this.comment,
    required this.firestoreService,
  });

  @override
  State<_CommentUserAvatar> createState() => _CommentUserAvatarState();
}

class _CommentUserAvatarState extends State<_CommentUserAvatar> {
  String? _fetchedAvatarUrl;

  @override
  void initState() {
    super.initState();
    if (widget.comment.authorAvatarUrl == null) {
      _fetchUserAvatar();
    }
  }

  void _fetchUserAvatar() async {
    try {
      final userDoc = await widget.firestoreService.getUser(widget.comment.authorId);
      if (mounted && userDoc?.profileImageUrl != null) {
        setState(() {
          _fetchedAvatarUrl = userDoc!.profileImageUrl;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.comment.authorAvatarUrl ?? _fetchedAvatarUrl;
    
    return UserAvatar(
      radius: 18,
      backgroundColor: widget.comment.isAdmin ? Colors.red[100] : Colors.grey[200],
      imageUrl: imageUrl,
      fallbackContent: Text(
        (widget.comment.authorName.isNotEmpty ? widget.comment.authorName[0] : "?").toUpperCase(),
        style: TextStyle(color: widget.comment.isAdmin ? Colors.red[800] : Colors.grey[700], fontWeight: FontWeight.bold),
      ),
    );
  }
}

