import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BrandGridScreen extends StatefulWidget {
  final String title;
  final List<String> brands;
  final String Function(String) logoGetter;
  final String? Function(String) urlGetter;

  const BrandGridScreen({
    super.key,
    required this.title,
    required this.brands,
    required this.logoGetter,
    required this.urlGetter,
  });

  @override
  State<BrandGridScreen> createState() => _BrandGridScreenState();
}

class _BrandGridScreenState extends State<BrandGridScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  late List<String> _filteredBrands;

  @override
  void initState() {
    super.initState();
    // Sort initially
    _filteredBrands = List.from(widget.brands)..sort();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredBrands = widget.brands
          .where((brand) => brand.toLowerCase().contains(_searchQuery))
          .toList()
          ..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Cleaner off-white
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
                hintText: "${widget.title} içinde ara...",
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

          // --- GRID CONTENT ---
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
                      childAspectRatio: 1.1, // Slightly more square for modern feel
                    ),
                    itemCount: _filteredBrands.length,
                    itemBuilder: (context, index) {
                      final brand = _filteredBrands[index];
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
            final url = widget.urlGetter(brand);
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
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Area
                Expanded(
                  child: Center(
                    child: Image.network(
                      widget.logoGetter(brand),
                      width: 65, // Slightly larger
                      height: 65,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                             color: Colors.grey[100],
                             shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            brand.isNotEmpty ? brand[0] : "?",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0059BC),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Brand Name
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
                
                // Action Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("İncele", style: TextStyle(fontSize: 12, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w500)),
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
