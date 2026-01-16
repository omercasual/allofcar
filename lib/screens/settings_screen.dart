import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../services/language_service.dart';
import '../utils/app_localizations.dart';

import 'profile_screen.dart';
import 'support_screen.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';



class SettingsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  const SettingsScreen({super.key, this.onNavigateToProfile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedLanguage = "Türkçe";
  bool _notificationsEnabled = true;

  // Privacy Settings
  bool _hideMyCars = false;
  bool _hideMyName = false;
  
  // Notification Settings
  bool _notifyMentions = true;
  bool _notifyReplies = true;
  bool _notifyNews = true;
  bool _notifySupport = true;
  

  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _selectedLanguage = LanguageService().currentLanguage == 'en' ? 'English' : 'Türkçe';
  }

  // Helper method for translation using AppLocalizations
  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  Future<void> _loadSettings() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      final userModel = await _firestoreService.getUser(uid);
      if (userModel != null && mounted) {
        setState(() {
          _hideMyCars = userModel.hideCars;
          _hideMyName = userModel.hideName;
          _notifyMentions = userModel.notifyMentions;
          _notifyReplies = userModel.notifyReplies;
          _notifyNews = userModel.notifyNews;
          _notifySupport = userModel.notifySupport;
          // Language is handled by LanguageService global state, but we sync dropdown UI here
          String langCode = LanguageService().currentLanguage;
          _selectedLanguage = langCode == 'en' ? 'English' : 'Türkçe';
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0059BC))),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('account'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            _buildSettingsTile(
              context,
              icon: Icons.person_outline,
              title: _t('profile'),
              onTap: () {
                if (widget.onNavigateToProfile != null) {
                  Navigator.pop(context); // Close settings
                  widget.onNavigateToProfile!(); // Switch tab
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            _buildSettingsTile(
              context,
              icon: Icons.security,
              title: _t('privacy'),
              onTap: () => _openPrivacySettingsPage(context),
            ),
            const SizedBox(height: 10),
            if (_authService.currentUser != null)
              _buildSettingsTile(
                context,
                icon: Icons.logout,
                title: _t('logout'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.redAccent),
                onTap: () async {
                  await _authService.signOut();
                  if (mounted) {
                    if (widget.onNavigateToProfile != null) {
                      Navigator.pop(context);
                      widget.onNavigateToProfile!();
                    } else {
                       Navigator.of(context).pushAndRemoveUntil(
                           MaterialPageRoute(builder: (context) => const ProfileScreen()),
                           (Route<dynamic> route) => false,
                       );
                    }
                  }
                },
              )
            else
              _buildSettingsTile(
                context,
                icon: Icons.login,
                title: "${_t('login')} / ${_t('register')}",
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
                onTap: () {
                    if (widget.onNavigateToProfile != null) {
                      Navigator.pop(context);
                      widget.onNavigateToProfile!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    }
                },
              ),
            const SizedBox(height: 25),

            Text(
              _t('general'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            
            _buildSettingsTile(
              context,
              icon: Icons.support_agent,
              title: _t('settings_support_feedback'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupportScreen()),
                );
              },
            ),

            const SizedBox(height: 10),

            _buildSettingsTile(
              context,
              icon: Icons.brightness_6, // Icon for Theme
              title: _t('app_theme_title'),
              trailing: DropdownButtonHideUnderline(
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeService().themeModeNotifier,
                  builder: (context, currentMode, _) {
                    return DropdownButton<ThemeMode>(
                      value: currentMode,
                      icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                      dropdownColor: Theme.of(context).cardColor,
                      onChanged: (ThemeMode? newMode) {
                        if (newMode != null) {
                          ThemeService().setTheme(newMode);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(_t('theme_light'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(_t('theme_dark'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            _buildSettingsTile(
              context,
              icon: Icons.view_sidebar_outlined,
              title: _t('nav_bar_settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NavBarSettingsScreen()),
                );
              },
            ),



            const SizedBox(height: 10),
            
            _buildSettingsTile(
              context,
              icon: Icons.language,
              title: _t('language'),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                  dropdownColor: Theme.of(context).cardColor,
                  onChanged: (String? newValue) async {
                    if (newValue == null) return;
                    
                    String code = newValue == 'English' ? 'en' : 'tr';
                    await LanguageService().setLanguage(code);
                    String currentLang = code; // Since service updates async, use local var for instant feedback logic if needed
                    
                    setState(() {
                      _selectedLanguage = newValue;
                    });
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            currentLang == 'en' 
                              ? "Language changed to English. AI and App will now respond in English." 
                              : "Dil Türkçe olarak ayarlandı. Uygulama ve yapay zeka Türkçe yanıt verecek."
                          ),
                          backgroundColor: const Color(0xFF0059BC),
                        ),
                      );
                    }
                  },
                  items: <String>['Türkçe', 'English']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            _buildSettingsTile(
              context,
              icon: Icons.notifications_none,
              title: _t('notifications'),
              onTap: () => _openNotificationSettingsPage(context),
            ),

            const SizedBox(height: 25),
            Text(
              _t('about'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            _buildSettingsTile(
              context,
              icon: Icons.info_outline,
              title: _t('version'),
              trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 10),
            
            _buildSettingsTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: _t('privacy_policy'),
              onTap: () {
                _openInfoPage(context, _t('privacy_policy'), _t('privacy_policy_content'));
              },
            ),
            const SizedBox(height: 10),
            
            _buildSettingsTile(
              context,
              icon: Icons.description_outlined,
              title: _t('terms'),
              onTap: () {
                _openInfoPage(context, _t('terms'), _t('terms_content'));
              },
            ),
            const SizedBox(height: 10),

             _buildSettingsTile(
              context,
              icon: Icons.help_outline,
              title: _t('about_guide'),
              onTap: () {
                _openAboutAppPage(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- BİLDİRİM AYARLARI ---
  void _openNotificationSettingsPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
           builder: (context, setModalState) {
             return Container(
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
               ),
               padding: EdgeInsets.only(
                 top: 24, left: 24, right: 24, 
                 bottom: MediaQuery.of(context).viewInsets.bottom + 24
               ),
               child: SingleChildScrollView(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Color(0xFF0059BC), size: 28),
                        const SizedBox(width: 10),
                        Text(_t('notif_options'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Bulk Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                              setState(() {
                                 _notifyMentions = true;
                                 _notifyReplies = true;
                                 _notifyNews = true;
                                 _notifySupport = true;
                              });
                              setModalState(() {
                                 _notifyMentions = true;
                                 _notifyReplies = true;
                                 _notifyNews = true;
                                 _notifySupport = true;
                              });
                                await _updateNotif(
                                  notifyMentions: true,
                                  notifyReplies: true,
                                  notifyNews: true,
                                  notifySupport: true
                                );
                                
                                // [NEW] FCM Topic Sync (Subscribe to News)
                                await NotificationService().subscribeToTopic('news_notifications');

                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(_t('enable_all')),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                              setState(() {
                                 _notifyMentions = false;
                                 _notifyReplies = false;
                                 _notifyNews = false;
                                 _notifySupport = false;
                              });
                              setModalState(() {
                                 _notifyMentions = false;
                                 _notifyReplies = false;
                                 _notifyNews = false;
                                 _notifySupport = false;
                              });
                                await _updateNotif(
                                  notifyMentions: false,
                                  notifyReplies: false,
                                  notifyNews: false,
                                  notifySupport: false
                                );

                                // [NEW] FCM Topic Sync (Unsubscribe from News)
                                await NotificationService().unsubscribeFromTopic('news_notifications');

                          },
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: Text(_t('disable_all')),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    
                    _buildSwitch(_t('mentions'), _t('mentions_desc'), _notifyMentions, (val) async {
                        setState(() => _notifyMentions = val);
                        setModalState(() => _notifyMentions = val);
                        await _updateNotif(notifyMentions: val);
                    }),
                    const Divider(),
                    _buildSwitch(_t('replies'), _t('replies_desc'), _notifyReplies, (val) async {
                        setState(() => _notifyReplies = val);
                        setModalState(() => _notifyReplies = val);
                        await _updateNotif(notifyReplies: val);
                    }),
                    const Divider(),
                    _buildSwitch(_t('news'), _t('news_desc'), _notifyNews, (val) async {
                        setState(() => _notifyNews = val);
                        setModalState(() => _notifyNews = val);
                        await _updateNotif(notifyNews: val);
                        
                        // [NEW] Real FCM Toggle
                        if (val) {
                          await NotificationService().subscribeToTopic('news_notifications');
                        } else {
                          await NotificationService().unsubscribeFromTopic('news_notifications');
                        }
                    }),


                    const Divider(),
                    _buildSwitch(_t('support'), _t('support_desc'), _notifySupport, (val) async {
                        setState(() => _notifySupport = val);
                        setModalState(() => _notifySupport = val);
                        await _updateNotif(notifySupport: val);
                    }),
                    const SizedBox(height: 20),
                 ],
               ),
             ),
             );
           }
        );
      },
    );
  }

  Future<void> _updateNotif({bool? notifyMentions, bool? notifyReplies, bool? notifyNews, bool? notifySupport}) async {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
          await _firestoreService.updateNotificationSettings(uid, 
             notifyMentions: notifyMentions,
             notifyReplies: notifyReplies,
             notifyNews: notifyNews,
             notifySupport: notifySupport
          );
      }
  }

  Widget _buildSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      activeColor: const Color(0xFF0059BC),
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }

  // --- GİZLİLİK AYARLARI ---
  void _openPrivacySettingsPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
           builder: (context, setModalState) {
             return Container(
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
               ),
               padding: const EdgeInsets.all(24),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.security, color: Color(0xFF0059BC), size: 28),
                        const SizedBox(width: 10),
                        Text(_t('privacy'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    SwitchListTile(
                      title: Text(_t('hide_cars'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_t('hide_cars_desc')),
                      value: _hideMyCars,
                      activeColor: const Color(0xFF0059BC),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                         setState(() => _hideMyCars = val);
                         setModalState(() => _hideMyCars = val);
                         
                         final uid = _authService.currentUser?.uid;
                         if (uid != null) {
                           await _firestoreService.updatePrivacySettings(uid, hideCars: val);
                         }
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: Text(_t('hide_name'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_t('hide_name_desc')),
                      value: _hideMyName,
                      activeColor: const Color(0xFF0059BC),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                         setState(() => _hideMyName = val);
                         setModalState(() => _hideMyName = val);
                         
                         final uid = _authService.currentUser?.uid;
                         if (uid != null) {
                           await _firestoreService.updatePrivacySettings(uid, hideName: val);
                         }
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('note_local'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 20),
                 ],
               ),
             );
           }
        );
      },
    );
  }

  // --- MODERN BİLGİ SAYFASI ---
  void _openInfoPage(BuildContext context, String title, String content) {
    // Determine icon based on title
    IconData headerIcon = Icons.article;
    if (title.contains("Gizlilik")) headerIcon = Icons.privacy_tip;
    else if (title.contains("Koşullar")) headerIcon = Icons.gavel;
    else if (title.contains("Hakkında")) headerIcon = Icons.info;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).appBarTheme.foregroundColor)),
            centerTitle: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                       color: const Color(0xFF0059BC).withOpacity(0.1),
                       shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, size: 40, color: const Color(0xFF0059BC)),
                  ),
                ),
                const SizedBox(height: 25),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       ...content.split('\n\n').map((block) {
                          if (block.startsWith('**')) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10, top: 15),
                              child: Text(
                                block.replaceAll('**', ''),
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                block,
                                style: TextStyle(fontSize: 15, height: 1.6, color: Theme.of(context).textTheme.bodyMedium?.color),
                              ),
                            );
                          }
                       }),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Center(child: Text(_t('thanks'), style: TextStyle(color: Colors.grey[400], fontSize: 12))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ZENGİN "HAKKINDA & REHBER" SAYFASI ---
  void _openAboutAppPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Hafif gri
          appBar: AppBar(
            title: Text(_t('about_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // LOGO VE İSİM
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.directions_car, size: 60, color: Color(0xFF0059BC)),
                ),
                const SizedBox(height: 15),
                const Text(
                  "AllofCar",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0059BC)),
                ),
                Text(
                  _t('slogan'),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_t('what_can_do'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,)),
                ),
                const SizedBox(height: 15),

                // FEATURE CARDS
                _buildGuideCard(
                  icon: Icons.garage,
                  title: _t('feat_garage'),
                  description: _t('feat_garage_desc'),
                ),
                _buildGuideCard(
                  icon: Icons.compare_arrows,
                  title: _t('feat_compare'),
                  description: _t('feat_compare_desc'),
                ),
                _buildGuideCard(
                  icon: Icons.smart_toy,
                  title: _t('feat_ai'),
                  description: _t('feat_ai_desc'),
                ),
                _buildGuideCard(
                  icon: Icons.forum_rounded,
                  title: _t('feat_comm'),
                  description: _t('feat_comm_desc'),
                ),

                const SizedBox(height: 20),
                const SizedBox(height: 20),
                 Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_t('how_to'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,)),
                ),
                const SizedBox(height: 10),
                 _buildGuideCard(
                  icon: Icons.add_circle_outline,
                  title: _t('how_garage'),
                  description: _selectedLanguage == 'English' 
                    ? "Add car info and photos by tapping the '+' button on the Home or Garage tab." 
                    : "Ana sayfadaki veya Garaj sekmesindeki '+' butonuna basarak aracınızın bilgilerini ve fotoğraflarını yükleyebilirsiniz.",
                ),
                
                const SizedBox(height: 30),
                Text("${_t('version')} 1.0.0", style: TextStyle(color: Colors.grey[400])),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard({required IconData icon, required String title, required String description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0059BC).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0059BC), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSettingsTile(BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0059BC).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0059BC), size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}

class NavBarSettingsScreen extends StatelessWidget {
  const NavBarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Helper to get localized string
    String _t(String key) => AppLocalizations.get(key, Localizations.localeOf(context).languageCode);

    Widget _buildSettingsTile(
      BuildContext context, {
      required IconData icon,
      required String title,
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      return ListTile(
        leading: Icon(icon, color: const Color(0xFF0059BC)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('nav_settings_title')), 
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                children: [
                   _buildSettingsTile(
                    context,
                    icon: Icons.palette_outlined, 
                    title: _t('nav_bar_theme_title'), 
                    trailing: DropdownButtonHideUnderline(
                      child: ValueListenableBuilder<String>(
                        valueListenable: ThemeService().navBarThemeNotifier,
                        builder: (context, currentNavTheme, _) {
                          return DropdownButton<String>(
                            value: currentNavTheme,
                            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                            dropdownColor: Theme.of(context).cardColor,
                            onChanged: (String? newTheme) {
                              if (newTheme != null) {
                                ThemeService().setNavBarTheme(newTheme);
                              }
                            },
                            items: [
                              DropdownMenuItem(
                                value: 'blue',
                                child: Text(_t('nav_bar_theme_blue'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              ),
                              DropdownMenuItem(
                                value: 'white',
                                child: Text(_t('nav_bar_theme_white'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const Divider(),
                   _buildSettingsTile(
                    context,
                    icon: Icons.view_comfy_alt_outlined, 
                    title: _t('nav_bar_style_title'), 
                    trailing: DropdownButtonHideUnderline(
                      child: ValueListenableBuilder<String>(
                        valueListenable: ThemeService().navBarStyleNotifier,
                        builder: (context, currentNavStyle, _) {
                          return DropdownButton<String>(
                            value: currentNavStyle,
                            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                            dropdownColor: Theme.of(context).cardColor,
                            onChanged: (String? newStyle) {
                              if (newStyle != null) {
                                ThemeService().setNavBarStyle(newStyle);
                              }
                            },
                            items: [
                              DropdownMenuItem(
                                value: 'floating',
                                child: Text(_t('nav_bar_style_floating'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              ),
                              DropdownMenuItem(
                                value: 'classic',
                                child: Text(_t('nav_bar_style_classic'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
