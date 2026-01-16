import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import '../services/comparison_scraper_service.dart';

class ComparisonCarSelector extends StatefulWidget {
  final Function(String brand, String model, String versionId, String versionName, String brandSlug, String modelSlug) onSelectionComplete;

  const ComparisonCarSelector({super.key, required this.onSelectionComplete});

  @override
  State<ComparisonCarSelector> createState() => _ComparisonCarSelectorState();
}

class _ComparisonCarSelectorState extends State<ComparisonCarSelector> {
  final ComparisonScraperService _service = ComparisonScraperService();

  // Helper for localization
  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  // Selection Data
  List<Map<String, String>> _brands = [];
  List<Map<String, String>> _models = [];
  List<Map<String, String>> _versions = [];

  // Selections
  Map<String, String>? _selectedBrand; // {name, slug}
  Map<String, String>? _selectedModel; // {name, slug}
  Map<String, String>? _selectedVersion; // {name, id}

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() => _isLoading = true);
    var list = await _service.getBrands();
    if (mounted) {
      setState(() {
        _brands = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _onBrandSelected(Map<String, String> brand) async {
    setState(() {
      _selectedBrand = brand;
      _selectedModel = null;
      _selectedVersion = null;
      _models = [];
      _versions = [];
      _isLoading = true;
    });

    try {
      var list = await _service.getModels(brand['name']!);
      if (mounted) {
        setState(() {
          _models = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading models: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onModelSelected(Map<String, String> model) async {
    setState(() {
      _selectedModel = model;
      _selectedVersion = null;
      _versions = [];
      _isLoading = true;
    });

    try {
      // Logic: Comparison service requires Year. We will try to fetch years, then fetch versions for ALL years or Latest.
      // Better UX: Fetch all years, then for each year fetch versions, and flatten the list.
      // Optimization: Just fetch latest year for now to be safe and fast.
      
      var years = await _service.getYears(_selectedBrand!['name']!, model['name']!);
      List<Map<String, String>> allVersions = [];

      if (years.isNotEmpty) {
         // Sort years descending? usually they are.
         // Let's take top 3 years to avoid too many requests
         var targetYears = years.take(3).toList();
         
         for (var year in targetYears) {
            var vList = await _service.getVersions(_selectedBrand!['name']!, model['name']!, year);
            // Append year to name for clarity
            for (var v in vList) {
               allVersions.add({
                 'name': "${v['name']} ($year)",
                 'id': v['id']!,
               });
            }
         }
      }
      
      if (mounted) {
        setState(() {
          _versions = allVersions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading versions: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height:1),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0059BC)))
              : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
           // Back button if in deeper level
           if (_selectedBrand != null)
             IconButton(
               icon: const Icon(Icons.arrow_back),
               onPressed: () {
                 setState(() {
                    if (_selectedVersion != null) {
                         _selectedVersion = null;
                         // Stay on versions
                    } else if (_selectedModel != null) {
                        _selectedModel = null; 
                        _versions = [];
                    } else {
                        _selectedBrand = null;
                        _models = [];
                    }
                 });
               }
             ),
           
           Expanded(
             child: Text(
               _getHeaderTitle(),
               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
           ),
           
            IconButton(
               icon: const Icon(Icons.close),
               onPressed: () => Navigator.pop(context),
             ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    if (_selectedBrand == null) return _t('select_brand');
    if (_selectedModel == null) return _t('select_model');
    return _t('select_version');
  }

  Widget _buildContent() {
     if (_selectedBrand == null) return _buildBrandList();
     if (_selectedModel == null) return _buildModelList();
     return _buildVersionList();
  }

  Widget _buildBrandList() {
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _brands.length,
      separatorBuilder: (c,i) => const SizedBox(height:5),
      itemBuilder: (context, index) {
        final b = _brands[index];
        final logo = b['logo'];
        return ListTile(
          leading: (logo != null && logo.isNotEmpty) 
              ? CachedNetworkImage(
                  imageUrl: logo,
                  width: 40,
                  height: 40,
                  errorWidget: (c,u,e) => const Icon(Icons.car_repair),
                )
              : const Icon(Icons.car_repair),
          title: Text(b['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => _onBrandSelected(b),
          tileColor: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
      },
    );
  }

  Widget _buildModelList() {
    if (_models.isEmpty) return Center(child: Text(_t('model_not_found'), style: const TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _models.length,
      separatorBuilder: (c,i) => const SizedBox(height:5),
      itemBuilder: (context, index) {
        final m = _models[index];
        return ListTile(
          title: Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => _onModelSelected(m),
          tileColor: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
      },
    );
  }

  Widget _buildVersionList() {
    if (_versions.isEmpty) return Center(child: Text(_t('version_not_found'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _versions.length,
      separatorBuilder: (c,i) => const SizedBox(height:5),
      itemBuilder: (context, index) {
        final v = _versions[index];
        return ListTile(
          title: Text(v['name']!, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          leading: const Icon(Icons.check_circle_outline, color: Color(0xFF0059BC)),
          onTap: () {
             widget.onSelectionComplete(
               _selectedBrand!['name']!,
               _selectedModel!['name']!,
               v['id']!,
               v['name']!,
               _selectedBrand!['name']!, // Fallback for slug
               _selectedModel!['name']!
             );
             Navigator.pop(context);
          },
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(10)
          ),
        );
      },
    );
  }
}
