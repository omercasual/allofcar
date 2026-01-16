import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert'; // [NEW]
import 'dart:async'; // [NEW] Required for TimeoutException
import '../widgets/user_avatar.dart'; // [NEW]
import 'package:image_picker/image_picker.dart'; // Fotoğraf seçimi için
import 'favorite_cars_screen.dart'; // Favori sayfası
import 'favorite_comparisons_screen.dart'; // Favori Karşılaştırmalar
import 'garage_screen.dart'; // Garaj sayfası
import 'fault_history_screen.dart'; // Arıza Geçmişi Sayfası
import '../services/notification_service.dart'; // Notification Service
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'admin_panel_screen.dart';
import '../models/car_model.dart';
import 'package:intl/intl.dart';
import 'my_forum_posts_screen.dart'; // [NEW] Açtığım konular sayfası
import 'car_expertise_screen.dart';
import 'home_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- DURUM DEĞİŞKENLERİ ---
  bool isLoggedIn = false;
  bool isAdmin = false;
  bool isLoginMode = true;
  bool _isLoading = true; // [NEW] Yükleniyor durumu
  int _selectedCarIndex = 0; // [NEW] Seçili araç indeksi
  late PageController _pageController; // [NEW]
  String _username = ""; // [NEW] Kullanıcı adı (email prefix)

  User? _userModel; // [CRITICAL FIX] Added missing state variable to store full user data
  int _secretTapCount = 0; // [EMERGENCY] Secret gesture counter
  
  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }
  
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // Profil Verileri
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(); // [NEW] Kullanıcı adı kontrolcüsü
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController(); // [NEW] Mevcut şifre kontrolcüsü

  // Bakım & Araç Verileri (Simülasyon)
  File? _profileImage;
  // String myCarName = "BMW 320i M Sport"; // Kaldırıldı: Firestore'dan çekiliyor
  // String maintenanceDate = "20.12.2025"; // Kaldırıldı

  // --- RESİM SEÇME FONKSİYONU ---
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // [NEW] Resize to avoid Firestore 1MB limit
      imageQuality: 70, // [NEW] Compress
    );
    
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      // 1. Show local preview - We can use FileImage for immediate preview
      setState(() {
        _profileImage = imageFile;
      });

      // 2. Notify User
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
              content: Row(children: [
                 SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                 SizedBox(width: 10),
                 Text("Profil fotoğrafı işleniyor ve kaydediliyor...")
              ]),
              duration: Duration(days: 1), // Indefinite until dismissed
           )
        );
      }

      try {
         String? uid = _authService.currentUser?.uid;
         if (uid != null && _userModel != null) {
            
            // 3. Convert to Base64 (Garage Logic)
            final bytes = await imageFile.readAsBytes();
            final base64Image = base64Encode(bytes);

            // 4. Update Firestore directly (Base64 String)
             // Add timeout to prevent infinite hang if network is down
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({'profileImageUrl': base64Image})
                .timeout(const Duration(seconds: 15), onTimeout: () {
                   throw TimeoutException("Sunucu yanıt vermedi, internetinizi kontrol edin.");
                });
            
            // 5. Sync updates to comments/posts
            // Now that index exists, this should be fast.
            await _firestoreService.synchronizeUserData(uid, _userModel!.name, _userModel!.username, newProfileImageUrl: base64Image);
            
             // 6. Update Local State
               if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Profil fotoğrafı başarıyla kaydedildi!"), backgroundColor: Colors.green)
                  );
                  
                  setState(() {
                     // Create new user model with updated Base64 string
                     _userModel = User(
                        id: _userModel!.id,
                        name: _userModel!.name,
                        username: _userModel!.username,
                        email: _userModel!.email,
                        password: _userModel!.password,
                        phone: _userModel!.phone,
                        isAdmin: _userModel!.isAdmin,
                        isBanned: _userModel!.isBanned,
                        hideCars: _userModel!.hideCars,
                        hideName: _userModel!.hideName,
                        notifyMentions: _userModel!.notifyMentions,
                        notifyReplies: _userModel!.notifyReplies,
                        notifyNews: _userModel!.notifyNews,
                        notifySupport: _userModel!.notifySupport,
                        language: _userModel!.language,
                        lastForumPostAt: _userModel!.lastForumPostAt,
                        lastCommentAt: _userModel!.lastCommentAt,
                        createdAt: _userModel!.createdAt,
                        profileImageUrl: base64Image, // Save Base64
                     );
                     _profileImage = null; // Clear local file so UserAvatar uses the Base64 string
                  });
               }
         }
      } catch (e) {
         debugPrint("Profile Process Error: $e");
         if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Ensure dismissed
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Hata: Fotoğraf kaydedilemedi. $e"), backgroundColor: Colors.red)
            );
            setState(() {
               _profileImage = null; 
            });
         }
      } finally {
        if (mounted) {
           // Double check to hide loading snackbar if somehow still active
           ScaffoldMessenger.of(context).clearSnackBars(); 
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9); // Slight peek at next card
    _checkCurrentUser();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      // User is logged in
      var userModel = await _firestoreService.getUser(user.uid);
      _userModel = userModel; // [CRITICAL FIX] Store in state variable
      if (mounted) {
        setState(() {
          isLoggedIn = true;
          isAdmin = userModel?.isAdmin ?? false; // Sadece veritabanından gelen yetkiye bak
          
          _emailController.text = user.email ?? "";
          
          // Username = Firestore'dan gelen kullanıcı adı. Yoksa email prefix
          _username = userModel?.username ?? user.email?.split('@')[0] ?? "";
          _usernameController.text = _username;
          
          // Name = Firestore'dan gelen isim. Yoksa "Kullanıcı"
          _nameController.text = userModel?.name ?? _t('default_username');
          
          if (userModel?.phone != null) _phoneController.text = userModel!.phone!;
          
          _isLoading = false; // [NEW] Yükleme bitti
        });
      }
    } else {
       if (mounted) {
         setState(() {
           _isLoading = false; // [NEW] Yükleme bitti (Kullanıcı yok)
         });
       }
    }
  }



  // --- ÇIKIŞ ---
  void _handleLogout() async {
    await _authService.signOut();
    setState(() {
      isLoggedIn = false;
      isAdmin = false;
      _profileImage = null;
      _emailController.clear();
      _emailController.clear();
      _passwordController.clear();
      _currentPasswordController.clear(); // [NEW]
      _nameController.clear();
      _usernameController.clear(); // [NEW]
      _phoneController.clear();
    });
  }



  // [EMERGENCY] Helper to restore admin
  Future<void> _restoreAdminStatus() async {
     if (_userModel != null && _authService.currentUser != null) {
        try {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Yönetici yetkisi yükleniyor...")));
           
           User restoredUser = User(
              id: _authService.currentUser!.uid,
              name: _userModel!.name,
              username: _userModel!.username,
              email: _userModel!.email,
              password: "",
              phone: _userModel!.phone,
              isAdmin: true, // FORCE TRUE
              isBanned: _userModel!.isBanned,
              createdAt: _userModel!.createdAt,
              hideCars: _userModel!.hideCars,
              hideName: _userModel!.hideName,
              notifyMentions: _userModel!.notifyMentions,
              notifyReplies: _userModel!.notifyReplies,
              notifyNews: _userModel!.notifyNews,
              notifySupport: _userModel!.notifySupport,
              language: _userModel!.language,
              lastForumPostAt: _userModel!.lastForumPostAt,
              lastCommentAt: _userModel!.lastCommentAt,
              profileImageUrl: _userModel!.profileImageUrl, // [CRITICAL FIX] Preserve profile image
           );
           
           await _firestoreService.saveUser(restoredUser);
           
           setState(() {
              isAdmin = true;
              _userModel = restoredUser;
           });
           
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("BAŞARILI: Yönetici yetkisi geri yüklendi!"), 
              backgroundColor: Colors.green
           ));
        } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
        }
     }
  }

  // --- GİRİŞ / KAYIT İŞLEMİ ---
  Future<void> _handleAuth() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('enter_email_password'))),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('password_min_length'))),
      );
      return;
    }

    // 1. ADMİN KONTROLÜ (Veritabanından bağımsız - Hardcoded)
    if (email == "admin" && password == "1234") {
      setState(() {
        isLoggedIn = true;
        isAdmin = true;
        _nameController.text = _t('admin_name');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('admin_login_success')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (isLoginMode) {
      // GİRİŞ YAPMA (Firebase)
      debugPrint("DEBUG: Attempting login for $email");
      var user = await _authService.login(email, password);
      
      if (user != null) {
        debugPrint("DEBUG: Login successful for UID: ${user.uid}");
        // Firestore'dan ekstra bilgileri çek
        var userModel = await _firestoreService.getUser(user.uid);
        debugPrint("DEBUG: Firestore User Model: ${userModel?.username}, isBanned: ${userModel?.isBanned}, Expiration: ${userModel?.banExpiration}");

        // [NEW] Ban Check with Expiration Logic
        if (userModel?.isBanned == true) {
             debugPrint("DEBUG: User is marked as banned.");
             // Check if ban matches expiration criteria
             final nowUtc = DateTime.now().toUtc();
             final banExpUtc = userModel?.banExpiration?.toUtc();
             debugPrint("DEBUG: Ban Check - Now (UTC): $nowUtc, Exp (UTC): $banExpUtc");
             
             if (banExpUtc != null && nowUtc.isAfter(banExpUtc)) {
                debugPrint("DEBUG: Ban has expired. Unbanning user...");
                // Auto-unban and allow access
                await _firestoreService.setBanStatus(user.uid, false);
                // Refresh local model to reflect unban
                userModel = await _firestoreService.getUser(user.uid);
                debugPrint("DEBUG: Unban complete. New status: ${userModel?.isBanned}");
             } else {
                debugPrint("DEBUG: Ban is still active. Signing out.");
                // Still banned
                await _authService.signOut();
                if (mounted) {
                  // Calculate remaining time
                  String remainingText = "Süresiz";
                  if (banExpUtc != null) {
                    Duration diff = banExpUtc.difference(nowUtc);
                    if (diff.inDays > 0) {
                       remainingText = "${diff.inDays} Gün ${diff.inHours % 24} Saat";
                    } else {
                       remainingText = "${diff.inHours} Saat ${diff.inMinutes % 60} Dakika";
                    }
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Hesabınız banlanmıştır. Kalan Süre: $remainingText"),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
                return;
             }
        } else {
           debugPrint("DEBUG: User is NOT banned.");
        }
        
        setState(() {
          isLoggedIn = true;
          isAdmin = userModel?.isAdmin ?? false;
          _username = userModel?.username ?? user.email!.split('@')[0];
          _usernameController.text = _username;
          
          // Name = Firestore'dan gelen isim. Yoksa email prefix'i değil, generic bir isim veya boş
          _nameController.text = userModel?.name ?? _t('default_username');
          _emailController.text = user.email!;
          if (userModel?.phone != null) _phoneController.text = userModel!.phone!;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('login_success_welcome'))),
          );
          
          // [FIX] Return to main screen (Home) if we came from Settings
          // This ensures the Navigation Bar is visible again
          if (Navigator.canPop(context)) {
             Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      } else {
        debugPrint("DEBUG: Login failed. User is null.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('invalid_email_password')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // KAYIT OLMA (Firebase)
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('enter_name'))),
        );
        return;
      }

      var user = await _authService.register(email, password);
      if (user != null) {
        // Firestore'a kaydet (Hata olsa bile akışı bozma)
        try {
          String baseUsername = email.split('@')[0];
          String finalUsername = baseUsername;
          
          // Check uniqueness
          bool exists = await _firestoreService.checkUsernameExists(finalUsername);
          if (exists) {
             // Append random suffix
             finalUsername = "${baseUsername}_${DateTime.now().millisecondsSinceEpoch % 10000}";
          }

          User newUserModel = User(
            id: user.uid,
            name: name,
            username: finalUsername,
            email: email,
            password: password,
            phone: phone.isNotEmpty ? phone : null,
            createdAt: DateTime.now(), // [NEW] Registration time
          );
          await _firestoreService.saveUser(newUserModel);
          _userModel = newUserModel; // [CRITICAL FIX] Store in state variable
          
          if (mounted) {
             // Update local state with the actual final username
             setState(() {
                _username = finalUsername;
                _usernameController.text = finalUsername;
             });
          }
        } catch (e) {
          debugPrint("Firestore save error: $e");
          // Opsiyonel: Kullanıcıya hata gösterilebilir ama kayıt başarılı sayılır
        }

        if (mounted) {
          setState(() {
            isLoggedIn = true;
            isAdmin = false;
            _nameController.text = name;
            _emailController.text = email;
            _username = email.split('@')[0]; // Username set
            _usernameController.text = _username;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('registration_success')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating, // Daha görünür yapar
            ),
          );
        }
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('registration_failed'))),
          );
         }
      }
    }
  }

  // --- ŞİFRE SIFIRLAMA PENCERESİ ---
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
             color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            top: 10,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.lock_reset, color: Color(0xFF0059BC), size: 28),
                    SizedBox(width: 10),
                    Text(
                      _t('password_reset_title'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 15),
                Text(
                  _t('password_reset_desc'),
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                SizedBox(height: 20),
                _buildModernEditField(Icons.email_outlined, _t('email_label'), resetEmailController, inputType: TextInputType.emailAddress),
                SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () async {
                    String email = resetEmailController.text.trim();
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('enter_email_error'))),
                      );
                      return;
                    }
                    try {
                      await _authService.sendPasswordResetEmail(email);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_t('reset_link_sent')),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${_t('error_prefix')}$e")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0059BC),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: Color(0xFF0059BC).withOpacity(0.3),
                  ),
                  child: Text(_t('send_link'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- BİLGİ DÜZENLEME PENCERESİ ---
  void _showEditProfileDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? usernameErrorText;
        bool isCheckingUsername = false; // Optional: loading indicator for check

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                top: 10,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // DRAG HANDLE
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // HEADER
                    Row(
                      children: [
                        Icon(Icons.edit_note, color: Color(0xFF0059BC), size: 28),
                        SizedBox(width: 10),
                        Text(
                          _t('edit_profile'),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 15),

                    // FORM FIELDS
                    _buildModernEditField(Icons.person_outline, _t('name_surname'), _nameController),
                    SizedBox(height: 15),
                    
                    // Username Field with Error
                    _buildModernEditField(Icons.alternate_email, _t('username_label'), _usernameController, errorText: usernameErrorText),
                    SizedBox(height: 15),
                    
                    _buildModernEditField(Icons.email_outlined, _t('email_label'), _emailController, inputType: TextInputType.emailAddress),
                    SizedBox(height: 15),
                    _buildModernEditField(Icons.phone_outlined, _t('phone_number_label'), _phoneController, isNumber: true),
                    SizedBox(height: 15),
                    _buildModernEditField(Icons.lock_outline, _t('new_password_optional'), _passwordController, isPassword: true),
                    SizedBox(height: 15),
                    _buildModernEditField(Icons.lock_clock_outlined, _t('current_password_required'), _currentPasswordController, isPassword: true),
                    
                    SizedBox(height: 25),

                    // ACTION BUTTON
                    ElevatedButton(
                      onPressed: isCheckingUsername ? null : () async {
                        // Clear previous error
                        setModalState(() { usernameErrorText = null; });
                        
                        // Parent setState
                        setState(() {}); 

                        if (isLoggedIn) {
                          String? uid = _authService.currentUser?.uid;
                          
                          // [NEW] KULLANICI ADI UNIQUE KONTROLÜ (INLINE ERROR)
                          String newUsername = _usernameController.text.trim();
                          if (newUsername != _username) {
                             if (newUsername.isEmpty) {
                                setModalState(() { usernameErrorText = _t('username_required'); });
                                return;
                             }
                             
                             setModalState(() { isCheckingUsername = true; });
                             bool exists = await _firestoreService.checkUsernameExists(newUsername);
                             setModalState(() { isCheckingUsername = false; });
                             
                             if (exists) {
                                setModalState(() { 
                                  usernameErrorText = _t('username_taken'); 
                                });
                                return;
                             }
                          }
                          
                          // 1. ŞİFRE GÜNCELLEME KONTROLÜ
                          String newPass = _passwordController.text.trim();
                          String currentPass = _currentPasswordController.text.trim();

                          if (newPass.isNotEmpty) {
                             if (currentPass.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_t('enter_current_password_error')), backgroundColor: Colors.red),
                                );
                                return;
                             }

                             // Re-auth
                             bool isReAuth = await _authService.reauthenticate(currentPass);
                             if (!isReAuth) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_t('current_password_invalid')), backgroundColor: Colors.red),
                                );
                                return;
                             }

                             // Update Password
                             bool isPassUpdated = await _authService.updatePassword(newPass);
                             if (!isPassUpdated) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_t('password_update_failed')), backgroundColor: Colors.red),
                                );
                                return;
                             }
                          }

                            
                            // [CRITICAL FIX] Preserve existing fields!
                            // If we create a new User() without passing fields like isAdmin, createdAt, etc.,
                            // they will be reset to default (false/null).
                            // We must use the current _userModel to copy these values.
                            
                            
                            // 2. DİĞER BİLGİLERİ GÜNCELLE
                            if (uid != null) {
                              
                              String? profileImageUrl = _userModel?.profileImageUrl;

                              // Upload new image if selected
                              if (_profileImage != null) {
                                final url = await _firestoreService.uploadProfileImage(_profileImage!, uid);
                                if (url != null) {
                                  profileImageUrl = url;
                                }
                              }

                              User updatedUser;
                              if (_userModel != null) {
                                 updatedUser = User(
                                  id: uid,
                                  name: _nameController.text.trim(),
                                  username: _usernameController.text.trim(),
                                  email: _emailController.text.trim(),
                                  password: "", 
                                  phone: _phoneController.text.trim(),
                                  profileImageUrl: profileImageUrl, // [NEW]
                                  
                                  // Preserved Fields
                                  isAdmin: _userModel!.isAdmin,
                                  isBanned: _userModel!.isBanned,
                                  createdAt: _userModel!.createdAt,
                                  hideCars: _userModel!.hideCars,
                                  hideName: _userModel!.hideName,
                                  notifyMentions: _userModel!.notifyMentions,
                                  notifyReplies: _userModel!.notifyReplies,
                                  notifyNews: _userModel!.notifyNews,
                                  notifySupport: _userModel!.notifySupport,
                                  language: _userModel!.language,
                                  lastForumPostAt: _userModel!.lastForumPostAt,
                                  lastCommentAt: _userModel!.lastCommentAt,
                                 );
                              } else {
                                 updatedUser = User(
                                    id: uid,
                                    name: _nameController.text.trim(),
                                    username: _usernameController.text.trim(),
                                    email: _emailController.text.trim(),
                                    password: "", 
                                    phone: _phoneController.text.trim(),
                                    profileImageUrl: profileImageUrl, // [NEW]
                                 );
                              }
                              await _firestoreService.saveUser(updatedUser);
                              
                              // [NEW] Senkronizasyon (Eski post ve yorumları güncelle)
                              _firestoreService.synchronizeUserData(
                                uid, 
                                updatedUser.name, 
                                updatedUser.username,
                                newProfileImageUrl: profileImageUrl
                              ).then((_) => debugPrint("User data synced to posts/comments"));
                              
                              // Parent state update
                              setState(() {
                                _userModel = updatedUser; // Update local model
                                _username = _usernameController.text.trim();
                                if (profileImageUrl != null) {
                                  // _profileImage is still File, but we won't need it for display if we use NetworkImage from _userModel
                                  // Actually let's keep _profileImage as null to force using NetworkImage from model in UI?
                                  // Or just leave it. If user selected a file, it's fine to show that file.
                                }
                              });
                            }

                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          _passwordController.clear();
                          _currentPasswordController.clear();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_t('profile_updated_msg')),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0059BC),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        shadowColor: Color(0xFF0059BC).withOpacity(0.3),
                      ),
                      child: isCheckingUsername 
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_t('update_btn'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernEditField(IconData icon, String hint, TextEditingController controller, {bool isNumber = false, bool isPassword = false, TextInputType? inputType, String? errorText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.number : inputType,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF0059BC), size: 20),
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500]),
            errorText: errorText,
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[50], // Theme-aware fill
            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[200]!), // Theme-aware border
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFF0059BC), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // --- ÇIKIŞ ---
  // Yukarıda tanımlandı

  @override
  Widget build(BuildContext context) {
    // [NEW] YÜKLENİYORSA SPINNER GÖSTER
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0059BC)),
        ),
      );
    }



    // EĞER GİRİŞ YAPILDIYSA PROFİL SAYFASINI GÖSTER
    if (isLoggedIn) {
      if (isAdmin) {
         return const AdminPanelScreen(initialIndex: 0); // Redirect Admins to Dashboard
      }
      
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.grey[50], // Adaptive Scaffold background
        appBar: AppBar(
          title: Text(
            isAdmin ? _t('admin_panel') : _t('profile'), // Changed 'my_profile' to 'profile' which is "Profilim" in TR
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0059BC), Color(0xFF003B7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _showEditProfileDialog,
              icon: Icon(Icons.edit, color: Colors.white),
            ),
          ],
        ),
        drawer: _buildSidebar(),
        body: SingleChildScrollView(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
          child: Column(
            children: [
              // --- PROFİL KARTI ---
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white, // Adaptive background
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // FOTOĞRAF SEÇME ALANI
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _profileImage != null
                              ? CircleAvatar(
                                  radius: 40,
                                  backgroundImage: FileImage(_profileImage!),
                                )
                              : UserAvatar(
                                  radius: 40,
                                  imageUrl: _userModel?.profileImageUrl,
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[200],
                                  fallbackContent: Icon(
                                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0059BC),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color, // Adaptive text color
                            ),
                          ),
                          Text(
                            "@$_username",
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600], // Adaptive text color
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Email'i gizleyebiliriz veya küçük gösterebiliriz, istek üzerine username ön planda
                          if (_phoneController.text.isNotEmpty)
                            Text(
                              _phoneController.text,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              if (isAdmin) _buildAdminDashboard() else _buildUserDashboard(),
            ],
          ),
        ),
      );
    }
    // GİRİŞ YAPILMADIYSA GİRİŞ EKRANINI GÖSTER
    return _buildAuthScreen();
  }

  // --- KULLANICI ÖZEL PANELİ ---
  Widget _buildUserDashboard() {
    return StreamBuilder<List<Car>>(
      stream: _firestoreService.getGarage(_authService.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("${_t('error_prefix')}${snapshot.error}", style: TextStyle(color: Colors.red));
        
        List<Car> cars = snapshot.data ?? [];
        if (cars.isEmpty) {
           return Center(
             child: Column(
               children: [
                 SizedBox(height: 50),
                 Icon(Icons.no_crash, size: 60, color: Colors.grey),
                 SizedBox(height: 10),
                 Text(_t('garage_empty_msg'), style: TextStyle(color: Colors.grey)),
                 SizedBox(height: 10),
                 ElevatedButton(
                   onPressed: () {
                     Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GarageScreen(showAddCarOnLoad: true)),
                      );
                   }, 
                   child: Text(_t('add_vehicle'))
                 )
               ],
             ),
           );
        }

        if (_selectedCarIndex >= cars.length) _selectedCarIndex = 0;
        Car activeCar = cars[_selectedCarIndex];

        return Column(
          children: [



            // 0. CAR TABS
            Container(
              height: 40,
              margin: EdgeInsets.only(bottom: 20),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 10),
                itemCount: cars.length + 1,
                separatorBuilder: (c, i) => SizedBox(width: 10),
                itemBuilder: (context, index) {
                   final isDark = Theme.of(context).brightness == Brightness.dark;
                   if (index == 0) {
                     // Add Button (First Item)
                     return GestureDetector(
                       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GarageScreen(showAddCarOnLoad: true))),
                       child: Container(
                         padding: EdgeInsets.symmetric(horizontal: 16),
                         alignment: Alignment.center,
                         decoration: BoxDecoration(
                           color: Theme.of(context).cardColor, // Theme-aware
                           borderRadius: BorderRadius.circular(20),
                           border: Border.all(color: const Color(0xFF0059BC)),
                         ),
                         child: Row(
                           children: [
                             Icon(Icons.add, color: const Color(0xFF0059BC), size: 18),
                             SizedBox(width: 5),
                             Text(_t('add_vehicle'), style: TextStyle(color: const Color(0xFF0059BC), fontWeight: FontWeight.bold)),
                           ],
                         ),
                       ),
                     );
                   }
                   // Car Tabs (Index shifted by 1)
                   int carIndex = index - 1;
                   bool isSelected = _selectedCarIndex == carIndex;
                   return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCarIndex = carIndex);
                        _pageController.animateToPage(carIndex, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                     child: AnimatedContainer(
                       duration: Duration(milliseconds: 300),
                       padding: EdgeInsets.symmetric(horizontal: 20),
                       alignment: Alignment.center,
                       decoration: BoxDecoration(
                         color: isSelected ? const Color(0xFF0059BC) : Theme.of(context).cardColor, // Theme-aware
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(color: isSelected ? const Color(0xFF0059BC) : (isDark ? Colors.grey[700]! : Colors.grey.shade300)),
                         boxShadow: isSelected ? [
                           BoxShadow(color: const Color(0xFF0059BC).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                         ] : [],
                       ),
                       child: Text(
                         "${_t('car_numbered')} ${carIndex + 1}",
                         style: TextStyle(
                           fontWeight: FontWeight.bold, 
                           color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700)
                         ),
                       ),
                     ),
                   );
                },
              ),
            ),

            // 1. GARAGE SUMMARY CARD (UNIFIED HEADER + CONTENT)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : const Color(0xFFF5F5F5), // Theme-aware background
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                   // HEADER SECTION
                   Padding(
                     padding: EdgeInsets.fromLTRB(20, 15, 20, 10),
                     child: Row(
                       children: [
                          Container(
                            padding: EdgeInsets.all(5), // Small padding for icon
                            child: Icon(Icons.directions_car, color: Colors.redAccent, size: 24),
                          ),
                          SizedBox(width: 8),
                          Text(_t('my_garage_only'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => GarageScreen(initialIndex: _selectedCarIndex, isReadOnly: false)),
                            ),
                            child: Icon(Icons.keyboard_arrow_right, size: 24, color: Colors.grey),
                          ),
                       ],
                     ),
                   ),
                   
                   // DIVIDER
                   Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.3)), // Theme-aware opacity
                   
                   // CONTENT SECTION (SWIPEABLE)
                   SizedBox(
                     height: 110, // Adjust height as needed for content
                     child: PageView.builder(
                       controller: _pageController,
                       itemCount: cars.length,
                       onPageChanged: (index) {
                         setState(() {
                           _selectedCarIndex = index;
                         });
                       },
                       itemBuilder: (context, index) {
                         Car carItem = cars[index];
                         return GestureDetector(
                             onTap: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (context) => GarageScreen(initialIndex: index, isReadOnly: true)),
                               );
                             },
                             child: Container(
                               padding: EdgeInsets.all(20),
                               color: Theme.of(context).cardColor, // Theme-aware card color
                               child: Row(
                                 children: [
                                   Container(
                                     padding: EdgeInsets.all(12),
                                     decoration: BoxDecoration(
                                       color: const Color(0xFF0059BC).withOpacity(0.1), // Adjusted for consistency
                                       borderRadius: BorderRadius.circular(12),
                                     ),
                                     child: Icon(Icons.directions_car, color: const Color(0xFF0059BC), size: 30),
                                   ),
                                   SizedBox(width: 15),
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       children: [
                                         Text(
                                           "${carItem.brand} ${carItem.model}",
                                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                                           maxLines: 1,
                                           overflow: TextOverflow.ellipsis,
                                         ),
                                         SizedBox(height: 4),
                                         Text(
                                           _t('click_to_see_status'),
                                           style: TextStyle(color: Colors.grey, fontSize: 13),
                                         ),
                                       ],
                                     ),
                                   ),
                                   Icon(Icons.check_circle, color: Colors.green, size: 28),
                                 ],
                               ),
                             ),
                         );
                       },
                     ),
                   ),
                ],
              ),
            ),
            SizedBox(height: 25),


            // --- COLLAPSIBLE VEHICLE DETAILS SECTION ---
            Container(
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white, // Adaptive background
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5),
                ],
              ),
              child: ExpansionTile(
                shape: Border(),
                initiallyExpanded: false,
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.car_repair, color: Color(0xFF0059BC)),
                ),
                title: Text(
                  _t('car_details_actions'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  _t('car_details_actions_desc'),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                childrenPadding: EdgeInsets.all(10),
                children: [
                   // 1. BAKIM TAKİBİ (Yellow Card)
                   _buildMaintenanceStatus(activeCar),
      
                   // 2. MUAYENE DURUMU (Blue Card)
                   _buildInspectionStatus(activeCar),
      
                   // 3. EKSPERTİZ RAPORU
                   _buildExpertiseStatus(activeCar),
                   
                   // 5. GEÇMİŞ ARIZA ANALİZLERİM (Simple Tile)
                    _buildActionTile(
                        Icons.smart_toy,
                        _t('fault_history_mine'),
                        _t('ai_detections'),
                        Colors.redAccent,
                       () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FaultHistoryScreen()));
                       },
                     ),
                ],
              ),
            ),


            // --- GLOBAL USER MENU ITEMS ---

            // FAVORİ ARAÇLARIM
              _buildActionTile(
                   Icons.favorite,
                   _t('fav_cars_title'),
                   _t('edit_list'),
                   Colors.pinkAccent,
                  () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoriteCarsScreen()));
                  },
                ),

            // FAVORİ KARŞILAŞTIRMALARIM
            _buildActionTile(
                   Icons.compare_arrows,
                   _t('fav_comparisons_title'),
                   _t('saved_analyses'),
                   Colors.orangeAccent,
                  () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => FavoriteComparisonsScreen()));
                  },
                ),

             // AÇTIĞIM KONULAR (FORUM)
              _buildActionTile(
                   Icons.forum,
                   _t('my_posts'),
                   _t('my_topics_desc'),
                   Colors.blueAccent,
                  () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyForumPostsScreen()));
                  },
                ),
          ],
        );
      },
    );
  }
 
 
   // --- DİĞER WIDGETLAR ---
 
   Widget _buildActionTile(
     IconData icon,
     String title,
     String subtitle,
     Color color,
     VoidCallback onTap,
   ) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return GestureDetector(
       onTap: onTap,
       child: Container(
         margin: EdgeInsets.only(bottom: 15),
         padding: EdgeInsets.all(15),
         decoration: BoxDecoration(
           color: Theme.of(context).cardColor, // Theme-aware
           borderRadius: BorderRadius.circular(15),
           boxShadow: [
             if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
           ],
         ),
         child: Row(
           children: [
             Container(
               padding: EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: isDark ? color.withOpacity(0.2) : Colors.grey.shade100, // Theme-aware
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Icon(icon, color: color),
             ),
             SizedBox(width: 15),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     title,
                     style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                   ),
                   Text(
                     subtitle,
                     style: TextStyle(color: Colors.grey, fontSize: 12),
                   ),
                 ],
               ),
             ),
             Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
           ],
         ),
       ),
     );
   }
 
   // --- REFACTORED STATUS WIDGETS (TILE STYLE) ---
 
   Widget _buildInspectionStatus(Car activeCar) {
     if (activeCar.nextInspectionDate == null) return SizedBox.shrink();
 
     final now = DateTime.now();
     final diff = activeCar.nextInspectionDate!.difference(now).inDays;
           final isDark = Theme.of(context).brightness == Brightness.dark;
       
       // Screenshot shows light purple/blue bg
       Color bgColor = const Color(0xFFF0F4FF); // Light Blue/Purple
       Color contentColor = const Color(0xFF5C6BC0);
       
       if (diff < 0) {
         bgColor = const Color(0xFFFFEBEE); // Light Red
         contentColor = Colors.red;
       } else if (diff < 30) {
         bgColor = const Color(0xFFFFF3E0); // Light Orange
         contentColor = Colors.orange;
       }
 


      // Dark mode overrides
       if (isDark) {
          bgColor = contentColor.withOpacity(0.15);
       }
 
       String subtitle = _t('inspection_status_next').replaceAll('{date}', '${activeCar.nextInspectionDate!.day}.${activeCar.nextInspectionDate!.month}.${activeCar.nextInspectionDate!.year}').replaceAll('{days}', diff.toString());
       if (diff < 0) subtitle = _t('inspection_status_expired').replaceAll('{days}', diff.toString());
 
       return GestureDetector(
         onTap: () => _showInspectionHistory(context, activeCar),
         child: Container(
           margin: EdgeInsets.only(bottom: 15),
           padding: EdgeInsets.all(15),
           decoration: BoxDecoration(
             color: bgColor,
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: contentColor.withOpacity(0.2)),
           ),
           child: Row(
             children: [
               Container(
                 padding: EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                   shape: BoxShape.circle,
                 ),
                 child: Icon(Icons.verified_user, color: contentColor, size: 20),
               ),
               SizedBox(width: 15),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       _t('inspection_status'),
                       style: TextStyle(color: contentColor, fontWeight: FontWeight.bold),
                     ),
                     Text(
                       subtitle,
                       style: TextStyle(color: contentColor.withOpacity(0.8), fontSize: 12),
                     ),
                   ],
                 ),
               ),
               Icon(Icons.arrow_forward_ios, size: 16, color: contentColor.withOpacity(0.5)),
             ],
           ),
         ),
        );
    }


   Widget _buildMaintenanceStatus(Car activeCar) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
 
     // Screenshot shows Yellow Card
     Color bgColor = const Color(0xFFFFF4E0); // Light Yellow
     Color contentColor = Colors.orange;
 
     String subtitle = _t('maint_status_untrackable');
     
     if (activeCar.nextMaintenanceDate != null) {
       final now = DateTime.now();
       final diff = activeCar.nextMaintenanceDate!.difference(now).inDays;
       subtitle = _t('maint_status_next_days').replaceAll('{days}', diff.toString());
       if (diff < 0) {
          subtitle = _t('maint_status_delayed_days').replaceAll('{days}', diff.toString());
          bgColor = const Color(0xFFFFEBEE);
          contentColor = Colors.red;
       }
     } else if (activeCar.nextMaintenanceKm > 0) {
        int remaining = activeCar.nextMaintenanceKm - activeCar.currentKm;
        subtitle = _t('maint_status_next_km').replaceAll('{km}', remaining.toString());
        if (remaining < 0) {
          subtitle = _t('maint_status_delayed_km').replaceAll('{km}', remaining.abs().toString());
          bgColor = const Color(0xFFFFEBEE);
          contentColor = Colors.red;
        }
     }
 
     // Dark mode overrides
     if (isDark) {
         bgColor = contentColor.withOpacity(0.15);
     }
 
     return GestureDetector(
       onTap: () {
          // Open Detailed Maintenance History directly
          _showMaintenanceHistory(context, activeCar);
       },
       child: Container(
         margin: EdgeInsets.only(bottom: 15),
         padding: EdgeInsets.all(15),
         decoration: BoxDecoration(
           color: bgColor,
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: contentColor.withOpacity(0.2)),
         ),
         child: Row(
           children: [
             Container(
               padding: EdgeInsets.all(10),
               decoration: BoxDecoration(
                 color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                 shape: BoxShape.circle,
               ),
               child: Icon(Icons.build, color: contentColor, size: 20),
             ),
             SizedBox(width: 15),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(
                     _t('maintenance_tracking'),
                     style: TextStyle(color: contentColor, fontWeight: FontWeight.bold),
                   ),
                   Text(
                     subtitle,
                     style: TextStyle(color: contentColor.withOpacity(0.8), fontSize: 12),
                   ),
                 ],
               ),
             ),

              Icon(Icons.arrow_forward_ios, size: 16, color: contentColor.withOpacity(0.5)),
            ],
          ),
        ),
      );
    }

  Widget _buildMaintenanceHistorySummaryCard(Car car) {
     // Replaced by direct call in main list (No longer used as separate widget if we inline, but keeping for safety/legacy removal later)
     return SizedBox.shrink(); 
  }

  Widget _buildExpertiseStatus(Car activeCar) {
    // Calculate Tramer matching GarageScreen logic
    double totalTramer = 0;
    for (var r in activeCar.tramerRecords) {
      var isInsVal = r['isInsurance'];
      bool isInsurance = (isInsVal == true || isInsVal.toString().toLowerCase() == 'true');
      
      if (isInsurance) {
        double amt = 0;
        if (r['amount'] is num) {
          amt = (r['amount'] as num).toDouble();
        } else if (r['amount'] is String) {
          String s = r['amount'].toString().replaceAll('.', '').replaceAll(',', '.');
          amt = double.tryParse(s) ?? 0;
        }
        totalTramer += amt;
      }
    }

    int changedCount = 0;
    int paintedCount = 0;
    activeCar.expertiseReport.forEach((part, status) {
      if (status == 'changed') {
        changedCount++;
      } else if (status == 'painted' || status == 'local_paint') {
        paintedCount++;
      }
    });

    String subtitle = _t('expertise_no_report');
    if (activeCar.expertiseReport.isNotEmpty || activeCar.tramerRecords.isNotEmpty) {
      final tramerText = totalTramer > 0 
          ? _t('tramer_label_with_amount').replaceAll('{amount}', NumberFormat('#,###', 'tr_TR').format(totalTramer)) 
          : _t('tramer_none');
      
      String countsText = "";
      if (activeCar.expertiseReport.isNotEmpty) {
        List<String> stats = [];
        if (changedCount > 0) stats.add(_t('changed_count_text').replaceAll('{count}', changedCount.toString()));
        if (paintedCount > 0) stats.add(_t('painted_count_text').replaceAll('{count}', paintedCount.toString()));
        if (stats.isEmpty) {
          stats.add(_t('error_free_text'));
        }
        countsText = " • ${stats.join(', ')}";
      }

      subtitle = activeCar.expertiseReport.isNotEmpty 
          ? "${_t('expertise_ready_prefix')} • $tramerText$countsText" 
          : tramerText;
    }

      return _buildActionTile(
        Icons.checklist,
        _t('expertise_report'),
        subtitle,
        Colors.green,
        () => _showExpertiseViewerDialog(activeCar),
      );
  }

  Widget _buildSidebar() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isAdmin ? Colors.redAccent : Color(0xFF0059BC),
            ),
            accountName: Text(_nameController.text),
            accountEmail: Text(
              isAdmin ? "admin@allofcar.com" : _emailController.text,
            ),
            currentAccountPicture: GestureDetector(
              onTap: () async {
                 // [EMERGENCY SECRET] 5 Taps to Restore Admin Status
                 // This is hidden for security.
                 _secretTapCount++;
                 if (_secretTapCount >= 5) {
                    _secretTapCount = 0;
                    if (!isAdmin && isLoggedIn) {
                       // SHOW RESTORE DIALOG
                       TextEditingController pinController = TextEditingController();
                       showDialog(
                         context: context, 
                         builder: (context) => AlertDialog(
                           title: Text("Yönetici Kurtarma (ACİL)", style: TextStyle(color: Colors.red)),
                           content: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Text("Yönetici yetkinizi kaybettiniz. Geri yüklemek için lütfen güvenlik kodunu girin."),
                               SizedBox(height: 10),
                               TextField(
                                 controller: pinController,
                                 decoration: InputDecoration(
                                   labelText: "Güvenlik Kodu",
                                   border: OutlineInputBorder(),
                                 ),
                                 obscureText: true,
                                 keyboardType: TextInputType.number,
                               ),
                             ],
                           ),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal")),
                             ElevatedButton(
                               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                               onPressed: () async {
                                  if (pinController.text.trim() == "1453") {
                                      Navigator.pop(context);
                                      await _restoreAdminStatus(); // Call helper method
                                  } else {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hatalı güvenlik kodu!"), backgroundColor: Colors.red));
                                  }
                               }, 
                               child: Text("YETKİYİ GERİ YÜKLE")
                             )
                           ],
                         )
                       );
                    }
                 }
              },
              child: _profileImage != null
                  ? CircleAvatar(
                      backgroundImage: FileImage(_profileImage!),
                      backgroundColor: Colors.white,
                    )
                  : UserAvatar(
                      imageUrl: _userModel?.profileImageUrl,
                      backgroundColor: Colors.white,
                      fallbackContent: Icon(Icons.person, color: Color(0xFF0059BC)),
                    ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text(_t('home_title')),
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),

          Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text(_t('logout_title')),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatStreamCard(_t('admin_users_title'), _firestoreService.getUserCount(), Colors.blue),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildStatStreamCard(_t('admin_cars_title'), _firestoreService.getTotalCarCount(), Colors.orange),
            ),
          ],
        ),
        SizedBox(height: 10),
        
        // Dynamic Pending Approvals
        StreamBuilder<int>(
          stream: _firestoreService.getPendingModerationCount(),
          builder: (context, modSnapshot) {
            return StreamBuilder<int>(
              stream: _firestoreService.getNewsPoolCount(),
              builder: (context, newsSnapshot) {
                final totalPending = (modSnapshot.data ?? 0) + (newsSnapshot.data ?? 0);
                return _buildInfoCard(
                  Icons.pending_actions_rounded,
                  _t('pending_approvals_title'),
                  totalPending > 0 
                      ? _t('pending_approvals_msg').replaceAll('{count}', totalPending.toString()) 
                      : _t('no_pending_approvals_msg'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                    );
                  },
                );
              },
            );
          },
        ),
        
        // YÖNETİCİ PANELİ (AI BRAIN)
        if (isAdmin)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.red),
                title: Text(
                  _t('admin_panel_ai_brain'),
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_t('manage_ai_settings')),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminPanelScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatStreamCard(String title, Stream<int> stream, Color color) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final countStr = NumberFormat("#,###", "tr_TR").format(count);
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Text(
                countStr,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title, style: TextStyle(color: color)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 15),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // Theme-aware
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Color(0xFF0059BC), size: 30),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color), // Theme-aware
                  ),
                  Text(subtitle, style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }


  // --- LOGIN EKRANI ---
  Widget _buildAuthScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50], // Adaptive background
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF0059BC).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: 60,
                  color: Color(0xFF0059BC),
                ),
              ),
              SizedBox(height: 20),
              Text(
                isLoginMode ? _t('login') : _t('sign_up'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0059BC),
                ),
              ),
              SizedBox(height: 30),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200], // Theme-aware
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    _buildToggleButton(_t('login'), true),
                    _buildToggleButton(_t('register'), false),
                  ],
                ),
              ),
              SizedBox(height: 30),
              if (!isLoginMode) ...[
                _buildTextField(
                  Icons.person,
                  _t('name_surname'),
                  _nameController,
                  inputType: TextInputType.name,
                ),
                SizedBox(height: 15),
              ],
              _buildTextField(
                Icons.email,
                _t('email_label'),
                _emailController,
                inputType: TextInputType.emailAddress,
              ),
              SizedBox(height: 15),
              _buildTextField(
                Icons.lock,
                _t('password_label'),
                _passwordController,
                isPassword: true,
                inputType: TextInputType.visiblePassword,
              ),
              if (isLoginMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      _t('forgot_password_q'),
                      style: TextStyle(
                        color: Color(0xFF0059BC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // YÖNETİCİ PANELİ (Sadece Adminler Görebilir)
              // YÖNETİCİ PANELİ (Sadece Adminler Görebilir)
              if (isAdmin)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings, color: Colors.red),
                      title: Text(
                        _t('admin_panel_ai_brain'),
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_t('manage_ai_settings')),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPanelScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0059BC),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    isLoginMode ? _t('login_btn_caps') : _t('register_btn_caps'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }

  Widget _buildToggleButton(String text, bool activeState) {
    bool isActive = isLoginMode == activeState;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isLoginMode = activeState),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).cardColor : Colors.transparent, // Theme-aware
            borderRadius: BorderRadius.circular(25),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1), // Theme-aware
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Color(0xFF0059BC) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String hint,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType? inputType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  // --- MUAYENE İŞLEMLERİ ---


  void _showAddInspectionDialog(BuildContext context, Car car) {
    final TextEditingController dateController = TextEditingController();
    final TextEditingController kmController = TextEditingController();
    final TextEditingController nextDateController = TextEditingController();
    DateTime? selectedDate;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setState) {
            void updateNextDate() {
              if (selectedDate != null) {
                final yearsToAdd = car.isCommercial ? 1 : 2;
                DateTime next = DateTime(selectedDate!.year + yearsToAdd,
                    selectedDate!.month, selectedDate!.day);
                nextDateController.text =
                    "${next.day}.${next.month}.${next.year}";
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor, // Theme-aware background
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade100)), // Theme-aware
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('new_inspection_title'),
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color, // Theme-aware
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: Colors.grey),
                          visualDensity: VisualDensity.compact,
                        )
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Muayene Tarihi Label
                          Text(
                            _t('inspection_date_label'),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: dateController,
                            readOnly: true,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            decoration: InputDecoration(
                              hintText: _t('select_date_hint'),
                              hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              prefixIcon: Icon(Icons.calendar_today, color: const Color(0xFF0059BC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), 
                                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300)
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), 
                                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300)
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), 
                                borderSide: BorderSide(color: const Color(0xFF0059BC), width: 2)
                              ),
                              filled: true,
                              fillColor: isDark ? Colors.grey[800] : Colors.white,
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                     return Theme(
                                       data: Theme.of(context).copyWith(
                                         colorScheme: isDark 
                                            ? ColorScheme.dark(primary: const Color(0xFF0059BC), onPrimary: Colors.white, surface: Colors.grey[900]!)
                                            : ColorScheme.light(primary: const Color(0xFF0059BC)),
                                       ),
                                       child: child!,
                                    );
                                  }
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                  dateController.text =
                                      "${picked.day}.${picked.month}.${picked.year}";
                                  updateNextDate();
                                });
                              }
                            },
                          ),
                          SizedBox(height: 24),
                          
                          // KM Label
                          Text(
                            _t('km_label'),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: kmController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            decoration: InputDecoration(
                              hintText: _t('km_hint_short'),
                              hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              prefixIcon: Icon(Icons.speed, color: const Color(0xFF0059BC)),
                              suffixText: _t('km_unit'),
                              suffixStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), 
                                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300)
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), 
                                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300)
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), 
                                borderSide: BorderSide(color: const Color(0xFF0059BC), width: 2)
                              ),
                              filled: true,
                              fillColor: isDark ? Colors.grey[800] : Colors.white,
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          SizedBox(height: 24),
                          
                          // Gelecek Muayene Label
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _t('next_inspection_label'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  car.isCommercial ? "${_t('vehicle_type_commercial')}: +1 Yıl" : "${_t('vehicle_type_private')}: +2 Yıl",
                                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: nextDateController,
                            readOnly: true,
                            enabled: false, 
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.event_repeat, color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15), 
                                borderSide: BorderSide.none
                              ),
                              filled: true,
                              fillColor: isDark ? Colors.grey[800] : Colors.grey.shade100,
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),

                          SizedBox(height: 40),

                          // SAVE BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (selectedDate != null && kmController.text.isNotEmpty) {
                                  int newKm = int.tryParse(kmController.text.trim()) ?? 0;
                                  
                                  // 1. New KM Check
                                   if (newKm < car.currentKm) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(_t('error_km_lower_than_current')), backgroundColor: Colors.red),
                                      );
                                      return;
                                   }
                                    
                                   // 2. History Check
                                    int maxHistoryKm = 0;
                                    if (car.inspectionHistory.isNotEmpty) {
                                       for (var record in car.inspectionHistory) {
                                          int hKm = int.tryParse(record['km'].toString()) ?? 0;
                                          if (hKm > maxHistoryKm) maxHistoryKm = hKm;
                                       }
                                    }
                                    if (newKm < maxHistoryKm) {
                                       ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(_t('error_km_lower_than_history')), backgroundColor: Colors.red),
                                      );
                                      return;
                                    }

                                   String uid = _authService.currentUser!.uid;

                                  // Smart KM Update
                                  if (newKm > car.currentKm) {
                                     try {
                                       await _firestoreService.updateCarKm(uid, car.id!, newKm);
                                     } catch (e) {
                                       debugPrint("KM Update Error: $e");
                                     }
                                  }
                                  
                                  // Next Date Calc
                                   final yearsToAdd = car.isCommercial ? 1 : 2;
                                   DateTime nextDate = DateTime(selectedDate!.year + yearsToAdd,
                                       selectedDate!.month, selectedDate!.day);

                                  final inspectionData = {
                                    'date': Timestamp.fromDate(selectedDate!),
                                    'km': newKm,
                                    'nextDate': Timestamp.fromDate(nextDate),
                                    'result': 'Geçti',
                                    'isCommercial': car.isCommercial, 
                                  };

                                  try {
                                    await _firestoreService.addInspection(
                                      uid,
                                      car.id!,
                                      inspectionData,
                                    );
                                    
                                    if (context.mounted) {
                                       Navigator.pop(context); // Close sheet
                                       ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(content: Text(_t('inspection_saved_msg')), backgroundColor: Colors.green),
                                       );
                                    }
                                  } catch (e) {
                                     if (context.mounted) {
                                       ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(content: Text("${_t('error_prefix')}$e"), backgroundColor: Colors.red),
                                       );
                                     }
                                  }
                                } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(content: Text(_t('enter_date_km_error')), backgroundColor: Colors.orange),
                                       );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF0059BC),
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: Color(0xFF0059BC).withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(_t('save_inspection_btn'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
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




  // --- BAKIM GEÇMİŞİ BOTTOM SHEET (Requested Feature) ---
  void _showMaintenanceHistory(BuildContext context, Car car) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // Listen to live updates if possible, or just use snapshot.
        // Since we are adding items, we want the list to update. 
        // We'll wrap in a StreamBuilder listening to the specific car (or garage) to get updates.
        return StreamBuilder<List<Car>>(
          stream: _firestoreService.getGarage(_authService.currentUser!.uid),
          builder: (context, snapshot) {
            // Find updated car
            Car currentCar = car;
            if (snapshot.hasData) {
               try {
                 currentCar = snapshot.data!.firstWhere((c) => c.id == car.id);
               } catch (_) {}
            }

            final history = List<Map<String, dynamic>>.from(currentCar.history);
            // Sort by date descending
            history.sort((a, b) {
                DateTime dateA = DateTime.now();
                DateTime dateB = DateTime.now();
                if (a['date'] is Timestamp) dateA = (a['date'] as Timestamp).toDate();
                if (b['date'] is Timestamp) dateB = (b['date'] as Timestamp).toDate();
                // If stored as string "dd/MM/yyyy"
                if (a['date'] is String) {
                   try {
                     var p = (a['date'] as String).split('/');
                     dateA = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
                   } catch (_) {}
                }
                if (b['date'] is String) {
                   try {
                     var p = (b['date'] as String).split('/');
                     dateB = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
                   } catch (_) {}
                }
                return dateB.compareTo(dateA);
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor, // Theme-aware
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // HEADER
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('maintenance_history_title'),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0059BC).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add, color: const Color(0xFF0059BC)),
                            onPressed: () async {
                              // ... (onPressed logic remains same)
                              final result = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => AddMaintenanceScreen(car: currentCar, isSheet: true),
                              );

                              if (result != null) {
                                  // Simplified logic reuse or duplication as in original
                                  String? uid = _authService.currentUser?.uid;
                                  if (uid != null) {
                                    int km = int.tryParse(result['km']?.toString() ?? '0') ?? 0;
                                    DateTime date = DateTime.now();
                                    if (result['date'] != null) {
                                      try {
                                        List<String> parts = result['date'].split('/');
                                        if (parts.length == 3) {
                                          date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                                        }
                                      } catch (e) {
                                        debugPrint("Date parse error: $e");
                                      }
                                    }
                                    
                                    if (km > currentCar.currentKm) {
                                      await _firestoreService.updateCarKm(uid, currentCar.id!, km);
                                    }
                                    
                                    try {
                                      await _firestoreService.addMaintenance(uid, currentCar.id!, result, km, date, true);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('new_maintenance_saved_msg')), backgroundColor: Colors.green));
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${_t('error_prefix')}$e"), backgroundColor: Colors.red));
                                      }
                                    }
                                  }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
                  
                  // LIST
                  Expanded(
                    child: history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 70, color: Colors.grey.shade300),
                              SizedBox(height: 16),
                              Text(_t('no_maint_history'), style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(24),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            DateTime date = DateTime.now();
                            if (item['date'] is Timestamp) {
                                date = (item['date'] as Timestamp).toDate();
                            } else if (item['date'] is String) {
                               try {
                                 var p = (item['date'] as String).split('/');
                                 date = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
                               } catch (_) {}
                            }
                            
                            int km = int.tryParse(item['km']?.toString() ?? '0') ?? 0;
                            String cost = item['cost']?.toString() ?? '';
                            String action = _getLocalizedAction(item['action']);
                            
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor, // Theme-aware
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  if (!isDark) BoxShadow(
                                    color: Colors.grey.withOpacity(0.08),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade100),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Icon Box
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.build_circle, color: Colors.orange, size: 24),
                                    ),
                                    SizedBox(width: 16),
                                    
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            action,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "${DateFormat('dd.MM.yyyy').format(date)} • $km KM",
                                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey.shade600, fontSize: 13),
                                          ),
                                          if (cost.isNotEmpty && cost != "0")
                                            Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Text(
                                                "$cost ₺",
                                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Delete (Optional, but good to have)
                                    // Since we don't have delete logic for maintenance yet in Profile, maybe skip or add simple one?
                                    // Inspect history has delete. Maint history usually should too.
                                    // But I don't see deleteMaintenance in ProfileScreen logic I read.
                                    // Let's add a placeholder or omit for now to match user request "similar to photo".
                                    // The photo shows a list. 
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }








  void _showInspectionHistory(BuildContext context, Car car) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent, // Transparent for rounded corners
        builder: (context) {
           final isDark = Theme.of(context).brightness == Brightness.dark;
           return Container(
             padding: EdgeInsets.all(20),
             decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor, // Theme-aware
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       _t('inspection_history_title'),
                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                     ),
                     IconButton(
                       icon: Icon(Icons.add_circle, color: const Color(0xFF0059BC)),
                       onPressed: () {
                         Navigator.pop(context);
                         _showAddInspectionDialog(context, car);
                       },
                     ),
                   ],
                 ),
                 SizedBox(height: 10),
                 if (car.inspectionHistory.isEmpty) 
                    Text(_t('no_records_found'), style: TextStyle(color: Colors.grey))
                 else
                 Expanded(
                   child: ListView.builder(
                     itemCount: car.inspectionHistory.length,
                     itemBuilder: (context, index) {
                        var rec = car.inspectionHistory[index];
                        return ListTile(
                          title: Text(_t('registered_maint_inspection'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                          subtitle: Text("${rec['date']} - ${rec['km']} km", style: TextStyle(color: Colors.grey)),
                          trailing: Text(rec['result'] ?? '', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                        );
                     }
                   ),
                 )
               ],
             ),
           );
        }
      );
  }

  void _showExpertiseViewerDialog(Car car) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CarExpertiseScreen(car: car),
    );
  }

  String _getLocalizedAction(String? action) {
    if (action == null || action.isEmpty) return _t('maintenance_default_title');
    // Check if it's already a key
    if (action.startsWith('maint_action_')) return _t(action);
    
    // Map legacy strings (Case Insensitive)
    switch (action.toLowerCase()) {
      case 'periyodik bakım':
      case 'periodic maintenance': 
      case 'periodik bakım': // Handle typo/variant from backend/legacy
        return _t('maint_action_periodic');
      case 'yağ değişimi': 
      case 'oil change':
        return _t('maint_action_oil_change');
      case 'fren bakımı': 
      case 'brake maintenance':
        return _t('maint_action_brake_maint');
      case 'lastik değişimi': 
      case 'tire change':
        return _t('maint_action_tire_change');
      case 'tamir': 
      case 'repair': 
        return _t('maint_action_repair'); 
    }
    return action;
  }
}
