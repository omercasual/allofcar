import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../utils/app_localizations.dart'; // [NEW]
import '../services/language_service.dart'; // [NEW]

import '../widgets/user_avatar.dart'; 


class AdminUserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const AdminUserProfileScreen({super.key, required this.userData, required this.userId});

  @override
  State<AdminUserProfileScreen> createState() => _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends State<AdminUserProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Map<String, dynamic> _currentUserData;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _checkAutoUnban();
  }
  
  void _checkAutoUnban() async {
    final bool isBanned = _currentUserData['isBanned'] ?? false;
    if (isBanned) {
        dynamic expirationRaw = _currentUserData['banExpiration'];
        DateTime? expiration;
        if (expirationRaw is Timestamp) {
           expiration = expirationRaw.toDate();
        } else if (expirationRaw is String) {
           expiration = DateTime.tryParse(expirationRaw);
        }
        
        if (expiration != null && DateTime.now().toUtc().isAfter(expiration.toUtc())) {
             debugPrint("Auto-Unbanning user ${widget.userId}");
             // Expired -> Unban automatically
             await _firestoreService.setBanStatus(widget.userId, false);
             if (mounted) {
                 setState(() {
                      _currentUserData['isBanned'] = false;
                      _currentUserData['banExpiration'] = null;
                 });
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Bu kullanıcının ban süresi dolmuş, otomatik olarak kaldırıldı."), backgroundColor: Colors.green)
                 );
             }
        }
    }
  }

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    
    // Parse data safely from state (to reflect auto-unban)
    final String name = _currentUserData['name'] ?? 'İsimsiz';
    final String username = _currentUserData['username'] ?? '@';
    final String email = _currentUserData['email'] ?? 'E-posta yok';
    final String? phone = _currentUserData['phone'];
    final bool isAdmin = _currentUserData['isAdmin'] ?? false;
    final bool isBanned = _currentUserData['isBanned'] ?? false;
    final String language = _currentUserData['language'] ?? 'tr';
    
    // Timestamps
    dynamic createdAtRaw = _currentUserData['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }
    
    // Last Seen
    final lastSeenTs = _currentUserData['lastSeen']; 
    
    final String createdStr = createdAt != null 
        ? DateFormat("dd MMM yyyy HH:mm").format(createdAt) 
        : _t('unknown');

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        actions: [
           IconButton(
             icon: const Icon(Icons.edit, color: Colors.blueAccent),
             tooltip: "Kullanıcıyı Düzenle",
             onPressed: () {
                _showEditUserDialog(context);
             },
           ),
           IconButton(
             icon: Icon(isBanned ? Icons.lock_open : Icons.block, color: isBanned ? Colors.green : Colors.red),
             tooltip: isBanned ? _t('unban_dialog_title') : _t('ban_dialog_title'),
             onPressed: () {
               // Create User object for the dialog
               final user = User.fromMap({..._currentUserData, 'id': widget.userId}); 
               _showAdminBanDialog(context, user, _firestoreService);
             },
           )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            UserAvatar(
              imageUrl: _currentUserData['profileImageUrl'],
              radius: 50,
              backgroundColor: isAdmin ? Colors.redAccent : Colors.blueAccent,
              fallbackContent: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "?",
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(email, style: const TextStyle(color: Colors.grey)),
            if (isAdmin) 
               Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Chip(label: Text(_t('admin_role')), backgroundColor: Colors.red, labelStyle: const TextStyle(color: Colors.white)),
              ),
              
            const SizedBox(height: 32),
            
            _buildInfoTile(Icons.phone, _t('phone_number_label'), phone ?? "-"),
            _buildInfoTile(Icons.calendar_today, _t('admin_reg_date'), createdStr),
            _buildInfoTile(Icons.language, _t('language'), language.toUpperCase()),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Stats (Garage, Faults)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBadge(Icons.directions_car, _t('home_garage'), _firestoreService.getGarage(widget.userId).map((s) => s.length.toString())),
                _buildStatBadge(Icons.build, _t('admin_tab_faults'), _firestoreService.getFaultLogs(widget.userId).map((s) => s.length.toString())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Stream<String> stream) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snapshot) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            Text(snapshot.data ?? "...", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        );
      }
    );
  }

  // Enhanced Ban Dialog (Duplicated for standalone usage)
  void _showAdminBanDialog(BuildContext context, User user, FirestoreService firestoreService) {
    if (user.isBanned) {
      // UNBAN CONFIRMATION
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('unban_dialog_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(_t('unban_user_confirm').replaceFirst('{}', user.username)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                firestoreService.setBanStatus(user.id!, false);
                Navigator.pop(ctx);
                Navigator.pop(context); // Close Profile Screen too to refresh list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_t('admin_unban_success')), backgroundColor: Colors.green)
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: Text(_t('unban_confirm_btn')),
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
                title: Text(_t('ban_dialog_title'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('ban_user_confirm').replaceFirst('{}', user.username)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      value: selectedDurationDays,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: _t('ban_duration_label'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: 1, child: Text(_t('ban_day_1'))),
                        DropdownMenuItem(value: 3, child: Text(_t('ban_day_3'))),
                        DropdownMenuItem(value: 7, child: Text(_t('ban_week_1'))),
                        DropdownMenuItem(value: 30, child: Text(_t('ban_month_1'))),
                        DropdownMenuItem(value: null, child: Text(_t('ban_permanent'))),
                      ],
                      onChanged: (val) => setState(() => selectedDurationDays = val),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(_t('cancel'), style: const TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      DateTime? expiration;
                      if (selectedDurationDays != null) {
                        expiration = DateTime.now().add(Duration(days: selectedDurationDays!));
                      }
                      
                      firestoreService.setBanStatus(user.id!, true, expirationDate: expiration);
                      
                      // [NEW] Send Notification to User
                      firestoreService.getFcmTokenByUsername(user.username).then((token) {
                        if (token != null) {
                           String durationText = selectedDurationDays == null 
                               ? "Süresiz" 
                               : "$selectedDurationDays Gün";
                           
                           firestoreService.sendFcmNotification(
                             token: token, 
                             title: "Hesabınız Askıya Alındı", 
                             body: "Hesabınız $durationText süreyle erişime kapatılmıştır. Detaylar için destek ile iletişime geçebilirsiniz."
                           ).catchError((e) => debugPrint("Notification Error: $e"));
                        }
                      });

                      Navigator.pop(ctx);
                      Navigator.pop(context); // Close Profile Screen to refresh
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('admin_ban_success')), backgroundColor: Colors.red)
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: Text(_t('ban_confirm_btn')),
                  ),
                ],
              );
            }
          );
        },
      );
    }
  }

  // [NEW] Edit User Dialog for Admins
  void _showEditUserDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(text: _currentUserData['name']);
    final TextEditingController usernameController = TextEditingController(text: _currentUserData['username']);
    bool removePhoto = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
           builder: (context, setState) {
             return AlertDialog(
                title: Text("Kullanıcıyı Düzenle", style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     TextField(
                       controller: nameController,
                       decoration: const InputDecoration(labelText: "İsim Soyisim", border: OutlineInputBorder()),
                     ),
                     const SizedBox(height: 10),
                     TextField(
                       controller: usernameController,
                       decoration: const InputDecoration(labelText: "Kullanıcı Adı", border: OutlineInputBorder()),
                     ),
                     const SizedBox(height: 15),
                     CheckboxListTile(
                        title: const Text("Profil Fotoğrafını Sıfırla (Kaldır)"),
                        value: removePhoto,
                        activeColor: Colors.red,
                        onChanged: (val) {
                           setState(() => removePhoto = val ?? false);
                        },
                     ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(_t('cancel'), style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                     onPressed: () async {
                        try {
                           Map<String, dynamic> updates = {};
                           
                           if (nameController.text != _currentUserData['name']) {
                              updates['name'] = nameController.text.trim();
                           }
                           if (usernameController.text != _currentUserData['username']) {
                              updates['username'] = usernameController.text.trim();
                           }
                           if (removePhoto) {
                              updates['profileImageUrl'] = null;
                           }
                           
                           if (updates.isNotEmpty) {
                              // 1. Update Firestore User
                              await FirebaseFirestore.instance.collection('users').doc(widget.userId).update(updates);
                              
                              // 2. Sync if name/username/photo changed
                              await _firestoreService.synchronizeUserData(
                                widget.userId, 
                                updates['name'] ?? _currentUserData['name'], 
                                updates['username'] ?? _currentUserData['username'],
                                newProfileImageUrl: removePhoto ? null : (_currentUserData['profileImageUrl']) // If not removed, keep old (or null if it was null)
                              );

                              if (mounted) {
                                 setState(() {
                                    if (updates.containsKey('name')) _currentUserData['name'] = updates['name'];
                                    if (updates.containsKey('username')) _currentUserData['username'] = updates['username'];
                                    if (removePhoto) _currentUserData['profileImageUrl'] = null;
                                 });
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kullanıcı güncellendi!"), backgroundColor: Colors.green));
                              }
                           }
                           Navigator.pop(ctx);
                        } catch (e) {
                           debugPrint("Update Error: $e");
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
                        }
                     },
                     child: const Text("Kaydet"),
                  )
                ],
             );
           }
        );
      },
    );
  }
}
