import 'package:flutter/material.dart';
import '../services/car_search_service.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class DetailedCarSelector extends StatefulWidget {
  final bool isYearSelectionEnabled;
  final Function(String brand, String series, String model, String hardware, int? year) onSelectionComplete;

  const DetailedCarSelector({super.key, required this.onSelectionComplete, this.isYearSelectionEnabled = false});

  @override
  State<DetailedCarSelector> createState() => _DetailedCarSelectorState();
}

class _DetailedCarSelectorState extends State<DetailedCarSelector> {
  final CarSearchService _searchService = CarSearchService();
  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);
  
  // Data Lists
  late List<String> _brands;
  List<String> _seriesList = [];
  List<String> _modelList = [];
  List<String> _hardwareList = [];
  late List<int> _years;

  // Selections
  String _selectedCategory = "otomobil"; 
  String? _selectedBrand;
  String? _selectedSeries;
  String? _selectedModel;
  String? _selectedHardware;
  int? _selectedYear;

  // Loading States
  bool _isSeriesLoading = false;
  bool _isModelLoading = false;
  bool _isHardwareLoading = false;

  @override
  void initState() {
    super.initState();
    _brands = CarSearchService.brandLogos.keys.toList()..sort();
    _years = List.generate(26, (index) => DateTime.now().year - index);
  }

  // --- API CALLS ---
  Future<void> _fetchSubCategories({
    required String parentPath, 
    required Function(List<String>) onSuccess, 
    required Function(bool) setLoading
  }) async {
    if (!mounted) return;
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

  // --- HANDLERS ---
  
  void _onCategoryChanged(String category) {
    if (category == _selectedCategory) return;
    setState(() {
      _selectedCategory = category;
      _selectedBrand = null;
      _selectedSeries = null; _seriesList = [];
      _selectedModel = null; _modelList = [];
      _selectedHardware = null; _hardwareList = [];
      _selectedYear = null;
    });
  }

  void _onBrandSelected(String brand) {
    setState(() {
      _selectedBrand = brand;
      _selectedSeries = null; _seriesList = [];
      _selectedModel = null; _modelList = [];
      _selectedHardware = null; _hardwareList = [];
      _selectedYear = null;
    });
    
    String slug = _searchService.slugify(brand);
    String path = "$_selectedCategory/$slug"; 
    _fetchSubCategories(
      parentPath: path,
      onSuccess: (list) => setState(() => _seriesList = list),
      setLoading: (val) => setState(() => _isSeriesLoading = val),
    );
  }

  void _onSeriesSelected(String series) {
    setState(() {
      _selectedSeries = series;
      _selectedModel = null; _modelList = [];
      _selectedHardware = null; _hardwareList = [];
      _selectedYear = null;
    });
    
    if (_selectedBrand != null) {
      String brandSlug = _searchService.slugify(_selectedBrand!);
      String seriesSlug = _searchService.slugify(series);
      String path = "$_selectedCategory/$brandSlug-$seriesSlug";
      _fetchSubCategories(
        parentPath: path,
        onSuccess: (list) => setState(() => _modelList = list),
        setLoading: (val) => setState(() => _isModelLoading = val),
      );
    }
  }

  void _onModelSelected(String model) {
    setState(() {
      _selectedModel = model;
      _selectedHardware = null; _hardwareList = [];
      _selectedYear = null;
    });
    
    if (_selectedBrand != null && _selectedSeries != null) {
       String brandSlug = _searchService.slugify(_selectedBrand!);
       String seriesSlug = _searchService.slugify(_selectedSeries!);
       String modelSlug = _searchService.slugify(model);
       
       String path = "$_selectedCategory/$brandSlug-$seriesSlug-$modelSlug";
       _fetchSubCategories(
        parentPath: path,
        onSuccess: (list) => setState(() => _hardwareList = list),
        setLoading: (val) => setState(() => _isHardwareLoading = val),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFF0059BC)),
              const SizedBox(width: 10),
              Text(_t('second_hand_vehicle_selection'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_isSeriesLoading || _isModelLoading || _isHardwareLoading) 
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          
          // Breadcrumbs
          if (_selectedBrand != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(_selectedBrand!, () => setState(() { 
                  _selectedBrand = null; _selectedSeries = null; _selectedModel = null; 
                  _selectedHardware = null; _selectedYear = null;
                  _seriesList = []; _modelList = []; _hardwareList = [];
                })),
                if (_selectedSeries != null) ...[
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  _buildChip(_selectedSeries!, () => setState(() { 
                    _selectedSeries = null; _selectedModel = null; 
                    _selectedHardware = null; _selectedYear = null;
                    _modelList = []; _hardwareList = [];
                  })),
                ],
                if (_selectedModel != null) ...[
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  _buildChip(_selectedModel!, () => setState(() { 
                    _selectedModel = null; _selectedHardware = null; _selectedYear = null;
                    _hardwareList = [];
                  })),
                ],
                if (_selectedHardware != null) ...[
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  _buildChip(_selectedHardware!, () => setState(() { _selectedHardware = null; _selectedYear = null; })),
                ],
              ],
            ),
          ),
          if (_selectedBrand != null) const SizedBox(height: 10),

          // Selection List
          Expanded(
            child: _buildSelectionContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: onDeleted,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        deleteIconColor: Colors.grey,
        deleteIcon: const Icon(Icons.cancel, size: 16),
      ),
    );
  }

  Widget _buildSelectionContent() {
    if (_selectedBrand == null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'otomobil', label: Text(_t('car')), icon: const Icon(Icons.directions_car)),
                ButtonSegment(value: 'arazi-suv-pick-up', label: Text(_t('suv')), icon: const Icon(Icons.terrain)),
              ],
              selected: {_selectedCategory},
              onSelectionChanged: (val) => _onCategoryChanged(val.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                selectedBackgroundColor: const Color(0xFF0059BC).withOpacity(0.1),
                selectedForegroundColor: const Color(0xFF0059BC),
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          Expanded(child: _buildBrandGrid()),
        ],
      );
    } else if (_selectedSeries == null) {
      return _buildList(_seriesList, _t('select_model'), (item) => _onSeriesSelected(item));
    } else if (_selectedModel == null) {
      return _buildList(_modelList, _t('select_submodel'), (item) => _onModelSelected(item));
    } else if (_selectedHardware == null) {
      return _buildList(_hardwareList, _t('select_package'), (item) => setState(() => _selectedHardware = item));
    } else if (widget.isYearSelectionEnabled && _selectedYear == null) {
      return _buildList(_years.map((e) => e.toString()).toList(), _t('select_year'), (item) => setState(() => _selectedYear = int.parse(item)));
    } else {
      // Summary / Confirmation
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 20),
            Text(_selectedBrand!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0059BC))),
            const SizedBox(height: 5),
            Text("${_selectedSeries} ${_selectedModel}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_selectedHardware != null) Text(_selectedHardware!, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            if (_selectedYear != null) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text("Model Yılı: ${_selectedYear}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                widget.onSelectionComplete(
                  _selectedBrand!, 
                  _selectedSeries!, 
                  _selectedModel ?? "", 
                  _selectedHardware ?? "", 
                  _selectedYear
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0059BC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 4,
              ),
              child: Text(_t('complete_selection'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBrandGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
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
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (logoUrl != null)
                  Image.network(logoUrl, height: 35, width: 35, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.directions_car, size: 30, color: Colors.grey))
                else
                  const Icon(Icons.directions_car, color: Colors.grey, size: 30),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(brand, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<String> items, String emptyMsg, Function(String) onTap) {
    if (items.isEmpty && !(_isSeriesLoading || _isModelLoading || _isHardwareLoading)) {
      return Center(child: Text(emptyMsg, style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(item, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () => onTap(item),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}
