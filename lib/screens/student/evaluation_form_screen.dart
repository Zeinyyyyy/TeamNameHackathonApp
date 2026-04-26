import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/grc_theme.dart';

class EvaluationFormScreen extends StatefulWidget {
  final QueryDocumentSnapshot instructorData;
  final Map<String, dynamic>  studentData;
  final String                section;

  const EvaluationFormScreen({
    required this.instructorData,
    required this.studentData,
    required this.section,
    super.key,
  });

  @override
  State<EvaluationFormScreen> createState() => _EvaluationFormScreenState();
}

class _EvaluationFormScreenState extends State<EvaluationFormScreen> {
  final Map<String, int>       _scores            = {};
  final TextEditingController  _commentController = TextEditingController();
  List<QueryDocumentSnapshot>  _criteria          = [];
  bool                         _loadingCriteria   = true;
  bool                         _submitting        = false;

  @override
  void initState() {
    super.initState();
    _loadCriteria();
    _loadDraft();
  }

  String get _draftId => "${widget.studentData['id']}_${widget.instructorData.id}";

  Future<void> _loadDraft() async {
    var doc = await FirebaseFirestore.instance.collection('evaluation_drafts').doc(_draftId).get();
    if (doc.exists && mounted) {
      setState(() {
        Map<String, dynamic> rawScores = doc.data()!['scores'] ?? {};
        rawScores.forEach((key, value) {
          _scores[key] = value as int;
        });
        _commentController.text = doc.data()!['comment'] ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft loaded successfully!"), backgroundColor: Colors.blue));
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _submitting = true);
    await FirebaseFirestore.instance.collection('evaluation_drafts').doc(_draftId).set({
      'scores': _scores,
      'comment': _commentController.text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Progress saved as draft!"), backgroundColor: Colors.orange));
    }
  }

  Future<void> _loadCriteria() async {
    final snap = await FirebaseFirestore.instance
        .collection('section_assignments')
        .doc(widget.section)
        .collection('criteria')
        .orderBy('index')
        .get();

    setState(() {
      _criteria        = snap.docs;
      _loadingCriteria = false;
    });
  }

  // 🟢 THE FIX: Re-wrote this function to use a Firebase Transaction!
  void _submitForm() async {
    if (_scores.length < _criteria.length) {
      final remaining = _criteria.length - _scores.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Please rate all criteria ($remaining remaining)."),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _submitting = true);

    try {
      double rawAvg = _scores.values.reduce((a, b) => a + b) / _scores.length;
      double weightedScore = rawAvg * 0.50;

      Map<String, int> structuredResponses = {};
      _scores.forEach((key, value) {
        structuredResponses[key] = value;
      });

      // 1. Setup Document References
      final teacherRef = FirebaseFirestore.instance.collection('teachers').doc(widget.instructorData.id);
      final evalRef = FirebaseFirestore.instance.collection('evaluations').doc(); // Auto-generates a new ID
      final draftRef = FirebaseFirestore.instance.collection('evaluation_drafts').doc(_draftId);

      // 2. Run the secure transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {

        // A. Read the teacher's current stats FIRST (Required by Firestore rules)
        DocumentSnapshot teacherSnapshot = await transaction.get(teacherRef);

        double currentTotalScore = 0.0;
        int currentEvalCount = 0;

        if (teacherSnapshot.exists) {
          var data = teacherSnapshot.data() as Map<String, dynamic>;
          currentTotalScore = (data['totalScore'] ?? 0.0).toDouble();
          currentEvalCount = data['evaluationCount'] ?? 0;
        }

        // B. Calculate their new overall average
        double newTotalScore = currentTotalScore + rawAvg;
        int newEvalCount = currentEvalCount + 1;
        double newAverage = newTotalScore / newEvalCount;

        // C. Save the new evaluation document
        transaction.set(evalRef, {
          'teacherId':     widget.instructorData.id,
          'teacherName':   widget.instructorData['name'],
          'evaluatorId':   widget.studentData['id'],
          'role':          'STUDENT',
          'section':       widget.studentData['section'],
          'weightedScore': weightedScore,
          'rawAverage':    rawAvg,
          'responses':     structuredResponses,
          'comment':       _commentController.text.trim(),
          'timestamp':     FieldValue.serverTimestamp(),
          // 'semester':   'A.Y. 2025-2026 | 1st Sem', <-- You can add your active semester variable here later!
        });

        // D. Update the teacher's profile with the pre-calculated average
        transaction.set(teacherRef, {
          'totalScore': newTotalScore,
          'evaluationCount': newEvalCount,
          'currentAverage': newAverage,
        }, SetOptions(merge: true));

        // E. Delete the student's draft
        transaction.delete(draftRef);
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
          content: Text("Error submitting evaluation: $e"),
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
        title: Text("EVALUATING: ${widget.instructorData['name']}",
            style: const TextStyle(color: GrcColors.gold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
        iconTheme: const IconThemeData(color: GrcColors.gold),
        actions: [
          if (!_loadingCriteria)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  "${_scores.length} / ${_criteria.length} rated",
                  style: TextStyle(
                      color: _scores.length == _criteria.length
                          ? Colors.greenAccent
                          : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loadingCriteria
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: GrcColors.maroon),
            SizedBox(height: 12),
            Text("Loading evaluation criteria...",
                style: TextStyle(color: GrcColors.textLight, fontSize: 13)),
          ],
        ),
      )
          : _criteria.isEmpty
          ? const Center(
        child: Text("No criteria found. Ask your Program Head to redeploy.",
            style: TextStyle(color: GrcColors.textLight)),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            decoration: BoxDecoration(
                color: GrcColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _criteria.isEmpty
                        ? 0
                        : _scores.length / _criteria.length,
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
                        hintText: "Optional: Provide constructive feedback for your instructor...",
                        hintStyle: const TextStyle(color: GrcColors.textLight, fontSize: 13),
                        filled: true,
                        fillColor: GrcColors.background.withOpacity(0.5),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: GrcColors.border)
                        ),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: GrcColors.maroon, width: 1.5)
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: GrcColors.maroon, width: 1.5),
                                minimumSize: const Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                            onPressed: _submitting ? null : _saveDraft,
                            child: const Text("SAVE DRAFT",
                                style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: GrcColors.maroon,
                                minimumSize: const Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                            onPressed: _submitting ? null : _submitForm,
                            child: _submitting
                                ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                    color: GrcColors.gold, strokeWidth: 2))
                                : const Text("SUBMIT EVALUATION",
                                style: TextStyle(color: GrcColors.gold,
                                    fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
                          ),
                        ),
                      ],
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
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (var doc in _criteria) {
      final d       = doc.data() as Map<String, dynamic>;
      final section = d['section'] ?? 'General';
      grouped.putIfAbsent(section, () => []).add(doc);
    }

    final List<Widget> widgets = [];
    grouped.forEach((sectionTitle, docs) {
      widgets.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: const BoxDecoration(
            color: GrcColors.background,
            border: Border(bottom: BorderSide(color: GrcColors.border))
        ),
        child: Text(sectionTitle.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.maroon, letterSpacing: 1)),
      ));
      for (var doc in docs) {
        final d     = doc.data() as Map<String, dynamic>;
        final index = d['index'] as int;
        final text  = d['text']  as String? ?? 'Criteria #$index';
        widgets.add(_buildEvalRow(index, text));
      }
    });
    return widgets;
  }

  Widget _buildEvalRow(int index, String criteriaText) {
    final key   = 'row_$index';
    final score = _scores[key] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GrcColors.border))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$index.  ',
                    style: const TextStyle(
                        fontSize: 13, color: GrcColors.textLight, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: criteriaText,
                    style: const TextStyle(fontSize: 14, color: GrcColors.textDark, height: 1.4),
                  ),
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
                        borderRadius: BorderRadius.circular(8)
                    ),
                    child: Column(
                      children: [
                        Icon(
                          score == val ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 24,
                          color: score == val ? GrcColors.maroon : GrcColors.textLight.withOpacity(0.5),
                        ),
                        const SizedBox(height: 4),
                        Text('$val',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: score == val ? FontWeight.bold : FontWeight.normal,
                                color: score == val ? GrcColors.maroon : GrcColors.textLight)),
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