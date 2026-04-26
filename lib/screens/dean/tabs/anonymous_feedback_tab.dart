import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';
import '../feedback_detail_screen.dart';

class AnonymousFeedbackTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const AnonymousFeedbackTab({this.userData, super.key});

  @override
  State<AnonymousFeedbackTab> createState() => _AnonymousFeedbackTabState();
}

class _AnonymousFeedbackTabState extends State<AnonymousFeedbackTab> {
  String _searchQuery = '';
  String _selectedFilterDept = 'ALL';
  String _sortBy = 'Name (A-Z)';

  final List<String> _filterOptions = ['ALL', 'BSIT', 'BSBA', 'BSE', 'BSA', 'BSED'];
  final List<String> _sortOptions = ['Name (A-Z)', 'Most Evaluated', 'Most Comments'];

  final Map<String, String> _chipToDbName = {
    'BSIT': 'College of Computer Studies',
    'BSBA': 'College of Business Administration',
    'BSE': 'College of Entrepreneurship',
    'BSA': 'College of Accountancy',
    'BSED': 'College of Education',
  };

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ANONYMOUS FEEDBACK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
          const SizedBox(height: 6),
          // 🟢 FIX: Font bumped to 13
          const Text("Select an instructor to view their detailed feedback and evaluations.", style: TextStyle(fontSize: 13, color: GrcColors.textLight)),
          const SizedBox(height: 24),

          // --- 1. SEARCH BAR & SORT DROPDOWN ---
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 300,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search instructor...",
                    // 🟢 FIX: Font bumped to 13
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: GrcColors.maroon),
                    filled: true,
                    fillColor: GrcColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
                  ),
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: GrcColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GrcColors.border)
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: const Icon(Icons.sort, color: GrcColors.maroon, size: 18),
                    // 🟢 FIX: Font bumped to 13
                    style: const TextStyle(fontSize: 13, color: GrcColors.textDark, fontWeight: FontWeight.bold),
                    items: _sortOptions.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(val),
                        ),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) setState(() => _sortBy = newVal);
                    },
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),

          // --- 2. COURSE FILTER CHIPS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((course) {
                bool isSelected = _selectedFilterDept == course;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    // 🟢 FIX: Font bumped to 12
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
          const SizedBox(height: 24),

          // --- 3. INSTRUCTOR LIST STREAM ---
          Expanded(
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('evaluations').snapshots(),
                  builder: (context, evalSnap) {
                    if (!evalSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
                        builder: (context, teacherSnap) {
                          if (!teacherSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                          List<Map<String, dynamic>> instructorDataList = [];

                          for (var teacherDoc in teacherSnap.data!.docs) {
                            var tData = teacherDoc.data() as Map<String, dynamic>;
                            String tName = (tData['name'] ?? 'Unknown').toString();
                            String tDept = (tData['department'] ?? '').toString();
                            String tSubj = (tData['subject'] ?? '').toString();

                            if (_selectedFilterDept != 'ALL' && tDept != _chipToDbName[_selectedFilterDept]) continue;

                            String query = _searchQuery.toLowerCase();
                            if (!tName.toLowerCase().contains(query) && !tSubj.toLowerCase().contains(query)) continue;

                            var teacherEvals = evalSnap.data!.docs.where((e) {
                              var eData = e.data() as Map<String, dynamic>;
                              return eData['teacherId'] == teacherDoc.id;
                            }).toList();

                            int totalEvals = teacherEvals.length;
                            int writtenComments = 0;

                            for (var eval in teacherEvals) {
                              var eData = eval.data() as Map<String, dynamic>;
                              String comment = (eData['comment'] ?? '').toString().trim();
                              if (comment.isNotEmpty) writtenComments++;
                            }

                            instructorDataList.add({
                              'id': teacherDoc.id,
                              'name': tName,
                              'department': tDept.isEmpty ? 'No Department' : tDept,
                              'subject': tSubj,
                              'totalEvals': totalEvals,
                              'writtenComments': writtenComments,
                            });
                          }

                          // --- 4. APPLY SORTING LOGIC ---
                          if (_sortBy == 'Name (A-Z)') {
                            instructorDataList.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
                          } else if (_sortBy == 'Most Evaluated') {
                            instructorDataList.sort((a, b) => b['totalEvals'].compareTo(a['totalEvals']));
                          } else if (_sortBy == 'Most Comments') {
                            instructorDataList.sort((a, b) => b['writtenComments'].compareTo(a['writtenComments']));
                          }

                          if (instructorDataList.isEmpty) {
                            return const Center(child: Text("No instructors found.", style: TextStyle(color: GrcColors.textLight)));
                          }

                          return ListView.builder(
                            itemCount: instructorDataList.length,
                            itemBuilder: (context, index) {
                              var data = instructorDataList[index];
                              int comments = data['writtenComments'];
                              bool hasComments = comments > 0;

                              return Card(
                                color: GrcColors.surface,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: GrcColors.border, width: 1),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FeedbackDetailScreen(
                                          teacherId: data['id'],
                                          teacherName: data['name'],
                                          subjectDept: "${data['subject']} • ${data['department']}",
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: GrcColors.maroon.withOpacity(0.1),
                                          child: const Icon(Icons.person, color: GrcColors.maroon, size: 24),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // 🟢 FIX: Font bumped to 15
                                              Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GrcColors.textDark)),
                                              const SizedBox(height: 4),

                                              // 🟢 FIX: Font bumped to 12
                                              Text("${data['subject']} • ${data['department']}", style: const TextStyle(fontSize: 12, color: GrcColors.textLight)),
                                              const SizedBox(height: 8),

                                              RichText(
                                                  text: TextSpan(
                                                    // 🟢 FIX: Font bumped to 12
                                                      style: const TextStyle(fontFamily: 'Roboto', fontSize: 12, color: GrcColors.textLight),
                                                      children: [
                                                        TextSpan(text: "${data['totalEvals']} Total Evaluations  •  "),
                                                        TextSpan(
                                                            text: "$comments Written Comments",
                                                            style: TextStyle(
                                                              fontWeight: hasComments ? FontWeight.bold : FontWeight.normal,
                                                              color: hasComments ? Colors.orange : GrcColors.textLight,
                                                            )
                                                        )
                                                      ]
                                                  )
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: GrcColors.textLight),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
}