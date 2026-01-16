import 'package:cloud_firestore/cloud_firestore.dart'; // [NEW] For Timestamp handling
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/car_model.dart';
import '../widgets/car_expertise_widget.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class CarExpertiseScreen extends StatefulWidget {
  final Car car;

  const CarExpertiseScreen({super.key, required this.car});

  @override
  State<CarExpertiseScreen> createState() => _CarExpertiseScreenState();
}

class _CarExpertiseScreenState extends State<CarExpertiseScreen> {
  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Bottom Sheet Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Custom Header
            Container(
              color: isDark ? Colors.grey[900] : Colors.white, // Theme-aware explicit
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    _t('car_details_actions'), // "Araç Detayları" -> "Car Details & Actions" (close enough) or "details"
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: _t('expertise_report')),
                      Tab(text: _t('tramer_text')),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: EXPERTISE REPORT
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: CarExpertiseWidget(
                      currentReport: widget.car.expertiseReport,
                      isEditable: false,
                    ),
                  ),

                  // TAB 2: TRAMER HISTORY
                  _buildTramerTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTramerTab(bool isDark) {
    final tramerRecords = widget.car.tramerRecords;
    
    double totalAmount = 0;
    for (var record in tramerRecords) {
      final isInsVal = record['isInsurance'];
      final bool isInsurance = (isInsVal == true || isInsVal.toString().toLowerCase() == 'true');
      
      if (isInsurance) {
        var amt = record['amount'];
        if (amt is num) {
          totalAmount += amt;
        } else if (amt is String) {
          String cleanAmt = amt.replaceAll('.', '').replaceAll(',', '.'); 
          cleanAmt = cleanAmt.replaceAll(RegExp(r'[^0-9.]'), '');
          totalAmount += double.tryParse(cleanAmt) ?? 0;
        }
      }
    }

    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

    return Container(
      color: isDark ? Colors.grey[900] : const Color(0xFFF9F9F9),
      child: Column(
        children: [
          // SUMMARY CARD
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [Theme.of(context).primaryColor.withOpacity(0.8), Theme.of(context).primaryColor.withOpacity(0.5)]
                    : [const Color(0xFF0059BC), const Color(0xFF007BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF0059BC)).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('total_tramer') + " " + _t('insurance_casco_label'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      currencyFormat.format(totalAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),

          // LIST OF RECORDS
          Expanded(
            child: tramerRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          _t('no_tramer_record'),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tramerRecords.length,
                    itemBuilder: (context, index) {
                      final record = tramerRecords[index];
                      
                      dynamic dateVal = record['date'];
                      String dateStr = _t('unknown');
                      if (dateVal is Timestamp) {
                        dateStr = DateFormat('dd.MM.yyyy').format(dateVal.toDate());
                      } else if (dateVal is String) {
                        dateStr = dateVal;
                      }

                      final desc = record['description'] ?? _t('no_damage_description');
                      
                      final isInsVal = record['isInsurance'];
                      final bool isInsurance = (isInsVal == true || isInsVal.toString().toLowerCase() == 'true');
                      
                      final String pMethod = isInsurance ? (record['paymentMethod'] ?? record['processType'] ?? _t('insurance_casco_type')).toString() : _t('out_of_pocket_type');
                      
                      final amount = record['amount']; 
                      String amountStr = "0 ₺";
                      if (amount is num) {
                         amountStr = currencyFormat.format(amount);
                      } else {
                         amountStr = amount.toString();
                      }
                      
                      final Color iconColor = isInsurance ? Colors.blueAccent : Colors.orangeAccent;
                      final IconData iconData = isInsurance ? Icons.shield : Icons.person;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(iconData, color: iconColor),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          desc,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 15,
                                            color: Theme.of(context).textTheme.bodyLarge?.color
                                          ),
                                        ),
                                      ),
                                      if (!isInsurance)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            _t('out_of_pocket_type').split(' ')[0].toUpperCase(),
                                            style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$dateStr • $pMethod",
                                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              amountStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
