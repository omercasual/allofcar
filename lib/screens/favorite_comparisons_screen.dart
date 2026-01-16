import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/car_comparison.dart';
import 'comparison_result_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class FavoriteComparisonsScreen extends StatelessWidget {
  const FavoriteComparisonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      return Scaffold(body: Center(child: Text(AppLocalizations.get('login_required', LanguageService().currentLanguage))));
    }

    String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('fav_comparisons_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestoreService.getComparisonFavorites(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text("${_t('error')}: ${snapshot.error}"));
          }
          
          final favorites = snapshot.data ?? [];
          
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  const Text(
                    "Henüz favori karşılaştırma yok.", // Keep TR as fallback or use key
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: favorites.length,
            separatorBuilder: (_,__) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              final fav = favorites[index];
              final car1 = fav['car1Name'] ?? '?';
              final car2 = fav['car2Name'] ?? '?';
              final winner = fav['winner'] ?? '?';
              // Convert Map back to Object if needed, or pass map loosely
              
              return Dismissible(
                key: Key(fav['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  firestoreService.removeComparisonFavorite(uid, fav['id']);
                },
                child: GestureDetector(
                  onTap: () {
                    // Reconstruct CarComparison object
                    final comparison = CarComparison(
                      winner: fav['winner'],
                      details: fav['details'] ?? "",
                      scoreA: (fav['scoreA'] as num).toDouble(),
                      scoreB: (fav['scoreB'] as num).toDouble(),
                      radarScoresA: List<double>.from(fav['radarScoresA'] ?? []),
                      radarScoresB: List<double>.from(fav['radarScoresB'] ?? []),
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ComparisonResultScreen(
                          car1Name: car1,
                          car2Name: car2,
                          comparisonData: comparison,
                          isNewCarMode: fav['isNewCarMode'] ?? false, 
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                         BoxShadow(
                           color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1), 
                           blurRadius: 10, 
                           offset: const Offset(0, 4)
                         )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.compare_arrows, color: Colors.pink),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("$car1 vs $car2", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                              const SizedBox(height: 5),
                              Text("${_t('winner_label')}: $winner", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             IconButton(
                               icon: const Icon(Icons.delete, color: Colors.red),
                               onPressed: () {
                                 firestoreService.removeComparisonFavorite(uid, fav['id']);
                               },
                             ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
