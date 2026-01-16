import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart'; // [NEW]
import '../services/car_search_service.dart';
import '../services/zero_km_service.dart'; // [NEW]
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/zero_km_model.dart'; // [NEW]
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class CarFinderScreen extends StatefulWidget {
  const CarFinderScreen({super.key});

  @override
  State<CarFinderScreen> createState() => _CarFinderScreenState();
}

class _CarFinderScreenState extends State<CarFinderScreen> {
  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  // --- FİLTRE DEĞİŞKENLERİ ---
  String _selectedCategory = 'otomobil'; 
  
  String? _selectedBrand;
  String? _selectedSeries;
  String? _selectedModel; 
  String? _selectedHardware; 
  
  List<String> _brands = CarSearchService.brandLogos.keys.toList()..sort(); 
  List<String> _seriesList = [];
  List<String> _modelList = [];   
  List<String> _hardwareList = []; 
  
  bool _isSeriesLoading = false;
  bool _isModelLoading = false;
  bool _isHardwareLoading = false;

  RangeValues _priceRange = const RangeValues(0, 5000000); 
  RangeValues _kmRange = const RangeValues(0, 400000);
  
  int? _minYear; int? _maxYear;
  int? _minPower; int? _maxPower;
  int? _minVolume; int? _maxVolume;
  
  final List<String> _gearOptions = ["Otomatik", "Yarı Otomatik", "Manuel"];
  List<String> _selectedGears = [];
  
  final List<String> _fuelOptions = ["Benzin", "Dizel", "Benzin & LPG", "Hibrit", "Elektrik"];
  List<String> _selectedFuels = [];

  final List<String> _caseTypes = ["Sedan", "Hatchback 5 Kapı", "Hatchback 3 Kapı", "Station Wagon", "MPV", "Coupe", "Cabrio", "Roadster"];
  List<String> _selectedCaseTypes = [];

  final List<String> _tractionOptions = ["Önden Çekiş", "Arkadan İtiş", "4WD (Sürekli)", "AWD (Elektronik)"];
  List<String> _selectedTractions = [];

  final List<String> _colorOptions = ["Beyaz", "Siyah", "Gri", "Gümüş Gri", "Kırmızı", "Mavi", "Lacivert", "Yeşil", "Turuncu", "Sarı", "Kahverengi", "Bej"];
  List<String> _selectedColors = [];

  bool? _warranty; 
  bool? _heavyDamage; 
  final List<String> _fromWhomOptions = ["Sahibinden", "Galeriden", "Yetkili Bayiden"];
  String? _selectedFromWhom;
  bool? _exchange; 

  final double _minPriceLimit = 0;
  final double _maxPriceLimit = 10000000;
  final double _minKmLimit = 0;
  final double _maxKmLimit = 500000;
  
  final FirestoreService _firestoreService = FirestoreService();
  final CarSearchService _searchService = CarSearchService();
  List<CarListing> _searchResults = [];
  
  bool _isLoading = false;
  bool _isLoadMoreLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  int _page = 1;

  final NumberFormat _compactFormat = NumberFormat.compact(locale: "tr_TR");

  // --- ZERO KM STATE ---
  bool _isZeroKmMode = false; // [NEW] Toggle state
  final ZeroKmService _zeroKmService = ZeroKmService();
  List<ZeroKmBrand> _zeroKmBrands = [];
  List<ZeroKmModel> _zeroKmModels = [];
  List<ZeroKmVersion> _zeroKmVersions = [];
  ZeroKmBrand? _selectedZeroKmBrand;
  ZeroKmModel? _selectedZeroKmModel;
  bool _isZeroKmLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadZeroKmBrands(); // Preload just in case
    _performSearch(); // [NEW] Auto-load second hand cars
  }

  Future<void> _loadZeroKmBrands() async {
    final brands = await _zeroKmService.getBrands();
    if(mounted) setState(() => _zeroKmBrands = brands);
  }

  Future<void> _loadZeroKmModels(String brandSlug) async {
    setState(() { _isZeroKmLoading = true; _zeroKmModels = []; _selectedZeroKmModel = null; _zeroKmVersions = []; });
    final models = await _zeroKmService.getModels(brandSlug);
    if(mounted) setState(() { _zeroKmModels = models; _isZeroKmLoading = false; });
  }

  Future<void> _loadZeroKmVersions(String modelSlug) async {
     setState(() { _isZeroKmLoading = true; _zeroKmVersions = []; });
     final versions = await _zeroKmService.getVersions(modelSlug);
     if(mounted) setState(() { _zeroKmVersions = versions; _isZeroKmLoading = false; });
  }

  Future<void> _fetchSubCategories({
    required String parentPath, 
    required Function(List<String>) onSuccess, 
    required Function(bool) setLoading
  }) async {
    setLoading(true);
    try {
      final items = await _searchService.getSubCategories(parentPath);
      if (mounted) {
        onSuccess(items);
        setLoading(false);
      }
    } catch (e) {
      if (mounted) setLoading(false);
    }
  }

  void _onCategoryChanged(String newCategory) {
    if (_selectedCategory == newCategory) return;
    setState(() {
      _selectedCategory = newCategory;
      _resetFilters(); 
    });
  }

  void _onBrandSelected(String? brand) {
    if (brand == _selectedBrand) return;
    setState(() {
      _selectedBrand = brand;
      _selectedSeries = null; _seriesList = [];
      _selectedModel = null; _modelList = [];
      _selectedHardware = null; _hardwareList = [];
    });
    
    if (brand != null) {
      String slug = _searchService.slugify(brand);
      String path = "$_selectedCategory/$slug";
      _fetchSubCategories(
        parentPath: path,
        onSuccess: (list) => setState(() => _seriesList = list),
        setLoading: (val) => setState(() => _isSeriesLoading = val),
      );
    }
  }

  void _onSeriesSelected(String? series) {
    if (series == _selectedSeries) return;
    setState(() {
      _selectedSeries = series;
      _selectedModel = null; _modelList = [];
      _selectedHardware = null; _hardwareList = [];
    });
    
    if (series != null && _selectedBrand != null) {
      String brandSlug = _searchService.slugify(_selectedBrand!);
      String seriesSlug = _searchService.slugify(series);
      // Path example: otomobil/bmw-3-serisi
      String path = "$_selectedCategory/$brandSlug-$seriesSlug";
      _fetchSubCategories(
        parentPath: path,
        onSuccess: (list) => setState(() => _modelList = list),
        setLoading: (val) => setState(() => _isModelLoading = val),
      );
    }
  }

  void _onModelSelected(String? model) {
    if (model == _selectedModel) return;
    setState(() {
      _selectedModel = model;
      _selectedHardware = null; _hardwareList = [];
    });
    
    // Fetch Hardware/Versions (Engine options)
    if (model != null && _selectedBrand != null && _selectedSeries != null) {
       String brandSlug = _searchService.slugify(_selectedBrand!);
       String seriesSlug = _searchService.slugify(_selectedSeries!);
       String modelSlug = _searchService.slugify(model);
       
       // Path example: otomobil/audi-a3-a3-sedan
       // Note: Arabam usually chains them. Sometimes it repeats brand, sometimes not.
       // Safe bet: Construct cumulative path carefully.
       // Actually most reliable is usually: brand-series-model
       // But if series is 'A3' and model is 'A3 Sedan', path is 'audi-a3-a3-sedan'.
       
       String path = "$_selectedCategory/$brandSlug-$seriesSlug-$modelSlug";
       _fetchSubCategories(
        parentPath: path,
        onSuccess: (list) => setState(() => _hardwareList = list),
        setLoading: (val) => setState(() => _isHardwareLoading = val),
      );
    }
  }

  void _onHardwareSelected(String? hardware) {
      setState(() => _selectedHardware = hardware);
  }

  // --- NEW MULTI-STEP SELECTION WIDGETS ---

  Widget _buildSecondHandSelectionContent() {
    if (_selectedBrand == null) {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(child: _buildTypeToggle(_t('car'), 'otomobil')),
                Expanded(child: _buildTypeToggle(_t('suv'), 'arazi-suv-pick-up')),
              ],
            ),
          ),
          _buildBrandGrid(),
        ],
      );
    } else if (_selectedSeries == null) {
      return _buildList(_seriesList, "Seri seçiniz", (item) => _onSeriesSelected(item), _isSeriesLoading);
    } else if (_selectedModel == null) {
      return _buildList(_modelList, "Model seçiniz", (item) => _onModelSelected(item), _isModelLoading);
    } else if (_selectedHardware == null) {
      return _buildList(_hardwareList, "Paket seçiniz", (item) => _onHardwareSelected(item), _isHardwareLoading);
    } else {
      // All selected
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$_selectedBrand $_selectedSeries $_selectedModel",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selectedHardware = null;
              }),
              child: const Text("Değiştir"),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBrandGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _brands.length,
      itemBuilder: (context, index) {
        final brand = _brands[index];
        final logoUrl = CarSearchService.brandLogos[brand];
        return InkWell(
          onTap: () => _onBrandSelected(brand),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (logoUrl != null)
                  CachedNetworkImage(
                    imageUrl: logoUrl, 
                    height: 30, 
                    width: 30, 
                    fit: BoxFit.contain, 
                    memCacheWidth: 60, // Optimize memory (2x display size for retina)
                    errorWidget: (c,e,s) => const Icon(Icons.directions_car, size: 25, color: Colors.grey)
                  )
                else
                  const Icon(Icons.directions_car, color: Colors.grey, size: 25),
                const SizedBox(height: 5),
                Text(brand, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<String> items, String emptyMsg, Function(String) onTap, bool isLoading) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(emptyMsg, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey.shade600))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (c, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          title: Text(item, style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => onTap(item),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  Widget _buildBreadcrumbs() {
    if (_selectedBrand == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          _buildChip(_selectedBrand!, () => setState(() { 
            _selectedBrand = null; _selectedSeries = null; _selectedModel = null; 
            _selectedHardware = null; _seriesList = []; _modelList = []; _hardwareList = [];
          })),
          if (_selectedSeries != null) 
            _buildChip(_selectedSeries!, () => setState(() { 
              _selectedSeries = null; _selectedModel = null; _selectedHardware = null; 
              _modelList = []; _hardwareList = [];
            })),
          if (_selectedModel != null)
            _buildChip(_selectedModel!, () => setState(() { 
              _selectedModel = null; _selectedHardware = null; _hardwareList = [];
            })),
          if (_selectedHardware != null)
            _buildChip(_selectedHardware!, () => setState(() { _selectedHardware = null; })),
        ],
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onDeleted: onDeleted,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
      surfaceTintColor: Colors.transparent,
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      deleteIconColor: Colors.grey,
      deleteIcon: const Icon(Icons.cancel, size: 14),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _resetFilters() {
    _selectedBrand = null;
    _selectedSeries = null; _seriesList = [];
    _selectedModel = null; _modelList = [];
    _selectedHardware = null; _hardwareList = [];
    _priceRange = const RangeValues(0, 5000000);
    _kmRange = const RangeValues(0, 400000);
    _minYear = null; _maxYear = null;
    _minPower = null; _maxPower = null;
    _minVolume = null; _maxVolume = null;
    _selectedGears = [];
    _selectedFuels = [];
    _selectedCaseTypes = [];
    _selectedTractions = [];
    _selectedColors = [];
    _warranty = null;
    _heavyDamage = null;
    _selectedFromWhom = null;
    _exchange = null;
    _hasSearched = false;
  }

  Future<void> _performSearch({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _searchResults = []; // Reset list only if new search
        _page = 1; // Reset to page 1
      });
    } else {
        setState(() {
          // Maybe show a small loader at bottom instead? 
          // For now just keep _isLoading false but maybe add a _isLoadingMore flag
        });
    }

    try {
      final filters = FilterOptions(
        category: _selectedCategory,
        brand: _selectedBrand ?? "Tümü",
        series: _selectedSeries,
        model: _selectedModel,
        hardware: _selectedHardware,
        
        minPrice: _priceRange.start,
        maxPrice: _priceRange.end,
        minKm: _kmRange.start,
        maxKm: _kmRange.end,
        
        minYear: _minYear,
        maxYear: _maxYear,
        minPower: _minPower,
        maxPower: _maxPower,
        minVolume: _minVolume,
        maxVolume: _maxVolume,
        
        gear: _selectedGears,
        fuel: _selectedFuels,
        caseType: _selectedCaseTypes,
        traction: _selectedTractions,
        color: _selectedColors,
        warranty: _warranty,
        heavyDamage: _heavyDamage,
        fromWhom: _selectedFromWhom,
        exchange: _exchange,
        
        page: isLoadMore ? _page + 1 : 1, // Use next page if loading more
      );

      final results = await _searchService.searchCars(filters);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasSearched = true;
          if (isLoadMore) {
             _searchResults.addAll(results);
             if (results.isNotEmpty) _page++; // Confirm page increment only if we got data
          } else {
             _searchResults = results;
             _page = 1;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Sonuçlar yüklenirken bir sorun oluştu: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFF4F5F9),
      appBar: AppBar(
        title: Text(_t('car_finder_title')),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white),
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
        elevation: 0.5,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // [NEW] ZERO KM vs 2. EL TOGGLE
                   Container(
                     margin: const EdgeInsets.only(bottom: 20),
                     padding: const EdgeInsets.all(4),
                     decoration: BoxDecoration(
                       color: Colors.grey.shade200,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Row(
                       children: [
                         Expanded(child: _buildModeToggle(_t('second_hand'), Icons.recycling, !_isZeroKmMode, () => setState(() => _isZeroKmMode = false))),
                         Expanded(child: _buildModeToggle(_t('zero_km'), Icons.new_releases, _isZeroKmMode, () => setState(() => _isZeroKmMode = true))),
                       ],
                     ),
                   ),

                   // IF ZERO KM MODE
                   if (_isZeroKmMode) ...[
                      _buildZeroKmContent(),
                   ] else ...[
                      // 1. ARAÇ SEÇİMİ
                      _buildSectionHeader(_t('car_selection')),
                      _buildCard([
                        _buildBreadcrumbs(),
                        _buildSecondHandSelectionContent(),
                        const Divider(height: 30),
                        _buildRangeSlider(_t('price_tl'), _priceRange, _minPriceLimit, _maxPriceLimit, (v) => setState(() => _priceRange = v), isPrice: true),
                      ]),

                  // 2. TEKNİK DETAYLAR
                  _buildSectionHeader(_t('technical_details')),
                  _buildCard([
                    _buildRangeSlider(_t('kilometer'), _kmRange, _minKmLimit, _maxKmLimit, (v) => setState(() => _kmRange = v)),
                    const SizedBox(height: 15),
                    Row(children: [
                      Expanded(child: _buildNumberInput(_t('min_year'), (v) => _minYear = int.tryParse(v))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildNumberInput(_t('max_year'), (v) => _maxYear = int.tryParse(v))),
                    ]),
                    const SizedBox(height: 15),
                    const Divider(),
                    const Text("HP", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _buildNumberInput(_t('min_hp'), (v) => _minPower = int.tryParse(v))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildNumberInput(_t('max_hp'), (v) => _maxPower = int.tryParse(v))),
                    ]),
                    const SizedBox(height: 15),
                    const Text("Motor Hacmi (CC)", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _buildNumberInput("Min CC", (v) => _minVolume = int.tryParse(v))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildNumberInput("Max CC", (v) => _maxVolume = int.tryParse(v))),
                    ]),
                    const Divider(),
                    _buildMultiSelect(_t('fuel_type'), _fuelOptions, _selectedFuels),
                    const Divider(),
                    _buildMultiSelect(_t('gear_type'), _gearOptions, _selectedGears),
                    const Divider(),
                    _buildMultiSelect(_t('case_type'), _caseTypes, _selectedCaseTypes),
                    const Divider(),
                    _buildMultiSelect(_t('traction'), _tractionOptions, _selectedTractions),
                  ]),
                  
                  // 3. DONANIM & DURUM
                  _buildSectionHeader("Durum ve Ekstralar"),
                  _buildCard([
                     _buildMultiSelect("Renk", _colorOptions, _selectedColors),
                     const Divider(),
                     CheckboxListTile(
                       title: const Text("Garanti"),
                       subtitle: Text(_warranty == null ? "Farketmez" : (_warranty! ? "Garantili" : "Garantisiz")),
                       value: _warranty,
                       tristate: true,
                       onChanged: (v) => setState(() => _warranty = v),
                       activeColor: const Color(0xFF0059BC),
                     ),
                     SwitchListTile(
                       title: const Text("Ağır Hasar Kayıtlı"),
                       value: _heavyDamage ?? false,
                       onChanged: (v) => setState(() => _heavyDamage = v),
                       activeColor: Colors.red,
                     ),
                     SwitchListTile(
                       title: const Text("Takaslı"),
                       value: _exchange ?? false,
                       onChanged: (v) => setState(() => _exchange = v),
                       activeColor: Colors.green,
                     ),
                  ]),

                  // 4. SATICI
                  _buildSectionHeader("Satıcı Bilgileri"),
                  _buildCard([
                     DropdownButtonFormField<String>(
                       dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, 
                       decoration: InputDecoration(
                         labelText: "Kimden", 
                         border: const OutlineInputBorder(),
                         fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, 
                         filled: true,
                         labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.black54),
                       ),
                       value: _selectedFromWhom,
                       items: [
                         const DropdownMenuItem(value: null, child: Text("Farketmez")),
                         ..._fromWhomOptions.map((e) => DropdownMenuItem(value: e, child: Text(e)))
                       ],
                       onChanged: (v) => setState(() => _selectedFromWhom = v),
                     )
                  ]),

                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0059BC),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: const Color(0xFF0059BC).withOpacity(0.4),
                    ),
                    child: Text(_t('show_results'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),

                  // SONUÇ LİSTESİ
                  if (_hasSearched) ...[
                    const SizedBox(height: 30),
                    if (_isLoading) ...[
                       const Center(child: CircularProgressIndicator())
                    ] else ...[
                       if (_errorMessage != null) ...[
                         Container(
                           padding: const EdgeInsets.all(16),
                           margin: const EdgeInsets.only(bottom: 20),
                           decoration: BoxDecoration(
                             color: Colors.red.shade50,
                             borderRadius: BorderRadius.circular(8),
                             border: Border.all(color: Colors.red.shade200),
                           ),
                           child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800), textAlign: TextAlign.center),
                         )
                       ] else ...[
                          _buildResults()
                       ]
                    ]
                  ],
                  const SizedBox(height: 50),
                   ], // End 2nd Hand Content
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  // --- ZERO KM UI BUILDER ---
  Widget _buildZeroKmContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BREADCRUMBS
        if (_selectedZeroKmBrand != null)
           Padding(
             padding: const EdgeInsets.only(bottom: 10.0),
             child: Wrap(
               spacing: 5,
               children: [
                 ActionChip(
                   backgroundColor: Colors.white,
                   side: BorderSide(color: Colors.grey.shade300),
                   label: Text(_selectedZeroKmBrand!.name, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.black87 : Colors.black87)),
                   onPressed: () {
                      setState(() { 
                        _selectedZeroKmBrand = null; 
                        _selectedZeroKmModel = null; 
                        _zeroKmModels = []; 
                        _zeroKmVersions = []; 
                      });
                   },
                   avatar: const Icon(Icons.close, size: 16, color: Colors.grey),
                 ),
                 if (_selectedZeroKmModel != null)
                    ActionChip(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300),
                      label: Text(_selectedZeroKmModel!.name, style: const TextStyle(color: Colors.black87)),
                      onPressed: () {
                         setState(() { 
                           _selectedZeroKmModel = null; 
                           _zeroKmVersions = []; 
                         });
                      },
                      avatar: const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
               ],
             ),
           ),

        if (_isZeroKmLoading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),

        if (_selectedZeroKmBrand == null) ...[
           // BRAND GRID
           if (_zeroKmBrands.isEmpty) const Text("Markalar yükleniyor..."),
           GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                childAspectRatio: 1.0, 
                crossAxisSpacing: 10, 
                mainAxisSpacing: 10
              ),
              itemCount: _zeroKmBrands.length,
              itemBuilder: (ctx, i) {
                final b = _zeroKmBrands[i];
                return InkWell(
                  onTap: () {
                    setState(() => _selectedZeroKmBrand = b);
                    _loadZeroKmModels(b.slug);
                  },
                  child: Container(
                     decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, 
                        borderRadius: BorderRadius.circular(10), 
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey.shade200)
                     ),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         if(b.logoUrl != null) CachedNetworkImage(imageUrl: b.logoUrl!, height: 30, memCacheWidth: 60, errorWidget: (c,e,s) => const SizedBox()),
                         const SizedBox(height: 5),
                         Text(b.name, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                       ],
                     ),
                  ),
                );
              },
           )
        ] else if (_selectedZeroKmModel == null) ...[
           // MODEL LIST
           if (!_isZeroKmLoading && _zeroKmModels.isEmpty) const Text("Model bulunamadı."),
           ListView.separated(
             physics: const NeverScrollableScrollPhysics(),
             shrinkWrap: true,
             itemCount: _zeroKmModels.length,
             separatorBuilder: (c,i) => const SizedBox(height: 10),
             itemBuilder: (ctx, i) {
               final m = _zeroKmModels[i];
               return Card(
                 color: Colors.white, // [FIX] Explicit white
                 elevation: 2,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 child: ListTile(
                   leading: m.imageUrl.isNotEmpty ? CachedNetworkImage(imageUrl: m.imageUrl, width: 60, height: 45, fit: BoxFit.cover, memCacheWidth: 120, errorWidget: (c,e,s) => const Icon(Icons.directions_car)) : const Icon(Icons.directions_car),
                   title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                   subtitle: Text(m.priceRange, style: const TextStyle(color: Color(0xFF0059BC))),
                   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                   onTap: () {
                      setState(() => _selectedZeroKmModel = m);
                      _loadZeroKmVersions(m.slug);
                   },
                 ),
               );
             },
           )
        ] else ...[
           // VERSION LIST (Results)
           if (!_isZeroKmLoading && _zeroKmVersions.isEmpty) const Text("Paket bulunamadı."),
           
           // WRAP WITH STREAM BUILDER FOR FAVORITES
           StreamBuilder<List<Map<String, dynamic>>>(
             stream: FirebaseAuth.instance.currentUser != null 
                ? _firestoreService.getFavorites(FirebaseAuth.instance.currentUser!.uid)  
                : const Stream.empty(),
             builder: (context, snapshot) {
                final favorites = snapshot.data ?? [];
                
                return ListView.separated(
                 physics: const NeverScrollableScrollPhysics(),
                 shrinkWrap: true,
                 itemCount: _zeroKmVersions.length,
                 separatorBuilder: (c,i) => const SizedBox(height: 10),
                 itemBuilder: (ctx, i) {
                   final v = _zeroKmVersions[i];
                   
                   // Check if favorite
                   // We use a unique ID for zero km: "ZEROKM_{brand}_{model}_{version}"
                   final String zeroKmId = "ZEROKM_${_selectedZeroKmBrand?.slug ?? ''}_${_selectedZeroKmModel?.slug ?? ''}_${v.name.replaceAll(' ', '_')}";
                   final bool isFav = favorites.any((f) => f['zeroKmId'] == zeroKmId);
                   final String? favDocId = isFav ? favorites.firstWhere((f) => f['zeroKmId'] == zeroKmId)['id'] : null;

                   return Card(
                     color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
                     elevation: 2,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     clipBehavior: Clip.antiAlias,
                     child: Column(
                       children: [
                            
                          if (v.imageUrl != null && v.imageUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: v.imageUrl!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              memCacheWidth: 600,
                              placeholder: (c, url) => Container(height: 180, color: Colors.grey[100], child: const Center(child: Icon(Icons.image, color: Colors.grey))),
                              errorWidget: (c, e, s) => Container(height: 180, color: Colors.grey[100], child: const Icon(Icons.broken_image, color: Colors.grey))
                            ),
                          
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Expanded(child: Text(v.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87))),
                                     
                                     // FAVORITE BUTTON
                                     IconButton(
                                       icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
                                       onPressed: () async {
                                          final user = FirebaseAuth.instance.currentUser;
                                          if (user == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favorilere eklemek için giriş yapmalısınız.")));
                                            return;
                                          }
                                          
                                          if (isFav && favDocId != null) {
                                            await _firestoreService.removeFavorite(user.uid, favDocId);
                                          } else {
                                            await _firestoreService.addFavorite(user.uid, {
                                               'zeroKmId': zeroKmId,
                                               'name': "${_selectedZeroKmBrand?.name} ${_selectedZeroKmModel?.name} ${v.name}",
                                               'price': v.price, // String like "1.500.000 TL"
                                               'image': v.imageUrl ?? _selectedZeroKmModel?.imageUrl ?? "",
                                               'year': 2024, // Assumption for Zero KM
                                               'km': 0,
                                               'isZeroKm': true,
                                               'date': FieldValue.serverTimestamp(),
                                            });
                                          }
                                       },
                                     )
                                   ],
                                 ),
                                 const SizedBox(height: 5),
                                 Text(v.price, style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold, fontSize: 18)),
                                 const Divider(),
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Text(v.fuelType, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700])),
                                     Text(v.gearType, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700])),
                                     Text(v.fuelConsumption, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700])),
                                   ],
                                 ),
                              ],
                            ),
                          ),
                       ],
                     ),
                   );
                 },
               );
             }
           )
        ]
      ],
    );
  }

  Widget _buildModeToggle(String title, IconData icon, bool isActive, VoidCallback onTap) {
     return GestureDetector(
       onTap: onTap,
       child: AnimatedContainer(
         duration: const Duration(milliseconds: 200),
         padding: const EdgeInsets.symmetric(vertical: 10),
         alignment: Alignment.center,
         decoration: BoxDecoration(
           color: isActive ? Colors.white : Colors.transparent,
           borderRadius: BorderRadius.circular(10),
           boxShadow: isActive ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : [],
         ),
         child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(icon, 
                    size: 16, 
                    color: isActive ? const Color(0xFF0059BC) : Colors.grey),
               const SizedBox(width: 8),
               Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF0059BC) : Colors.grey)),
            ],
         ),
       ),
     );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black54)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildTypeToggle(String title, String value) {
    bool isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => _onCategoryChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0059BC) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? val, Function(String?) onChange) {
    bool isBrandDropdown = label == "Marka";
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
             color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, 
             border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey.shade300),
             borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
              value: val,
              isExpanded: true,
              hint: const Text("Seçiniz"),
              // Increase menu height for better visibility of logos
              menuMaxHeight: 400,
              items: [
                const DropdownMenuItem(value: null, child: Text("Hepsi")),
                ...items.map((e) {
                   return DropdownMenuItem(
                     value: e, 
                     child: isBrandDropdown ? Row(
                       children: [
                          if (CarSearchService.brandLogos.containsKey(e))
                             Padding(
                               padding: const EdgeInsets.only(right: 12.0),
                               child: Image.network(
                                 CarSearchService.brandLogos[e]!, 
                                 width: 24, 
                                 height: 24,
                                 errorBuilder: (c, e, s) => const Icon(Icons.car_repair, size: 24),
                               ),
                             ),
                          Text(e),
                       ],
                     ) : Text(e, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87))
                   );
                }),
              ],
              onChanged: onChange,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildRangeSlider(String label, RangeValues values, double min, double max, Function(RangeValues) onChange, {bool isPrice = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87)),
            Text(
               "${_compactFormat.format(values.start)} - ${_compactFormat.format(values.end)}",
               style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF0059BC),
            thumbColor: const Color(0xFF0059BC),
            overlayColor: const Color(0xFF0059BC).withValues(alpha: 0.1),
          ),
          child: RangeSlider(
            values: values,
            min: min,
            max: max,
            divisions: 100,
            onChanged: onChange,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput(String hint, Function(String) onChanged) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.black54),
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
        filled: true,
      ),
      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
      onChanged: onChanged,
    );
  }

  Widget _buildMultiSelect(String title, List<String> options, List<String> selected) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(selected.isNotEmpty ? selected.join(", ") : "Tümü", maxLines: 1, overflow: TextOverflow.ellipsis),
      tilePadding: EdgeInsets.zero,
      children: options.map((opt) {
        return CheckboxListTile(
          title: Text(opt, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87)),
          value: selected.contains(opt),
          activeColor: const Color(0xFF0059BC),
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() {
              if (val == true) {
                selected.add(opt);
              } else {
                selected.remove(opt);
              }
            });
          }
        );
      }).toList(),
    );
  }

  Widget _buildResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Sonuç bulunamadı.")));
    }
    return Column(
      children: [
        // WRAP WITH STREAM BUILDER FOR FAVORITES
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirebaseAuth.instance.currentUser != null 
             ? _firestoreService.getFavorites(FirebaseAuth.instance.currentUser!.uid)  
             : const Stream.empty(),
          builder: (context, snapshot) {
            final favorites = snapshot.data ?? [];
            
            return ListView.separated(
               physics: const NeverScrollableScrollPhysics(),
               shrinkWrap: true,
               itemCount: _searchResults.length,
               separatorBuilder: (context, index) => const SizedBox(height: 10),
               itemBuilder: (context, idx) => _buildCarCard(_searchResults[idx], favorites),
            );
          }
        ),
        if (_searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ElevatedButton(
              onPressed: () => _performSearch(isLoadMore: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text("Daha Fazla Göster", style: TextStyle(color: Colors.white)),
            ),
          ),
      ],
    );
  }

  Widget _buildCarCard(CarListing car, List<Map<String, dynamic>> favorites) {
    final user = FirebaseAuth.instance.currentUser;
    final isFavorite = favorites.any((f) => f['id'] == car.id || f['link'] == car.link);

    return Card(
      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
           if (car.link.isNotEmpty) await launchUrl(Uri.parse(car.link), mode: LaunchMode.inAppWebView);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // IMAGE
                CachedNetworkImage(
                  imageUrl: car.imageUrl,
                  height: 200, 
                  width: double.infinity, 
                  fit: BoxFit.cover,
                  memCacheWidth: 400, // Reduced resolution for list view
                  placeholder: (context, url) => Container(height: 200, color: Colors.grey[200], child: const Center(child: Icon(Icons.image, color: Colors.grey))),
                  errorWidget: (context, url, error) => Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                ),
                
                // FAVORITE BUTTON
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: () async {
                        if (user == null) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favoriye eklemek için giriş yapmalısınız.")));
                           return;
                        }

                        if (isFavorite) {
                          final favDoc = favorites.firstWhere((f) => f['id'] == car.id || f['link'] == car.link);
                          await _firestoreService.removeFavorite(user.uid, favDoc['id']);
                        } else {
                          await _firestoreService.addFavorite(user.uid, {
                            'name': car.title,
                            'price': car.price,
                            'image': car.imageUrl,
                            'year': car.year,
                            'km': car.km,
                            'location': car.location,
                            'link': car.link,
                            'isZeroKm': false,
                            'hasHeavyDamage': car.hasHeavyDamage,
                            'expertiseStatus': car.expertiseStatus,
                            'date': FieldValue.serverTimestamp(),
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(car.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   const SizedBox(height: 5),
                   Text(car.price, style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold, fontSize: 18)),
                   const SizedBox(height: 5),
                   Row(
                     children: [
                       Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                       const SizedBox(width: 4),
                       Text(car.year, style: TextStyle(color: Colors.grey[600])),
                       const SizedBox(width: 15),
                       Icon(Icons.speed, size: 14, color: Colors.grey[500]),
                       const SizedBox(width: 4),
                       Text(car.km, style: TextStyle(color: Colors.grey[600])),
                     ],
                   ),
                   const SizedBox(height: 5),
                   Text(car.location, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
