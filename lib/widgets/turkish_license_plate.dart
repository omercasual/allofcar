import 'package:flutter/material.dart';

class TurkishLicensePlate extends StatelessWidget {
  final String plate;
  final double width;
  final double height;
  final double fontSize;

  const TurkishLicensePlate({
    Key? key,
    required this.plate,
    this.width = 200,
    this.height = 50,
    this.fontSize = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Blue Strip (TR)
          Container(
            width: 35,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF003399),
              border: Border(right: BorderSide(color: Colors.black, width: 0)), // Border usually not needed if tight
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                 Text(
                  "TR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
              ],
            ),
          ),
          // Plate Number
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  plate.toUpperCase(),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontFamily: "RobotoMono",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
