import 'package:flutter/material.dart';
import '../services/opet_service.dart';
import '../models/fuel_price_model.dart';
import '../services/language_service.dart';
import '../utils/app_localizations.dart';

class FuelPriceWidget extends StatefulWidget {
  const FuelPriceWidget({Key? key}) : super(key: key);

  @override
  State<FuelPriceWidget> createState() => _FuelPriceWidgetState();
}

class _FuelPriceWidgetState extends State<FuelPriceWidget> {
  final OpetService _opetService = OpetService();
  
  // Data
  List<FuelPrice> _prices = [];
  bool _isLoading = true;
  String? _error;

  // Selected Location
  int _provinceCode = 6; // Default: Ankara
  String _provinceName = "Ankara";
  String _districtCode = "006019"; // Default: Çankaya
  String _districtName = "Çankaya";

  // Modal State
  List<FuelProvince> _provinces = [];
  List<FuelDistrict> _districts = [];
  FuelProvince? _selectedProvince;
  FuelDistrict? _selectedDistrict;
  bool _isLoadingProvinces = false;
  bool _isLoadingDistricts = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final saved = await _opetService.getSavedLocation();
    if (saved != null) {
      if (mounted) {
        setState(() {
          _provinceCode = saved['provinceCode'];
          _provinceName = saved['provinceName'];
          _districtCode = saved['districtCode'];
          _districtName = saved['districtName'];
        });
      }
    }
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prices = await _opetService.getFuelPrices(_provinceCode, _districtCode);
      if (mounted) {
        setState(() {
          _prices = prices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Veri alınamadı";
          _isLoading = false;
        });
      }
    }
  }

  void _showLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          // Initial Load of Provincs
          if (_provinces.isEmpty && !_isLoadingProvinces) {
            _isLoadingProvinces = true;
            _opetService.getProvinces().then((list) {
              if (mounted) {
                setModalState(() {
                  _provinces = list;
                  _isLoadingProvinces = false;
                  // Pre-select current
                  try {
                    _selectedProvince = list.firstWhere((p) => p.code == _provinceCode);
                    _loadDistrictsForModal(_selectedProvince!.code, setModalState);
                  } catch (_) {}
                });
              }
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.7, // Taller modal
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Konum Seçimi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 20),
                
                // Province Dropdown
                Text("Şehir", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                const SizedBox(height: 8),
                _isLoadingProvinces 
                  ? const Center(child: CircularProgressIndicator()) 
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<FuelProvince>(
                          value: _selectedProvince,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          hint: Text("Şehir Seçiniz", style: TextStyle(color: Theme.of(context).hintColor)),
                          items: _provinces.map((p) => DropdownMenuItem(
                            value: p, 
                            child: Text(p.name, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
                          )).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setModalState(() {
                              _selectedProvince = val;
                              _selectedDistrict = null;
                              _districts = [];
                            });
                            _loadDistrictsForModal(val.code, setModalState);
                          },
                        ),
                      ),
                    ),
                
                const SizedBox(height: 20),
                
                // District Dropdown
                Text("İlçe", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                const SizedBox(height: 8),
                 _isLoadingDistricts 
                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())) 
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<FuelDistrict>(
                          value: _selectedDistrict,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          hint: Text("İlçe Seçiniz", style: TextStyle(color: Theme.of(context).hintColor)),
                          items: _districts.map((d) => DropdownMenuItem(
                            value: d, 
                            child: Text(d.name, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
                          )).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setModalState(() {
                              _selectedDistrict = val;
                            });
                          },
                        ),
                      ),
                    ),

                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_selectedProvince != null && _selectedDistrict != null) 
                      ? () async {
                          // Save
                          await _opetService.saveLocationPreference(
                            _selectedProvince!.code, 
                            _selectedProvince!.name, 
                            _selectedDistrict!.code, 
                            _selectedDistrict!.name
                          );
                          
                          // Update UI
                          if (mounted) {
                            setState(() {
                              _provinceCode = _selectedProvince!.code;
                              _provinceName = _selectedProvince!.name;
                              _districtCode = _selectedDistrict!.code;
                              _districtName = _selectedDistrict!.name;
                            });
                            _fetchPrices(); // Refresh prices
                          }
                          Navigator.pop(context);
                        } 
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadDistrictsForModal(int provinceCode, StateSetter setModalState) async {
    setModalState(() => _isLoadingDistricts = true);
    final list = await _opetService.getDistricts(provinceCode);
    if (mounted) {
      setModalState(() {
        _districts = list;
        _isLoadingDistricts = false;
        // Auto-select center if available
        try {
          if (_selectedDistrict == null && list.isNotEmpty) {
             _selectedDistrict = list.firstWhere((d) => d.isCenter, orElse: () => list.first);
          }
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prices.isEmpty && _isLoading) return SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));

    // Filter for main products: Benzin (Gasoline) and Motorin (Diesel)
    // Adjust logic based on exact names from API/Mock
    var gasPrice = _prices.firstWhere((p) => p.productName.toLowerCase().contains("benzin") || p.productName.contains("95"), orElse: () => FuelPrice(productName: "-", amount: 0)).amount;
    var dieselPrice = _prices.firstWhere((p) => p.productName.toLowerCase().contains("motorin") || p.productName.contains("ultra"), orElse: () => FuelPrice(productName: "-", amount: 0)).amount;

    return GestureDetector(
      onTap: () => _showLocationPicker(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end, // Align to right as per request/image
          mainAxisSize: MainAxisSize.min,
          children: [
            // Location Selector with Icon (Like Image)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getShortProvinceName(_provinceName), 
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withOpacity(0.5)
                  )
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
              ],
            ),
            SizedBox(height: 4),
            
            // Gasoline
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Benzin ", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                Text(
                   gasPrice > 0 ? gasPrice.toStringAsFixed(2) : "-", 
                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                ),
              ],
            ),
            
            // Diesel
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Dizel ", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                Text(
                   dieselPrice > 0 ? dieselPrice.toStringAsFixed(2) : "-", 
                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getShortProvinceName(String name) {
    final upperName = name.toUpperCase();
    if (upperName.contains("İSTANBUL") && upperName.contains("ANADOLU")) {
      return "İSTANBUL AN.";
    }
    if (upperName.contains("İSTANBUL") && upperName.contains("AVRUPA")) {
      return "İSTANBUL AV.";
    }
    return name;
  }
}
