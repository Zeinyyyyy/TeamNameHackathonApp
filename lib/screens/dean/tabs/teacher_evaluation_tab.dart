import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

class TeacherEvaluationPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const TeacherEvaluationPage({this.userData, super.key});

  @override
  State<TeacherEvaluationPage> createState() => _TeacherEvaluationPageState();
}

class _TeacherEvaluationPageState extends State<TeacherEvaluationPage> {
  String _selectedFilterDept = 'ALL';
  final List<String> _filterOptions = ['ALL', 'BSIT', 'BSBA', 'BSE', 'BSA', 'BSED'];

  // Semester Filter State
  String _selectedSemester = 'All Semesters';
  final List<String> _semesterOptions = ['All Semesters', 'A.Y. 2025-2026 | 1st Sem', 'A.Y. 2025-2026 | 2nd Sem'];

  final Map<String, String> _chipToDbName = {
    'BSIT': 'College of Computer Studies',
    'BSBA': 'College of Business Administration',
    'BSE': 'College of Entrepreneurship',
    'BSA': 'College of Accountancy',
    'BSED': 'College of Education',
  };

  Color _getStatusColor(double score) {
    if (score == 0) return Colors.grey;
    if (score >= 4.5) return Colors.green;
    if (score >= 3.5) return Colors.blue;
    if (score >= 2.5) return Colors.orange;
    return Colors.red;
  }

  String _getStatusText(double score) {
    if (score == 0) return "UNRATED";
    if (score >= 4.5) return "EXCELLENT";
    if (score >= 3.5) return "GOOD";
    if (score >= 2.5) return "AVERAGE";
    return "POOR";
  }

  Widget _buildStatusBadge(double score) {
    Color color = _getStatusColor(score);
    String text = _getStatusText(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      // 🟢 FIX: Font size bumped from 10 to 11
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
    );
  }

  // Drill-Down Pop-up Logic
  void _showInstructorProfile(Map<String, dynamic> stat) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    List<QueryDocumentSnapshot> evals = stat['evals'];
    double overallScore = stat['score'];

    List<String> comments = [];
    double pedagogyTotal = 0, knowledgeTotal = 0, attendanceTotal = 0;

    for (var e in evals) {
      var data = e.data() as Map<String, dynamic>;
      String? comment = data['comment'] ?? data['feedback'];
      if (comment != null && comment.trim().isNotEmpty) {
        comments.add(comment);
      }
      pedagogyTotal += (data['pedagogy'] ?? data['rawAverage'] ?? 0).toDouble();
      knowledgeTotal += (data['knowledge'] ?? data['rawAverage'] ?? 0).toDouble();
      attendanceTotal += (data['attendance'] ?? data['rawAverage'] ?? 0).toDouble();
    }

    double pedagogyAvg = evals.isNotEmpty ? (pedagogyTotal / evals.length) : 0;
    double knowledgeAvg = evals.isNotEmpty ? (knowledgeTotal / evals.length) : 0;
    double attendanceAvg = evals.isNotEmpty ? (attendanceTotal / evals.length) : 0;

    showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: GrcColors.surface,
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  decoration: const BoxDecoration(
                    color: GrcColors.maroon,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.person, color: GrcColors.maroon, size: 32)),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stat['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            const SizedBox(height: 4),
                            Text("${stat['subject']} • ${stat['department']}", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(overallScore.toStringAsFixed(2), style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, fontSize: 32)),
                          // 🟢 FIX: Font size bumped to 12
                          Text(_getStatusText(overallScore), style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                        ],
                      )
                    ],
                  ),
                ),

                // BODY
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🟢 FIX: Font size bumped to 13
                        const Text("CATEGORY BREAKDOWN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GrcColors.textLight, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        _buildCategoryRow("Subject Knowledge", knowledgeAvg),
                        const SizedBox(height: 12),
                        _buildCategoryRow("Teaching Pedagogy", pedagogyAvg),
                        const SizedBox(height: 12),
                        _buildCategoryRow("Attendance & Professionalism", attendanceAvg),
                        const SizedBox(height: 32),

                        // 🟢 FIX: Font size bumped to 13
                        const Text("RECENT STUDENT COMMENTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GrcColors.textLight, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        comments.isEmpty
                            ? const Text("No written feedback provided yet.", style: TextStyle(color: GrcColors.textLight, fontStyle: FontStyle.italic))
                            : Column(
                          children: comments.map((c) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: GrcColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: GrcColors.border)),
                            child: Text('"$c"', style: const TextStyle(color: GrcColors.textDark, fontStyle: FontStyle.italic, fontSize: 13)),
                          )).toList(),
                        )
                      ],
                    ),
                  ),
                ),

                // FOOTER
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: GrcColors.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE PROFILE", style: TextStyle(color: GrcColors.textLight, fontWeight: FontWeight.bold))),
                    ],
                  ),
                )
              ],
            ),
          ),
        )
    );
  }

  Widget _buildCategoryRow(String label, double score) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textDark, fontSize: 13))),
        Expanded(flex: 3, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: score > 0 ? score / 5.0 : 0, minHeight: 8, backgroundColor: GrcColors.background, valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(score))))),
        const SizedBox(width: 16),
        SizedBox(width: 40, child: Text(score.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _getStatusColor(score)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("INSTRUCTOR LEADERBOARD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
                  SizedBox(height: 6),
                  // 🟢 FIX: Font size bumped to 13
                  Text("A comprehensive view of all instructors, including those pending evaluation.", style: TextStyle(fontSize: 13, color: GrcColors.textLight)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: GrcColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSemester,
                    icon: const Icon(Icons.calendar_today, size: 16, color: GrcColors.maroon),
                    // 🟢 FIX: Font size bumped to 13
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GrcColors.maroon),
                    items: _semesterOptions.map((e) => DropdownMenuItem(value: e, child: Padding(padding: const EdgeInsets.only(right: 16), child: Text(e)))).toList(),
                    onChanged: (val) => setState(() => _selectedSemester = val!),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((course) {
                bool isSelected = _selectedFilterDept == course;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    // 🟢 FIX: Font size bumped to 12
                    label: Text(course, style: TextStyle(color: isSelected ? GrcColors.gold : GrcColors.textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                    selected: isSelected,
                    selectedColor: GrcColors.maroon,
                    backgroundColor: GrcColors.surface,
                    showCheckmark: isSelected,
                    checkmarkColor: GrcColors.gold,
                    side: BorderSide(color: isSelected ? GrcColors.maroon : GrcColors.border),
                    onSelected: (bool selected) => setState(() => _selectedFilterDept = course),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('evaluations').snapshots(),
                  builder: (context, evalSnap) {
                    if (!evalSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
                        builder: (context, teacherSnap) {
                          if (!teacherSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                          List<Map<String, dynamic>> instructorStats = [];
                          int exc = 0, good = 0, avg = 0, poor = 0, unrated = 0;

                          for (var teacherDoc in teacherSnap.data!.docs) {
                            var tData = teacherDoc.data() as Map<String, dynamic>;
                            String tDept = (tData['department'] ?? '').toString();
                            if (_selectedFilterDept != 'ALL' && tDept != _chipToDbName[_selectedFilterDept]) continue;

                            var teacherEvals = evalSnap.data!.docs.where((e) {
                              var eData = e.data() as Map<String, dynamic>;
                              bool matchesTeacher = eData['teacherId'] == teacherDoc.id;

                              String evalSem = eData['semester'] ?? 'All Semesters';
                              bool matchesSemester = _selectedSemester == 'All Semesters' || evalSem == _selectedSemester;

                              return matchesTeacher && matchesSemester;
                            }).toList();

                            double studentTotal = 0, phTotal = 0, deanTotal = 0;
                            int studentCount = 0, phCount = 0, deanCount = 0;

                            for (var eval in teacherEvals) {
                              var eData = eval.data() as Map<String, dynamic>;
                              double raw = (eData['rawAverage'] ?? 0).toDouble();
                              String role = eData['role'] ?? 'STUDENT';
                              
                              if (role == 'STUDENT') { studentTotal += raw; studentCount++; }
                              else if (role == 'PROGRAM HEAD') { phTotal += raw; phCount++; }
                              else if (role == 'DEAN') { deanTotal += raw; deanCount++; }
                            }

                            double studentAvg = studentCount > 0 ? studentTotal / studentCount : 0;
                            double phAvg = phCount > 0 ? phTotal / phCount : 0;
                            double deanAvg = deanCount > 0 ? deanTotal / deanCount : 0;

                            double finalAverage = 0;
                            double totalWeight = 0;

                            if (studentCount > 0) { finalAverage += studentAvg * 0.50; totalWeight += 0.50; }
                            if (phCount > 0) { finalAverage += phAvg * 0.30; totalWeight += 0.30; }
                            if (deanCount > 0) { finalAverage += deanAvg * 0.20; totalWeight += 0.20; }

                            if (totalWeight > 0) {
                              finalAverage = finalAverage / totalWeight; // Normalize to available weights
                            }

                            if (finalAverage == 0) unrated++;
                            else if (finalAverage >= 4.5) exc++;
                            else if (finalAverage >= 3.5) good++;
                            else if (finalAverage >= 2.5) avg++;
                            else poor++;

                            instructorStats.add({
                              'name': tData['name'] ?? 'Unknown',
                              'department': tDept.isEmpty ? 'No Department' : tDept,
                              'subject': tData['subject'] ?? '',
                              'score': finalAverage,
                              'evalCount': teacherEvals.length,
                              'evals': teacherEvals,
                            });
                          }

                          instructorStats.sort((a, b) => b['score'].compareTo(a['score']));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatChip(Colors.green, exc, "EXCELLENT"),
                                  _buildStatChip(Colors.blue, good, "GOOD"),
                                  _buildStatChip(Colors.orange, avg, "AVERAGE"),
                                  _buildStatChip(Colors.red, poor, "POOR"),
                                  _buildStatChip(Colors.grey, unrated, "UNRATED"),
                                ],
                              ),
                              const SizedBox(height: 24),

                              Container(
                                height: 230,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: GrcColors.border)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🟢 FIX: Font size bumped to 12
                                    const Text("TOP RATED INSTRUCTORS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GrcColors.textLight, letterSpacing: 1)),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: instructorStats.take(5).map((stat) {
                                            double height = stat['score'] > 0 ? (stat['score'] / 5.0) * 100 : 5;
                                            Color barColor = _getStatusColor(stat['score']);
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  // 🟢 FIX: Font size bumped to 12
                                                  Text(stat['score'].toStringAsFixed(2), style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                  const SizedBox(height: 6),
                                                  Container(width: 45, height: height, decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))),
                                                  const SizedBox(height: 8),
                                                  // 🟢 FIX: The "Long Name Break" fix using SizedBox and TextOverflow.ellipsis
                                                  SizedBox(
                                                    width: 55, // Match bar width so it doesn't spill over
                                                    child: Text(
                                                      stat['name'].toString().split(' ').first,
                                                      style: const TextStyle(fontSize: 11, color: GrcColors.textDark, fontWeight: FontWeight.bold),
                                                      textAlign: TextAlign.center,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: GrcColors.border, thickness: 1.5),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 900,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: GrcColors.surface,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: GrcColors.border),
                                          ),
                                          child: Row(
                                            children: const [
                                              // 🟢 FIX: Font sizes for headers bumped from 10 to 11
                                              SizedBox(width: 50, child: Text("RANK", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1))),
                                              Expanded(flex: 3, child: Text("INSTRUCTOR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1))),
                                              Expanded(flex: 3, child: Text("PERFORMANCE GAUGE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1))),
                                              SizedBox(width: 60, child: Text("SCORE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1), textAlign: TextAlign.center)),
                                              SizedBox(width: 90, child: Text("STATUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1), textAlign: TextAlign.center)),
                                              SizedBox(width: 50, child: Text("EVALS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1), textAlign: TextAlign.center)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            padding: const EdgeInsets.only(top: 8),
                                            itemCount: instructorStats.length,
                                            itemBuilder: (context, index) {
                                              var stat = instructorStats[index];
                                              double score = stat['score'];
                                              Widget rankWidget;
                                              if (index == 0 && score > 0) rankWidget = Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle), child: const Text("🥇", style: TextStyle(fontSize: 18)));
                                              else if (index == 1 && score > 0) rankWidget = Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), shape: BoxShape.circle), child: const Text("🥈", style: TextStyle(fontSize: 18)));
                                              else if (index == 2 && score > 0) rankWidget = Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.brown.withOpacity(0.2), shape: BoxShape.circle), child: const Text("🥉", style: TextStyle(fontSize: 18)));
                                              else rankWidget = Padding(padding: const EdgeInsets.all(8.0), child: Text("#${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textLight, fontSize: 16)));

                                              return Card(
                                                margin: const EdgeInsets.only(bottom: 12),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: GrcColors.border)),
                                                color: GrcColors.surface,
                                                child: InkWell(
                                                  onTap: () => _showInstructorProfile(stat),
                                                  borderRadius: BorderRadius.circular(8),
                                                  hoverColor: GrcColors.maroon.withOpacity(0.05),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                    child: Row(
                                                      children: [
                                                        SizedBox(width: 50, child: rankWidget),
                                                        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                          Text(stat['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.textDark)),
                                                          const SizedBox(height: 4),
                                                          Text("${stat['subject']} • ${stat['department']}", style: const TextStyle(fontSize: 12, color: GrcColors.textLight)),
                                                        ])),
                                                        Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 30), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: score > 0 ? score / 5.0 : 0, minHeight: 10, backgroundColor: GrcColors.background, valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(score)))))),
                                                        SizedBox(width: 60, child: Text(score.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _getStatusColor(score)), textAlign: TextAlign.center)),
                                                        SizedBox(width: 90, child: Center(child: _buildStatusBadge(score))),
                                                        SizedBox(width: 50, child: Text(stat['evalCount'].toString(), style: const TextStyle(color: GrcColors.textLight, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            ],
                          );
                        }
                    );
                  }
              )
          )
        ],
      ),
    );
  }

  Widget _buildStatChip(Color color, int count, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: GrcColors.border)),
      // 🟢 FIX: Font size bumped from 10 to 11
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 10, color: color), const SizedBox(width: 8), Text("$count $label", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))]),
    );
  }
}