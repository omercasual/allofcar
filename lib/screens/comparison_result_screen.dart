import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/car_comparison.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'ai_assistant_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import '../widgets/translatable_text.dart';

class ComparisonResultScreen extends StatefulWidget {
  final String car1Name;
  final String car2Name;
  final CarComparison comparisonData;
  final bool isNewCarMode;

  const ComparisonResultScreen({
    super.key,
    required this.car1Name,
    required this.car2Name,
    required this.comparisonData,
    required this.isNewCarMode,
  });

  @override
  State<ComparisonResultScreen> createState() => _ComparisonResultScreenState();
}

class _ComparisonResultScreenState extends State<ComparisonResultScreen> with SingleTickerProviderStateMixin {
  String? _favoriteDocId;

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final user = AuthService().currentUser;
    if (user != null && !user.isAnonymous) {
      final firestore = FirestoreService();
      String? id = await firestore.findComparisonFavoriteId(user.uid, widget.car1Name, widget.car2Name);
      if (mounted) {
        setState(() {
          _favoriteDocId = id;
        });
      }
    }
  }

  Future<void> _launchMotor1Search(String query) async {
    final encodedQuery = Uri.encodeComponent('site:tr.motor1.com "${query}" inceleme');
    final url = Uri.parse("https://www.google.com/search?q=$encodedQuery");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('comparison_result_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _favoriteDocId != null ? Icons.favorite : Icons.favorite_border, 
              color: Colors.red
            ),
            onPressed: () async {
              final auth = AuthService();
              final user = auth.currentUser;
              final uid = user?.uid;

              if (uid != null && !user!.isAnonymous) {
                final firestore = FirestoreService();
                
                if (_favoriteDocId != null) {
                  await firestore.removeFavorite(uid, _favoriteDocId!);
                  if (mounted) setState(() => _favoriteDocId = null);
                } else {
                  String id = await firestore.addComparisonFavorite(
                    uid, 
                    {
                      'car1Name': widget.car1Name,
                      'car2Name': widget.car2Name,
                      'winner': widget.comparisonData.winner,
                      'details': widget.comparisonData.details,
                      'scoreA': widget.comparisonData.scoreA,
                      'scoreB': widget.comparisonData.scoreB,
                      'radarScoresA': widget.comparisonData.radarScoresA,
                      'radarScoresB': widget.comparisonData.radarScoresB,
                      'isNewCarMode': widget.isNewCarMode,
                    }
                  );
                  if (mounted) setState(() => _favoriteDocId = id);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_t('login_required'))),
                );
              }
            },
          ),
        ],
      ),
      body: PageView(
        controller: PageController(viewportFraction: 0.95),
        children: [
          // PAGE 1: TECHNICAL & OVERVIEW
          _buildPageContainer(
            title: _t('overview_technical'),
            icon: Icons.speed,
            color: const Color(0xFF0059BC),
            content: _buildTechnicalContent(),
          ),

          // PAGE 2: MARKET & OTO GURME
          _buildPageContainer(
            title: _t('market_analysis_title'),
            icon: Icons.monetization_on,
            color: Colors.green,
            content: _buildMarketAnalysisContent(),
          ),

          // PAGE 3: REVIEWS & CHRONIC ISSUES
          _buildPageContainer(
            title: _t('user_experiences'),
            icon: Icons.forum,
            color: Colors.orange,
            content: _buildReviewContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContainer({required String title, required IconData icon, required Color color, required Widget content}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                         color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, 
                         shape: BoxShape.circle
                     ),
                     child: Icon(icon, color: color, size: 28),
                   ),
                   const SizedBox(width: 15),
                   Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
                   const Icon(Icons.swipe_left, color: Colors.grey, size: 20),
                ],
              ),
            ),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PAGE 1: TECHNICAL ---
  Widget _buildTechnicalContent() {
    return Column(
      children: [
        // Photos Row (If Available)
        if (widget.comparisonData.photoA != null && widget.comparisonData.photoB != null)
           Padding(
             padding: const EdgeInsets.only(bottom: 20.0),
             child: Row(
               children: [
                 Expanded(child: _buildCarPhoto(widget.comparisonData.photoA!, widget.car1Name)),
                 const SizedBox(width: 10),
                 const Icon(Icons.compare_arrows, size: 30, color: Colors.grey),
                 const SizedBox(width: 10),
                 Expanded(child: _buildCarPhoto(widget.comparisonData.photoB!, widget.car2Name)),
               ],
             ),
           ),

        // Winner Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0059BC), Color(0xFF0088FF)]),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: const Color(0xFF0059BC).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            children: [
              Text(_t('winner_caps'), style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12)),
              const SizedBox(height: 5),
              Text(
                widget.comparisonData.winner,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        // Comparison Bars (Simulated Radar)
        _buildComparisonBars(),

        const SizedBox(height: 25),
        Text(_t('technical_scores'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _buildScoreCard(widget.car1Name, widget.comparisonData.scoreA),
        const SizedBox(height: 10),
        _buildScoreCard(widget.car2Name, widget.comparisonData.scoreB),
        
        const SizedBox(height: 25),
        const Divider(),
        
        // Feature Comparison Bars (Detailed Specs)
        if (widget.comparisonData.comparisonFeatures != null && widget.comparisonData.comparisonFeatures!.isNotEmpty)
          ...widget.comparisonData.comparisonFeatures!.map((f) => _buildFeatureRow(f)).toList()
        else
          TranslatableText(
             widget.comparisonData.details.contains("###") 
                ? widget.comparisonData.details.replaceAll('#', '').trim()
                : widget.comparisonData.details, 
             style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, height: 1.5)
          ),
      ],
    );
  }

  Widget _buildFeatureRow(Map<String, dynamic> feature) {
    String title = feature['title'];
    String valA = feature['valA'];
    String valB = feature['valB'];
    double numA = feature['numA'] ?? 0;
    double numB = feature['numB'] ?? 0;
    bool higherIsBetter = feature['higherIsBetter'] ?? true;
    
    // Determine Bar Percentage (Relative to max)
    double maxVal = (numA > numB ? numA : numB);
    if (maxVal == 0) maxVal = 1;
    
    double percentA = (numA / maxVal);
    double percentB = (numB / maxVal);
    
    // Safety clamp (shouldn't be needed if logic is correct but good practice)
    if (percentA > 1.0) percentA = 1.0;
    if (percentB > 1.0) percentB = 1.0;

    // Logic: 
    // If numA == maxVal && higherIsBetter => A Wins
    // If numA < maxVal && !higherIsBetter => A Wins (smaller is better)
    bool aWins = (numA == maxVal && higherIsBetter) || (numA < maxVal && !higherIsBetter);
    if (numA == numB) aWins = false; // Tie

    bool bWins = (numB == maxVal && higherIsBetter) || (numB < maxVal && !higherIsBetter);
    if (numA == numB) bWins = false; // Tie

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 5),
          Row(
            children: [
               // Left Side (Car A) - Aligned Right
               Expanded(
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(valA, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: aWins ? const Color(0xFF0059BC) : Theme.of(context).textTheme.bodyLarge?.color)),
                      ),
                      // Bar A (Growing Left)
                       Container(
                         height: 8,
                         width: 60 * percentA, // Max width 60
                         decoration: BoxDecoration(
                           color: const Color(0xFF0059BC).withOpacity(aWins ? 1.0 : 0.3),
                           borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                         ),
                       ),
                   ],
                 ),
               ),
               
               // Center Separator
               const SizedBox(width: 4),
               Container(width: 1, height: 15, color: Colors.grey.withOpacity(0.3)),
               const SizedBox(width: 4),
               
               // Right Side (Car B) - Aligned Left
               Expanded(
                 child: Row(
                   children: [
                      // Bar B (Growing Right)
                       Container(
                         height: 8,
                         width: 60 * percentB,
                         decoration: BoxDecoration(
                           color: Colors.red.withOpacity(bWins ? 1.0 : 0.3),
                           borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                         ),
                       ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(valB, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bWins ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color)),
                      ),
                   ],
                 ),
               ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCarPhoto(String url, String name) {
    return Column(
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            color: Theme.of(context).cardColor,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url, 
              fit: BoxFit.cover, 
              width: double.infinity,
              errorBuilder: (c,e,s) => const Center(child: Icon(Icons.directions_car, color: Colors.grey, size: 40)),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(name.split(" ")[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // --- PAGE 2: MARKET ANALYSIS ---
  Widget _buildMarketAnalysisContent() {
    final market = widget.comparisonData.marketAnalysis ?? "Veri yok.";
    final reliability = widget.comparisonData.reliabilityInfo ?? "Veri yok.";
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(_t('used_market'), market, Icons.trending_up, Colors.green),
        const SizedBox(height: 30),
        _buildInfoSection(_t('reliability_chronic'), reliability, Icons.handyman, Colors.redAccent),
        const SizedBox(height: 30),
        
        // "Oto Gurme" Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
                const SizedBox(width: 8),
                Text(_t('ai_analysis_badge'), style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        )
      ],
    );
  }

  // --- PAGE 3: REVIEWS ---
  Widget _buildReviewContent() {
    final reviews = widget.comparisonData.userReviews ?? "Veri yok.";

    return Column( 
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(_t('user_reviews_summary'), reviews, Icons.people, Colors.orange),
        const SizedBox(height: 30),
        
        Text(_t('for_more'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Image.network("https://tr.motor1.com/favicon.ico", width: 24, height: 24, errorBuilder: (c,e,s)=>const Icon(Icons.public)),
          title: Text(_t('motor1_reviews')),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => _launchMotor1Search("${widget.car1Name} ${widget.car2Name}"),
        ),

        const SizedBox(height: 30),
        // Chatbot Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
             onPressed: _openAiAssistant,
             icon: const Icon(Icons.chat_bubble_outline),
             label: Text(_t('discuss_with_ai')),
             style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFF0059BC),
               foregroundColor: Colors.white,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
             ),
          ),
        ),
      ],
    );
  }

  void _openAiAssistant() {
    String initialPrompt = "";
    if (LanguageService().currentLanguage == 'tr') {
       initialPrompt = """
Motor1.com Editörü gibi davranarak şu iki aracı kıyaslar mısın?

ARAÇ 1: ${widget.car1Name} (Puan: ${widget.comparisonData.scoreA})
ARAÇ 2: ${widget.car2Name} (Puan: ${widget.comparisonData.scoreB})

Teknik Veriler (A vs B):
- Hız: ${widget.comparisonData.radarScoresA[0]} vs ${widget.comparisonData.radarScoresB[0]}
- Konfor: ${widget.comparisonData.radarScoresA[1]} vs ${widget.comparisonData.radarScoresB[1]}
- Teknoloji: ${widget.comparisonData.radarScoresA[2]} vs ${widget.comparisonData.radarScoresB[2]}

Lütfen şunları yap:
1. "tr.motor1.com" verilerine dayanarak bu araçları analiz et.
2. Kronik sorunlarını (Şikayetvar verileri) söyle.
3. İkinci el piyasası hakkında bilgi ver.
4. Sonuç olarak hangisini neden önerdiğini söyle.
    """;
    } else {
       initialPrompt = """
Act like a Motor1.com Editor and compare these two cars:

CAR 1: ${widget.car1Name} (Score: ${widget.comparisonData.scoreA})
CAR 2: ${widget.car2Name} (Score: ${widget.comparisonData.scoreB})

Technical Data (A vs B):
- Speed: ${widget.comparisonData.radarScoresA[0]} vs ${widget.comparisonData.radarScoresB[0]}
- Comfort: ${widget.comparisonData.radarScoresA[1]} vs ${widget.comparisonData.radarScoresB[1]}
- Technology: ${widget.comparisonData.radarScoresA[2]} vs ${widget.comparisonData.radarScoresB[2]}

Please provide:
1. Detailed analysis based on expert data.
2. Chronic issues and common complaints.
3. Used car market overview.
4. Conclusion on which one you recommend and why.
    """;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: AiAssistantScreen(initialPrompt: initialPrompt),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        Text(content, style: TextStyle(fontSize: 15, height: 1.5, color: Theme.of(context).textTheme.bodyMedium?.color)),
      ],
    );
  }

  Widget _buildScoreCard(String name, double score) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: score > 8 ? Colors.green : (score > 6 ? Colors.orange : Colors.red),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              score.toString(), 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
    );
  }

  Widget _buildComparisonBars() {
    return Column(
      children: [
        Text(_t('ai_perf_analysis'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(_t('perf_labels_desc'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          width: double.infinity,
          child: CustomPaint(
            painter: RadarChartPainter(
              scoresA: widget.comparisonData.radarScoresA,
              scoresB: widget.comparisonData.radarScoresB,
              labels: [_t('speed_label'), _t('comfort_label'), _t('tech_label'), _t('fuel_label'), _t('safety_label')],
              colorA: const Color(0xFF0059BC),
              colorB: Colors.redAccent, // Changed to Red for better visibility against Blue
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Legend
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
              _buildLegendItem(widget.car1Name, const Color(0xFF0059BC)),
              const SizedBox(width: 20),
              _buildLegendItem(widget.car2Name, Colors.redAccent),
           ],
        )
      ],
    );
  }

  Widget _buildLegendItem(String name, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(name.split(" ")[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> scoresA;
  final List<double> scoresB;
  final List<String> labels;
  final Color colorA;
  final Color colorB;
  final bool isDark;

  RadarChartPainter({
    required this.scoresA,
    required this.scoresB,
    required this.labels,
    required this.colorA,
    required this.colorB,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 30;
    
    final paintGrid = Paint()
      ..color = isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final paintText = TextPainter(textDirection: TextDirection.ltr);

    // Draw Grid (5 levels)
    for (int i = 1; i <= 5; i++) {
        double r = radius * (i / 5);
        Path path = Path();
        for (int j = 0; j < 5; j++) {
            double angle = (2 * math.pi * j) / 5 - (math.pi / 2);
            double x = center.dx + r * math.cos(angle);
            double y = center.dy + r * math.sin(angle);
            if (j == 0) path.moveTo(x, y);
            else path.lineTo(x, y);
        }
        path.close();
        canvas.drawPath(path, paintGrid);
    }
    
    // Draw Spokes & Labels
    for (int j = 0; j < 5; j++) {
        double angle = (2 * math.pi * j) / 5 - (math.pi / 2);
        double x = center.dx + radius * math.cos(angle);
        double y = center.dy + radius * math.sin(angle);
        canvas.drawLine(center, Offset(x, y), paintGrid);

        // Labels
        double labelX = center.dx + (radius + 20) * math.cos(angle);
        double labelY = center.dy + (radius + 20) * math.sin(angle);
        
        paintText.text = TextSpan(text: labels[j], style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 10));
        paintText.layout();
        paintText.paint(canvas, Offset(labelX - paintText.width / 2, labelY - paintText.height / 2));
    }

    // Draw Data A
    Path pathA = Path();
    for (int j = 0; j < 5; j++) {
        double score = j < scoresA.length ? scoresA[j] : 0;
        double r = radius * (score / 10);
        double angle = (2 * math.pi * j) / 5 - (math.pi / 2);
        double x = center.dx + r * math.cos(angle);
        double y = center.dy + r * math.sin(angle);
        if (j == 0) pathA.moveTo(x, y);
        else pathA.lineTo(x, y);
    }
    pathA.close();
    
    // Increased Opacity for better visibility
    Paint paintA = Paint()..color = colorA.withOpacity(0.5)..style = PaintingStyle.fill;
    Paint paintBorderA = Paint()..color = colorA..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawPath(pathA, paintA);
    canvas.drawPath(pathA, paintBorderA);

    // Draw Data B
    Path pathB = Path();
    for (int j = 0; j < 5; j++) {
        double score = j < scoresB.length ? scoresB[j] : 0;
        double r = radius * (score / 10);
        double angle = (2 * math.pi * j) / 5 - (math.pi / 2);
        double x = center.dx + r * math.cos(angle);
        double y = center.dy + r * math.sin(angle);
        if (j == 0) pathB.moveTo(x, y);
        else pathB.lineTo(x, y);
    }
    pathB.close();

    Paint paintB = Paint()..color = colorB.withOpacity(0.5)..style = PaintingStyle.fill;
    Paint paintBorderB = Paint()..color = colorB..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawPath(pathB, paintB);
    canvas.drawPath(pathB, paintBorderB);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
