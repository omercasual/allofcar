import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/forum_model.dart';
import '../widgets/user_avatar.dart';
import '../models/car_model.dart';
import '../models/news_model.dart';
import '../data/car_data.dart';
import '../services/firestore_service.dart';
import 'post_detail_screen.dart';
import 'news_detail_screen.dart';
import '../services/moderation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/create_forum_post_modal.dart';
import '../widgets/translatable_text.dart';
import 'public_profile_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- FORUM POSTS SCREEN ---
class ForumTimelineScreen extends StatefulWidget {
  final Function(int) onTabSwitch; // Callback to switch to News
  const ForumTimelineScreen({super.key, required this.onTabSwitch});

  @override
  State<ForumTimelineScreen> createState() => _ForumTimelineScreenState();
}

class _ForumTimelineScreenState extends State<ForumTimelineScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ModerationService _moderationService = ModerationService();
  List<Car> _userGarage = [];
  bool _isAdmin = false;

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  void initState() {
    super.initState();
    _loadGarage();
    _checkAdminStatus();
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

  void _loadGarage() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestoreService.getGarage(user.uid).listen((cars) {
        if (mounted) setState(() => _userGarage = cars);
      });
    }
  }

  void _showAddPostDialog() {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('login_to_post'))));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateForumPostModal(
        currentUser: user,
        isAdmin: _isAdmin,
        userGarage: _userGarage,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
        title: Text(
          _t('tab_forum_allof'), // "allof 🗣️"
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: ForumTabHeader(
            selectedIndex: 0, // 0 for Posts
            onTabSelected: widget.onTabSwitch,
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // Raise the FAB slightly
        child: FloatingActionButton.extended(
          heroTag: 'forum_post_fab',
          onPressed: _showAddPostDialog,
          icon: const Icon(Icons.add_comment_rounded),
          label: Text(_t('new_topic')),
          backgroundColor: const Color(0xFF0059BC),
        ),
      ),
      body: _buildForumList(),
    );
  }

  Widget _buildForumList() {    
    return StreamBuilder<List<ForumPost>>(
      stream: _firestoreService.getForumPosts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("${_t('error')}: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final posts = snapshot.data!;
        if (posts.isEmpty) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                 const SizedBox(height: 10),
                 Text("Henüz hiç konu yok.\nİlkini sen başlat! 🚀", 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)
                 ),
               ],
             ),
           );
        }
        
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 100),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              elevation: 3,
              color: Theme.of(context).cardColor,
              surfaceTintColor: Theme.of(context).cardColor,
              margin: const EdgeInsets.only(bottom: 15, left: 4, right: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(
                                      userId: post.authorId,
                                      displayName: post.authorName,
                                    )));
                                },
                                child: UserAvatar(
                                  radius: 22,
                                  backgroundColor: isDark ? Colors.grey[800]! : Colors.blue[50]!,
                                  imageUrl: post.authorAvatarUrl,
                                  fallbackContent: Text(
                                    (post.authorName.isNotEmpty ? post.authorName[0] : "?").toUpperCase(),
                                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0059BC), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(
                                          userId: post.authorId,
                                          displayName: post.authorName,
                                        )));
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!post.isNameHidden)
                                          Text(post.authorName, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0059BC))),
                                        Text(
                                          "@${post.authorUsername.isNotEmpty ? post.authorUsername : post.authorName.toLowerCase().replaceAll(' ', '')}",
                                          style: TextStyle(
                                            color: post.isNameHidden ? (isDark ? Colors.blue[300] : Colors.blue[800]) : (isDark ? Colors.blue[300] : Colors.blue[600]), 
                                            fontSize: post.isNameHidden ? 14 : 13, 
                                            fontWeight: post.isNameHidden ? FontWeight.bold : FontWeight.normal
                                          ),
                                        ),
                                        if (post.isAdmin) ...[
                                          const SizedBox(height: 2),
                                          FutureBuilder<String>(
                                            future: _firestoreService.getAdminBadgeLabel(),
                                            builder: (context, labelSnap) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0059BC),
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
                                  ),
                                  if (post.carInfo != null)
                                    Text("${post.carInfo} Sahibi", style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                            Text(DateFormat('dd MMM').format(post.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            if (post.authorId == _auth.currentUser?.uid || _isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeletePost(post),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.report_problem_outlined, size: 20, color: Colors.orangeAccent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _handleReportPost(post),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TranslatableText(post.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        const SizedBox(height: 5),
                        TranslatableText(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                        
                        if (post.images.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          if (post.images.length == 1)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                post.images.first,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 50,
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: post.images.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        post.images[index],
                                        width: 160,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],

                        if (post.pollOptions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("📊 Anket", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                                const SizedBox(height: 8),
                                ...post.pollOptions.keys.map((option) {
                                  int votes = post.pollOptions[option] ?? 0;
                                  int totalVotes = post.pollOptions.values.fold(0, (sum, v) => sum + v);
                                  double percent = totalVotes > 0 ? (votes / totalVotes) : 0;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(option, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                                            Text("%${(percent * 100).toInt()}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: percent,
                                          backgroundColor: isDark ? Colors.grey[700] : Colors.white,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0059BC)),
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildVoteButton(
                                  icon: Icons.thumb_up_alt_outlined,
                                  activeIcon: Icons.thumb_up_alt,
                                  label: "Faydalı",
                                  count: post.helpfulUids.length,
                                  isActive: post.helpfulUids.contains(_auth.currentUser?.uid),
                                  onTap: () => _firestoreService.voteOnPost(post.id, _auth.currentUser!.uid, true),
                                  activeColor: Colors.blue[700]!,
                                ),
                                const SizedBox(width: 8),
                                _buildVoteButton(
                                  icon: Icons.thumb_down_alt_outlined,
                                  activeIcon: Icons.thumb_down_alt,
                                  label: "Faydalı Değil",
                                  count: post.unhelpfulUids.length,
                                  isActive: post.unhelpfulUids.contains(_auth.currentUser?.uid),
                                  onTap: () => _firestoreService.voteOnPost(post.id, _auth.currentUser!.uid, false),
                                  activeColor: Colors.red[700]!,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.comment_outlined, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("${post.commentCount} Yorum", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

  Widget _buildVoteButton({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        if (_auth.currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Oylama yapmak için giriş yapmalısınız.")));
          return;
        }
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? activeColor.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(isActive ? activeIcon : icon, size: 18, color: isActive ? activeColor : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              "$count $label",
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReportPost(ForumPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Şikayet Et", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text("Bu içeriği kurallara aykırı olduğu gerekçesiyle şikayet etmek istediğinize emin misiniz? Yapay zeka incelemesi başlatılacaktır.", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Şikayet Et", style: TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şikayet iletildi, yapay zeka inceliyor...")));
      
      try {
        final content = "${post.title} ${post.content}";
        final result = await _moderationService.checkText(content);
        
        if (!result.isSafe) {
          await _firestoreService.setContentVisibility('post', post.id, true);
          await _firestoreService.addModerationLog(
            type: 'post_report_auto',
            contentId: post.id,
            authorName: post.authorName,
            reason: "Kullanıcı şikayeti & AI Kararı: ${result.reason}",
            content: content,
          );
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ İçerik kurallara aykırı bulundu ve gizlendi."), backgroundColor: Colors.red));
          }
        } else {
          await _firestoreService.addModerationLog(
            type: 'post_report_manual',
            contentId: post.id,
            authorName: post.authorName,
            reason: "Kullanıcı şikayeti (AI 'Güvenli' dedi ama inceleme gerekiyor)",
            content: content,
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

  void _confirmDeletePost(ForumPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Konuyu Sil", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text("Bu konuyu ve tüm yorumlarını silmek istediğine emin misin? Bu işlem geri alınamaz.", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(
            onPressed: () async {
              await _firestoreService.deleteForumPost(post.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konu başarıyla silindi.")));
              }
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// --- NEWS SCREEN ---
class ForumNewsScreen extends StatefulWidget {
  final Function(int) onTabSwitch; // Callback to switch to Posts
  const ForumNewsScreen({super.key, required this.onTabSwitch});

  @override
  State<ForumNewsScreen> createState() => _ForumNewsScreenState();
}

class _ForumNewsScreenState extends State<ForumNewsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
        title: Text(
          _t('tab_forum_allof'), // "allof 🗣️"
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: ForumTabHeader(
            selectedIndex: 1, // 1 for News
            onTabSelected: widget.onTabSwitch,
          ),
        ),
      ),
      body: _buildNewsList(),
    );
  }

  Widget _buildNewsList() {
    return StreamBuilder<List<NewsArticle>>(
      stream: _firestoreService.getNewsArticles(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final articles = snapshot.data!;
        if (articles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.newspaper_rounded, size: 64, color: Colors.grey),
                const SizedBox(height: 10),
                Text("Henüz haber yok.\nTakipte kalın! 🗞️",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 100),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final article = articles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).cardColor,
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article))),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        article.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: article.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: Icon(Icons.error)),
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 50, color: Colors.grey),
                            ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.9),
                                  Colors.black.withOpacity(0.0),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0059BC),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    DateFormat('dd MMM yyyy').format(article.timestamp),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TranslatableText(
                                  article.title, 
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    shadows: [BoxShadow(color: Colors.black, blurRadius: 4)]
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- SHARED HEADER WIDGET ---
class ForumTabHeader extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const ForumTabHeader({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  String _t(BuildContext context, String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTab(context, _t(context, 'tab_forum_posts'), 0),
          _buildTab(context, _t(context, 'tab_forum_news'), 1),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String title, int index) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF0059BC) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected 
                  ? const Color(0xFF0059BC) 
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
