import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import '../widgets/translatable_text.dart';

class FaultHistoryScreen extends StatelessWidget {
  final String? carId;

  const FaultHistoryScreen({super.key, this.carId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(_t('login_required'))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(carId != null ? _t('fault_history_car') : _t('fault_history_mine'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0059BC),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: carId != null 
            ? firestoreService.getFaultLogsForCar(user.uid, carId!)
            : firestoreService.getFaultLogs(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("${_t('error')}: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0059BC)));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(_t('no_fault_logs'), style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final date = log['timestamp'] != null 
                  ? (log['timestamp'] as Timestamp).toDate() 
                  : DateTime.now();
              final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(date);
              final carName = log['carName'] ?? _t('general_vehicle');
              final problem = log['problem'] ?? (log['hasImage'] == true ? _t('photo_analysis') : _t('not_specified'));
              final imageUrl = log['imageUrl'] as String?;

              return Card(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
                surfaceTintColor: Colors.transparent,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.05),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FaultDetailScreen(log: log)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image / Icon
                        Hero(
                          tag: 'fault_img_${log['id']}',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0059BC).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              image: imageUrl != null 
                                ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                : null,
                            ),
                            child: imageUrl == null 
                                ? const Icon(Icons.build_circle, color: Color(0xFF0059BC), size: 32)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                carName, 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                problem, 
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dateStr, 
                                style: TextStyle(fontSize: 12, color: Colors.grey[500])
                              ),
                            ],
                          ),
                        ),
                        
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(_t('delete_confirm_title')),
                                content: Text(_t('delete_confirm_msg')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cancel'))),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (user.uid.isNotEmpty && log['id'] != null) {
                                        firestoreService.deleteFaultLog(user.uid, log['id']);
                                      }
                                    },
                                    child: Text(_t('delete'), style: const TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FaultDetailScreen extends StatefulWidget {
  final Map<String, dynamic> log;
  final File? localImage;

  const FaultDetailScreen({super.key, required this.log, this.localImage});

  @override
  State<FaultDetailScreen> createState() => _FaultDetailScreenState();
}

class _FaultDetailScreenState extends State<FaultDetailScreen> {
  bool? _isUseful; // null=not selected, true=useful, false=not useful
  bool _isLoadingFeedback = false;
  final TextEditingController _correctionController = TextEditingController();

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  void initState() {
    super.initState();
    // Load existing feedback if available (assuming log is updated or passed correctly)
    // Note: If we just created the log, these are null.
    if (widget.log.containsKey('isUseful')) {
      _isUseful = widget.log['isUseful'];
    }
  }

  @override
  void dispose() {
    _correctionController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback(bool isUseful, {String? correction}) async {
    final user = FirebaseAuth.instance.currentUser;
    final logId = widget.log['id']; // Firestore ID

    if (user == null || logId == null) {
      debugPrint("User or Log ID missing for feedback. User: $user, LogID: $logId");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('error_no_id'))));
      return;
    }

    setState(() => _isLoadingFeedback = true);

    try {
      await FirestoreService().updateFaultFeedback(
        user.uid, 
        logId, 
        isUseful, 
        correction: correction
      );
      
      if (mounted) {
        setState(() {
          _isUseful = isUseful;
          _isLoadingFeedback = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(isUseful ? _t('feedback_thanks') : _t('feedback_received_fix')),
             backgroundColor: isUseful ? Colors.green : Colors.orange,
           )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  Future<void> _undoFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    final logId = widget.log['id'];

    if (user == null || logId == null) return;

    setState(() => _isLoadingFeedback = true);

    try {
      await FirestoreService().resetFaultFeedback(user.uid, logId);
      
      if (mounted) {
        setState(() {
          _isUseful = null;
          _isLoadingFeedback = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(_t('feedback_undone')))
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  void _showNotUsefulDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.thumb_down_rounded, color: Colors.deepOrange, size: 32),
              ),
              const SizedBox(height: 16),
              
              Text(
                _t('feedback_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              
              Text(
                _t('feedback_reason_q'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              
                // Input Field
              TextField(
                controller: _correctionController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _t('feedback_contact_hint'),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50], // Very light grey
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder( // Explicit border for visibility if desired, or keep none
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0059BC), width: 1.5),
                  ),
                ),
                maxLines: 4,
              ),
              
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_t('cancel'), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submitFeedback(false, correction: _correctionController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0059BC), // App Blue
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_t('send'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.log['timestamp'] != null 
        ? (widget.log['timestamp'] as Timestamp).toDate() 
        : DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(date);
    final carName = widget.log['carName'] ?? _t('general_vehicle');
    final problem = widget.log['problem'] ?? "-";
    final result = widget.log['aiResponse'] ?? _t('no_content');
    final imageUrl = widget.log['imageUrl'] as String?;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('analysis_detail'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0059BC),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Display (Network OR Local)
            if (imageUrl != null || widget.localImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Hero(
                    tag: 'fault_img_${widget.log['id'] ?? "temp"}',
                    child: widget.localImage != null 
                      ? Image.file(widget.localImage!, fit: BoxFit.cover)
                      : Image.network(imageUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),

            Row(
              children: [
                const Icon(Icons.directions_car, color: Color(0xFF0059BC)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    carName, 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(dateStr, style: TextStyle(color: Colors.grey[600])),
            const Divider(height: 30),

            Text(_t('problem_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0059BC))),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[50], // Adaptive grey50
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TranslatableText(problem, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),

            Text("📝 ${_t('usta_view')}:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: TranslatableText(result, style: const TextStyle(height: 1.6, fontSize: 15)),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 10),
            
            // --- FEEDBACK SECTION ---
            if (_isUseful == null && !_isLoadingFeedback)
              Column(
                children: [
                  Text(_t('useful_q'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _submitFeedback(true),
                        icon: const Icon(Icons.thumb_up, color: Colors.white),
                        label: Text(_t('useful_yes'), style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showNotUsefulDialog,
                        icon: const Icon(Icons.thumb_down, color: Colors.white),
                        label: Text(_t('useful_no'), style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      ),
                    ],
                  ),
                ],
              )
            else if (_isLoadingFeedback)
              const Center(child: CircularProgressIndicator())
            else
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: _isUseful! ? Colors.green.shade50 : Colors.red.shade50,
                   borderRadius: BorderRadius.circular(10),
                   border: Border.all(color: _isUseful! ? Colors.green : Colors.red),
                 ),
                 child: Row(
                   children: [
                     Icon(_isUseful! ? Icons.check_circle : Icons.info, color: _isUseful! ? Colors.green : Colors.red),
                     const SizedBox(width: 10),
                     Text(
                       _isUseful! ? _t('thanks') : _t('feedback_received'),
                       style: TextStyle(color: _isUseful! ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold),
                     ),
                     const Spacer(),
                     TextButton(
                        onPressed: _undoFeedback,
                        child: Text(_t('undo'), style: TextStyle(color: _isUseful! ? Colors.green.shade900 : Colors.red.shade900, decoration: TextDecoration.underline)),
                     )
                   ],
                 ),
               ),
              const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
