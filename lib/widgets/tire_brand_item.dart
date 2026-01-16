import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'brand_logo.dart';

class TireBrandItem extends StatelessWidget {
  final String brandName;
  final String logoUrl;
  final VoidCallback onTap;
  final double size;

  const TireBrandItem({
    super.key,
    required this.brandName,
    required this.logoUrl,
    required this.onTap,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Increased rim size ratio to make logo bigger
    final double rimRatio = 0.82; 
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom Tire Paint
                CustomPaint(
                  size: Size(size, size),
                  painter: TirePainter(
                    tireColor: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF222222), 
                  ),
                ),
                
                // Inner Rim Circle
                Container(
                  width: size * rimRatio, 
                  height: size * rimRatio,
                  decoration: BoxDecoration(
                    // User requested dark grey background for inner circle in dark mode (like oil brands)
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  ),
                  alignment: Alignment.center,
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      // Increased logo size
                      child: BrandLogo(logoUrl: logoUrl, size: size * 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size + 10,
          child: Text(
            brandName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }
}

class TirePainter extends CustomPainter {
  final Color tireColor;

  TirePainter({required this.tireColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = size.width / 2;
    final double innerRadius = outerRadius * 0.75; // Where the treads start
    
    final Paint paint = Paint()
      ..color = tireColor 
      ..style = PaintingStyle.fill;

    final Path path = Path();
    
    // Draw the main body (inner circle)
    // We'll add the treads to this path so it's one solid shape
    
    const int treadCount = 16; // Matches the chunky look of the reference
    const double anglePerTread = (2 * math.pi) / treadCount;
    // The tread block occupies about 60% of the angle, gap is 40%
    const double treadOccupancy = 0.65; 
    
    for (int i = 0; i < treadCount; i++) {
      double startAngle = i * anglePerTread;
      double endAngle = (i + 1) * anglePerTread;
      
      // Calculate block angles
      double blockCenterAngle = startAngle + (anglePerTread / 2);
      double halfBlockAngle = (anglePerTread * treadOccupancy) / 2;
      
      double angle1 = blockCenterAngle - halfBlockAngle;
      double angle2 = blockCenterAngle + halfBlockAngle;
      
      // Outer points (Tips of treads)
      Offset outer1 = Offset(
        center.dx + outerRadius * math.cos(angle1),
        center.dy + outerRadius * math.sin(angle1),
      );
      Offset outer2 = Offset(
        center.dx + outerRadius * math.cos(angle2),
        center.dy + outerRadius * math.sin(angle2),
      );
      
      // Inner points (Base of treads)
      Offset inner1 = Offset(
        center.dx + innerRadius * math.cos(angle1),
        center.dy + innerRadius * math.sin(angle1),
      );
      Offset inner2 = Offset(
        center.dx + innerRadius * math.cos(angle2),
        center.dy + innerRadius * math.sin(angle2),
      );
      
      // Base points in the "gap"
      Offset gapStart = Offset(
        center.dx + innerRadius * math.cos(angle2),
        center.dy + innerRadius * math.sin(angle2),
      );
      Offset gapEnd = Offset(
        center.dx + innerRadius * math.cos(endAngle - ((anglePerTread * (1-treadOccupancy))/2)), // Approximate next start
        center.dy + innerRadius * math.sin(endAngle),
      );

      if (i == 0) {
        path.moveTo(inner1.dx, inner1.dy);
      } else {
        // Line from previous tread end to this tread start (gap)
        // We draw the arc for the gap
         path.arcToPoint(inner1, radius: Radius.circular(innerRadius), clockwise: true);
      }
      
      path.lineTo(outer1.dx, outer1.dy);
      path.lineTo(outer2.dx, outer2.dy);
      path.lineTo(inner2.dx, inner2.dy);
    }
    
    path.close();
    
    // Draw the Outer rugged shape
    canvas.drawPath(path, paint);

    // Draw the "Sidewall" detail - a slightly lighter ring inside
    final Paint sidewallPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
      
    canvas.drawCircle(center, innerRadius * 0.9, sidewallPaint);

    // Draw a decorative "Rim" border to visually separate tire from the white logo container
    final Paint rimBorderPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;
      
    // This fills the hole where the white container will sit, 
    // effectively creating a background for it if there's any gap.
    canvas.drawCircle(center, innerRadius * 0.95, rimBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
