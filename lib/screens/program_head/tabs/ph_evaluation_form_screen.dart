import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

class PhEvaluationFormScreen extends StatefulWidget {
  final QueryDocumentSnapshot instructorData;
  final Map<String, dynamic> userData;

  const PhEvaluationFormScreen({
    required this.instructorData,
    required this.userData,
    super.key,
  });

  @override
  State<PhEvaluationFormScreen> createState() => _PhEvaluationFormScreenState();
}

class _PhEvaluationFormScreenState extends State<PhEvaluationFormScreen> {
  final Map<String, int> _scores = {};
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  final List<Map<String, String>> _phCriteria = [
    {'section': 'Curriculum Design', 'text': 'Designs course content aligned with program outcomes.'},
    {'section': 'Curriculum Design', 'text': 'Integrates updated and relevant instructional materials.'},
    {'section': 'Curriculum Design', 'text': 'Ensures syllabus coverage meets institutional standards.'},
    {'section': 'Assessment Practices', 'text': 'Implements fair and comprehensive assessment strategies.'},
    {'section': 'Assessment Practices', 'text': 'Provides timely and constructive feedback to students.'},
    {'section': 'Assessment Practices', 'text': 'Aligns assessments with the course learning outcomes.'},
    {'section': 'Mentoring & Guidance', 'text': 'Actively mentors students in academic and career growth.'},
    {'section': 'Mentoring & Guidance', 'text': 'Is accessible and responsive to student concerns.'},
    {'section': 'Mentoring & Guidance', 'text': 'Fosters a supportive and inclusive learning environment.'},
    {'section': 'Professional Development', 'text': 'Participates in faculty training and development programs.'},
    {'section': 'Professional Development', 'text': 'Demonstrates initiative in improving teaching methodologies.'},
  ];

  void _submitForm() async {
    if (_scores.length < _phCriteria.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Please rate all ${_phCriteria.length} criteria."),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _submitting = true);

    try {
      double rawAvg = _scores.values.reduce((a, b) => a + b) / _scores.length;
      double weightedScore = rawAvg * 0.30;

      Map<String, int> structuredResponses = {};
      _scores.forEach((key, value) => structuredResponses[key] = value);

      await FirebaseFirestore.instance.collection('evaluations').add({
        'teacherId': widget.instructorData.id,
        'teacherName': widget.instructorData['name'],
        'evaluatorId': widget.userData['id'],
        'role': 'PROGRAM HEAD',
        'section': 'N/A',
        'weightedScore': weightedScore,
        'rawAverage': rawAvg,
        'responses': structuredResponses,
        'comment': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Evaluation Submitted Successfully!"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrcColors.background,
      appBar: AppBar(
        backgroundColor: GrcColors.maroon,
        title: Text(
          "PH EVALUATION: ${widget.instructorData['name']}",
          style: const TextStyle(color: GrcColors.gold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        iconTheme: const IconThemeData(color: GrcColors.gold),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "${_scores.length} / ${_phCriteria.length} rated",
                style: TextStyle(
                  color: _scores.length == _phCriteria.length ? Colors.greenAccent : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            decoration: BoxDecoration(
              color: GrcColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GrcColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _phCriteria.isEmpty ? 0 : _scores.length / _phCriteria.length,
                    backgroundColor: GrcColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(GrcColors.maroon),
                    minHeight: 6,
                  ),
                  ..._buildSections(),
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Optional: Add confidential notes or feedback for this instructor...",
                        hintStyle: const TextStyle(color: GrcColors.textLight, fontSize: 13),
                        filled: true,
                        fillColor: GrcColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon, width: 1.5)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GrcColors.maroon,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitting ? null : _submitForm,
                      child: _submitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: GrcColors.gold, strokeWidth: 2))
                          : const Text(
                        "SUBMIT PH EVALUATION",
                        style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
                      ),
                    ),
                  ),
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
    for (int i = 0; i < _phCriteria.length; i++) {
      grouped.putIfAbsent(_phCriteria[i]['section']!, () => []).add({'index': i + 1, 'text': _phCriteria[i]['text']});
    }

    final List<Widget> widgets = [];
    grouped.forEach((sectionTitle, items) {
      widgets.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: const BoxDecoration(color: GrcColors.background, border: Border(bottom: BorderSide(color: GrcColors.border))),
        child: Text(sectionTitle.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GrcColors.maroon, letterSpacing: 1)),
      ));
      for (var item in items) {
        widgets.add(_buildEvalRow(item['index'], item['text']));
      }
    });
    return widgets;
  }

  Widget _buildEvalRow(int index, String criteriaText) {
    final key = 'row_$index';
    final score = _scores[key] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GrcColors.border))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: '$index.  ', style: const TextStyle(fontSize: 12, color: GrcColors.textLight, fontWeight: FontWeight.bold)),
                  TextSpan(text: criteriaText, style: const TextStyle(fontSize: 13, color: GrcColors.textDark, height: 1.4)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (idx) {
                int val = idx + 1;
                return GestureDetector(
                  onTap: () => setState(() => _scores[key] = val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: score == val ? GrcColors.maroon.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          score == val ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 24,
                          color: score == val ? GrcColors.maroon : GrcColors.textLight.withOpacity(0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$val',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: score == val ? FontWeight.bold : FontWeight.normal,
                            color: score == val ? GrcColors.maroon : GrcColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}