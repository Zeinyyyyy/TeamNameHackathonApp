import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../theme/grc_theme.dart';

class EvaluationStatistics extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EvaluationStatistics({required this.userData, super.key});
  @override
  State<EvaluationStatistics> createState() => _EvaluationStatisticsState();
}

class _EvaluationStatisticsState extends State<EvaluationStatistics> {
  String? _selectedCourse;
  String? _selectedYear = '1';
  String? _selectedSection;

  bool _isNudging = false;
  bool _isExporting = false;

  final Map<String, String> collegeToCode = {
    'College of Business Administration': 'BSBA',
    'College of Entrepreneurship': 'BSE',
    'College of Accountancy': 'BSA',
    'College of Education': 'BSED',
    'College of Computer Studies': 'BSIT',
  };

  // --- REAL CSV EXPORT FUNCTION ---
  Future<void> _exportReport() async {
    if (_selectedSection == null) return;
    setState(() => _isExporting = true);

    try {
      // 1. Get assigned teachers
      var sectionDoc = await FirebaseFirestore.instance.collection('section_assignments').doc(_selectedSection).get();
      List assignedTeachers = sectionDoc.exists ? (sectionDoc.data()?['teacherIds'] ?? []) : [];
      int assignedCount = assignedTeachers.length;

      // 2. Get students in this section
      var allStudentsSnap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'STUDENT').get();
      
      // Filter locally to handle "303" vs "BSIT - 303" and irregular subjects
      var studentsDocs = allStudentsSnap.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String sSec = (data['section'] ?? '').toString();
        List subjects = data['enrolled_subjects'] ?? [];

        bool mainMatch = sSec.isNotEmpty && (_selectedSection == sSec || _selectedSection!.endsWith(sSec));
        bool subjectMatch = subjects.any((s) {
          String subSec = (s['section'] ?? '').toString();
          return subSec.isNotEmpty && (_selectedSection == subSec || _selectedSection!.endsWith(subSec));
        });

        return mainMatch || subjectMatch;
      }).toList();

      String csvData = "Student Name,Student ID,Section,Status,Progress\n";

      // 3. Calculate accurate progress for each student
      for (var student in studentsDocs) {
        var evalSnap = await FirebaseFirestore.instance.collection('evaluations').where('evaluatorId', isEqualTo: student['id']).get();
        int doneCount = 0;
        for (var eval in evalSnap.docs) {
          if (assignedTeachers.contains(eval['teacherId'])) doneCount++;
        }

        String status = doneCount >= assignedCount && assignedCount > 0 ? "COMPLETED" : "PENDING";
        csvData += "\"${student['name']}\",\"${student['id']}\",\"$_selectedSection\",\"$status\",\"$doneCount / $assignedCount\"\n";
      }

      // 4. Download file
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "Status_Report_$_selectedSection.csv")
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Downloaded Successfully!"), backgroundColor: Colors.green));
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red));
    }
    setState(() => _isExporting = false);
  }

  // --- REAL EMAIL NUDGE FUNCTION ---
  Future<void> _nudgePending() async {
    if (_selectedSection == null) return;
    setState(() => _isNudging = true);

    try {
      var sectionDoc = await FirebaseFirestore.instance.collection('section_assignments').doc(_selectedSection).get();
      List assignedTeachers = sectionDoc.exists ? (sectionDoc.data()?['teacherIds'] ?? []) : [];
      int assignedCount = assignedTeachers.length;

      if (assignedCount == 0) throw "No instructors are assigned to this section yet.";

      var allStudentsSnap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'STUDENT').get();
      var studentsDocs = allStudentsSnap.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String sSec = (data['section'] ?? '').toString();
        List subjects = data['enrolled_subjects'] ?? [];

        bool mainMatch = sSec.isNotEmpty && (_selectedSection == sSec || _selectedSection!.endsWith(sSec));
        bool subjectMatch = subjects.any((s) {
          String subSec = (s['section'] ?? '').toString();
          return subSec.isNotEmpty && (_selectedSection == subSec || _selectedSection!.endsWith(subSec));
        });

        return mainMatch || subjectMatch;
      }).toList();

      List<String> emailsToNudge = [];

      for (var student in studentsDocs) {
        var evalSnap = await FirebaseFirestore.instance.collection('evaluations').where('evaluatorId', isEqualTo: student['id']).get();
        int doneCount = 0;
        for (var eval in evalSnap.docs) {
          if (assignedTeachers.contains(eval['teacherId'])) doneCount++;
        }

        // If they are not done, add their email to the list
        if (doneCount < assignedCount && student['email'] != null) {
          String email = student['email'].toString().trim();
          if (email.isNotEmpty && email.contains('@')) {
            emailsToNudge.add(email);
          }
        }
      }

      if (emailsToNudge.isEmpty) throw "All students in $_selectedSection have completed their evaluations!";

      // Send Bulk Email via EmailJS
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': 'service_pxefso9',
          'template_id': 'template_5fu425e',
          'user_id': 'a1IlFJdn9QUOqWMMM',
          'template_params': {
            'to_name': 'GRC Students ($_selectedSection)',
            'to_email': emailsToNudge.join(','),
            'message': 'This is an urgent reminder from your Program Head. You have pending instructor evaluations for $_selectedSection. Please log in and complete them immediately.'
          }
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nudged ${emailsToNudge.length} pending student(s) successfully!"), backgroundColor: Colors.green));
      } else {
        throw "EmailJS Error. Check your EmailJS domain settings.";
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
    setState(() => _isNudging = false);
  }

  // --- REPORT ISSUE DIALOG ---
  void _showReportIssueDialog(BuildContext context) {
    final TextEditingController issueCtrl = TextEditingController();
    String issueType = 'App Bug';

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: GrcColors.surface,
          title: const Text("Report an Issue", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: issueType,
                decoration: const InputDecoration(labelText: "Issue Type", border: OutlineInputBorder()),
                items: ['Missing Instructor Data', 'Wrong Student List', 'App Bug', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => issueType = v!,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: issueCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: "Describe the problem...", border: OutlineInputBorder(), hintStyle: TextStyle(fontSize: 13)),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: GrcColors.textLight))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
                onPressed: () async {
                  if (issueCtrl.text.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('reported_issues').add({
                      'studentId': widget.userData['id'],
                      'studentName': widget.userData['name'],
                      'section': 'Program Head Dashboard',
                      'type': issueType,
                      'description': issueCtrl.text,
                      'timestamp': FieldValue.serverTimestamp(),
                      'status': 'Open'
                    });
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue reported to System Admin!"), backgroundColor: Colors.green));
                    }
                  }
                },
                child: const Text("SUBMIT", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold))
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    String prefix = collegeToCode[_selectedCourse] ?? "SELECT";

    // Wrapped in Scaffold so we can add the Floating Action Button for reporting issues
    return Scaffold(
      backgroundColor: GrcColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GrcColors.maroon,
        icon: const Icon(Icons.bug_report, color: GrcColors.gold),
        label: const Text("REPORT ISSUE", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
        onPressed: () => _showReportIssueDialog(context),
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('evaluations').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  Map<String, List<double>> teacherScores = {};
                  Map<String, String> teacherNames = {};

                  for (var doc in snapshot.data!.docs) {
                    var d = doc.data() as Map<String, dynamic>;
                    String tId = d['teacherId'] ?? '';
                    teacherNames[tId] = d['teacherName'] ?? 'Unknown';
                    double rawAvg = (d['rawAverage'] ?? 0).toDouble();
                    if (rawAvg > 0) {
                      teacherScores.putIfAbsent(tId, () => []).add(rawAvg);
                    }
                  }

                  List<String> atRiskTeachers = [];
                  teacherScores.forEach((id, scores) {
                    double avg = scores.reduce((a, b) => a + b) / scores.length;
                    if (avg < 3.0 && scores.length > 2) {
                      atRiskTeachers.add(teacherNames[id]!);
                    }
                  });

                  if (atRiskTeachers.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Early Warning Alert", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text("The following instructors are currently averaging below 3.0: ${atRiskTeachers.join(', ')}. Please report to Dean.",
                                  style: const TextStyle(color: GrcColors.textDark, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
            ),

            const Text("STUDENT EVALUATION TRACKER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: GrcColors.maroon)),
            const SizedBox(height: 4),
            const Text("Monitor student completion rates and export official PDF reports.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 600;
                
                Widget courseDropdown = DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedCourse,
                  decoration: const InputDecoration(labelText: "Course", border: OutlineInputBorder(), filled: true, fillColor: GrcColors.surface),
                  items: collegeToCode.keys.map((c) => DropdownMenuItem(value: c, child: Text(collegeToCode[c]!, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() { _selectedCourse = v; _selectedSection = null; }),
                );
                
                Widget yearDropdown = DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedYear,
                  decoration: const InputDecoration(labelText: "Year", border: OutlineInputBorder(), filled: true, fillColor: GrcColors.surface),
                  items: ['1','2','3','4'].map((y) => DropdownMenuItem(value: y, child: Text("Year $y", style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() { _selectedYear = v; _selectedSection = null; }),
                );

                Widget sectionDropdown = DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedSection,
                  decoration: const InputDecoration(labelText: "Section", border: OutlineInputBorder(), filled: true, fillColor: GrcColors.surface),
                  items: List.generate(10, (i) => "$prefix - $_selectedYear${(i+1).toString().padLeft(2,'0')}").map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _selectedSection = v),
                );

                return isMobile 
                  ? Column(
                      children: [
                        courseDropdown,
                        const SizedBox(height: 10),
                        yearDropdown,
                        const SizedBox(height: 10),
                        sectionDropdown,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: courseDropdown),
                        const SizedBox(width: 10),
                        Expanded(child: yearDropdown),
                        const SizedBox(width: 10),
                        Expanded(child: sectionDropdown),
                      ],
                    );
              },
            ),
            const SizedBox(height: 20),

            if (_selectedSection != null)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                    onPressed: _isNudging
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: GrcColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: GrcColors.border),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(Icons.notifications_active_outlined, color: Colors.orange, size: 22),
                                    SizedBox(width: 10),
                                    Text("Send Nudge Emails?",
                                        style: TextStyle(color: GrcColors.textDark, fontWeight: FontWeight.w700, fontSize: 16)),
                                  ],
                                ),
                                content: Text(
                                  "This will send reminder emails to all students in $_selectedSection who have not yet completed their evaluations.\n\nAre you sure you want to proceed?",
                                  style: const TextStyle(color: GrcColors.textMid, fontSize: 13, height: 1.5),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("CANCEL",
                                        style: TextStyle(color: GrcColors.textLight, fontWeight: FontWeight.w700)),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    icon: const Icon(Icons.send, size: 14, color: Colors.white),
                                    label: const Text("SEND NUDGE",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) _nudgePending();
                          },
                    icon: _isNudging
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2))
                        : const Icon(Icons.notifications_active_outlined, size: 16),
                    label: Text(_isNudging ? "SENDING EMAILS..." : "NUDGE PENDING",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
                    onPressed: _isExporting ? null : _exportReport,
                    icon: _isExporting ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: GrcColors.gold, strokeWidth: 2)) : const Icon(Icons.download, size: 16, color: GrcColors.gold),
                    label: Text(_isExporting ? "GENERATING..." : "EXPORT REPORT", style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.gold)),
                  ),
                ],
              ),
            const SizedBox(height: 15),

            if (_selectedSection != null && _selectedCourse != null)
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('section_assignments').doc(_selectedSection).snapshots(),
                  builder: (context, assignSnap) {
                    int assignedCount = 0;
                    List<dynamic> assignedTeacherIds = [];

                    if (assignSnap.hasData && assignSnap.data!.exists) {
                      assignedTeacherIds = assignSnap.data!['teacherIds'] as List<dynamic>? ?? [];
                      assignedCount = assignedTeacherIds.length;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));
                        
                        var students = snapshot.data!.docs.where((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String role = (data['role'] ?? '').toString().toUpperCase();
                          String sSec = (data['section'] ?? '').toString();
                          List subjects = data['enrolled_subjects'] ?? [];
                          
                          bool isStudent = role == 'STUDENT';
                          
                          // Match by main section
                          bool mainMatch = sSec.isNotEmpty && (_selectedSection == sSec || _selectedSection!.endsWith(sSec));
                          
                          // Match by enrolled subjects section
                          bool subjectMatch = subjects.any((s) {
                            String subSec = (s['section'] ?? '').toString();
                            return subSec.isNotEmpty && (_selectedSection == subSec || _selectedSection!.endsWith(subSec));
                          });
                          
                          return isStudent && (mainMatch || subjectMatch);
                        }).toList();

                        if (students.isEmpty) return const Center(child: Text("No students found in this section.", style: TextStyle(color: GrcColors.textLight)));

                        return ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, i) {
                            var student = students[i];
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('evaluations')
                                  .where('evaluatorId', isEqualTo: student['id']).snapshots(),
                              builder: (context, evalSnap) {

                                // --- FIXED MATH LOGIC ---
                                int doneCount = 0;
                                if (evalSnap.hasData) {
                                  for (var eval in evalSnap.data!.docs) {
                                    // ONLY count evaluations for teachers assigned to THIS section right now
                                    if (assignedTeacherIds.contains(eval['teacherId'])) {
                                      doneCount++;
                                    }
                                  }
                                }

                                bool isComplete = doneCount >= assignedCount && assignedCount > 0;
                                bool started = doneCount > 0;

                                return Card(
                                  color: GrcColors.surface,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: GrcColors.border)),
                                  child: ListTile(
                                    leading: Icon(
                                        isComplete ? Icons.check_circle : (started ? Icons.hourglass_top : Icons.error_outline),
                                        color: isComplete ? Colors.green : (started ? Colors.orange : Colors.red)),
                                    title: Text(student['name'].toString().toUpperCase(),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GrcColors.textDark)),
                                    subtitle: Text("ID: ${student['id']}", style: const TextStyle(color: GrcColors.textLight, fontSize: 11)),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            isComplete ? "COMPLETED" : (started ? "IN PROGRESS" : "PENDING"),
                                            style: TextStyle(
                                                fontSize: 10, fontWeight: FontWeight.bold,
                                                color: isComplete ? Colors.green : (started ? Colors.orange : Colors.red))),
                                        Text("$doneCount / $assignedCount Evaluated",
                                            style: const TextStyle(fontSize: 9, color: GrcColors.textLight)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.query_stats, size: 80, color: GrcColors.border.withOpacity(0.8)),
                      const SizedBox(height: 16),
                      const Text("AWAITING SELECTION", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GrcColors.textLight, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      const Text("Please select a Course, Year, and Section from the dropdowns\nabove to view the evaluation statistics.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}