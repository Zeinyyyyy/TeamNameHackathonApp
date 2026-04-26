import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PERFORMANCE ANALYTICS DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1, color: GrcColors.maroon)),
          const SizedBox(height: 4),
          const Text("Macro-level analysis of institutional evaluation scores.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('evaluations').snapshots(),
                builder: (context, eSnap) {
                  if (!eSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                  return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
                      builder: (context, tSnap) {
                        if (!tSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                        Map<String, String> teacherDepartments = {};
                        for (var doc in tSnap.data!.docs) {
                          final d = doc.data() as Map<String, dynamic>;
                          teacherDepartments[doc.id] = (d['department'] ?? 'Other').toString();
                        }

                        Map<String, List<double>> deptScores = {
                          'College of Computer Studies': [],
                          'College of Business Administration': [],
                          'College of Entrepreneurship': [],
                          'College of Accountancy': [],
                          'College of Education': [],
                        };

                        double totalRawSum = 0;
                        int totalEvals = 0;

                        for (var doc in eSnap.data!.docs) {
                          final d = doc.data() as Map<String, dynamic>;
                          String tId = d['teacherId'] ?? '';
                          String dept = teacherDepartments[tId] ?? 'Other';
                          double rawAvg = (d['rawAverage'] ?? 0).toDouble();

                          if (rawAvg > 0 && deptScores.containsKey(dept)) {
                            totalRawSum += rawAvg;
                            totalEvals++;
                            if (deptScores.containsKey(dept)) {
                              deptScores[dept]!.add(rawAvg);
                            }
                          }
                        }

                        double institutionAvg = totalEvals > 0 ? totalRawSum / totalEvals : 0.0;

                        List<Map<String, dynamic>> chartData = [
                          {'code': 'BSIT', 'name': 'College of Computer Studies', 'avg': 0.0},
                          {'code': 'BSBA', 'name': 'College of Business Administration', 'avg': 0.0},
                          {'code': 'BSE',  'name': 'College of Entrepreneurship', 'avg': 0.0},
                          {'code': 'BSA',  'name': 'College of Accountancy', 'avg': 0.0},
                          {'code': 'BSED', 'name': 'College of Education', 'avg': 0.0},
                        ];

                        double highestScore = 0.0;
                        String topDept = "N/A";
                        double lowestScore = 5.0;
                        String bottomDept = "N/A";

                        for (var data in chartData) {
                          List<double> scores = deptScores[data['name']] ?? [];
                          if (scores.isNotEmpty) {
                            double avg = scores.reduce((a, b) => a + b) / scores.length;
                            data['avg'] = avg;
                            if (avg > highestScore) { highestScore = avg; topDept = data['code']; }
                            if (avg < lowestScore) { lowestScore = avg; bottomDept = data['code']; }
                          }
                        }

                        if (lowestScore == 5.0 && bottomDept == "N/A") lowestScore = 0.0;

                        return Column(
                          children: [
                            // --- TOP METRIC CARDS ---
                            LayoutBuilder(
                              builder: (context, constraints) {
                                bool isMobile = constraints.maxWidth < 700;
                                if (isMobile) {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          _buildSummaryCard("Total Evals", totalEvals.toString(), Icons.assessment, Colors.blue),
                                          const SizedBox(width: 12),
                                          _buildSummaryCard("Inst. Avg", institutionAvg.toStringAsFixed(2), Icons.star, Colors.orange),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _buildSummaryCard("Top College", topDept, Icons.emoji_events, Colors.green),
                                          const SizedBox(width: 12),
                                          _buildSummaryCard("Focus Area", bottomDept, Icons.warning_amber_rounded, Colors.red),
                                        ],
                                      )
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    _buildSummaryCard("Total Evals", totalEvals.toString(), Icons.assessment, Colors.blue),
                                    const SizedBox(width: 16),
                                    _buildSummaryCard("Institution Avg", institutionAvg.toStringAsFixed(2), Icons.star, Colors.orange),
                                    const SizedBox(width: 16),
                                    _buildSummaryCard("Top College", topDept, Icons.emoji_events, Colors.green),
                                    const SizedBox(width: 16),
                                    _buildSummaryCard("Focus Area", bottomDept, Icons.warning_amber_rounded, Colors.red),
                                  ],
                                );
                              }
                            ),
                            const SizedBox(height: 24),

                            // --- PREMIUM BAR CHART ---
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                                decoration: BoxDecoration(
                                    color: GrcColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: GrcColors.border),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("AVERAGE SCORE BY COLLEGE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: GrcColors.textLight)),
                                    const SizedBox(height: 30),
                                    Expanded(
                                      child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Stack(
                                              children: [
                                                // Background Grid Lines
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    _buildGridLine("5.0"),
                                                    _buildGridLine("4.0"),
                                                    _buildGridLine("3.0"),
                                                    _buildGridLine("2.0"),
                                                    _buildGridLine("1.0"),
                                                    _buildGridLine("0.0"),
                                                  ],
                                                ),
                                                // Animated Bars
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: chartData.map((data) {
                                                    double avg = data['avg'];
                                                    double heightRatio = avg / 5.0;
                                                    Color barColor = avg >= 4.0 ? Colors.green : avg >= 3.0 ? Colors.blue : avg > 0 ? Colors.orange : Colors.grey.shade300;
                                                    bool isMobile = constraints.maxWidth < 500;

                                                    return Column(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        Text(avg > 0 ? avg.toStringAsFixed(2) : "N/A", style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10 : 13, color: avg > 0 ? GrcColors.textDark : GrcColors.textLight)),
                                                        const SizedBox(height: 8),
                                                        AnimatedContainer(
                                                          duration: const Duration(milliseconds: 800),
                                                          curve: Curves.easeOut,
                                                          width: isMobile ? (constraints.maxWidth / chartData.length * 0.5) : 60, // Responsive width
                                                          height: (constraints.maxHeight - 60) * heightRatio, // Adjust for text
                                                          decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6))),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(data['code'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10 : 13, color: GrcColors.maroon)),
                                                      ],
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            );
                                          }
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                  );
                }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: GrcColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: GrcColors.textLight, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GrcColors.textDark), overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGridLine(String label) {
    return Row(
      children: [
        SizedBox(width: 25, child: Text(label, style: const TextStyle(fontSize: 10, color: GrcColors.textLight))),
        Expanded(child: Container(height: 1, color: GrcColors.border.withOpacity(0.5))),
      ],
    );
  }
}