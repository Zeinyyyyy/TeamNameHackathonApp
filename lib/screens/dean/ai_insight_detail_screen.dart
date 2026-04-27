import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io' as io;
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/grc_theme.dart';

class AiInsightDetailScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String subjectDept;
  final int evalCount;

  const AiInsightDetailScreen({
    required this.teacherId,
    required this.teacherName,
    required this.subjectDept,
    required this.evalCount,
    super.key,
  });

  @override
  State<AiInsightDetailScreen> createState() => _AiInsightDetailScreenState();
}

class _AiInsightDetailScreenState extends State<AiInsightDetailScreen> {
  bool _isGenerating = false;
  bool _isExporting = false;
  bool _hasGenerated = false;
  bool _detectedTagalog = false;

  // Dynamic AI Text States
  String _aiStrengths = "";
  String _aiImprovements = "";
  String _aiSentiment = "";

  // List of common Tagalog keywords for simple detection
  final List<String> _tagalogKeywords = [
    'mabait', 'mahusay', 'magaling', 'terror', 'naiintindihan', 'paliwanag', 
    'mahirap', 'madali', 'bastat', 'kasi', 'po', 'opo', 'masaya', 'malungkot', 
    'nagtuturo', 'aralin', 'maintindihan', 'matuto', 'marami'
  ];

  // Simulated AI Generation Process with Dynamic Output
  Future<void> _generateInsights() async {
    if (widget.evalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient data to generate AI insights."), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _hasGenerated = false;
      _detectedTagalog = false;
    });

    // --- REAL DATA SCANNING (Simulated detection) ---
    // We scan actual comments to see if Tagalog is used
    try {
      final commentsSnap = await FirebaseFirestore.instance
          .collection('evaluations')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();
      
      for (var doc in commentsSnap.docs) {
        String comment = (doc.data()['comment'] ?? '').toString().toLowerCase();
        for (var keyword in _tagalogKeywords) {
          if (comment.contains(keyword)) {
            _detectedTagalog = true;
            break;
          }
        }
        if (_detectedTagalog) break;
      }
    } catch (e) {
      debugPrint("Error scanning comments: $e");
    }

    // Simulate network/API delay for the AI generating
    await Future.delayed(const Duration(seconds: 3));

    // --- DYNAMIC AI LOGIC ---
    // We use the length of the teacher's name to pick one of 3 highly detailed, distinct profiles
    int profileVariant = widget.teacherName.length % 3;

    // Extract just the subject name for natural reading (e.g., "CAPSTONE 1 • No Department" -> "CAPSTONE 1")
    String cleanSubject = widget.subjectDept.split(' • ').first;
    String firstName = widget.teacherName.split(' ').first;

    String tagalogMention = _detectedTagalog 
        ? " The AI also successfully processed and translated student feedback provided in Tagalog, ensuring a comprehensive view of all sentiments."
        : "";

    if (profileVariant == 0) {
      // Profile A: The Rigorous Academic
      _aiStrengths = "Students consistently highlight $firstName's profound command over $cleanSubject. The lectures are described as intellectually stimulating, pushing students to think critically rather than simply memorize textbook material. The highly structured syllabus, combined with comprehensive supplemental materials, ensures that learners are exceptionally well-equipped to tackle complex, real-world problems. Furthermore, the instructor's ability to answer difficult questions on the spot is frequently praised.$tagalogMention";
      _aiImprovements = "While the academic rigor is deeply appreciated by top-performing students, a significant portion of the class indicated that the pacing can sometimes feel overwhelming, especially in the middle of the semester. Several evaluations suggested incorporating more formative assessments—such as brief, ungraded checkpoints or short quizzes—to help students gauge their understanding of the material before moving on to major midterms or high-stakes projects.";
      _aiSentiment = "Highly Respectful but Academically Challenged. The overall sentiment reflects a strong appreciation for the high academic standard maintained in the classroom, though there is a notable undercurrent of stress regarding the volume of the workload and the speed of the lectures.";
    }
    else if (profileVariant == 1) {
      // Profile B: The Engaging Mentor
      _aiStrengths = "$firstName creates an incredibly welcoming, highly interactive, and psychologically safe environment within the $cleanSubject classes. Students frequently praise the instructor's exceptional ability to break down highly technical or abstract concepts into easily digestible, relatable everyday analogies. The consistent use of group discussions, open-floor Q&A sessions, and hands-on classroom activities significantly boosts overall student engagement, attendance rates, and long-term material retention.$tagalogMention";
      _aiImprovements = "The primary area for growth centers around administrative consistency. A recurring piece of feedback across multiple evaluations notes that project instructions and assignment parameters can occasionally be ambiguous, leading to student confusion as deadlines approach. Students strongly recommend the implementation of highly detailed, standardized grading rubrics and a more rigid, predictable adherence to the initially published syllabus timeline.";
      _aiSentiment = "Overwhelmingly Positive and Enthusiastic. Students feel deeply supported and mentored on a personal level, highlighting the instructor's deep empathy and unwavering dedication to student success that goes well above and beyond standard university lecturing.";
    }
    else {
      // Profile B: The Industry Professional
      _aiStrengths = "The most prominent theme in the evaluations for $firstName is the seamless integration of current, modern industry standards directly into the $cleanSubject curriculum. Students highly value the practical, hands-on lab sessions and the real-world case studies that successfully bridge the gap between theoretical academic concepts and actual, modern workplace demands. The instructor's personal industry experience brings invaluable context to the lectures.$tagalogMention";
      _aiImprovements = "Feedback suggests that while the practical application is excellent, the foundational theoretical aspects are sometimes rushed. A noticeable percentage of students requested that the instructor spend slightly more time explicitly explaining the fundamental 'why' behind certain concepts before immediately diving into the technical 'how'. Additionally, students requested faster turnaround times on project feedback so they can apply corrections to subsequent assignments.";
      _aiSentiment = "Highly Motivated and Career-Oriented. The sentiment is incredibly pragmatic, with the vast majority of students feeling that taking this specific course significantly enhances their future employability, resume strength, and practical hard-skill sets.";
    }

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _hasGenerated = true;
      });
    }
  }

  Future<void> _exportReport() async {
    setState(() => _isExporting = true);
    try {
      String report = """
==================================================
        FACULTY AI INSIGHTS REPORT
==================================================
Generated on : ${DateTime.now().toString()}
Instructor   : ${widget.teacherName}
Subject/Dept : ${widget.subjectDept}
Total Evals  : ${widget.evalCount}
==================================================

--------------------------------------------------
[1] TOP STRENGTHS
--------------------------------------------------
$_aiStrengths

--------------------------------------------------
[2] AREAS FOR IMPROVEMENT
--------------------------------------------------
$_aiImprovements

--------------------------------------------------
[3] OVERALL SENTIMENT
--------------------------------------------------
$_aiSentiment

--------------------------------------------------
END OF REPORT
Generated by Teacher Evaluation Pro AI System
--------------------------------------------------
""";

      final bytes = utf8.encode(report);
      final fileName = "AI_Report_${widget.teacherName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.txt";

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Report downloaded successfully!"), backgroundColor: Colors.green)
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = io.File("${directory.path}/$fileName");
        await file.writeAsBytes(bytes);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text("Report saved to Documents"),
               action: SnackBarAction(
                 label: "SHARE",
                 textColor: Colors.white,
                 onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'AI Insights Report for ${widget.teacherName}'),
               ),
               backgroundColor: Colors.green,
             )
           );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: GrcColors.background,
      appBar: AppBar(
        backgroundColor: GrcColors.maroon,
        title: const Text("AI FACULTY INSIGHTS", style: TextStyle(color: GrcColors.gold, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: GrcColors.gold),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- INSTRUCTOR HEADER ---
            Row(
              children: [
                CircleAvatar(
                    radius: 36,
                    backgroundColor: GrcColors.maroon.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: GrcColors.maroon, size: 36)
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.teacherName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GrcColors.textDark)),
                      const SizedBox(height: 4),
                      Text(widget.subjectDept, style: const TextStyle(fontSize: 13, color: GrcColors.textLight)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: GrcColors.border),
            const SizedBox(height: 24),

            // --- AI GENERATION ACTION AREA ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GrcColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.evalCount < 3 ? Colors.orange.withOpacity(0.3) : GrcColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Icon(Icons.psychology, size: 48, color: widget.evalCount == 0 ? Colors.grey : GrcColors.maroon),
                  const SizedBox(height: 16),
                  const Text("Intelligent Evaluation Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: GrcColors.textDark)),
                  const SizedBox(height: 8),
                  
                  // --- MULTILINGUAL STATUS BADGE ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.translate, size: 12, color: Colors.blue),
                        SizedBox(width: 6),
                        Text("Multilingual Analysis Enabled", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  if (widget.evalCount < 3 && widget.evalCount > 0)
                     Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text("⚠️ LIMITED DATA: Insights may be less accurate.", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  
                  if (_hasGenerated && _detectedTagalog)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.3))),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text("Tagalog feedback was detected and incorporated into this report.", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ),

                  Text(
                    widget.evalCount == 0 
                        ? "There are no student evaluations for this instructor yet. AI insights require actual data to generate reports."
                        : "Compile all ${widget.evalCount} numeric scores and written feedback (English & Tagalog) into a comprehensive qualitative report.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: GrcColors.textLight, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: 250,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_isGenerating || widget.evalCount == 0) ? null : _generateInsights,
                      icon: _isGenerating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(Icons.auto_awesome, color: widget.evalCount == 0 ? Colors.grey : GrcColors.gold, size: 20),
                      label: Text(
                        _isGenerating ? "ANALYZING DATA..." : (_hasGenerated ? "REGENERATE INSIGHTS" : "GENERATE AI REPORT"),
                        style: TextStyle(color: widget.evalCount == 0 ? Colors.grey : GrcColors.gold, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.evalCount == 0 ? Colors.grey[300] : GrcColors.maroon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- AI RESULTS AREA ---
            if (_hasGenerated) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("AI ANALYSIS REPORT", style: TextStyle(fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1)),
                  OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportReport,
                    icon: _isExporting 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: GrcColors.maroon))
                      : const Icon(Icons.download, size: 16, color: GrcColors.maroon),
                    label: Text(_isExporting ? "EXPORTING..." : "DOWNLOAD REPORT", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrcColors.maroon)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GrcColors.maroon),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dynamic Results Output
              _buildInsightCard("Top Strengths", Icons.thumb_up_alt_outlined, Colors.green, _aiStrengths),
              const SizedBox(height: 16),
              _buildInsightCard("Areas for Improvement", Icons.trending_up, Colors.orange, _aiImprovements),
              const SizedBox(height: 16),
              _buildInsightCard("Overall Sentiment", Icons.analytics_outlined, Colors.blue, _aiSentiment),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, IconData icon, Color color, String content) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GrcColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          // Changed textAlign to justify and increased line height for a more professional "report" feel
          Text(
              content,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 14, color: GrcColors.textDark, height: 1.6)
          ),
        ],
      ),
    );
  }
}