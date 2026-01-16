class CarData {
  static const Map<String, List<String>> brandModels = {
    "Audi": ["A1", "A3", "A4", "A5", "A6", "A7", "A8", "Q2", "Q3", "Q5", "Q7", "Q8", "e-tron"],
    "BMW": ["1 Serisi", "2 Serisi", "3 Serisi", "4 Serisi", "5 Serisi", "7 Serisi", "X1", "X2", "X3", "X4", "X5", "X6", "X7", "iX", "i4"],
    "Chery": ["Tiggo 4 Pro", "Tiggo 7 Pro", "Tiggo 8 Pro", "Omoda 5"],
    "Citroen": ["C3", "C3 Aircross", "C4", "C4 X", "C5 Aircross", "Berlingo"],
    "Dacia": ["Sandero", "Sandero Stepway", "Duster", "Jogger", "Spring"],
    "Fiat": ["Egea", "Egea Cross", "500", "500X", "Panda", "Doblo", "Fiorino"],
    "Ford": ["Fiesta", "Focus", "Puma", "Kuga", "Ranger", "Tourneo Courier", "Transit"],
    "Honda": ["Civic", "City", "Jazz", "HR-V", "CR-V", "ZR-V"],
    "Hyundai": ["i10", "i20", "i30", "Bayon", "Kona", "Tucson", "Santa Fe", "Elantra", "Ioniq 5", "Ioniq 6"],
    "Kia": ["Picanto", "Rio", "Stonic", "Cerato", "Ceed", "XCeed", "Niro", "Sportage", "Sorento", "EV6"],
    "Mercedes": ["A Serisi", "B Serisi", "C Serisi", "E Serisi", "S Serisi", "CLA", "GLA", "GLB", "GLC", "GLE", "G Serisi", "EQA", "EQB", "EQE"],
    "Nissan": ["Micra", "Juke", "Qashqai", "X-Trail"],
    "Opel": ["Corsa", "Astra", "Mokka", "Crossland", "Grandland", "Combo"],
    "Peugeot": ["208", "308", "408", "508", "2008", "3008", "5008", "Rifter"],
    "Renault": ["Clio", "Taliant", "Captur", "Megane", "Austral", "Koleos", "Zoe", "Kangoo"],
    "Seat": ["Ibiza", "Leon", "Arona", "Ateca", "Tarraco"],
    "Skoda": ["Fabia", "Scala", "Octavia", "Superb", "Kamiq", "Karoq", "Kodiaq"],
    "Toyota": ["Yaris", "Corolla", "Corolla Cross", "C-HR", "RAV4", "Hilux", "Proace City"],
    "Volkswagen": ["Polo", "Golf", "T-Roc", "Taigo", "Tiguan", "Passat", "Caddy", "Transporter"],
    "Volvo": ["XC40", "XC60", "XC90", "S60", "S90", "V60", "V90", "C40"],
    "Togg": ["T10X"],
    "Tesla": ["Model 3", "Model Y", "Model S", "Model X"],
    "Diğer": ["Diğer"]
  };

  static const Map<String, String> carLogos = {
    "Alfa Romeo": "https://m.atcdn.co.uk/schemes/media/w64/alfa_romeo/cb035c49efc14d30a7051f967e05ab7c.jpg",
    "Anadol": "",
    "Arora": "",
    "Aston Martin": "https://m.atcdn.co.uk/schemes/media/w64/aston_martin/f04aebbdaddb46d6b45f3cd780864ed7.jpg",
    "Audi": "https://m.atcdn.co.uk/schemes/media/w64/audi/226b3dbffe2b4155a69702dc9d547f4d.jpg",
    "Bentley": "https://m.atcdn.co.uk/schemes/media/w64/bentley/f0a8daf96d6b4125bc500845c49f6624.jpg",
    "BMW": "https://m.atcdn.co.uk/schemes/media/w64/bmw/74deb1191aeb438eb9764aef4b52665a.jpg",
    "Bugatti": "https://m.atcdn.co.uk/schemes/media/w64/bugatti/9ced27639255452fb1f8b94e06f7559b.jpg",
    "Buick": "https://m.atcdn.co.uk/schemes/media/w64/buick/af27eac92089403faf53a4c1239b6fa6.jpg",
    "BYD": "https://m.atcdn.co.uk/schemes/media/w64/byd/0ca62fc652e6455a8be0f63dda10b0ee.jpg",
    "Cadillac": "https://m.atcdn.co.uk/schemes/media/w64/cadillac/d34d5b02848c48518e74fdfb746d88e0.jpg",
    "Chery": "https://m.atcdn.co.uk/schemes/media/w64/chery/ca7c69167cd542b6a6db13520a01a92c.jpg",
    "Chevrolet": "https://m.atcdn.co.uk/schemes/media/w64/chevrolet/16a449e0d3ca4bffa6b855fac92619fb.jpg",
    "Chrysler": "https://m.atcdn.co.uk/schemes/media/w64/chrysler/1b94c2dfd29b4bb0930e1c800b759c3d.jpg",
    "Citroen": "https://m.atcdn.co.uk/schemes/media/w64/citroen/5372f8c8d28241c3a472f58a9b83de4c.jpg",
    "Cupra": "https://m.atcdn.co.uk/schemes/media/w64/cupra/77a98a4260ad4db882d2fd592617f191.jpg",
    "Dacia": "https://m.atcdn.co.uk/schemes/media/w64/dacia/2ad7def945274187a774cccd7b8d198b.jpg",
    "Daewoo": "https://m.atcdn.co.uk/schemes/media/w64/daewoo/183ebbac6c6141899a150470cc9ad724.jpg",
    "Daihatsu": "https://m.atcdn.co.uk/schemes/media/w64/daihatsu/5d2d3ee7aed941a0b7677055b7ab84a7.jpg",
    "Dodge": "https://m.atcdn.co.uk/schemes/media/w64/dodge/f47a4f860b0e414995d6f1086d11392e.jpg",
    "DS Automobiles": "https://m.atcdn.co.uk/schemes/media/w64/ds_automobiles/ae3d64c0d8d84143899cff2a09b31076.jpg",
    "Ferrari": "https://m.atcdn.co.uk/schemes/media/w64/ferrari/1b06f0715f5f4cc1a4d80c33dfc4fef9.jpg",
    "Fiat": "https://m.atcdn.co.uk/schemes/media/w64/fiat/fa6d1b2cdbb94de1ac565ff0243df2f5.jpg",
    "Ford": "https://m.atcdn.co.uk/schemes/media/w64/ford/03156d35774a4e0bb86272a4ddf7dc8a.jpg",
    "Geely": "https://m.atcdn.co.uk/schemes/media/w64/geely/c368e2c2b04943e48615e864d48477cb.jpg",
    "Honda": "https://m.atcdn.co.uk/schemes/media/w64/honda/1986837707564ab68f9a1f4a7400f00b.jpg",
    "Hyundai": "https://m.atcdn.co.uk/schemes/media/w64/hyundai/dfb2888449874886af3d4c11d41e6b98.jpg",
    "Ikco": "",
    "Infiniti": "https://m.atcdn.co.uk/schemes/media/w64/infiniti/3b12e3431c3b4e54a9e27d70f98a86a7.jpg",
    "Jaguar": "https://m.atcdn.co.uk/schemes/media/w64/jaguar/39fe71594d884a13b84799d998b3a267.jpg",
    "Kia": "https://m.atcdn.co.uk/schemes/media/w64/kia/906a0acc02ec458d8b8c3b4aa1dc426f.jpg",
    "Kuba": "",
    "Lada": "https://m.atcdn.co.uk/schemes/media/w64/lada/db6e55f4b6b8451abec67194b181aa37.jpg",
    "Lamborghini": "https://m.atcdn.co.uk/schemes/media/w64/lamborghini/4a6329ba3a324c1c85f270082eccbbdc.jpg",
    "Lancia": "https://m.atcdn.co.uk/schemes/media/w64/lancia/015acb2df36b484f9326cce627ff5135.jpg",
    "Lexus": "https://m.atcdn.co.uk/schemes/media/w64/lexus/751f9d063b3d4cd899009f97515eacb9.jpg",
    "Lincoln": "https://m.atcdn.co.uk/schemes/media/w64/lincoln/fa5105a62125476d9e677dbf32b27f5a.jpg",
    "Lotus": "https://m.atcdn.co.uk/schemes/media/w64/lotus/18fe7c3cad1a46a39d58c1eb535f8f2a.jpg",
    "Maserati": "https://m.atcdn.co.uk/schemes/media/w64/maserati/ad9942553a0f43a7a0f153dc640a8162.jpg",
    "Mazda": "https://m.atcdn.co.uk/schemes/media/w64/mazda/19bcfe562a664955b84a9e3ead6ab890.jpg",
    "McLaren": "https://m.atcdn.co.uk/schemes/media/w64/mclaren/a627d7a079b04d6bad9541be80647482.jpg",
    "Mercedes - Benz": "https://m.atcdn.co.uk/schemes/media/w64/mercedes-benz/de5dcb1b8505459badef9b8e3fc310d1.jpg",
    "MG": "https://m.atcdn.co.uk/schemes/media/w64/mg/8c8f5575553e4267808e51e0a3d84b5a.jpg",
    "Mini": "https://m.atcdn.co.uk/schemes/media/w64/mini/9bf7c84c84bd4e699027d4fde8bd4a46.jpg",
    "Mitsubishi": "https://m.atcdn.co.uk/schemes/media/w64/mitsubishi/31c0aa4a3ae14dee9449efab354cff5f.jpg",
    "Nissan": "https://m.atcdn.co.uk/schemes/media/w64/nissan/6ea26bb667584442836971cab6e9a981.jpg",
    "Opel": "https://m.atcdn.co.uk/schemes/media/w64/opel/7558e9d7125145b99e6b4ac7c19c3b2d.jpg",
    "Peugeot": "https://m.atcdn.co.uk/schemes/media/w64/peugeot/0dc587254f9e4acab78581d28cc06216.jpg",
    "Pontiac": "https://m.atcdn.co.uk/schemes/media/w64/pontiac/12a8f6ca3e794b6294bb1c3ae5c3bc60.jpg",
    "Porsche": "https://m.atcdn.co.uk/schemes/media/w64/porsche/55445017cf8c4b779b73faedfbc8373e.jpg",
    "Proton": "https://m.atcdn.co.uk/schemes/media/w64/proton/8365eacbd4704a2bbb20f3e314cd4bd1.jpg",
    "Renault": "https://m.atcdn.co.uk/schemes/media/w64/renault/477fb5d8323949dab0f860194d2852f6.jpg",
    "Rolls-Royce": "https://m.atcdn.co.uk/schemes/media/w64/rolls-royce/55b781cdc5cb40fb9ad71b09b73bc210.jpg",
    "Rover": "https://m.atcdn.co.uk/schemes/media/w64/rover/13f0cfed230d42558727a6c5b5c18eef.jpg",
    "Saab": "https://m.atcdn.co.uk/schemes/media/w64/saab/7a4faa31e4004a66afe78b00ac6f1404.jpg",
    "Seat": "https://m.atcdn.co.uk/schemes/media/w64/seat/cbdf5fb570874227bfddc6e1c0ae2e33.jpg",
    "Skoda": "https://m.atcdn.co.uk/schemes/media/w64/skoda/0a73e0599dd740838a0b022ebe1788a1.jpg",
    "Smart": "https://m.atcdn.co.uk/schemes/media/w64/smart/d4eaf73bff9b4a0094a2a00380632e42.jpg",
    "Subaru": "https://m.atcdn.co.uk/schemes/media/w64/subaru/e142e786ab8c4baab8b040f1feda4016.jpg",
    "Suzuki": "https://m.atcdn.co.uk/schemes/media/w64/suzuki/cd60eeeb433e4eb0a480d4f1db98f530.jpg",
    "Tata": "",
    "Tesla": "https://m.atcdn.co.uk/schemes/media/w64/tesla/c5c9eec1e08c42ca8ad1169fda72d4a8.jpg",
    "Tofaş": "",
    "Togg": "",
    "Toyota": "https://m.atcdn.co.uk/schemes/media/w64/toyota/fa1a842719aa49409639ac160b0a138b.jpg",
    "Volkswagen": "https://m.atcdn.co.uk/schemes/media/w64/volkswagen/661f92e5c2d044a8b9151461fe1c1e5d.jpg",
    "Volvo": "https://m.atcdn.co.uk/schemes/media/w64/volvo/aa179d958257472f98231cba21fb3ada.jpg",
  };

  static const Map<String, String> brandUrls = {
    "Audi": "https://www.audi.com.tr",
    "BMW": "https://www.bmw.com.tr",
    "Chery": "https://cherytr.com",
    "Citroen": "https://www.citroen.com.tr",
    "Dacia": "https://www.dacia.com.tr",
    "Fiat": "https://www.fiat.com.tr",
    "Ford": "https://www.ford.com.tr",
    "Honda": "https://www.honda.com.tr",
    "Hyundai": "https://www.hyundai.com.tr",
    "Kia": "https://www.kia.com/tr",
    "Mercedes": "https://www.mercedes-benz.com.tr",
    "Nissan": "https://www.nissan.com.tr",
    "Opel": "https://www.opel.com.tr",
    "Peugeot": "https://www.peugeot.com.tr",
    "Renault": "https://www.renault.com.tr",
    "Seat": "https://www.seat.com.tr",
    "Skoda": "https://www.skoda.com.tr",
    "Toyota": "https://www.toyota.com.tr",
    "Volkswagen": "https://www.vw.com.tr",
    "Volvo": "https://www.volvocars.com/tr",
    "Togg": "https://www.togg.com.tr",
    "Tesla": "https://www.tesla.com/tr_TR",
    "Diğer": "https://www.google.com/search?q=araba+markalar%C4%B1"
  };

  static String getLogoUrl(String brand) {
    // Normalization
    String normalized = brand.toLowerCase().trim();
    
    // Manual mapping for special cases in the dataset
    // Check local map first (case-insensitive)
    for (var entry in carLogos.entries) {
      if (entry.key.toLowerCase() == normalized) {
        return entry.value;
      }
    }
    
    // Default format: https://.../brand.png
    // If not found in our curated list, return empty string to trigger fallback UI.
    return "";
  }
}
