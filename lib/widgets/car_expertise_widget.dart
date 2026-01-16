import 'package:flutter/material.dart';

class CarExpertiseWidget extends StatefulWidget {
  final Map<String, String> currentReport;
  final bool isEditable;
  final Function(String partKey, String status)? onPartChanged;

  const CarExpertiseWidget({
    super.key,
    required this.currentReport,
    this.isEditable = false,
    this.onPartChanged,
  });

  @override
  State<CarExpertiseWidget> createState() => _CarExpertiseWidgetState();
}

class _CarExpertiseWidgetState extends State<CarExpertiseWidget> {
  // Enhanced Status Colors & Symbols mapping
  final Map<String, Map<String, dynamic>> _statusConfigs = {
    'original': {'color': Colors.transparent, 'symbol': '✔', 'textColor': Colors.black},
    'local_paint': {'color': Colors.yellow.withValues(alpha: 0.9), 'symbol': 'L', 'textColor': Colors.black},
    'painted': {'color': Colors.indigo.withValues(alpha: 0.8), 'symbol': 'B', 'textColor': Colors.white},
    'changed': {'color': Colors.red.withValues(alpha: 0.9), 'symbol': 'D', 'textColor': Colors.white},
    'sok_tak': {'color': Colors.grey.withValues(alpha: 0.7), 'symbol': 'S', 'textColor': Colors.black},
    'plastic': {'color': Colors.transparent, 'symbol': 'P', 'textColor': Colors.black},
    'folyo': {'color': Colors.blueGrey.withValues(alpha: 0.5), 'symbol': 'F', 'textColor': Colors.white},
    'undefined': {'color': Colors.transparent, 'symbol': '', 'textColor': Colors.transparent},
  };

  void _cycleStatus(String partKey) {
    if (!widget.isEditable) return;

    final currentStatus = widget.currentReport[partKey] ?? 'undefined';
    final statuses = _statusConfigs.keys.where((k) => k != 'undefined').toList()..add('undefined');
    
    int currentIndex = statuses.indexOf(currentStatus);
    String nextStatus = statuses[(currentIndex + 1) % statuses.length];

    widget.onPartChanged?.call(partKey, nextStatus);
  }

  @override
  Widget build(BuildContext context) {
    // Schematic needs to stay white-ish because the base image is likely white/light
    // But the surrounding UI should be dark in dark mode.
    
    return Column(
      children: [
        // ENHANCED LEGEND
        _buildLegend(),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white, // Keep white for the schematic image blend
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
            border: Border.all(color: Colors.grey.withOpacity(0.3)), // Add border for visibility in dark mode
          ),
          child: AspectRatio(
            aspectRatio: 1.0, // New schematic is more square
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                return Stack(
                  children: [
                    // NEW CLEAN SCHEMATIC (V3)
                    Center(
                      child: Image.asset(
                        'assets/images/expertise_schematic_v3.jpg',
                        fit: BoxFit.contain,
                      ),
                    ),

                    // CUSTOM PAINTER FOR SYMBOLS AND OVERLAYS
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CarExpertisePainter(
                          report: widget.currentReport,
                          configs: _statusConfigs,
                        ),
                      ),
                    ),

                    // HOTSPOTS (Bypass refactoring for brevity, identical to original)
                    // CENTER COLUMN (Top-down)
                    _buildHotspot('front_bumper', 0.42, 0.04, 0.16, 0.08, w, h),
                    _buildHotspot('hood', 0.42, 0.22, 0.16, 0.12, w, h),
                    _buildHotspot('roof', 0.42, 0.44, 0.16, 0.20, w, h),
                    _buildHotspot('trunk', 0.42, 0.70, 0.16, 0.12, w, h),
                    _buildHotspot('rear_bumper', 0.42, 0.84, 0.16, 0.08, w, h),

                    // LEFT SIDE
                    _buildHotspot('left_rocker_panel', 0.08, 0.50, 0.06, 0.12, w, h),
                    
                    // Profile Circles
                    _buildHotspot('left_front_fender', 0.15, 0.25, 0.08, 0.10, w, h),
                    _buildHotspot('left_front_door', 0.15, 0.38, 0.08, 0.10, w, h),
                    _buildHotspot('left_b_pillar', 0.15, 0.48, 0.08, 0.10, w, h),
                    _buildHotspot('left_rear_door', 0.15, 0.58, 0.08, 0.10, w, h),
                    _buildHotspot('left_rear_fender', 0.15, 0.74, 0.08, 0.10, w, h),

                    // Corridor Circles
                    _buildHotspot('left_a_pillar', 0.25, 0.30, 0.08, 0.10, w, h), // Moved Left
                    _buildHotspot('left_b_pillar_internal', 0.31, 0.46, 0.08, 0.10, w, h),
                    _buildHotspot('left_c_pillar', 0.31, 0.63, 0.08, 0.10, w, h),

                    // RIGHT SIDE
                    _buildHotspot('right_rocker_panel', 0.86, 0.50, 0.06, 0.12, w, h),

                    // Profile Circles
                    _buildHotspot('right_front_fender', 0.77, 0.25, 0.08, 0.10, w, h),
                    _buildHotspot('right_front_door', 0.77, 0.38, 0.08, 0.10, w, h),
                    _buildHotspot('right_b_pillar', 0.77, 0.48, 0.08, 0.10, w, h),
                    _buildHotspot('right_rear_door', 0.77, 0.58, 0.08, 0.10, w, h),
                    _buildHotspot('right_rear_fender', 0.77, 0.74, 0.08, 0.10, w, h),

                    // Corridor Circles
                    _buildHotspot('right_a_pillar', 0.67, 0.30, 0.08, 0.10, w, h), // Moved Right
                    _buildHotspot('right_b_pillar_internal', 0.61, 0.46, 0.08, 0.10, w, h),
                    _buildHotspot('right_c_pillar', 0.61, 0.63, 0.08, 0.10, w, h),
                  ],
                );
              },
            ),
          ),
        ),

        if (widget.isEditable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Bölgelere dokunarak durumlarını güncelleyin.",
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildHotspot(String key, double l, double t, double width, double height, double screenW, double screenH) {
    return Positioned(
      left: l * screenW,
      top: t * screenH,
      width: width * screenW,
      height: height * screenH,
      child: GestureDetector(
        onTap: () => _cycleStatus(key),
        behavior: HitTestBehavior.opaque,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem(Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black, "ORİJİNAL", "✔"),
          _buildLegendItem(Colors.yellow, "L. BOYALI", "L"),
          _buildLegendItem(Colors.indigo, "BOYALI", "B"),
          _buildLegendItem(Colors.red, "DEĞİŞEN", "D"),
          _buildLegendItem(Colors.grey[400]!, "SÖK TAK", "S"),
          _buildLegendItem(Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black, "PLASTİK", "P"),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String symbol) {
    // For Original and Plastic, we use the color as the text/symbol color, but the circle background should probably be transparent or lightly tinted
    // The original code used Colors.white for Original/Plastic background and black for symbol.
    // In Dark Mode, if we use Theme.cardColor for Legend background, we need visible text.
    
    // Let's refine:
    Color circleBg = color;
    Color symbolColor = Colors.white;
    
    if (label == "ORİJİNAL" || label == "PLASTİK") {
        circleBg = Colors.transparent;
        symbolColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    } else if (label == "SÖK TAK") {
       symbolColor = Colors.black; 
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(symbol, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: symbolColor)),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
      ],
    );
  }
}

class CarExpertisePainter extends CustomPainter {
  final Map<String, String> report;
  final Map<String, Map<String, dynamic>> configs;

  CarExpertisePainter({required this.report, required this.configs});

  static const List<String> _allParts = [
    'front_bumper', 'hood', 'roof', 'trunk', 'rear_bumper',
    'left_front_fender', 'left_front_door', 'left_b_pillar', 'left_rear_door', 'left_rear_fender', 'left_rocker_panel', 
    'left_a_pillar', 'left_b_pillar_internal', 'left_c_pillar',
    'right_front_fender', 'right_front_door', 'right_b_pillar', 'right_rear_door', 'right_rear_fender', 'right_rocker_panel',
    'right_a_pillar', 'right_b_pillar_internal', 'right_c_pillar',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    for (final key in _allParts) {
      final status = report[key] ?? 'original'; // Default to original if missing
      
      if (status == 'undefined') continue;
      final config = configs[status]!;
      
      final path = _getPathForPart(key, w, h);
      if (path != null) {
        // Draw fill color
        final fillPaint = Paint()..color = config['color'];
        canvas.drawPath(path, fillPaint);
      }
      
      // Always draw Symbol in circle (Pillars/Rockers might not have a path)
      _drawSymbol(canvas, key, config, w, h);
    }
  }

  void _drawSymbol(Canvas canvas, String key, Map<String, dynamic> config, double w, double h) {
    final centers = _getCentersForPart(key, w, h);
    if (centers.isEmpty) return;

    final radius = 0.025 * w;
    
    for (final center in centers) {
      // Circle background
      final circlePaint = Paint()
        ..color = config['color'] == Colors.transparent ? Colors.white : config['color']
        ..style = PaintingStyle.fill;
      
      final borderPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawCircle(center, radius, circlePaint);
      canvas.drawCircle(center, radius, borderPaint);

      // Text (Symbol)
      final textPainter = TextPainter(
        text: TextSpan(
          text: config['symbol'],
          style: TextStyle(
            color: config['textColor'],
            fontSize: radius * 1.3,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
      );
    }
  }

  List<Offset> _getCentersForPart(String key, double w, double h) {
    switch (key) {
      // Top Down Column
      case 'front_bumper': return [Offset(0.50 * w, 0.06 * h)];
      case 'hood': return [Offset(0.50 * w, 0.28 * h)];
      case 'roof': return [Offset(0.50 * w, 0.53 * h)];
      case 'trunk': return [Offset(0.50 * w, 0.75 * h)];
      case 'rear_bumper': return [Offset(0.50 * w, 0.87 * h)];

      // Left Side
      case 'left_front_fender': return [Offset(0.18 * w, 0.28 * h)]; // Reverted to near original (was 0.20, orig 0.30)
      case 'left_front_door': return [Offset(0.18 * w, 0.43 * h)];
      case 'left_b_pillar': return [Offset(0.18 * w, 0.53 * h)]; // Profile
      case 'left_rear_door': return [Offset(0.18 * w, 0.63 * h)];
      case 'left_rear_fender': return [Offset(0.18 * w, 0.78 * h)];
      case 'left_rocker_panel': return [Offset(0.11 * w, 0.54 * h)];
      case 'left_a_pillar': return [Offset(0.28 * w, 0.34 * h)]; // Adjusted X
      case 'left_b_pillar_internal': return [Offset(0.34 * w, 0.51 * h)]; // Internal
      case 'left_c_pillar': return [Offset(0.34 * w, 0.68 * h)];

      // Right Side
      case 'right_front_fender': return [Offset(0.82 * w, 0.28 * h)]; // Reverted to near original (was 0.20, orig 0.30)
      case 'right_front_door': return [Offset(0.82 * w, 0.43 * h)];
      case 'right_b_pillar': return [Offset(0.82 * w, 0.53 * h)]; // Profile
      case 'right_rear_door': return [Offset(0.82 * w, 0.63 * h)];
      case 'right_rear_fender': return [Offset(0.82 * w, 0.78 * h)];
      case 'right_rocker_panel': return [Offset(0.89 * w, 0.54 * h)];
      case 'right_a_pillar': return [Offset(0.72 * w, 0.34 * h)]; // Adjusted X
      case 'right_b_pillar_internal': return [Offset(0.66 * w, 0.51 * h)]; // Internal
      case 'right_c_pillar': return [Offset(0.66 * w, 0.68 * h)];

      default: return [];
    }
  }

  Path? _getPathForPart(String key, double w, double h) {
    final path = Path();
    
    switch (key) {
      // CENTER COLUMN (Tighter paths to prevent bleeding)
      case 'front_bumper':
        path.moveTo(0.44 * w, 0.04 * h);
        path.lineTo(0.56 * w, 0.04 * h);
        path.lineTo(0.54 * w, 0.08 * h);
        path.lineTo(0.46 * w, 0.08 * h);
        path.close();
        break;
      case 'hood':
        path.moveTo(0.44 * w, 0.09 * h);
        path.lineTo(0.56 * w, 0.09 * h);
        path.quadraticBezierTo(0.60 * w, 0.10 * h, 0.60 * w, 0.14 * h);
        path.lineTo(0.61 * w, 0.31 * h);
        path.lineTo(0.39 * w, 0.31 * h);
        path.lineTo(0.40 * w, 0.14 * h);
        path.quadraticBezierTo(0.40 * w, 0.10 * h, 0.44 * w, 0.09 * h);
        path.close();
        break;
      case 'roof':
        path.addRect(Rect.fromLTWH(0.40 * w, 0.41 * h, 0.20 * w, 0.22 * h));
        break;
      case 'trunk':
        path.moveTo(0.39 * w, 0.66 * h);
        path.lineTo(0.61 * w, 0.66 * h);
        path.lineTo(0.62 * w, 0.84 * h);
        path.quadraticBezierTo(0.50 * w, 0.86 * h, 0.38 * w, 0.84 * h);
        path.close();
        break;
      case 'rear_bumper':
        path.moveTo(0.44 * w, 0.88 * h);
        path.lineTo(0.56 * w, 0.88 * h);
        path.lineTo(0.58 * w, 0.94 * h);
        path.lineTo(0.42 * w, 0.94 * h);
        path.close();
        break;
      
      // LEFT PROFILE
      case 'left_front_fender':
        path.moveTo(0.12 * w, 0.14 * h); // Extended up to 0.14 (Headlight area)
        path.quadraticBezierTo(0.20 * w, 0.13 * h, 0.23 * w, 0.16 * h);
        path.lineTo(0.23 * w, 0.335 * h);
        path.lineTo(0.12 * w, 0.335 * h);
        path.close();
        break;
      case 'left_front_door':
        path.addRect(Rect.fromLTWH(0.12 * w, 0.375 * h, 0.11 * w, 0.13 * h)); // Shifted to 0.375, height 0.13
        break;
      case 'left_rear_door':
        path.addRect(Rect.fromLTWH(0.12 * w, 0.52 * h, 0.11 * w, 0.19 * h));
        break;
      case 'left_rear_fender':
        path.moveTo(0.12 * w, 0.72 * h);
        path.lineTo(0.23 * w, 0.72 * h);
        path.lineTo(0.23 * w, 0.86 * h);
        path.quadraticBezierTo(0.18 * w, 0.90 * h, 0.12 * w, 0.86 * h);
        path.close();
        break;
      case 'left_rocker_panel':
        // No body fill, only symbol circle via _drawSymbol
        break;

      // RIGHT PROFILE
      case 'right_front_fender':
        path.moveTo(0.88 * w, 0.14 * h); // Extended up to 0.14 (Headlight area)
        path.quadraticBezierTo(0.80 * w, 0.13 * h, 0.77 * w, 0.16 * h);
        path.lineTo(0.77 * w, 0.335 * h);
        path.lineTo(0.88 * w, 0.335 * h);
        path.close();
        break;
      case 'right_front_door':
        path.addRect(Rect.fromLTWH(0.77 * w, 0.375 * h, 0.11 * w, 0.13 * h)); // Shifted to 0.375, height 0.13
        break;
      case 'right_rear_door':
        path.addRect(Rect.fromLTWH(0.77 * w, 0.52 * h, 0.11 * w, 0.19 * h));
        break;
      case 'right_rear_fender':
        path.moveTo(0.88 * w, 0.72 * h);
        path.lineTo(0.77 * w, 0.72 * h);
        path.lineTo(0.77 * w, 0.86 * h);
        path.quadraticBezierTo(0.82 * w, 0.90 * h, 0.88 * w, 0.86 * h);
        path.close();
        break;
      case 'right_rocker_panel':
        // No body fill
        break;

      default:
        return null;
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant CarExpertisePainter oldDelegate) => true;
}
