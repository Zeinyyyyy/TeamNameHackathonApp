import 'package:flutter/material.dart';
import '../../../theme/grc_theme.dart';

class AiInsightDetailScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String subjectDept;

  const AiInsightDetailScreen({
    required this.teacherId,
    required this.teacherName,
    required this.subjectDept,
    super.key,
  });

  @override
  State<AiInsightDetailScreen> createState() => _AiInsightDetailScreenState();
}

class _AiInsightDetailScreenState extends State<AiInsightDetailScreen> {
  bool _isGenerating = false;
  bool _hasGenerated = false;

  // Dynamic AI Text States
  String _aiStrengths = "";
  String _aiImprovements = "";
  String _aiSentiment = "";

  // Simulated AI Generation Process with Dynamic Output
  Future<void> _generateInsights() async {
    setState(() {
      _isGenerating = true;
      _hasGenerated = false;
    });

    // Simulate network/API delay for the AI generating
    await Future.delayed(const Duration(seconds: 3));

    // --- DYNAMIC AI LOGIC ---
    // We use the length of the teacher's name to pick one of 3 highly detailed, distinct profiles
    int profileVariant = widget.teacherName.length % 3;

    // Extract just the subject name for natural reading (e.g., "CAPSTONE 1 • No Department" -> "CAPSTONE 1")
    String cleanSubject = widget.subjectDept.split(' • ').first;
    String firstName = widget.teacherName.split(' ').first;

    if (profileVariant == 0) {
      // Profile A: The Rigorous Academic
      _aiStrengths = "Students consistently highlight $firstName's profound command over $cleanSubject. The lectures are described as intellectually stimulating, pushing students to think critically rather than simply memorize textbook material. The highly structured syllabus, combined with comprehensive supplemental materials, ensures that learners are exceptionally well-equipped to tackle complex, real-world problems. Furthermore, the instructor's ability to answer difficult questions on the spot is frequently praised.";
      _aiImprovements = "While the academic rigor is deeply appreciated by top-performing students, a significant portion of the class indicated that the pacing can sometimes feel overwhelming, especially in the middle of the semester. Several evaluations suggested incorporating more formative assessments—such as brief, ungraded checkpoints or short quizzes—to help students gauge their understanding of the material before moving on to major midterms or high-stakes projects.";
      _aiSentiment = "Highly Respectful but Academically Challenged. The overall sentiment reflects a strong appreciation for the high academic standard maintained in the classroom, though there is a notable undercurrent of stress regarding the volume of the workload and the speed of the lectures.";
    }
    else if (profileVariant == 1) {
      // Profile B: The Engaging Mentor
      _aiStrengths = "$firstName creates an incredibly welcoming, highly interactive, and psychologically safe environment within the $cleanSubject classes. Students frequently praise the instructor's exceptional ability to break down highly technical or abstract concepts into easily digestible, relatable everyday analogies. The consistent use of group discussions, open-floor Q&A sessions, and hands-on classroom activities significantly boosts overall student engagement, attendance rates, and long-term material retention.";
      _aiImprovements = "The primary area for growth centers around administrative consistency. A recurring piece of feedback across multiple evaluations notes that project instructions and assignment parameters can occasionally be ambiguous, leading to student confusion as deadlines approach. Students strongly recommend the implementation of highly detailed, standardized grading rubrics and a more rigid, predictable adherence to the initially published syllabus timeline.";
      _aiSentiment = "Overwhelmingly Positive and Enthusiastic. Students feel deeply supported and mentored on a personal level, highlighting the instructor's deep empathy and unwavering dedication to student success that goes well above and beyond standard university lecturing.";
    }
    else {
      // Profile C: The Industry Professional
      _aiStrengths = "The most prominent theme in the evaluations for $firstName is the seamless integration of current, modern industry standards directly into the $cleanSubject curriculum. Students highly value the practical, hands-on lab sessions and the real-world case studies that successfully bridge the gap between theoretical academic concepts and actual, modern workplace demands. The instructor's personal industry experience brings invaluable context to the lectures.";
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
                border: Border.all(color: GrcColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  const Icon(Icons.psychology, size: 48, color: GrcColors.maroon),
                  const SizedBox(height: 16),
                  const Text("Intelligent Evaluation Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: GrcColors.textDark)),
                  const SizedBox(height: 8),
                  const Text(
                    "Compile all numeric scores and written feedback into a comprehensive, easy-to-read qualitative report.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: GrcColors.textLight, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: 250,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateInsights,
                      icon: _isGenerating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, color: GrcColors.gold, size: 20),
                      label: Text(
                        _isGenerating ? "ANALYZING DATA..." : (_hasGenerated ? "REGENERATE INSIGHTS" : "GENERATE AI REPORT"),
                        style: const TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GrcColors.maroon,
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
              const Text("AI ANALYSIS REPORT", style: TextStyle(fontWeight: FontWeight.bold, color: GrcColors.maroon, letterSpacing: 1)),
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