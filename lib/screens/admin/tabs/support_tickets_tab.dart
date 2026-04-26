import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

/// [SupportTicketsTab] fetches and displays a real-time list of issues 
/// reported by students or staff (e.g., bugs, missing professors). 
/// It allows the System Admin to review these issues and mark them as resolved.
class SupportTicketsTab extends StatelessWidget {
  const SupportTicketsTab({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("STUDENT SUPPORT TICKETS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1, color: GrcColors.maroon)),
          const SizedBox(height: 6),
          const Text("Review and resolve issues reported by students (e.g., missing instructors, bugs).", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 32),

          if (!isMobile)
            Container(
                color: GrcColors.maroon,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text("STUDENT INFO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrcColors.gold, letterSpacing: 1))),
                      Expanded(flex: 2, child: Text("ISSUE TYPE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrcColors.gold, letterSpacing: 1))),
                      Expanded(flex: 4, child: Text("DESCRIPTION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrcColors.gold, letterSpacing: 1))),
                      SizedBox(width: 100, child: Text("STATUS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrcColors.gold, letterSpacing: 1), textAlign: TextAlign.center))
                    ]
                )
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reported_issues').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                  var issues = snapshot.data!.docs;

                  if (issues.isEmpty) {
                    return const Center(child: Text("No issues have been reported. Everything is running smoothly!", style: TextStyle(color: GrcColors.textLight)));
                  }

                  return ListView.separated(
                      itemCount: issues.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: GrcColors.border),
                      itemBuilder: (context, i) {
                        var doc = issues[i];
                        var d = doc.data() as Map<String, dynamic>;

                        bool isResolved = d['status'] == 'Resolved';
                        Color statusColor = isResolved ? Colors.green : Colors.red;

                        // Safely format the date
                        String dateStr = "Recent";
                        if (d['timestamp'] != null) {
                          DateTime dt = (d['timestamp'] as Timestamp).toDate();
                          dateStr = "${dt.month}/${dt.day}/${dt.year}";
                        }

                        if (isMobile) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: GrcColors.border)),
                            color: GrcColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(d['studentName']?.toString().toUpperCase() ?? 'UNKNOWN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.textDark)),
                                            const SizedBox(height: 4),
                                            Text("${d['studentId']} • Sec: ${d['section']}", style: const TextStyle(fontSize: 12, color: GrcColors.textLight)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(d['type'] ?? 'General', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(d['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 13, color: GrcColors.textDark, height: 1.4)),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(dateStr, style: const TextStyle(fontSize: 11, color: GrcColors.maroon, fontWeight: FontWeight.bold)),
                                      isResolved
                                          ? Row(
                                              children: const [
                                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                                SizedBox(width: 4),
                                                Text("RESOLVED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            )
                                          : ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: GrcColors.maroon,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                                              ),
                                              onPressed: () {
                                                FirebaseFirestore.instance.collection('reported_issues').doc(doc.id).update({'status': 'Resolved'});
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue marked as resolved!"), backgroundColor: Colors.green));
                                              },
                                              child: const Text("RESOLVE", style: TextStyle(color: GrcColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        }

                        return Container(
                          color: i.isEven ? GrcColors.surface : GrcColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d['studentName']?.toString().toUpperCase() ?? 'UNKNOWN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GrcColors.textDark)),
                                    const SizedBox(height: 2),
                                    Text("${d['studentId']} • Sec: ${d['section']}", style: const TextStyle(fontSize: 11, color: GrcColors.textLight)),
                                    const SizedBox(height: 4),
                                    Text(dateStr, style: const TextStyle(fontSize: 10, color: GrcColors.maroon)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(d['type'] ?? 'General', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(d['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 12, color: GrcColors.textDark, height: 1.4)),
                              ),
                              SizedBox(
                                width: 100,
                                child: isResolved
                                    ? const Column(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                                    SizedBox(height: 4),
                                    Text("RESOLVED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                )
                                    : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: GrcColors.maroon,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                                  ),
                                  onPressed: () {
                                    FirebaseFirestore.instance.collection('reported_issues').doc(doc.id).update({'status': 'Resolved'});
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue marked as resolved!"), backgroundColor: Colors.green));
                                  },
                                  child: const Text("RESOLVE", style: TextStyle(color: GrcColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              )
                            ],
                          ),
                        );
                      }
                  );
                }
            ),
          )
        ],
      ),
    );
  }
}