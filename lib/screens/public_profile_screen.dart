import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // For base64Decode
import '../models/user_model.dart';
import '../models/car_model.dart';
import '../widgets/user_avatar.dart';
import '../models/forum_model.dart'; 
import '../services/firestore_service.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import 'post_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final String? initialPhotoUrl; // Optional: Pass if already known to avoid flicker

  const PublicProfileScreen({
    Key? key,
    required this.userId,
    required this.displayName,
    this.initialPhotoUrl,
  }) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  User? _userProfile;
  bool _isLoadingUser = true;
  bool _isCurrentUserAdmin = false;

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkCurrentUserAdmin();
  }

  Future<void> _checkCurrentUserAdmin() async {
     final currentUser = auth.FirebaseAuth.instance.currentUser;
     if (currentUser != null) {
        final userModel = await _firestoreService.getUser(currentUser.uid);
        if (mounted && userModel != null && userModel.isAdmin) {
           setState(() => _isCurrentUserAdmin = true);
        }
     }
  }

  Future<void> _loadUserProfile() async {
    final user = await _firestoreService.getUser(widget.userId);
    if (mounted) {
      setState(() {
        _userProfile = user;
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine profile photo to show
    String? photoUrl = _userProfile?.profileImageUrl ?? widget.initialPhotoUrl;
    final currentUid = auth.FirebaseAuth.instance.currentUser?.uid;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      body: CustomScrollView(
        slivers: [
          // 1. MODERN APP BAR & HEADER
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0D47A1), // Fallback
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Background Pattern (Optional opacity)
                  Opacity(
                    opacity: 0.05,
                    child: Center(child: Icon(Icons.directions_car_filled, size: 200, color: Colors.white)),
                  ),
                  // Profile Content
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80, bottom: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                              ]
                            ),
                            child: Hero(
                              tag: 'avatar_${widget.userId}', 
                              child: UserAvatar(
                                imageUrl: photoUrl,
                                radius: 55,
                                backgroundColor: Colors.white,
                                fallbackContent: const Icon(Icons.person, size: 60, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                             (_userProfile?.hideName == true) ? _t('hidden_user_name') : widget.displayName,
                             style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (_userProfile != null && _userProfile!.username.isNotEmpty)
                            Text(
                              "@${_userProfile!.username}",
                              style: TextStyle(fontSize: 14, color: Colors.blue[100]),
                            ),
                          if (_userProfile != null && _userProfile!.isAdmin)
                             Container(
                               margin: const EdgeInsets.only(top: 8),
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                               decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.2),
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(color: Colors.white.withOpacity(0.5))
                               ),
                               child: const Text(
                                 "ADMIN", 
                                 style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                               ),
                             )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            actions: [
               if (_isCurrentUserAdmin && widget.userId != currentUid)
                 IconButton(
                   icon: Container(
                     padding: const EdgeInsets.all(6),
                     decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                     child: const Icon(Icons.gavel, color: Colors.white, size: 20)
                   ),
                   tooltip: _t('ban_user_admin'),
                   onPressed: () => _showBanUserDialog(context),
                 ),
               if (currentUid != null && currentUid != widget.userId)
                IconButton(
                  icon: Container(
                     padding: const EdgeInsets.all(6),
                     decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                     child: const Icon(Icons.report_problem, color: Colors.white, size: 20)
                   ),
                  tooltip: _t('report_user'),
                  onPressed: () => _showReportUserDialog(context, currentUid ?? ""),
                ),
            ],
          ),

          // 2. STATS ROW
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: StreamBuilder<List<ForumPost>>(
                  stream: _firestoreService.getUserForumPosts(widget.userId),
                  builder: (context, postSnapshot) {
                     final postCount = postSnapshot.data?.length ?? 0;
                     
                     return StreamBuilder<List<Car>>(
                       stream: _firestoreService.getGarage(widget.userId),
                       builder: (context, garageSnapshot) {
                         final carCount = garageSnapshot.data?.length ?? 0;
                         
                         return Row(
                           children: [
                             Expanded(child: _buildStatCard(Icons.directions_car, carCount.toString(), _t('garage_label'))),
                             const SizedBox(width: 12),
                             Expanded(child: _buildStatCard(Icons.forum, postCount.toString(), _t('tab_forum'))),
                           ],
                         );
                       }
                     );
                  },
                ),
              ),
            ),
          ),

          // 3. USER DETAILS (Join Date, etc.)
          if (_userProfile != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 2,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (_userProfile!.createdAt != null) ...[
                          _buildDetailRow(Icons.calendar_today, _t('join_date'), _formatDate(_userProfile!.createdAt!)),
                          const Divider(height: 24),
                        ],
                        _buildDetailRow(Icons.language, _t('language'), _userProfile!.language.toUpperCase()),
                        if (_userProfile!.lastForumPostAt != null) ...[
                          const Divider(height: 24),
                          _buildDetailRow(Icons.access_time, _t('last_post_prefix').replaceAll('{}', '').trim(), _formatDate(_userProfile!.lastForumPostAt!)),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 4. GARAGE TITLE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _t('garage_label').toUpperCase(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2),
              ),
            ),
          ),
          
          // 5. GARAGE LIST (Enhanced)
          StreamBuilder<List<Car>>(
            stream: _firestoreService.getGarage(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                 return SliverToBoxAdapter(
                   child: Container(
                     margin: const EdgeInsets.all(16),
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                     child: Center(
                       child: Column(
                         children: [
                           Icon(Icons.garage_outlined, size: 40, color: Colors.grey[300]),
                           const SizedBox(height: 8),
                           Text(_t('empty_garage_user'), style: TextStyle(color: Colors.grey[500])),
                         ],
                       ),
                     ),
                   ),
                 );
              }

              // [NEW] Privacy Check
              if (_userProfile?.hideCars == true) {
                 final isDark = Theme.of(context).brightness == Brightness.dark;
                 return SliverToBoxAdapter(
                   child: Container(
                     margin: const EdgeInsets.all(16),
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                        color: isDark ? Colors.blueGrey.shade900.withOpacity(0.3) : Colors.blueGrey[50], 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey[100]!)
                     ),
                     child: Center(
                       child: Column(
                         children: [
                           Icon(Icons.lock_outline, size: 40, color: Colors.blueGrey[300]),
                           const SizedBox(height: 12),
                           Text(_t('user_hidden_garage_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[700])),
                           const SizedBox(height: 4),
                           Text(_t('user_hidden_garage_msg'), style: TextStyle(color: Colors.blueGrey[500])),
                         ],
                       ),
                     ),
                   ),
                 );
              }

              final cars = snapshot.data!;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final car = cars[index];
                    return _buildCarItem(car);
                  },
                  childCount: cars.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 6. FORUM TITLE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _t('recent_posts_caps'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2),
              ),
            ),
          ),

          // 7. FORUM POSTS (Enhanced)
          StreamBuilder<List<ForumPost>>(
            stream: _firestoreService.getUserForumPosts(widget.userId),
            builder: (context, snapshot) {
               if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: SizedBox(height: 50));
               
               if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(child: Text(_t('no_posts_user'), style: TextStyle(color: Colors.grey[500]))),
                    ),
                  );
               }

               final posts = snapshot.data!;
               posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
               final recentPosts = posts.take(5).toList();

               return SliverList(
                 delegate: SliverChildBuilderDelegate(
                   (context, index) {
                     final post = recentPosts[index];
                     if (post.isNameHidden || post.isHidden) return const SizedBox.shrink();
                     return _buildPostItem(post);
                    },
                   childCount: recentPosts.length,
                 ),
               );
            },
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String count, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1976D2), size: 28),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String key, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
             color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50], 
             borderRadius: BorderRadius.circular(8)
          ),
          child: Icon(icon, color: Colors.blue[800], size: 18),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(key, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ],
        )
      ],
    );
  }

  Widget _buildCarItem(Car car) {
     final String? plate = car.plate;
     final maskedPlate = (plate != null && plate.length > 4) 
        ? "${plate.substring(0, 2)} *** ${plate.substring(plate.length - 2)}"
        : (plate ?? "***");

     String? carPhoto;
     if (car.photos.isNotEmpty) {
        carPhoto = car.photos.first;
     }

     final isDark = Theme.of(context).brightness == Brightness.dark;

     return Container(
       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
       decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]
       ),
       child: ListTile(
         contentPadding: const EdgeInsets.all(10),
         leading: Container(
           width: 60,
           height: 60,
           decoration: BoxDecoration(
             color: isDark ? Colors.grey[800] : Colors.grey[100],
             borderRadius: BorderRadius.circular(10),
             image: (carPhoto != null) ? DecorationImage(
               image: carPhoto.startsWith('http') 
                  ? NetworkImage(carPhoto) 
                  : MemoryImage(base64Decode(carPhoto)) as ImageProvider,
               fit: BoxFit.cover,
             ) : null,
           ),
           child: (carPhoto == null) ? const Icon(Icons.directions_car, color: Colors.grey) : null,
         ),
         title: Text("${car.brand} ${car.model}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color)),
         subtitle: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const SizedBox(height: 4),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
               decoration: BoxDecoration(
                 color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue[50], 
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue[100]!)
                ),
               child: Text(maskedPlate, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[200] : Colors.blue[900])),
             ),
           ],
         ),
         trailing: Text("${car.modelYear}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
       ),
     );
  }

  Widget _buildPostItem(ForumPost post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
         color: Theme.of(context).cardColor,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[100]!)
      ),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
        leading: CircleAvatar(
          backgroundColor: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50],
          child: const Icon(Icons.article_rounded, color: Colors.orange),
        ),
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)),
        subtitle: Text(
           post.content, 
           maxLines: 1, 
           overflow: TextOverflow.ellipsis, 
           style: TextStyle(color: Colors.grey[500], fontSize: 12)
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[300]),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', LanguageService().currentLanguage == 'tr' ? 'tr_TR' : 'en_US').format(date);
  }

  void _showReportUserDialog(BuildContext context, String currentUid) {
    String selectedReason = _t('spam_ad');
    final TextEditingController descriptionController = TextEditingController();
    final List<String> reasons = [
      _t('spam_ad'),
      _t('inappropriate_content'),
      _t('harassment'),
      _t('fake_profile'),
      _t('other'),
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Modern Shape
               title: Row(
                children: [
                   const Icon(Icons.report_rounded, color: Colors.redAccent, size: 32),
                   const SizedBox(width: 16),
                   Expanded(child: Text(_t('report_user'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('report_reason_prompt'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 15)),
                    const SizedBox(height: 12),
                    ...reasons.map((reason) => RadioListTile<String>(
                      activeColor: Colors.redAccent,
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading, // Modern Check
                      onChanged: (value) {
                         setState(() => selectedReason = value!);
                      },
                    )),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        labelText: _t('description_optional'),
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50], // Theme-aware fill
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_t('cancel'), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0
                  ),
                  onPressed: () {
                    // Send Report
                    _firestoreService.reportUser(
                      currentUid,
                      widget.userId,
                      selectedReason,
                      descriptionController.text.trim(),
                    ).then((_) {
                       if (context.mounted) {
                          Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Text(_t('report_received_msg'))]),
                             backgroundColor: Colors.green,
                             behavior: SnackBarBehavior.floating,
                           )
                         );
                       }
                    }).catchError((e) {
                        if (context.mounted) {
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text(_t('error_prefix') + ": $e"), backgroundColor: Colors.red)
                         );
                       }
                    });
                  },
                  child: Text(_t('send_caps'), style: const TextStyle(fontWeight: FontWeight.bold)), // Use send_caps
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showBanUserDialog(BuildContext context) {
    bool isCurrentlyBanned = _userProfile?.isBanned ?? false;
    
    if (isCurrentlyBanned) {
        // UNBAN CONFIRMATION
        showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
             const Icon(Icons.lock_open_rounded, color: Colors.green, size: 28),
             const SizedBox(width: 12),
             Expanded(child: Text(_t('unban_user'), style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          content: Text("${_userProfile?.username} kullanıcısının yasağını kaldırmak üzeresiniz."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                 _firestoreService.setBanStatus(widget.userId, false).then((_) {
                   Navigator.pop(ctx);
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kullanıcı yasağı kaldırıldı"), backgroundColor: Colors.green));
                   }
                 });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: Text(_t('confirm_unban') ?? "Yasağı Kaldır"),
            ),
          ],
        ),
      );
    } else {
      // BAN DURATION SELECTION
      int? selectedDurationDays = null; // null = Permanent
      
      showDialog(
       context: context,
       builder: (ctx) {
         return StatefulBuilder(
           builder: (context, setState) {
             return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
               title: Row(children: [
                  const Icon(Icons.block_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_t('ban_user_admin'), style: const TextStyle(fontWeight: FontWeight.bold))),
               ]),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text("${_userProfile?.username} engellenecek. Süre seçiniz:"),
                   const SizedBox(height: 16),
                   DropdownButtonFormField<int?>(
                     value: selectedDurationDays,
                     decoration: const InputDecoration(
                       border: OutlineInputBorder(),
                       labelText: "Yasak Süresi",
                       contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     ),
                     items: const [
                       DropdownMenuItem(value: 1, child: Text("1 Gün")),
                       DropdownMenuItem(value: 3, child: Text("3 Gün")),
                       DropdownMenuItem(value: 7, child: Text("1 Hafta")),
                       DropdownMenuItem(value: 30, child: Text("1 Ay")),
                       DropdownMenuItem(value: null, child: Text("Süresiz (Kalıcı)")),
                     ],
                     onChanged: (val) => setState(() => selectedDurationDays = val),
                   ),
                 ],
               ),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(ctx),
                   child: Text(_t('cancel'), style: TextStyle(color: Colors.grey[600])),
                 ),
                 ElevatedButton(
                   onPressed: () {
                     DateTime? expiration;
                     if (selectedDurationDays != null) {
                       expiration = DateTime.now().add(Duration(days: selectedDurationDays!));
                     }
                     
                     _firestoreService.setBanStatus(widget.userId, true, expirationDate: expiration).then((_) {
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kullanıcı yasaklandı"), backgroundColor: Colors.red));
                        }
                     });
                   },
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                   child: Text(_t('confirm_ban') ?? "Yasakla"),
                 ),
               ],
             );
           }
         );
       },
      );
    }
  }
}
