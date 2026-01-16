import 'package:flutter/material.dart';
import '../models/car_comparison.dart';

class ResultScreen extends StatelessWidget {
  final String car1;
  final String car2;
  final CarComparison result;

  const ResultScreen({
    super.key,
    required this.car1,
    required this.car2,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analiz Sonucu"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildScoreCard(car1, result.scoreA, result.winner == car1),
                _buildScoreCard(car2, result.scoreB, result.winner == car2),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              "Yapay Zeka Yorumu:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Text(
                result.details,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String carName, double score, bool isWinner) {
    return Column(
      children: [
        Text(
          carName.length > 10 ? "${carName.substring(0, 10)}..." : carName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isWinner ? Colors.green : Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        CircleAvatar(
          radius: 35,
          backgroundColor: isWinner ? Colors.green : Colors.grey.shade300,
          child: Text(
            score.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.white : Colors.black54,
            ),
          ),
        ),
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              "Kazanan!",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
