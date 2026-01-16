import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class AdminCarListScreen extends StatelessWidget {
  const AdminCarListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tüm Araçlar (Garajlar)"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getAllCars(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }

          final cars = snapshot.data?.docs ?? [];
          if (cars.isEmpty) {
            return const Center(child: Text("Sistemde kayıtlı araç yok."));
          }

          return ListView.builder(
            itemCount: cars.length,
            itemBuilder: (context, index) {
              final data = cars[index].data() as Map<String, dynamic>;
              final String brand = data['brand'] ?? '-';
              final String model = data['model'] ?? '-';
              final String series = data['series'] ?? '';
              final int? year = data['year'];
              final String plate = data['plate'] ?? 'Plakasız';
              
              Timestamp? createdAt = data['createdAt'];
              String dateStr = createdAt != null 
                  ? DateFormat("dd MMM yyyy").format(createdAt.toDate()) 
                  : "-";

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orangeAccent,
                  child: Icon(Icons.directions_car, color: Colors.white),
                ),
                title: Text("$brand $model $series ($year)"),
                subtitle: Text("Plaka: $plate\nKayıt: $dateStr"),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
