import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'favorite_detail_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class FavoriteCarsScreen extends StatefulWidget {
  const FavoriteCarsScreen({super.key});

  @override
  State<FavoriteCarsScreen> createState() => _FavoriteCarsScreenState();
}

class _FavoriteCarsScreenState extends State<FavoriteCarsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  String? get uid => _authService.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
     if (uid == null) {
      return Scaffold(body: Center(child: Text(_t('login_required'))));
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _t('fav_cars_title'),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getFavorites(uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(child: Text("${_t('error')}: ${snapshot.error}"));
          }

          final favorites = snapshot.data ?? [];

          return favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(
                        _t('no_fav_cars'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final car = favorites[index];
                    return Card(
                      color: Theme.of(context).cardColor,
                      margin: const EdgeInsets.only(bottom: 15),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: InkWell(
                        onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (context) => FavoriteDetailScreen(car: car))
                           );
                        },
                        borderRadius: BorderRadius.circular(15),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                            // Araç Resmi
                            Container(
                              width: 100,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: (car['image'] ?? car['imageUrl']) != null
                                  ? ((car['image'] ?? car['imageUrl']).toString().startsWith('http')
                                      ? Image.network(car['image'] ?? car['imageUrl'])
                                      : Image.asset(car['image'] ?? car['imageUrl'], errorBuilder: (c, o, s) => const Icon(Icons.directions_car, size: 50, color: Colors.grey)))
                                  : const Icon(
                                      Icons.directions_car,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 15),
                            // Bilgiler
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    car['name'] ?? car['title'] ?? 'İsimsiz Araç',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    car['price'] ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF0059BC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Silme Butonu
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                if (car['id'] != null) {
                                  await _firestoreService.removeFavorite(uid!, car['id']);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_t('fav_removed')),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),);
                  },
                );
        },
      ),
    );
  }
}
