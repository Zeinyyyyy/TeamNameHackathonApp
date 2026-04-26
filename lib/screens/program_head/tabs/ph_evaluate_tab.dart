import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';
import 'ph_evaluation_form_screen.dart';

class PhEvaluateTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PhEvaluateTab({required this.userData, super.key});

  @override
  State<PhEvaluateTab> createState() => _PhEvaluateTabState();
}

class _PhEvaluateTabState extends State<PhEvaluateTab> {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ASSIGNED INSTRUCTORS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text("You can only evaluate instructors assigned to you by the Dean. Your evaluations carry 30% weight.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 24),

          // --- Search Bar & Course Chips ---
          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 700;
              Widget searchField = TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search name or subject...",
                  hintStyle: const TextStyle(fontSize: 12),
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
                        showCheckmark: isSelected,
                        checkmarkColor: GrcColors.gold,
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
          const SizedBox(height: 20),

          // --- Info Banner ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 500;
                
                Widget textContent = const Text(
                  "Criteria: Curriculum Design • Assessment Practices • Mentoring & Guidance — Weight: 30%",
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                );

                Widget deadlineBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3))
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.timer, color: Colors.red, size: 14),
                      SizedBox(width: 6),
                      Text("DEADLINE: PENDING", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                    ],
                  ),
                );

                if (isDesktop) {
                  return Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: textContent),
                      const SizedBox(width: 12),
                      deadlineBadge,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: textContent),
                        ],
                      ),
                      const SizedBox(height: 12),
                      deadlineBadge,
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),

          // --- List of Instructors ---
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('assignments').doc(widget.userData['id']).snapshots(),
              builder: (context, assignmentSnap) {
                if (assignmentSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));
                }

                List<dynamic> assignedIds = [];
                if (assignmentSnap.hasData && assignmentSnap.data!.exists) {
                  assignedIds = (assignmentSnap.data!.data() as Map<String, dynamic>)['assignedTeachers'] ?? [];
                }

                if (assignedIds.isEmpty) {
                  return const Center(child: Text("No instructors assigned to you yet.", style: TextStyle(color: GrcColors.textLight)));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('teachers').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No instructors found.", style: TextStyle(color: GrcColors.textLight)));
                    }

                    // Applying Filters
                    var instructors = snapshot.data!.docs.where((doc) {
                      if (!assignedIds.contains(doc.id)) return false;

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

                return ListView.builder(
                  itemCount: instructors.length,
                  itemBuilder: (context, index) {
                    var instructor = instructors[index];
                    var data = instructor.data() as Map<String, dynamic>;
                    String deptDisplay = data['department'] ?? 'No Department Assigned';

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('evaluations')
                          .where('teacherId', isEqualTo: instructor.id)
                          .where('evaluatorId', isEqualTo: widget.userData['id'])
                          .where('role', isEqualTo: 'PROGRAM HEAD')
                          .snapshots(),
                      builder: (context, evalSnap) {
                        bool isDone = evalSnap.hasData && evalSnap.data!.docs.isNotEmpty;

                        return Card(
                          color: GrcColors.surface,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDone ? Colors.green.withOpacity(0.4) : GrcColors.border,
                              width: isDone ? 1.5 : 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isDone
                                      ? Colors.green.withOpacity(0.1)
                                      : GrcColors.maroon.withValues(alpha: 0.1),
                                  child: Icon(
                                    isDone ? Icons.check_circle : Icons.person,
                                    color: isDone ? Colors.green : GrcColors.maroon,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.textDark)),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text("${data['subject']} • $deptDisplay", style: const TextStyle(fontSize: 11, color: GrcColors.textLight)),
                                          if (!isDone) 
                                            Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: Colors.red.withValues(alpha: 0.05),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.red.withValues(alpha: 0.2))
                                                ),
                                                child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      Icon(Icons.access_time, size: 10, color: Colors.red),
                                                      SizedBox(width: 4),
                                                      Text("Due Soon", style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                                                    ]
                                                )
                                            )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDone)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("COMPLETED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: GrcColors.maroon,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      // FIXED: navigate to PH evaluation form
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PhEvaluationFormScreen(
                                            instructorData: instructor,
                                            userData: widget.userData,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text("EVALUATE", style: TextStyle(color: GrcColors.gold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  ),
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
          ),
        ],
      ),
    );
  }
}