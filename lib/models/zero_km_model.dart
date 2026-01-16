class ZeroKmBrand {
  final String name;
  final String slug;
  final String? logoUrl;

  ZeroKmBrand({required this.name, required this.slug, this.logoUrl});
}

class ZeroKmModel {
  final String name;
  final String slug;
  final String priceRange; // e.g. "1.099.000 - 1.500.000 TL"
  final String imageUrl;

  ZeroKmModel({required this.name, required this.slug, required this.priceRange, required this.imageUrl});
}

class ZeroKmVersion {
  final String name; // e.g. 1.4 Fire Easy
  final String price; // e.g. 1.099.900 TL
  final String fuelType; // e.g. Benzin
  final String gearType; // e.g. Düz
  final String fuelConsumption; // e.g. 6.4 lt/100km
  final String specsUrl; // e.g. /sifir-km/technicaldetail/...
  final String compareUrl; // e.g. /sifir-km/karsilastirma/...
  final String? imageUrl;

  ZeroKmVersion({
    required this.name,
    required this.price,
    required this.fuelType,
    required this.gearType,
    required this.fuelConsumption,
    required this.specsUrl,
    required this.compareUrl,
    this.imageUrl,
  });
}

class ZeroKmSpecs {
  final Map<String, String> specs;

  ZeroKmSpecs({required this.specs});
}
