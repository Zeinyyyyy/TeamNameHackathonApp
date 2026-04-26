import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/grc_theme.dart';

class FeedbackDetailScreen extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final String subjectDept;

  const FeedbackDetailScreen({
    required this.teacherId,
    required this.teacherName,
    required this.subjectDept,
    super.key,
  });

  // 🟢 NEW: Moderation Logic
  void _flagComment(BuildContext context, String evalId) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            backgroundColor: GrcColors.surface,
            title: const Text("Flag Comment?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: const Text("This will permanently hide this comment from all dashboards. Proceed?", style: TextStyle(color: GrcColors.textDark)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: GrcColors.textLight, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(ctx);

                  // 1. Update the evaluation to hide it
                  await FirebaseFirestore.instance.collection('evaluations').doc(evalId).update({
                    'isFlagged': true
                  });

                  // 2. Log the moderation action
                  await FirebaseFirestore.instance.collection('audit_logs').add({
                    'action': 'Moderated (Flagged) abusive comment for instructor: $teacherName',
                    'user': 'Dean',
                    'date': DateTime.now().toString(),
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comment flagged and hidden successfully."), backgroundColor: Colors.orange));
                  }
                },
                child: const Text("FLAG & HIDE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: GrcColors.background,
      appBar: AppBar(
        backgroundColor: GrcColors.maroon,
        title: const Text("ANONYMOUS FEEDBACK", style: TextStyle(color: GrcColors.gold, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: GrcColors.gold),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- INSTRUCTOR HEADER ---
            Row(
              children: [
                CircleAvatar(
                    radius: 36,
                    backgroundColor: GrcColors.maroon.withOpacity(0.1),
                    child: const Icon(Icons.person, color: GrcColors.maroon, size: 36)
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacherName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GrcColors.textDark)),
                      const SizedBox(height: 4),
                      Text(subjectDept, style: const TextStyle(fontSize: 13, color: GrcColors.textLight)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: GrcColors.border),
            const SizedBox(height: 16),
            const Text("WRITTEN COMMENTS", style: TextStyle(fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1)),
            const SizedBox(height: 16),

            // --- FEEDBACK LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('evaluations')
                    .where('teacherId', isEqualTo: teacherId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                  // 🟢 FIX: Filter to show evaluations that have text AND are NOT flagged
                  var feedbacks = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String comment = (data['comment'] ?? '').toString().trim();
                    bool isFlagged = data['isFlagged'] ?? false; // Default to false if missing

                    return comment.isNotEmpty && !isFlagged;
                  }).toList();

                  if (feedbacks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 60, color: GrcColors.border.withOpacity(0.8)),
                          const SizedBox(height: 16),
                          const Text("No written comments available.", style: TextStyle(color: GrcColors.textLight)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: feedbacks.length,
                    itemBuilder: (context, index) {
                      var doc = feedbacks[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String evalId = doc.id;

                      return Card(
                        color: GrcColors.surface,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: GrcColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.format_quote_rounded, color: Colors.orange, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  data['comment'] ?? '',
                                  style: const TextStyle(fontSize: 14, color: GrcColors.textDark, height: 1.6, fontStyle: FontStyle.italic),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 🟢 NEW: The Moderation Flag Button
                              IconButton(
                                tooltip: "Flag & Hide Abusive Comment",
                                icon: const Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                                onPressed: () => _flagComment(context, evalId),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}