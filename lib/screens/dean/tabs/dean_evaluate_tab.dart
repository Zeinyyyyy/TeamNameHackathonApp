import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

class DeanEvaluateTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DeanEvaluateTab({required this.userData, super.key});

  @override
  State<DeanEvaluateTab> createState() => _DeanEvaluateTabState();
}

class _DeanEvaluateTabState extends State<DeanEvaluateTab> {
  String _searchQuery = '';
  String _selectedCourse = 'ALL';
  final List<String> _courses = ['ALL', 'BSIT', 'BSBA', 'BSE', 'BSA', 'BSED'];
  final Map<String, String> chipToDatabaseName = {
    'BSIT': 'College of Computer Studies',
    'BSBA': 'College of Business Administration',
    'BSE': 'College of Entrepreneurship',
    'BSA': 'College of Accountancy',
    'BSED': 'College of Education',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("EVALUATE INSTRUCTORS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1, color: GrcColors.maroon)),
          const SizedBox(height: 4),
          const Text("Your evaluations carry 20% weight in the composite score.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
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
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _courses.map((course) {
                      bool isSelected = _selectedCourse == course;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(course, style: TextStyle(color: isSelected ? GrcColors.gold : GrcColors.textDark, fontWeight: FontWeight.bold, fontSize: 11)),
                          selected: isSelected,
                          selectedColor: GrcColors.maroon,
                          backgroundColor: GrcColors.surface,
                          side: BorderSide(color: isSelected ? GrcColors.maroon : GrcColors.border),
                          onSelected: (bool selected) { setState(() => _selectedCourse = course); },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), border: Border.all(color: Colors.orange.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(child: Text("Criteria: Institutional Alignment  •  Leadership  •  Policy Adherence  —  Weight: 20%", style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
              builder: (context, tSnap) {
                if (!tSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                var instructors = tSnap.data!.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final subj = (d['subject'] ?? '').toString().toLowerCase();
                  final dept = (d['department'] ?? '').toString().toUpperCase();

                  bool matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()) || subj.contains(_searchQuery.toLowerCase());
                  bool matchesCourse = true;
                  if (_selectedCourse != 'ALL') {
                    String targetDeptName = chipToDatabaseName[_selectedCourse] ?? _selectedCourse;
                    matchesCourse = dept == targetDeptName;
                  }

                  return matchesSearch && matchesCourse;
                }).toList();

                if (instructors.isEmpty) return const Center(child: Text("No instructors match your search.", style: TextStyle(color: GrcColors.textLight)));

                return ListView.separated(
                  itemCount: instructors.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: GrcColors.border),
                  itemBuilder: (context, i) {
                    final doc  = instructors[i];
                    final d    = doc.data() as Map<String, dynamic>;
                    final name = d['name']    ?? 'Unknown';
                    final subj = d['subject'] ?? '—';

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('evaluations').where('teacherId', isEqualTo: doc.id).where('evaluatorId', isEqualTo: widget.userData['id']).where('role', isEqualTo: 'DEAN').snapshots(),
                      builder: (context, evalSnap) {
                        bool isDone = evalSnap.hasData && evalSnap.data!.docs.isNotEmpty;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDone ? Colors.green.withOpacity(0.3) : GrcColors.border)),
                          child: Row(children: [
                            CircleAvatar(backgroundColor: isDone ? Colors.green : GrcColors.maroon, radius: 18, child: Icon(isDone ? Icons.check : Icons.person_outline, color: isDone ? Colors.white : GrcColors.gold, size: 16)),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GrcColors.textDark)), Text(subj, style: const TextStyle(fontSize: 11, color: GrcColors.textLight))])),
                            if (isDone)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Text("COMPLETED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)))
                            else
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: GrcColors.border))),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => DeanEvaluationFormScreen(
                                          instructorData: doc,
                                          userData: widget.userData,
                                        )
                                    ));
                                  },
                                  child: const Text("EVALUATE", style: TextStyle(color: GrcColors.gold, fontSize: 10, fontWeight: FontWeight.bold))
                              ),
                          ]),
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

class DeanEvaluationFormScreen extends StatefulWidget {
  final QueryDocumentSnapshot instructorData;
  final Map<String, dynamic>  userData;
  const DeanEvaluationFormScreen({required this.instructorData, required this.userData, super.key});
  @override
  State<DeanEvaluationFormScreen> createState() => _DeanEvaluationFormScreenState();
}

class _DeanEvaluationFormScreenState extends State<DeanEvaluationFormScreen> {
  final Map<String, int> _scores = {};
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  final List<Map<String, String>> _deanCriteria = [
    {'section': 'Institutional Alignment', 'text': 'Promotes the vision, mission, and core values of GRC.'},
    {'section': 'Institutional Alignment', 'text': 'Follows administrative policies and academic regulations.'},
    {'section': 'Institutional Alignment', 'text': 'Demonstrates ethical and professional conduct at all times.'},
    {'section': 'Leadership & Initiative', 'text': 'Shows initiative in improving departmental outcomes.'},
    {'section': 'Leadership & Initiative', 'text': 'Contributes to institutional projects and committees.'},
    {'section': 'Leadership & Initiative', 'text': 'Fosters collaborative relationships with co-faculty.'},
    {'section': 'Policy Adherence', 'text': 'Submits grades, syllabi, and reports accurately and on time.'},
    {'section': 'Policy Adherence', 'text': 'Maintains excellent attendance and punctuality records.'},
    {'section': 'Overall Effectiveness', 'text': 'Exhibits strong overall competence in academic delivery.'},
    {'section': 'Overall Effectiveness', 'text': 'Demonstrates clear commitment to institutional growth.'},
  ];

  void _submitForm() async {
    if (_scores.length < _deanCriteria.length) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please rate all ${_deanCriteria.length} criteria."), backgroundColor: Colors.red)); return; }
    setState(() => _submitting = true);

    double rawAvg = _scores.values.reduce((a, b) => a + b) / _scores.length;
    double weightedScore = rawAvg * 0.20;

    Map<String, int> structuredResponses = {};
    _scores.forEach((key, value) { structuredResponses[key] = value; });

    await FirebaseFirestore.instance.collection('evaluations').add({'teacherId': widget.instructorData.id, 'teacherName': widget.instructorData['name'], 'evaluatorId': widget.userData['id'], 'role': 'DEAN', 'section': 'N/A', 'weightedScore': weightedScore, 'rawAverage': rawAvg, 'responses': structuredResponses, 'comment': _commentController.text.trim(), 'timestamp': FieldValue.serverTimestamp()});
    if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Instructor Evaluation Submitted!"), backgroundColor: Colors.green)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrcColors.background,
      appBar: AppBar(backgroundColor: GrcColors.maroon, title: Text("DEAN EVALUATION: ${widget.instructorData['name']}", style: const TextStyle(color: GrcColors.gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)), iconTheme: const IconThemeData(color: GrcColors.gold), actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text("${_scores.length} / ${_deanCriteria.length} rated", style: TextStyle(color: _scores.length == _deanCriteria.length ? Colors.greenAccent : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))))]),
      body: SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Container(constraints: const BoxConstraints(maxWidth: 900), decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: GrcColors.border)),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Column(children: [
          LinearProgressIndicator(value: _scores.length / _deanCriteria.length, backgroundColor: GrcColors.border, valueColor: const AlwaysStoppedAnimation<Color>(GrcColors.maroon), minHeight: 6),
          ..._buildSections(),
          Padding(padding: const EdgeInsets.all(30), child: TextField(controller: _commentController, maxLines: 4, decoration: InputDecoration(hintText: "Confidential feedback & administrative notes for this instructor...", hintStyle: const TextStyle(color: GrcColors.textLight, fontSize: 13), filled: true, fillColor: GrcColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon))))),
          Padding(padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _submitting ? null : _submitForm, child: _submitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: GrcColors.gold, strokeWidth: 2)) : const Text("SUBMIT DEAN EVALUATION", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)))),
        ],
        ),
        ),
      ),
      ),
      ),
    );
  }

  List<Widget> _buildSections() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (int i = 0; i < _deanCriteria.length; i++) { grouped.putIfAbsent(_deanCriteria[i]['section']!, () => []).add({'index': i + 1, 'text': _deanCriteria[i]['text']}); }
    final List<Widget> widgets = [];
    grouped.forEach((sectionTitle, items) {
      widgets.add(Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), decoration: const BoxDecoration(color: GrcColors.background, border: Border(bottom: BorderSide(color: GrcColors.border))), child: Text(sectionTitle.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GrcColors.maroon, letterSpacing: 1))));
      for (var item in items) { widgets.add(_buildEvalRow(item['index'], item['text'])); }
    });
    return widgets;
  }

  Widget _buildEvalRow(int index, String criteriaText) {
    final key = 'row_$index'; final score = _scores[key] ?? 0;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GrcColors.border))),
      child: Row(children: [
        Expanded(flex: 3, child: RichText(text: TextSpan(children: [TextSpan(text: '$index.  ', style: const TextStyle(fontSize: 12, color: GrcColors.textLight, fontWeight: FontWeight.bold)), TextSpan(text: criteriaText, style: const TextStyle(fontSize: 13, color: GrcColors.textDark, height: 1.4))]))),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(5, (idx) {
          int val = idx + 1;
          return GestureDetector(onTap: () => setState(() => _scores[key] = val), child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: score == val ? GrcColors.maroon.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Column(children: [Icon(score == val ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 24, color: score == val ? GrcColors.maroon : GrcColors.textLight.withOpacity(0.5)), const SizedBox(height: 4), Text('$val', style: TextStyle(fontSize: 11, fontWeight: score == val ? FontWeight.bold : FontWeight.normal, color: score == val ? GrcColors.maroon : GrcColors.textLight))])));
        }))),
      ],
      ),
    );
  }
}