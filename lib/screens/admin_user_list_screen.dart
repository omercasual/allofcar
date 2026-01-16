import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart'; // [NEW]
import 'admin_user_profile_screen.dart'; // [NEW]
import '../utils/app_localizations.dart'; // [NEW]
import '../services/language_service.dart'; // [NEW]

class AdminUserListScreen extends StatelessWidget {
  const AdminUserListScreen({super.key});

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('admin_all_users')),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("${_t('error')}: ${snapshot.error}"));
          }

          final users = snapshot.data?.docs ?? [];
          if (users.isEmpty) {
            return Center(child: Text(_t('admin_no_users')));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;
              final String name = data['name'] ?? 'İsimsiz';
              final String email = data['email'] ?? 'E-posta yok';
              final String username = data['username'] ?? '@';
              final bool isAdmin = data['isAdmin'] ?? false;
              final bool isBanned = data['isBanned'] ?? false;
              
              dynamic createdAtRaw = data['createdAt'];
              DateTime? createdAt;
              if (createdAtRaw is Timestamp) {
                createdAt = createdAtRaw.toDate();
              } else if (createdAtRaw is String) {
                createdAt = DateTime.tryParse(createdAtRaw);
              }

              String dateStr = createdAt != null 
                  ? DateFormat("dd MMM yyyy").format(createdAt) 
                  : "-";

              return ListTile(
                leading: UserAvatar(
                  imageUrl: data['profileImageUrl'],
                  radius: 20,
                  backgroundColor: isAdmin ? Colors.redAccent : (isBanned ? Colors.grey : Colors.blueAccent),
                  fallbackContent: Icon(isAdmin ? Icons.security : Icons.person, color: Colors.white),
                ),
                title: Text("$name ($username)"),
                subtitle: Text("$email\n${_t('admin_reg_date')}: $dateStr"),
                isThreeLine: true,
                trailing: isBanned 
                    ? const Icon(Icons.block, color: Colors.red) 
                    : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AdminUserProfileScreen(userData: data, userId: users[index].id)
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
