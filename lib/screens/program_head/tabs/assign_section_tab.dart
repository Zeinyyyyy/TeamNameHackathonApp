import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

class AssignSectionTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AssignSectionTab({required this.userData, super.key});
  @override
  State<AssignSectionTab> createState() => _AssignSectionTabState();
}

class _AssignSectionTabState extends State<AssignSectionTab> {
  String? _selectedCourse;
  String? _yr  = '1';
  String? _sec;
  DateTime? _selectedDeadline;
  bool    _aiLoading = false;

  // --- Search & Filter State ---
  String _searchQuery = '';
  String _selectedFilterDept = 'ALL';

  final List<String> _filterOptions = ['ALL', 'BSIT', 'BSBA', 'BSE', 'BSA', 'BSED'];

  final Map<String, String> _chipToDbName = {
    'BSIT': 'College of Computer Studies',
    'BSBA': 'College of Business Administration',
    'BSE': 'College of Entrepreneurship',
    'BSA': 'College of Accountancy',
    'BSED': 'College of Education',
  };

  final Map<String, String> collegeToCode = {
    'College of Business Administration': 'BSBA',
    'College of Entrepreneurship': 'BSE',
    'College of Accountancy': 'BSA',
    'College of Education': 'BSED',
    'College of Computer Studies': 'BSIT',
  };

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: GrcColors.maroon,
              onPrimary: GrcColors.gold,
              onSurface: GrcColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _activateAiDeploy() async {
    if (_sec == null) return;
    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a deadline before deploying."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _aiLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final critRef = FirebaseFirestore.instance.collection('section_assignments').doc(_sec).collection('criteria');
      final oldCrit = await critRef.get();
      for (var doc in oldCrit.docs) { batch.delete(doc.reference); }

      // --- RESTORED: Full 24 Comprehensive Criteria ---
      const List<Map<String, String>> kAiCriteria = [
        // A. TEACHING EFFECTIVENESS (6)
        {'section': 'Teaching Effectiveness', 'text': 'Explains lessons in a clear and understandable manner.'},
        {'section': 'Teaching Effectiveness', 'text': 'Demonstrates mastery of the subject matter.'},
        {'section': 'Teaching Effectiveness', 'text': 'Uses relevant examples and real-life applications.'},
        {'section': 'Teaching Effectiveness', 'text': 'Maintains an appropriate pace during lectures.'},
        {'section': 'Teaching Effectiveness', 'text': 'Encourages students to ask questions and participate.'},
        {'section': 'Teaching Effectiveness', 'text': 'Speaks with a clear and audible voice.'},
        // B. CLASS MANAGEMENT (6)
        {'section': 'Class Management', 'text': 'Maintains discipline and order inside the classroom.'},
        {'section': 'Class Management', 'text': 'Starts and ends the class strictly on time.'},
        {'section': 'Class Management', 'text': 'Checks attendance and monitors student absences.'},
        {'section': 'Class Management', 'text': 'Treats all students with respect and fairness.'},
        {'section': 'Class Management', 'text': 'Motivates students to perform their best.'},
        {'section': 'Class Management', 'text': 'Creates a safe and positive learning environment.'},
        // C. ASSESSMENT & GRADING (6)
        {'section': 'Assessment & Grading', 'text': 'Grades requirements fairly and consistently.'},
        {'section': 'Assessment & Grading', 'text': 'Provides constructive feedback on assignments/exams.'},
        {'section': 'Assessment & Grading', 'text': 'Returns graded materials promptly.'},
        {'section': 'Assessment & Grading', 'text': 'Bases grades on a clear and transparent rubric.'},
        {'section': 'Assessment & Grading', 'text': 'Gives exams that are relevant to the lessons taught.'},
        {'section': 'Assessment & Grading', 'text': 'Clearly explains how the final grade is computed.'},
        // D. PROFESSIONALISM (6)
        {'section': 'Professionalism', 'text': 'Dresses appropriately and professionally.'},
        {'section': 'Professionalism', 'text': 'Is approachable and accommodating to student concerns.'},
        {'section': 'Professionalism', 'text': 'Shows enthusiasm and dedication to teaching.'},
        {'section': 'Professionalism', 'text': 'Follows the course syllabus and timeline.'},
        {'section': 'Professionalism', 'text': 'Is available during consultation hours.'},
        {'section': 'Professionalism', 'text': 'Demonstrates ethical behavior at all times.'},
      ];

      for (int i = 0; i < kAiCriteria.length; i++) {
        final docRef = critRef.doc('q${(i + 1).toString().padLeft(2, '0')}');
        batch.set(docRef, {'index': i + 1, 'section': kAiCriteria[i]['section'], 'text': kAiCriteria[i]['text']});
      }

      batch.set(FirebaseFirestore.instance.collection('section_assignments').doc(_sec),
          {
            'status': 'AI_ACTIVE',
            'section': _sec,
            'criteriaCount': kAiCriteria.length,
            'deployedAt': FieldValue.serverTimestamp(),
            'deadline': _selectedDeadline,
          },
          SetOptions(merge: true));

      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Evaluation Deployed successfully with 24 Criteria!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
    setState(() => _aiLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    String prefix = collegeToCode[_selectedCourse] ?? "SELECT";
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DEPLOY EVALUATIONS TO SECTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: GrcColors.maroon)),
          const SizedBox(height: 4),
          const Text("Activate evaluation forms and assign specific instructors to a class.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 700;
              Widget courseDropdown = DropdownButtonFormField<String>(
                value: _selectedCourse, decoration: const InputDecoration(labelText: "Course", border: OutlineInputBorder(), filled: true, fillColor: GrcColors.surface),
                items: collegeToCode.keys.map((c) => DropdownMenuItem(value: c, child: Text(collegeToCode[c]!, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() { _selectedCourse = v; _sec = null; }),
              );
              Widget yearDropdown = DropdownButtonFormField<String>(
                value: _yr, decoration: const InputDecoration(labelText: "Year", border: OutlineInputBorder(), filled: true, fillColor: GrcColors.surface),
                items: ['1','2','3','4'].map((y) => DropdownMenuItem(value: y, child: Text("Year $y", style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() { _yr = v; _sec = null; }),
              );
              Widget secDropdown = DropdownButtonFormField<String>(
                value: _sec, decoration: const InputDecoration(labelText: "Section", border: OutlineInputBorder(), filled: true, fillColor: GrcColors.surface),
                items: List.generate(10, (i) => "$prefix - $_yr${(i+1).toString().padLeft(2,'0')}").map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _sec = v),
              );

              if (isDesktop) {
                return Row(children: [
                  Expanded(child: courseDropdown),
                  const SizedBox(width: 10),
                  Expanded(child: yearDropdown),
                  const SizedBox(width: 10),
                  Expanded(child: secDropdown),
                ]);
              } else {
                return Column(children: [
                  courseDropdown,
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: yearDropdown),
                    const SizedBox(width: 10),
                    Expanded(child: secDropdown),
                  ]),
                ]);
              }
            },
          ),
          const SizedBox(height: 20),

          if (_sec != null && _selectedCourse != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 700;
                Widget deadlineButton = InkWell(
                  onTap: () => _selectDeadline(context),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: GrcColors.border),
                      borderRadius: BorderRadius.circular(4),
                      color: GrcColors.surface,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: GrcColors.maroon, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDeadline == null
                              ? "Set Deadline (Required)"
                              : "Due: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}",
                          style: TextStyle(
                            color: _selectedDeadline == null ? GrcColors.textLight : GrcColors.textDark,
                            fontSize: 13,
                            fontWeight: _selectedDeadline != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                Widget aiButton = SizedBox(
                  height: 50,
                  width: isDesktop ? null : double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _aiLoading ? null : _activateAiDeploy,
                    icon: _aiLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: GrcColors.maroon)) : const Icon(Icons.auto_awesome),
                    label: Text(_aiLoading ? "AI GENERATING CRITERIA..." : "ACTIVATE AI EVALUATION", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: GrcColors.maroon, side: const BorderSide(color: GrcColors.maroon, width: 2), backgroundColor: GrcColors.surface),
                  ),
                );

                if (isDesktop) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: deadlineButton),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: aiButton),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      deadlineButton,
                      const SizedBox(height: 10),
                      aiButton,
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 24),
            const Divider(height: 1, color: GrcColors.border),
            const SizedBox(height: 16),

            // Search Bar & Course Chips
            LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 700;
                Widget searchField = TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search instructor...",
                    prefixIcon: const Icon(Icons.search, size: 18, color: GrcColors.maroon),
                    filled: true,
                    fillColor: GrcColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
                  ),
                );

                Widget filterChips = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((course) {
                      bool isSelected = _selectedFilterDept == course;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(course, style: TextStyle(color: isSelected ? GrcColors.gold : GrcColors.textDark, fontWeight: FontWeight.bold, fontSize: 11)),
                          selected: isSelected,
                          selectedColor: GrcColors.maroon,
                          backgroundColor: GrcColors.surface,
                          side: BorderSide(color: isSelected ? GrcColors.maroon : GrcColors.border),
                          onSelected: (bool selected) {
                            setState(() => _selectedFilterDept = course);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                );

                if (isDesktop) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: searchField),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: filterChips),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      filterChips,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('teachers').orderBy('name').snapshots(),
                builder: (context, tSnap) {
                  if (!tSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                  var instructors = tSnap.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = (data['name'] ?? '').toString().toLowerCase();
                    String subject = (data['subject'] ?? '').toString().toLowerCase();
                    String dept = (data['department'] ?? '').toString();

                    String query = _searchQuery.toLowerCase();
                    bool matchesSearch = name.contains(query) || subject.contains(query);
                    bool matchesDept = _selectedFilterDept == 'ALL' || dept == _chipToDbName[_selectedFilterDept];

                    return matchesSearch && matchesDept;
                  }).toList();

                  if (instructors.isEmpty) {
                    return const Center(child: Text("No matching instructors found.", style: TextStyle(color: GrcColors.textLight)));
                  }

                  Map<String, List<DocumentSnapshot>> groupedInstructors = {};
                  for (var doc in instructors) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = (data['name'] ?? 'Unknown').toString().toUpperCase();
                    if (!groupedInstructors.containsKey(name)) {
                      groupedInstructors[name] = [];
                    }
                    groupedInstructors[name]!.add(doc);
                  }

                  List<String> sortedNames = groupedInstructors.keys.toList()..sort();

                  return ListView.builder(
                    itemCount: sortedNames.length,
                    itemBuilder: (context, i) {
                      String instructorName = sortedNames[i];
                      List<DocumentSnapshot> teacherDocs = groupedInstructors[instructorName]!;
                      
                      return Card(
                        color: GrcColors.surface,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: GrcColors.border)),
                        child: ExpansionTile(
                          shape: const Border(), // Remove borders when expanded
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: GrcColors.maroon.withOpacity(0.1),
                            child: const Icon(Icons.person, color: GrcColors.maroon),
                          ),
                          title: Text(instructorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("${teacherDocs.length} Subject(s) Taught", style: const TextStyle(color: GrcColors.textLight, fontSize: 11)),
                          children: teacherDocs.map((instructor) {
                            var data = instructor.data() as Map<String, dynamic>;
                            String deptDisplay = data['department'] ?? 'No Department Assigned';
                            String subj = data['subject'] ?? 'Unassigned';
                            String subjId = data['subjectId'] ?? 'No ID';

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('section_assignments').doc(_sec).snapshots(),
                              builder: (context, assignSnap) {
                                bool assigned = false;
                                if (assignSnap.hasData && assignSnap.data!.exists) {
                                  List ids = assignSnap.data!['teacherIds'] ?? [];
                                  assigned = ids.contains(instructor.id);
                                }

                                return Container(
                                  decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: GrcColors.border))
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(left: 72, right: 20, top: 4, bottom: 4),
                                    title: Text("$subj ($subjId)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: GrcColors.textDark)),
                                    subtitle: Text(deptDisplay, style: const TextStyle(color: GrcColors.textLight, fontSize: 11)),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: assigned ? Colors.red : GrcColors.maroon,
                                        elevation: 0,
                                        minimumSize: const Size(80, 32)
                                      ),
                                      onPressed: () {
                                        if (assigned) {
                                          FirebaseFirestore.instance.collection('section_assignments').doc(_sec!).update({'teacherIds': FieldValue.arrayRemove([instructor.id])});
                                        } else {
                                          FirebaseFirestore.instance.collection('section_assignments').doc(_sec!).set({'section': _sec, 'teacherIds': FieldValue.arrayUnion([instructor.id])}, SetOptions(merge: true));
                                        }
                                      },
                                      child: Text(assigned ? "REMOVE" : "ASSIGN", style: TextStyle(color: assigned ? Colors.white : GrcColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ] else
          // --- REVERTED: Clean, Simple Minimalist Empty State ---
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_mosaic_outlined, size: 80, color: GrcColors.border.withOpacity(0.8)),
                    const SizedBox(height: 16),
                    const Text("READY TO DEPLOY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GrcColors.textLight, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    const Text("Select a Course, Year, and Section from the dropdowns above\nto configure evaluation criteria and assign instructors.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}