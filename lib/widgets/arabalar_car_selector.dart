import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import '../services/comparison_scraper_service.dart';
import '../services/car_search_service.dart'; // [NEW] For logos

class ArabalarCarSelector extends StatefulWidget {
  final Function(String brand, String model, String year, String version, String versionId) onSelectionComplete;

  const ArabalarCarSelector({Key? key, required this.onSelectionComplete}) : super(key: key);

  @override
  _ArabalarCarSelectorState createState() => _ArabalarCarSelectorState();
}

class _ArabalarCarSelectorState extends State<ArabalarCarSelector> {
  // Helper for localization
  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);
  final ComparisonScraperService _service = ComparisonScraperService();

  // Selection Steps
  int _currentStep = 0; // 0: Brand, 1: Model, 2: Year, 3: Version

  // Data Lists
  List<Map<String, String>> _brands = [];
  List<Map<String, String>> _models = [];
  List<String> _years = [];
  List<Map<String, String>> _versions = [];

  // Data Loading States
  bool _isLoading = true;
  String? _error;

  // Selected Values
  Map<String, String>? _selectedBrand;
  Map<String, String>? _selectedModel;
  String? _selectedYear;
  Map<String, String>? _selectedVersion;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final brands = await _service.getBrands();
      // Sort alphabetically
      brands.sort((a, b) => a['name']!.compareTo(b['name']!));
      
      setState(() {
        _brands = brands;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = _t('error_brands_load') + ': $e';
      });
    }
  }

  Future<void> _loadModels(String brandName) async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final models = await _service.getModels(brandName);
      setState(() {
        _models = models;
        _isLoading = false;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = _t('error_models_load') + ': $e'; });
    }
  }

  Future<void> _loadYears(String brandName, String modelName) async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final years = await _service.getYears(brandName, modelName);
      setState(() {
        _years = years;
        _isLoading = false;
        _currentStep = 2;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = _t('error_years_load') + ': $e'; });
    }
  }

  Future<void> _loadVersions(String brandName, String modelName, String year) async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final versions = await _service.getVersions(brandName, modelName, year);
      setState(() {
        _versions = versions;
        _isLoading = false;
        _currentStep = 3;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = _t('error_versions_load') + ': $e'; });
    }
  }

  void _handleBack() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : const Color(0xFFF4F5F9), // Light background for modern look
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              if (_currentStep > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: _handleBack,
                  color: const Color(0xFF0059BC),
                ),
              Expanded(
                child: Text(
                  _getHeaderText(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_currentStep > 0)
                const SizedBox(width: 48), // Balance back button
            ],
          ),
          const SizedBox(height: 10),

          // Selected Breadcrumbs
          if (_currentStep > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (_selectedBrand != null) _buildStepChip(_selectedBrand!['name']!, 0),
                  if (_selectedModel != null) _buildStepChip(_selectedModel!['name']!, 1),
                  if (_selectedYear != null) _buildStepChip(_selectedYear!, 2),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0059BC)))
              : _error != null 
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, int stepIndex) {
    return GestureDetector(
      onTap: () {
        setState(() {
           _currentStep = stepIndex;
           // If jumping back to brand, clear everything? 
           // For now just navigate back to that step's list.
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF0059BC).withOpacity(0.3)),
          boxShadow: [
             BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 4, offset: const Offset(0,2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 12, color: Colors.grey)
          ],
        ),
      ),
    );
  }

  String _getHeaderText() {
    switch (_currentStep) {
      case 0: return _t('select_brand');
      case 1: return _t('select_model');
      case 2: return _t('select_year');
      case 3: return _t('select_version');
      default: return "";
    }
  }

  Widget _buildList() {
    switch (_currentStep) {
      case 0:
        // [NEW] GRID LAYOUT FOR BRANDS
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _brands.length,
          itemBuilder: (context, index) {
            final brand = _brands[index];
            final brandName = brand['name']!;
            final logoUrl = CarSearchService.brandLogos[brandName]; // Get Logo

            return InkWell(
              onTap: () {
                setState(() => _selectedBrand = brand);
                _loadModels(brandName);
              },
              borderRadius: BorderRadius.circular(15),
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
                    if (logoUrl != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.network(
                           logoUrl, 
                           height: 40, 
                           width: 40, 
                           fit: BoxFit.contain,
                           errorBuilder: (c,e,s) => const Icon(Icons.directions_car, size: 30, color: Colors.grey),
                        ),
                      )
                    else
                      const Icon(Icons.directions_car, size: 30, color: Colors.grey),
                    
                    const SizedBox(height: 5),
                    Text(
                      brandName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      case 1:
        return ListView.separated(
          itemCount: _models.length,
          separatorBuilder: (c,i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final model = _models[index];
            return ListTile(
              tileColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
              title: Text(model['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                setState(() => _selectedModel = model);
                _loadYears(_selectedBrand!['name']!, model['name']!);
              },
            );
          },
        );
      case 2:
        return ListView.separated(
          itemCount: _years.length,
          separatorBuilder: (c,i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final year = _years[index];
            return ListTile(
              tileColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
              title: Text(year, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                setState(() => _selectedYear = year);
                _loadVersions(_selectedBrand!['name']!, _selectedModel!['name']!, year);
              },
            );
          },
        );
      case 3:
        return ListView.separated(
          itemCount: _versions.length,
          separatorBuilder: (c,i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final version = _versions[index];
            return ListTile(
              tileColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
              title: Text(version['name']!, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF0059BC)),
              onTap: () {
                setState(() => _selectedVersion = version);
                widget.onSelectionComplete(
                  _selectedBrand!['name']!,
                  _selectedModel!['name']!,
                  _selectedYear!,
                  version['name']!,
                  version['id']!,
                );
                Navigator.pop(context);
              },
            );
          },
        );
      default:
        return const SizedBox();
    }
  }
}
