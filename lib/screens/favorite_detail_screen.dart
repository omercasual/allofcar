import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class FavoriteDetailScreen extends StatelessWidget {
  final Map<String, dynamic> car;

  const FavoriteDetailScreen({super.key, required this.car});

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  Widget build(BuildContext context) {
    // Determine data structure (Zero KM cards vs Second Hand results might use different keys)
    final String name = car['name'] ?? car['title'] ?? _t('unnamed_car');
    final String price = car['price'] ?? _t('price_not_specified');
    final dynamic imageObj = car['image'] ?? car['imageUrl'];
    final String? link = car['link'] ?? car['url'];
    
    // Details
    final String? year = car['year']?.toString();
    final String? km = car['km']?.toString();
    final String? location = car['location']?.toString();
    final bool isZeroKm = car['isZeroKm'] ?? false;
    final bool hasHeavyDamage = car['hasHeavyDamage'] ?? false;
    final String? expertiseStatus = car['expertiseStatus'];

    final String currentLang = LanguageService().currentLanguage;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(name, style: Theme.of(context).appBarTheme.titleTextStyle ?? const TextStyle(fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION
            if (imageObj != null)
              Hero(
                tag: 'favorite_${car['id'] ?? car['link']}',
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imageObj.toString().startsWith('http')
                      ? Image.network(imageObj.toString(), fit: BoxFit.cover, errorBuilder: (c, o, s) => _buildPlaceholder(context))
                      : Image.asset(imageObj.toString(), fit: BoxFit.cover, errorBuilder: (c, o, s) => _buildPlaceholder(context)),
                ),
              )
            else
              _buildPlaceholder(context, height: 200),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE & PRICE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.blue[300] : const Color(0xFF0059BC)
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 25),
                  const Divider(),
                  const SizedBox(height: 15),
                  
                  // SPECS GRID
                  _buildSpecRow(context, Icons.calendar_today, _t('year_label'), year ?? _t('unknown')),
                  _buildSpecRow(context, Icons.speed, _t('km_label'), isZeroKm ? "0 KM" : (km ?? _t('unknown'))),
                  _buildSpecRow(context, Icons.location_on, _t('location_label'), location ?? _t('unknown')),
                  _buildSpecRow(context, Icons.info_outline, _t('status_label'), isZeroKm ? _t('zero_km') : _t('second_hand')),

                  const SizedBox(height: 25),
                  const Divider(),
                  const SizedBox(height: 15),

                  // HEAVY DAMAGE WARNING
                  if (hasHeavyDamage)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.red.withOpacity(0.2) : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.red[900]! : Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.report_problem, color: Colors.red[700]),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              _t('heavy_damage_warning'),
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // EXPERTISE SECTION
                  Text(_t('expertise_report'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildExpertiseSection(context, expertiseStatus),

                  const SizedBox(height: 40),
                  
                  // ACTION BUTTON
                  if (link != null && link.startsWith('http'))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        label: Text(_t('go_to_ad'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0059BC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.inAppWebView),
                      ),
                    ),
                  
                  const SizedBox(height: 100), // Space at bottom
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600], size: 22),
          const SizedBox(width: 15),
          Text(label, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertiseSection(BuildContext context, String? status) {
    final String currentLang = LanguageService().currentLanguage;
    // Generate a mock report or show status
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _buildExpertiseRow(context, _t('unpainted_parts'), status == "Boyasız / Hatasız" ? _t('all') : _t('unknown')),
          const Divider(),
          _buildExpertiseRow(context, _t('changed_parts'), status == "Değişen Var" ? _t('exists') : _t('none')),
          const Divider(),
          _buildExpertiseRow(context, _t('general_status'), status ?? (currentLang == 'tr' ? "Ekspertiz raporu için ilan detayına bakınız." : "Check ad details for expertise report.")),
        ],
      ),
    );
  }

  Widget _buildExpertiseRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {double height = 250}) {
    return Container(
      height: height,
      width: double.infinity,
      color: Theme.of(context).cardColor,
      child: const Icon(Icons.directions_car, size: 80, color: Colors.grey),
    );
  }
}
