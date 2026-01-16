class OilCatalog {
  static const Map<String, Map<String, List<String>>> data = {
    "Castrol": {
      "Edge": ["0W-30", "5W-30", "5W-40", "10W-60"],
      "Magnatec": ["5W-30", "10W-40"],
      "GTX": ["5W-30", "10W-40", "15W-40", "20W-50"],
    },
    "Mobil 1": {
      "ESP": ["0W-30", "5W-30"],
      "FS": ["0W-40"],
      "Extended Life": ["10W-60"],
      "New Life": ["0W-40"],
    },
    "Mobil": {
      "Super 3000": ["5W-30", "5W-40"],
      "Super 2000": ["10W-40"],
      "Delvac": ["5W-30", "10W-40", "15W-40"],
    },
    "Motul": {
      "8100 X-Process": ["5W-30"],
      "8100 X-Clean": ["5W-30", "5W-40"],
      "8100 X-Cess": ["5W-40"],
      "8100 Eco-nergy": ["5W-30"],
      "8100 X-Power": ["10W-60"],
      "300V Power": ["0W-20", "5W-30", "5W-40", "15W-50"],
      "6100 Synergie+": ["10W-40"],
    },
    "Shell": {
      "Helix Ultra": ["0W-20", "0W-30", "5W-30", "5W-40"],
      "Helix HX8": ["5W-30", "5W-40"],
      "Helix HX7": ["10W-40"],
      "Helix HX6": ["10W-40"],
    },
    "Liqui Moly": {
      "Top Tec 4200": ["5W-30"],
      "Top Tec 4600": ["5W-30"],
      "Molygen": ["5W-30", "5W-40", "10W-40"],
      "Leichtlauf": ["5W-40", "10W-40"],
      "MoS2 Leichtlauf": ["10W-40"],
    },
    "Petrol Ofisi": {
      "Maxima CX": ["5W-30"],
      "Maxima GA": ["5W-30", "5W-40"],
      "Maxima": ["10W-40"],
    },
    "Opet": {
      "Fullmax": ["0W-20", "5W-30", "5W-40", "10W-40"],
      "Fulllife": ["5W-30", "10W-40", "20W-50"],
    },
    "Elf": {
      "Evolution Fulltech": ["5W-30", "5W-40"],
      "Evolution 900": ["5W-30", "5W-40"],
      "Evolution 700": ["10W-40"],
    },
    "TotalEnergies": {
      "Quartz Ineo": ["0W-30", "5W-30"],
      "Quartz 9000": ["5W-40"],
      "Quartz 7000": ["10W-40"],
    },
  };

  static List<String> getBrands() => data.keys.toList()..sort();

  static List<String> getModels(String brand) {
    return data[brand]?.keys.toList()  ?? [];
  }

  static List<String> getViscosities(String brand, String model) {
    return data[brand]?[model] ?? [];
  }
}
