import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';
import '../ai_insight_detail_screen.dart';

class InstructorListTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const InstructorListTab({this.userData, super.key});

  @override
  State<InstructorListTab> createState() => _InstructorListTabState();
}

class _InstructorListTabState extends State<InstructorListTab> {
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

  Widget _buildDataReadinessBadge(int evalCount) {
    Color color;
    String text;
    IconData icon;

    if (evalCount == 0) {
      color = Colors.grey;
      text = "NO DATA";
      icon = Icons.block;
    } else if (evalCount < 3) {
      color = Colors.orange;
      text = "LIMITED DATA";
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.green;
      text = "READY FOR AI";
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // --- REUSABLE NAVIGATION FUNCTION ---
  void _navigateToAI(BuildContext context, Map<String, dynamic> data) {
    if ((data['evalCount'] ?? 0) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No evaluation data available for this instructor yet."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiInsightDetailScreen(
          teacherId: data['id'],
          teacherName: data['name'],
          subjectDept: "${data['subject']} • ${data['department']}",
          evalCount: data['evalCount'] ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("AI INSIGHTS & FACULTY LIST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text("Select an instructor to generate in-depth AI summaries using their actual evaluation data.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "Search instructor or subject...",
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 18, color: GrcColors.maroon),
              filled: true,
              fillColor: GrcColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
            ),
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
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
                    onSelected: (bool selected) => setState(() => _selectedFilterDept = course),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

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

                          Map<String, Map<String, dynamic>> groupedInstructors = {};
                          
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

                            String key = tName.toUpperCase();
                            if (!groupedInstructors.containsKey(key)) {
                              groupedInstructors[key] = {
                                'id': teacherDoc.id,
                                'name': tName,
                                'department': tDept.isEmpty ? 'No Department' : tDept,
                                'subjects': <String>{},
                                'evalCount': 0,
                              };
                            }
                            
                            groupedInstructors[key]!['subjects'].add(tSubj);
                            groupedInstructors[key]!['evalCount'] += teacherEvals.length;
                          }

                          instructorDataList = groupedInstructors.values.map((v) {
                            return {
                              'id': v['id'],
                              'name': v['name'],
                              'department': v['department'],
                              'subject': (v['subjects'] as Set<String>).join(', '),
                              'evalCount': v['evalCount'],
                            };
                          }).toList();

                          instructorDataList.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

                          if (instructorDataList.isEmpty) {
                            return const Center(child: Text("No instructors found.", style: TextStyle(color: GrcColors.textLight)));
                          }

                          return ListView.builder(
                            itemCount: instructorDataList.length,
                            itemBuilder: (context, index) {
                              var data = instructorDataList[index];
                              int evalCount = data['evalCount'];

                              return Card(
                                color: GrcColors.surface,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: GrcColors.border, width: 1),
                                ),
                                // --- THE ENTIRE CARD IS NOW CLICKABLE ---
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _navigateToAI(context, data),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        bool isMobile = constraints.maxWidth < 450;
                                        
                                        Widget content = Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.textDark)),
                                            const SizedBox(height: 4),
                                            Text("${data['subject']} • ${data['department']}", style: const TextStyle(fontSize: 10, color: GrcColors.textLight)),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                _buildDataReadinessBadge(evalCount),
                                                Text("($evalCount records)", style: const TextStyle(fontSize: 10, color: GrcColors.textLight)),
                                              ],
                                            )
                                          ],
                                        );

                                        Widget button = OutlinedButton.icon(
                                          onPressed: evalCount == 0 ? null : () => _navigateToAI(context, data),
                                          icon: const Icon(Icons.auto_awesome, size: 16),
                                          label: const Text("VIEW INSIGHTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: evalCount == 0 ? Colors.grey : GrcColors.maroon,
                                              side: BorderSide(color: evalCount == 0 ? Colors.grey : GrcColors.maroon),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                          ),
                                        );

                                        if (isMobile) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor: GrcColors.maroon.withValues(alpha: 0.1),
                                                    child: const Icon(Icons.person, color: GrcColors.maroon, size: 24),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(child: content),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              SizedBox(width: double.infinity, child: button),
                                            ],
                                          );
                                        }

                                        return Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: GrcColors.maroon.withValues(alpha: 0.1),
                                              child: const Icon(Icons.person, color: GrcColors.maroon, size: 24),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(child: content),
                                            const SizedBox(width: 16),
                                            button,
                                          ],
                                        );
                                      }
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