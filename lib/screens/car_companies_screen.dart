import '../widgets/brand_logo.dart'; // [NEW] Shared widget
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../data/car_data.dart';

class CarCompaniesScreen extends StatefulWidget {
  const CarCompaniesScreen({super.key});

  @override
  State<CarCompaniesScreen> createState() => _CarCompaniesScreenState();
}

class _CarCompaniesScreenState extends State<CarCompaniesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<String> _allBrands = [];
  List<String> _filteredBrands = [];

  @override
  void initState() {
    super.initState();
    // Load and sort brands
    _allBrands = CarData.brandModels.keys.toList()..sort();
    
    // Move "Diğer" to end if exists
    if (_allBrands.contains("Diğer")) {
      _allBrands.remove("Diğer");
      _allBrands.add("Diğer");
    }
    
    _filteredBrands = List.from(_allBrands);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredBrands = _allBrands
          .where((brand) => brand.toLowerCase().contains(_searchQuery))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Araç Firmaları",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Marka ara (örn: Audi, BMW)...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                 suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                         _searchController.clear();
                         _onSearchChanged("");
                      },
                    ) 
                  : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),

          // --- GRID ---
          Expanded(
            child: _filteredBrands.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                         const SizedBox(height: 16),
                         Text("Sonuç bulunamadı: '$_searchQuery'", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, 
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _filteredBrands.length,
                    itemBuilder: (context, index) {
                      String brand = _filteredBrands[index];
                      return _buildBrandCard(brand);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandCard(String brand) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
             final url = CarData.brandUrls[brand];
             if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.inAppWebView);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Bu site açılamadı.")),
                    );
                  }
                }
             } else {
               if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$brand için web sitesi bulunamadı.")),
                  );
               }
             }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: BrandLogo(
                      logoUrl: CarData.getLogoUrl(brand), 
                      size: 65
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  brand,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 6),
                
                // Action
                 Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Modeller", style: TextStyle(fontSize: 12, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.blueAccent.shade700),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
