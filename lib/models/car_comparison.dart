class CarComparison {
  final String winner;
  final String details;
  final double scoreA;
  final double scoreB;
  final List<double> radarScoresA;
  final List<double> radarScoresB;
  final int? year1;
  final int? year2;
  final String? priceA;
  final String? priceB;
  
  // [NEW] Enhanced AI Fields
  final String? marketAnalysis; // Oto Gurme Analysis
  final String? reliabilityInfo; // Chronic issues etc.
  final String? userReviews; // Motor1 summary
  
  // [NEW] Photos from Scraper
  final String? photoA;
  final String? photoB;
  
  // [NEW] Structured Comparison Features for Bar Charts
  final List<Map<String, dynamic>>? comparisonFeatures; // [{'title': 'Hız', 'valA': '200', 'valB': '220', 'unit': 'km/s', 'winner': 'B'}]

  CarComparison({
    required this.winner,
    required this.details,
    required this.scoreA,
    required this.scoreB,
    this.radarScoresA = const [8, 7, 7, 8, 9],
    this.radarScoresB = const [7, 8, 8, 7, 8],
    this.year1,
    this.year2,
    this.priceA,
    this.priceB,
    this.marketAnalysis,
    this.reliabilityInfo,
    this.userReviews,
    this.photoA,
    this.photoB,
    this.comparisonFeatures,
  });
}
