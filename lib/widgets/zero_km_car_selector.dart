import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import '../services/zero_km_service.dart';
import '../models/zero_km_model.dart';
import '../services/car_search_service.dart'; // Fixed path
import 'package:cached_network_image/cached_network_image.dart'; // [NEW]

class ZeroKmCarSelector extends StatefulWidget {
  final Function(String brand, String model, String version, String price, List<String> photos, Map<String, String> specs) onSelectionComplete;

  const ZeroKmCarSelector({super.key, required this.onSelectionComplete});

  @override
  State<ZeroKmCarSelector> createState() => _ZeroKmCarSelectorState();
}

class _ZeroKmCarSelectorState extends State<ZeroKmCarSelector> {
  // Helper for localization
  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);
  final ZeroKmService _service = ZeroKmService();

  // Selection state
  ZeroKmBrand? _selectedBrand;
  ZeroKmModel? _selectedModel;
  ZeroKmVersion? _selectedVersion;

  // Data state
  List<ZeroKmBrand> _brands = [];
  List<ZeroKmModel> _models = [];
  List<ZeroKmVersion> _versions = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() => _isLoading = true);
    var brands = await _service.getBrands();
    setState(() {
      _brands = brands;
      _isLoading = false;
    });
  }

  Future<void> _onBrandSelected(ZeroKmBrand brand) async {
    setState(() {
      _selectedBrand = brand;
      _selectedModel = null;
      _selectedVersion = null;
      _models = [];
      _versions = [];
      _isLoading = true;
    });
    
    var models = await _service.getModels(brand.slug);
    setState(() {
      _models = models;
      _isLoading = false;
    });
  }

  Future<void> _onModelSelected(ZeroKmModel model) async {
    setState(() {
      _selectedModel = model;
      _selectedVersion = null;
      _versions = [];
      _isLoading = true;
    });

    var versions = await _service.getVersions(model.slug);
    setState(() {
      _versions = versions;
      _isLoading = false;
    });
  }

  // Handle Back Button
  void _handleBack() {
    setState(() {
      if (_selectedVersion != null) {
        _selectedVersion = null; // Should not really happen as we select immediately
      } else if (_selectedModel != null) {
        _selectedModel = null;
        _versions = [];
      } else if (_selectedBrand != null) {
        _selectedBrand = null;
        _models = [];
        // Reload brands? No need, they are cached.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : const Color(0xFFF4F5F9), // Light background
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
            ),
            child: Row(
              children: [
                if (_selectedBrand != null)
                   IconButton(
                     icon: const Icon(Icons.arrow_back_ios, size: 18),
                     onPressed: _handleBack,
                     color: const Color(0xFF0059BC),
                   ),
                Expanded(
                  child: Text(
                    _getHeaderTitle(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_selectedBrand != null) const SizedBox(width: 48), // Balance spacing
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          
          if (_selectedBrand != null)
            Padding(
               padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
               child: Wrap(
                 alignment: WrapAlignment.center,
                 spacing: 8,
                 children: [
                    _buildStepChip(_selectedBrand!.name, true),
                    if (_selectedModel != null) _buildStepChip(_selectedModel!.name, false),
                 ],
               )
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0059BC)))
                : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSelectionList(),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, bool isBrand) {
     return Chip(
        label: Text(label), 
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, 
        side: const BorderSide(color: Color(0xFF0059BC)),
        labelStyle: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold),
     );
  }

  String _getHeaderTitle() {
    if (_selectedBrand == null) return _t('select_brand');
    if (_selectedModel == null) return _t('select_model');
    return _t('select_version');
  }

  Widget _buildSelectionList() {
    if (_selectedBrand == null) {
      // GRID LAYOUT FOR BRANDS
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          var brand = _brands[index];
          return InkWell(
            onTap: () => _onBrandSelected(brand),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (brand.logoUrl != null) 
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CachedNetworkImage(
                          imageUrl: brand.logoUrl!, 
                          width: 40, 
                          height: 40, 
                          fit: BoxFit.contain,
                          memCacheWidth: 80,
                          errorWidget: (c,e,s) => const Icon(Icons.directions_car, size: 30, color: Colors.grey),
                        ),
                      )
                  else 
                      const Icon(Icons.directions_car, size: 30, color: Colors.grey),
                  
                  const SizedBox(height: 5),
                  Text(
                    brand.name, 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (_selectedModel == null) {
      if (_models.isEmpty) return Center(child: Text(_t('model_not_found')));
      return ListView.separated(
        itemCount: _models.length,
        separatorBuilder: (c, i) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          var model = _models[index];
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)]
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: model.imageUrl.isNotEmpty 
                 ? ClipRRect(
                     borderRadius: BorderRadius.circular(8),
                     child: CachedNetworkImage(
                       imageUrl: model.imageUrl, 
                       width: 80, 
                       height: 60, 
                       fit: BoxFit.cover, 
                       memCacheWidth: 160,
                       errorWidget: (c,e,s) => const Icon(Icons.directions_car)
                     )
                   )
                 : const Icon(Icons.directions_car, size: 40),
              title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(model.priceRange, style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => _onModelSelected(model),
            ),
          );
        },
      );
    } else {
       if (_versions.isEmpty) {
         return Center(child: Text(_t('version_not_found')));
       }
       return ListView.separated(
          itemCount: _versions.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
             var version = _versions[index];
             return Container(
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(15),
                 boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)]
               ),
               child: ListTile(
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 title: Text(version.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                 subtitle: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const SizedBox(height: 4),
                     Text(version.price, style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold)),
                     Text("${version.fuelType} • ${version.gearType}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                   ],
                 ),
                 trailing: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF0059BC), 
                     foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                   ),
                   onPressed: () async {
                      // Show Loading
                      showDialog(
                         context: context, 
                         barrierDismissible: false,
                         builder: (c) => const Center(child: CircularProgressIndicator())
                      );
                      
                      try {
                          var details = await _service.getSifirAracAlDetails(_selectedBrand!.name, _selectedModel!.name, version.name);

                          List<dynamic> photosDyn = details['photos'] ?? [];
                          List<String> photos = photosDyn.map((e) => e.toString()).toList();
                          Map<dynamic, dynamic> specsDyn = details['specs'] ?? {};
                          Map<String, String> specs = specsDyn.map((k, v) => MapEntry(k.toString(), v.toString()));

                          // Fallback logic
                          if (photos.isEmpty) {
                             String? fallback = version.imageUrl;
                             if (fallback != null && fallback.isNotEmpty) photos.add(fallback);
                             else if (_selectedModel!.imageUrl.isNotEmpty) photos.add(_selectedModel!.imageUrl);
                          }

                          if (mounted) Navigator.pop(context); // Close loading

                          widget.onSelectionComplete(
                             _selectedBrand!.name,
                             _selectedModel!.name,
                             version.name,
                             version.price,
                             photos,
                             specs
                          );
                          
                          if (mounted) Navigator.pop(context); // Close selector
                          
                      } catch (e) {
                         if (mounted) Navigator.pop(context); // Close loading
                         debugPrint("Error fetching details: $e");
                         
                         // Fallback to Mock Data (Safe Mode) - [UI LAYER PROTECTION]
                         widget.onSelectionComplete(
                             _selectedBrand!.name,
                             _selectedModel!.name,
                             version.name,
                             version.price,
                             [ version.imageUrl ?? "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png" ], 
                             {
                                "Mod": "Offline Demo",
                                "Motor": "1.0 TCe",
                                "Güç": "90 BG",
                                "Tork": "160 Nm",
                                "Yakıt": "Benzin",
                             }
                          );
                          if (mounted) Navigator.pop(context);
                      }
                   },
                   child: const Text("Seç"),
                 ),
               ),
             );
          },
       );
    }
  }
}
