class BrandData {
  // Car Brands
  static const List<String> carBrands = [
    "Alfa Romeo", "Audi", "BMW", "Chery", "Chevrolet", "Citroen", "Dacia", "DS Automobiles",
    "Fiat", "Ford", "Honda", "Hyundai", "Kia", "Land Rover", "Mercedes-Benz", "Mini",
    "Nissan", "Opel", "Peugeot", "Renault", "Seat", "Skoda", "Subaru", "Suzuki", "Togg",
    "Toyota", "Volkswagen", "Volvo", "Maserati", "Porsche", "Ferrari", "Lamborghini", "Aston Martin",
    "Bentley", "Bugatti", "Cadillac", "Chrysler", "Dodge", "GMC", "Infiniti", "Jaguar", "Jeep",
    "Lexus", "Lincoln", "Lotus", "McLaren", "Mitsubishi", "Rolls-Royce", "Tesla", "Smart"
  ];

  // Tyre Brands
  static const List<String> tyreBrands = [
    "Michelin",
    "Continental",
    "Bridgestone",
    "Goodyear",
    "Pirelli",
    "Lassa",
    "Petlas",
    "Hankook",
    "Dunlop",
    "Falken",
    "Yokohama"
  ];

  static const Map<String, String> tyreBrandUrls = {
    "Michelin": "https://www.michelin.com.tr",
    "Continental": "https://www.continental-tires.com/tr/tr/",
    "Bridgestone": "https://www.bridgestone.com.tr",
    "Goodyear": "https://www.goodyear.eu/tr_tr/consumer.html",
    "Pirelli": "https://www.pirelli.com/tyres/tr-tr/otomobil/anasayfa",
    "Lassa": "https://www.lassa.com.tr",
    "Petlas": "https://www.petlas.com.tr",
    "Hankook": "https://www.hankooktire.com/tr/",
    "Dunlop": "https://www.dunlop.com/tr/"
  };

  // Engine Oil Brands
  static const List<String> oilBrands = [
    "Mobil 1",
    "Castrol",
    "Shell",
    "Motul",
    "Liqui Moly",
    "TotalEnergies",
    "Elf",
    "Petrol Ofisi",
    "Opet",
    "Petronas",
    "Lukoil"
  ];

  static const Map<String, String> oilBrandUrls = {
    "Mobil 1": "https://www.mobil.com.tr",
    "Castrol": "https://www.castrol.com/tr_tr/turkey/home.html",
    "Shell": "https://www.shell.com.tr/suruculer/madeni-yaglar.html",
    "Motul": "https://www.motul.com/tr/tr",
    "Liqui Moly": "https://www.liqui-moly.com/tr/tr/",
    "TotalEnergies": "https://services.totalenergies.tr",
    "Elf": "https://www.elf.com.tr",
    "Petrol Ofisi": "https://www.petrolofisi.com.tr/madeni-yaglar",
    "Opet": "https://www.opetfuchs.com.tr",
    "Petronas": "https://www.pli-petronas.com/tr-tr",
    "Lukoil": "https://lukoil-turkey.com.tr/tr/Products/ForMotorists/MotorOils"
  };

  static const Map<String, String> oilBrandLogos = {
    "Liqui Moly": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/427/liqui-moly-logo-973BFDEB3D-seeklogo.com.png?revision=1690963084",
    "Mobil 1": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/300/2560px-Mobil_logo.svg.png?revision=1690963245",
    "Castrol": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/299/indir%20(1).png?revision=1690963256",
    "Shell": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/301/shell-logo-25F8B6686F-seeklogo.com.png?revision=1690963052",
    "Motul": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/358/2560px-Motul_logo.svg.png?revision=1690963048",
    "TotalEnergies": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/342/Total-Logo.png?revision=1690962639",
    "Elf": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/315/315_logo.jpg?revision=1469134347",
    "Petrol Ofisi": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/325/325_logo.png?revision=1690962772",
    "Opet": "https://www.turkoilmarket.com/shop/ur/92/myassets/brands/453/opet-marka-logo.png?revision=1690962858"
  };

  static const Map<String, String> tyreBrandLogos = {
    "Michelin": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/8/michelin.png",
    "Continental": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/7/continental.png",
    "Bridgestone": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/14/bridgestone.png",
    "Goodyear": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/3/goodyear.png",
    "Pirelli": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/5/pirelli.png",
    "Lassa": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/9/lassa.png",
    "Petlas": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/10/petlas.png",
    "Hankook": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/2/hankook.png",
    "Dunlop": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/23/dunlop.png",
    "Falken": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/20/falken.png",
    "Yokohama": "https://www.lastiksiparis.com/idea/jh/97/myassets/brands/30/yokohama.png"
  };

  static String getLogoUrl(String brand) {
    // If it's a tyre brand with a specific logo URL, return it
    if (tyreBrandLogos.containsKey(brand)) {
      return tyreBrandLogos[brand]!;
    }
    
    // If it's an oil brand with a specific logo URL, return it
    if (oilBrandLogos.containsKey(brand)) {
      return oilBrandLogos[brand]!;
    }

    String normalized = brand.toLowerCase().replaceAll(" ", "").trim();
    
    // Specific mappings for brands where domain isn't obvious or Clearbit needs help
    if (normalized == "lassa") return "https://www.lassa.com.tr/assets/img/logo.png";
    if (normalized == "petlas") return "https://www.petlas.com.tr/assets/images/petlas-logo.png";
    if (normalized == "liquimoly") return "https://logo.clearbit.com/liqui-moly.com";
    if (normalized == "mobil1") return "https://logo.clearbit.com/mobil.com";
    if (normalized == "totalenergies") return "https://logo.clearbit.com/totalenergies.com";

    // Try to get domain from URLs if mapped
    String? url = tyreBrandUrls[brand] ?? oilBrandUrls[brand];
    if (url != null) {
      final uri = Uri.parse(url);
      final domain = uri.host.replaceFirst("www.", "");
      return "https://logo.clearbit.com/$domain";
    }

    // Default Clearbit format
    return "https://logo.clearbit.com/$normalized.com";
  }
}
