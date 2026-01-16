import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async'; // For Timer

import '../models/forum_model.dart';
import '../models/car_model.dart';
import '../models/user_model.dart'; // App User Model
import '../services/firestore_service.dart';
import '../services/moderation_service.dart';
import '../services/language_service.dart';
import '../data/car_data.dart'; // [NEW] Link to CarData

import '../utils/app_localizations.dart';

class CreateForumPostModal extends StatefulWidget {
  final auth.User currentUser;
  final bool isAdmin;
  final List<Car> userGarage;

  const CreateForumPostModal({
    Key? key,
    required this.currentUser,
    required this.isAdmin,
    required this.userGarage,
  }) : super(key: key);

  @override
  State<CreateForumPostModal> createState() => _CreateForumPostModalState();
}

class _CreateForumPostModalState extends State<CreateForumPostModal> {
  final FirestoreService _firestoreService = FirestoreService();
  final ModerationService _moderationService = ModerationService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _carInfoController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [];

  bool _showPollFields = false;
  bool _isNameHidden = false;
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  String? _cooldownWarning;
  Timer? _cooldownTimer;
  int _remainingSeconds = 0;

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _carInfoController.dispose();
    for (var c in _pollOptionControllers) c.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final userDoc = await _firestoreService.getUser(widget.currentUser.uid);
    if (userDoc != null) {
      // 1. Set Privacy Preference
      if (mounted) {
        setState(() {
          _isNameHidden = userDoc.hideName;
        });
      }

      // 2. Check Cooldown
      if (userDoc.lastForumPostAt != null) {
        final diff = DateTime.now().difference(userDoc.lastForumPostAt!);
        if (diff.inSeconds < 60) {
          if (mounted) {
            setState(() {
              _remainingSeconds = 60 - diff.inSeconds;
              _startTimer();
            });
          }
        }
      }
    }
  }

  void _startTimer() {
    _cooldownTimer?.cancel();
    _updateWarningMessage();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _cooldownTimer?.cancel();
          _cooldownWarning = null;
        } else {
          _updateWarningMessage();
        }
      });
    });
  }

  void _updateWarningMessage() {
    setState(() {
      _cooldownWarning = "Yeni konu açmak için $_remainingSeconds saniye beklemelisiniz.";
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, // Theme-aware
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300], // Theme-aware
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Text(
                    _t('new_topic_title'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
          
           const Divider(),

          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(), // [NEW] Dismiss keyboard
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                // Title Input
                TextField(
                  controller: _titleController,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: _t('topic_title_hint'),
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                
                // Content Input
                TextField(
                  controller: _contentController,
                  maxLines: 6,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: _t('topic_content_hint'),
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                    border: InputBorder.none,
                    // [NEW] Hide Keyboard Button
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.keyboard_hide, color: Colors.grey),
                      onPressed: () => FocusScope.of(context).unfocus(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Image Preview Area
                if (_selectedImages.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(_selectedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImages.removeAt(index)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    final List<XFile> images = await _picker.pickMultiImage();
                    if (images.isNotEmpty) {
                      setState(() {
                        _selectedImages.addAll(images.map((x) => File(x.path)));
                      });
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF0059BC)),
                  label: Text(_t('add_photo'), style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                
                // Car Selection (Modernized)
                Text(_t('car_info_optional'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                const SizedBox(height: 12),
                if (_carInfoController.text.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0059BC).withOpacity(0.1) : const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF0059BC).withOpacity(0.3) : const Color(0xFFCCE3FF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_rounded, size: 20, color: Color(0xFF0059BC)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _carInfoController.text,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0059BC)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _carInfoController.clear()),
                          child: const Icon(Icons.cancel, size: 20, color: Color(0xFF0059BC)),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showGarageSelector(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[700]!, Colors.blue[500]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.garage_rounded, color: Colors.white, size: 28),
                              const SizedBox(height: 8),
                                Text(
                                  _t('select_from_garage'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showGlobalCarSelector(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.indigo[700]!, Colors.indigo[500]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.search_rounded, color: Colors.white, size: 28),
                              const SizedBox(height: 8),
                                Text(
                                  _t('select_from_catalog'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Poll Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.poll_rounded, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(_t('add_poll'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            activeColor: Colors.orange,
                            value: _showPollFields,
                            onChanged: (val) {
                              setState(() {
                                _showPollFields = val;
                                if (val && _pollOptionControllers.isEmpty) {
                                  _pollOptionControllers.add(TextEditingController());
                                  _pollOptionControllers.add(TextEditingController());
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (_showPollFields) ...[
                        const SizedBox(height: 12),
                        ..._pollOptionControllers.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: entry.value,
                              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                              decoration: InputDecoration(
                                hintText: "${entry.key + 1}. ${_t('new_option')}",
                                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                                filled: true,
                                fillColor: isDark ? Colors.grey[800] : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => setState(() => _pollOptionControllers.removeAt(entry.key)),
                                ),
                              ),
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: () => setState(() => _pollOptionControllers.add(TextEditingController())),
                          icon: const Icon(Icons.add, color: Colors.orange),
                          label: Text(_t('new_option'), style: const TextStyle(color: Colors.orange)),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                // Name Hiding Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue[100]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_off_rounded, color: Colors.blue[800], size: 20),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_t('hide_name'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(_t('hide_name_sub'), style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        activeColor: Colors.blue[800],
                        value: _isNameHidden,
                        onChanged: (val) => setState(() => _isNameHidden = val),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 100), // Space for FAB
              ],
              ),
            ),
          ),
          
          // Action Buttons
          SafeArea(
            bottom: true,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // Theme-aware
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cooldownWarning != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            _cooldownWarning!,
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  if (_isSubmitting)
                    Column(
                      children: [
                        const CircularProgressIndicator(strokeWidth: 2),
                        const SizedBox(height: 12),
                        Text(_t('submitting_wait'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    )
                  else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0059BC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(_t('publish_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() async {
     if (_remainingSeconds > 0) { // Should not happen if button disabled/warning shown, but double check
       return;
     }

     if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('warn_empty_fields'))));
       return;
     }
     
     // 1. Check Cooldown First (One last time before submit)
     final userDocForCooldown = await _firestoreService.getUser(widget.currentUser.uid);
     if (userDocForCooldown?.lastForumPostAt != null) {
       final diff = DateTime.now().difference(userDocForCooldown!.lastForumPostAt!);
       if (diff.inSeconds < 60) {
         setState(() {
           _remainingSeconds = 60 - diff.inSeconds;
           _startTimer(); // Restart timer if it was stale
         });
         return; 
       }
     }

     // 2. Start Submitting
     setState(() => _isSubmitting = true);
     
     try {
       final textToCheck = "${_titleController.text} ${_contentController.text}";
       final moderationResult = await _moderationService.checkText(textToCheck);
       
       bool isHidden = !moderationResult.isSafe;
       String? reason = moderationResult.reason;

       String authorName = widget.currentUser.displayName ?? widget.currentUser.email?.split('@')[0] ?? 'Anonim';
       String authorUsername = widget.currentUser.email?.split('@')[0] ?? '';
       final userDoc = await _firestoreService.getUser(widget.currentUser.uid);
       if (userDoc != null) {
         authorName = userDoc.name;
         if (userDoc.username.isNotEmpty) authorUsername = userDoc.username;
       }

       Map<String, int> pollOptions = {};
       if (_showPollFields) {
         for (var controller in _pollOptionControllers) {
           if (controller.text.trim().isNotEmpty) {
             pollOptions[controller.text.trim()] = 0;
           }
         }
       }

       final newPostId = FirebaseFirestore.instance.collection('forum_posts').doc().id;

       // Upload Images if any
       List<String> imageUrls = [];
       if (_selectedImages.isNotEmpty) {
          imageUrls = await _firestoreService.uploadForumImages(newPostId, _selectedImages);
       }

       debugPrint("DEBUG: UserDoc for post creation fetched. Model Avatar: ${userDoc?.profileImageUrl}");

       final post = ForumPost(
         id: newPostId,
         authorId: widget.currentUser.uid,
         authorName: authorName,
         authorUsername: authorUsername,
         authorAvatarUrl: userDoc?.profileImageUrl, // [NEW] Persist avatar even if name is hidden
         carInfo: _carInfoController.text.trim().isNotEmpty ? _carInfoController.text.trim() : null,
         title: _titleController.text.trim(),
         content: _contentController.text.trim(),
         timestamp: DateTime.now(),
         images: imageUrls,
         pollOptions: pollOptions,
         isHidden: isHidden,
         moderationReason: reason,
         helpfulUids: [],
         unhelpfulUids: [],
         isNameHidden: _isNameHidden,
         isAdmin: widget.isAdmin,
       );
       
       debugPrint("DEBUG: Created Post Object. isNameHidden: $_isNameHidden, AvatarUrl: ${post.authorAvatarUrl}");

       await _firestoreService.addForumPost(post);

       if (isHidden) {
         await _firestoreService.addModerationLog(
           type: 'post',
           contentId: newPostId,
           authorName: authorName,
           reason: reason ?? "AI tarafından engellendi",
           content: textToCheck,
         );
         if (mounted) { // FIX: Use mounted check properly
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('content_violation')), backgroundColor: Colors.orange));
            Navigator.pop(context);
         }
       } else {
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('upload_success')), backgroundColor: Colors.green));
             Navigator.pop(context);
          }
        }

        // 3. Handle Mentions (@username) in Post
        final mentionRegex = RegExp(r'@(\w+)');
        final mentions = mentionRegex.allMatches(textToCheck).map((m) => m.group(1)).where((u) => u != null).toSet();
        
        for (var username in mentions) {
          if (username == null) continue;
          final fcmToken = await _firestoreService.getFcmTokenByUsername(username);
          if (fcmToken != null) {
            await _firestoreService.sendFcmNotification(
              token: fcmToken,
              title: "Yeni bir konuda senden bahsedildi",
              body: "$authorName: ${_titleController.text}",
              data: {
                'type': 'mention',
                'postId': newPostId,
              },
            );
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
        setState(() => _isSubmitting = false);
     }
  }

  void _showGarageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Garajınızdaki Araçlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.userGarage.length,
                itemBuilder: (context, index) {
                  final car = widget.userGarage[index];
                  return ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: Text(car.name),
                    subtitle: Text("${car.brand ?? ''} ${car.model ?? ''}"),
                    onTap: () {
                      setState(() {
                        _carInfoController.text = "${car.brand ?? ''} ${car.model ?? ''}".trim();
                        if (_carInfoController.text.isEmpty) _carInfoController.text = car.name;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGlobalCarSelector() {
    String searchKey = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setInternalState) {
          List<String> allModels = [];
          CarData.brandModels.forEach((brand, models) {
            for (var m in models) {
              if (searchKey.isEmpty || brand.toLowerCase().contains(searchKey.toLowerCase()) || m.toLowerCase().contains(searchKey.toLowerCase())) {
                allModels.add("$brand $m");
              }
            }
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text("Model Listesinden Seç", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), // Theme-aware text
                  decoration: const InputDecoration(hintText: "Marka veya model ara...", prefixIcon: Icon(Icons.search)),
                  onChanged: (val) => setInternalState(() => searchKey = val),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: allModels.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(allModels[index]),
                        onTap: () {
                          setState(() { // Use parent setState
                            _carInfoController.text = allModels[index];
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
