import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../utils/app_localizations.dart';
import 'home_screen.dart'; // [NEW] For navigation after logout
import 'dart:async'; // [NEW] For Timer
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/translatable_text.dart';

class SupportScreen extends StatefulWidget {
  final DateTime? banExpiration; // [NEW] Optional expiration
  const SupportScreen({super.key, this.banExpiration});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  
  // Form Fields
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController(); // Auto-filled if possible
  String _selectedType = 'support'; // support, suggestion, complaint
  
  bool _isLoading = false;
  File? _selectedImage;
  
  // Timer for countdown
  Timer? _timer;
  String _timeRemaining = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserInfo();
    
    // Start timer if banned
    if (widget.banExpiration != null) {
      _startCountdown();
    }
  }
  
  void _loadUserInfo() {
    final user = _authService.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }
  
  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  // Image Picker
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }


  void _startCountdown() {
    // Initial update
    _updateTimeRemaining();
    
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateTimeRemaining();
    });
  }

  void _updateTimeRemaining() {
    if (widget.banExpiration == null) return;
    
    final now = DateTime.now().toUtc(); // Use UTC
    final expiration = widget.banExpiration!.toUtc(); // Use UTC
    
    final diff = expiration.difference(now);
    
    if (diff.isNegative) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _timeRemaining = "Süre doldu. Lütfen uygulamayı yeniden başlatın.";
        });
      }
      return;
    }
    
    // Format duration
    String formatted = "";
    if (diff.inDays > 0) {
      formatted += "${diff.inDays} Gün ";
    }
    int hours = diff.inHours % 24;
    int minutes = diff.inMinutes % 60;
    int seconds = diff.inSeconds % 60;
    
    formatted += "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    
    if (mounted) {
      setState(() {
        _timeRemaining = formatted;
      });
    }
  }

  // Helper to format remaining time (Old static method, keeping for reference but not using)
  String _getRemainingTime() {
    if (widget.banExpiration == null) return "Süresiz (Kalıcı)";
    return _timeRemaining;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    _timer?.cancel(); // Cancel timer
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = _authService.currentUser;
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('support_login_required'))));
       return;
    }

    setState(() => _isLoading = true);

    try {
      // Get user name (optimistic)
      String userName = user.displayName ?? "Kullanıcı";
      try {
        final userDoc = await _firestoreService.getUser(user.uid);
        if (userDoc != null) userName = userDoc.name;
      } catch (_) {}

      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _firestoreService.uploadSupportImage(_selectedImage!);
      }

      await _firestoreService.submitSupportRequestWithImage(
        uid: user.uid,
        email: _emailController.text.isNotEmpty ? _emailController.text : (user.email ?? ""),
        name: userName,
        type: _selectedType,
        message: _messageController.text.trim(),
        imageUrl: imageUrl, 
        imagePath: _selectedImage?.path, // Just for metadata if needed
      );

      _messageController.clear();
      setState(() {
        _selectedImage = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('support_sent_success')),
            backgroundColor: Colors.green,
          )
        );
        // Switch to History tab
        _tabController.animateTo(1); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWithdraw(String requestId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Talebi Geri Çek')), // fallback if key missing
        content: Text("Bu destek talebini silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Sil", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteSupportRequest(requestId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Talep başarıyla geri çekildi.")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomeScreen()), // This will likely trigger a reload of HomeScreen
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Text(_t('settings_support') ?? "Destek & Geri Bildirim"), // Fallback if key missing
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0059BC),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0059BC),
          tabs: [
            Tab(text: _t('support_tab_new')), // "Yeni Mesaj"
            Tab(text: _t('support_tab_history')), // "Geçmiş Talepler"
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Çıkış Yap",
            onPressed: () {
               showDialog(
                 context: context,
                 builder: (ctx) => AlertDialog(
                   title: const Text("Çıkış Yap"),
                   content: const Text("Hesabınızdan çıkış yapmak istiyor musunuz?"),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
                     TextButton(onPressed: () { Navigator.pop(ctx); _handleLogout(); }, child: const Text("Çıkış", style: TextStyle(color: Colors.red))),
                   ],
                 ),
               );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRequestForm(),
          _buildRequestHistory(),
        ],
      ),
    );
  }

  Widget _buildNewRequestForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0059BC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0059BC).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                   Icon(Icons.info_outline, color: const Color(0xFF0059BC)),
                   const SizedBox(width: 10),
                     Expanded(
                       child: Text(
                         _t('support_info_text'),
                         style: TextStyle(color: const Color(0xFF0059BC), fontSize: 13),
                       ),
                     ),
                ],
                ),
            ),
            const SizedBox(height: 25),
            
            // [NEW] Display Ban Information if active
            if (widget.banExpiration != null || widget.banExpiration == null && _t('support_info_text').contains("yasaklandınız")) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 25),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                       Icon(Icons.timer, color: Colors.red, size: 30),
                       SizedBox(height: 10),
                       Text("Hesap Erişim Engeli", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                       SizedBox(height: 5),
                       Text("Erişimin açılmasına kalan süre:", style: TextStyle(color: Colors.red[800])),
                       SizedBox(height: 5),
                       Text(
                         widget.banExpiration == null ? "Süresiz (Kalıcı)" : _timeRemaining,
                         style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24),
                       ),
                    ],
                  ),
                ),
            ],
            
            Text(_t('support_subject_label'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTypeChip('support', _t('support_type_support'), Icons.help_outline),
                const SizedBox(width: 10),
                _buildTypeChip('suggestion', _t('support_type_suggestion'), Icons.lightbulb_outline),
                const SizedBox(width: 10),
                _buildTypeChip('complaint', _t('support_type_complaint'), Icons.report_problem_outlined),
              ],
            ),
            
            const SizedBox(height: 25),
            Text(_t('support_message_label'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: _t('support_message_hint'),
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.all(16),
              ),
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
              validator: (val) => val == null || val.length < 10 ? _t('support_valid_min_chars') : null,
            ),
            
            // [NEW] Image Upload UI
            const SizedBox(height: 15),
            if (_selectedImage != null)
              Stack(
                children: [
                   Container(
                     height: 200,
                     width: double.infinity,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(12),
                       image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                     ),
                   ),
                   Positioned(
                     top: 10,
                     right: 10,
                     child: GestureDetector(
                       onTap: _removeImage,
                       child: Container(
                         padding: EdgeInsets.all(5),
                         decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                         child: Icon(Icons.close, color: Colors.white, size: 20),
                       ),
                     ),
                   ),
                ],
              )
            else
              Row(
                children: [
                   TextButton.icon(
                     onPressed: () => _pickImage(ImageSource.gallery), 
                     icon: Icon(Icons.photo_library, color: const Color(0xFF0059BC)), 
                     label: Text(_t('support_photo_lib') ?? "Galeriden Seç"),
                   ),
                   SizedBox(width: 10),
                   TextButton.icon(
                     onPressed: () => _pickImage(ImageSource.camera), 
                     icon: Icon(Icons.camera_alt, color: const Color(0xFF0059BC)), 
                     label: Text(_t('support_photo_cam') ?? "Fotoğraf Çek"),
                   ),
                ],
              ),


            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0059BC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                  : Text(_t('support_btn_send'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTypeChip(String value, String label, IconData icon) {
    bool isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0059BC) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF0059BC) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[300]!)),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0059BC).withOpacity(0.3), blurRadius: 8)] : [],
          ),
          child: Column(
             children: [
               Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 22),
               const SizedBox(height: 4),
               Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
             ],
          ),
        ),
      ),
    );
  }

    Widget _buildRequestHistory() {
      final user = _authService.currentUser;
      if (user == null) return Center(child: Text("Giriş yapmalısınız."));

      return StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getUserSupportRequests(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Bir hata oluştu."));
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          
          // Client-side Sort (Newest First)
          docs.sort((a, b) {
             Timestamp? tA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
             Timestamp? tB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
             if (tA == null) return 1;
             if (tB == null) return -1;
             return tB.compareTo(tA);
          });

          if (docs.isEmpty) {

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey[300]),
                  SizedBox(height: 10),
                  Text(_t('support_empty_history'), style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'open';
              bool isReplied = status == 'replied';
              String? requestImageUrl = data['imageUrl'];
              
              Color statusColor = isReplied ? Colors.green : Colors.orange;
              String statusText = isReplied ? _t('support_status_replied') : _t('support_status_pending');
              
              return Container(
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[100]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _getStatusIcon(data['type']),
                              SizedBox(width: 8),
                              Text(
                                _getTypeLabel(data['type']),
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                              ),
                            ],
                          ),
                          // Status + Delete Action
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              if (!isReplied) ...[
                                 SizedBox(width: 8),
                                 IconButton(
                                   icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                   tooltip: "Talebi Geri Çek",
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(),
                                   splashRadius: 20,
                                   onPressed: () => _handleWithdraw(docs[index].id),
                                 ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatableText(data['message'] ?? '', style: TextStyle(fontSize: 14, height: 1.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87)),
                          
                          // [NEW] Display Image if Available
                          if (requestImageUrl != null) ...[
                            SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: requestImageUrl,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[200], height: 150),
                                errorWidget: (context, url, error) => Icon(Icons.broken_image),
                              ),
                            ),
                          ],

                          SizedBox(height: 8),
                          Text(
                            _formatDate(data['createdAt']),
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    
                    // Reply Section
                    if (isReplied && data['reply'] != null)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 0).copyWith(bottom: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.support_agent, size: 16, color: Colors.green),
                                SizedBox(width: 5),
                                Text(_t('support_team_name'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                              ],
                            ),
                            SizedBox(height: 5),
                            TranslatableText(data['reply'], style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

  Icon _getStatusIcon(String? type) {
    if (type == 'suggestion') return Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber);
    if (type == 'complaint') return Icon(Icons.report_problem_outlined, size: 18, color: Colors.redAccent);
    return Icon(Icons.help_outline, size: 18, color: Colors.blue);
  }
  
  String _getTypeLabel(String? type) {
    if (type == 'suggestion') return _t('support_type_suggestion');
    if (type == 'complaint') return _t('support_type_complaint');
    return _t('support_request_title');
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    return DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
  }
}
