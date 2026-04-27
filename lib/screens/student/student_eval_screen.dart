import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/grc_theme.dart';
import '../../widgets/split_panel_scaffold.dart';
import 'evaluation_form_screen.dart';

/// [TeacherListScreen] – Student dashboard.
/// Uses [SplitPanelScaffold] (same as Admin/Dean/PH) with three side-nav items:
/// Pending · History · Profile.
class TeacherListScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const TeacherListScreen({required this.userData, super.key});

  @override
  State<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends State<TeacherListScreen> {
  int _selectedIndex = 0;
  int _refreshKey = 0;

  // ── computed from userData ──────────────────────────────────────────────
  late final List<dynamic> _enrolledSubjects;
  late final List<String> _targetSections;
  late final String _displayTitle;

  @override
  void initState() {
    super.initState();
    _enrolledSubjects = widget.userData['enrolled_subjects'] ?? [];

    final List<String> secs = [];
    final raw = widget.userData['section']?.toString() ?? '';
    if (raw.isNotEmpty) {
      secs.add(raw);
      if (!raw.contains('-') && raw.length == 3) secs.add('BSIT - $raw');
    }
    for (var s in _enrolledSubjects) {
      final sec = s['section']?.toString() ?? '';
      if (sec.isNotEmpty) {
        secs.add(sec);
        if (!sec.contains('-') && sec.length == 3) secs.add('BSIT - $sec');
      }
    }
    var unique = secs.toSet().toList();
    if (unique.length > 10) unique = unique.sublist(0, 10);
    if (unique.isEmpty) unique = ['N/A'];
    _targetSections = unique;
    _displayTitle = _enrolledSubjects.isNotEmpty ? 'CUSTOM SCHEDULE' : _targetSections.first;
  }

  // ── pull-to-refresh ─────────────────────────────────────────────────────
  Future<void> _onRefresh() async {
    setState(() => _refreshKey++);
    // Small delay so the spinner is visible before streams re-emit
    await Future.delayed(const Duration(milliseconds: 600));
  }

  /// Wraps a non-scrollable widget in a scrollable container so
  /// [RefreshIndicator] can still be triggered by dragging.
  Widget _scrollableCenter(BuildContext context, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }

  // ── report issue ────────────────────────────────────────────────────────
  void _showReportIssueDialog(BuildContext context) {
    final ctrl = TextEditingController();
    String issueType = 'Missing Instructor';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrcColors.surface,
        title: const Text('Report an Issue',
            style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: issueType,
              decoration: const InputDecoration(labelText: 'Issue Type', border: OutlineInputBorder()),
              items: ['Missing Instructor', 'Wrong Subject Listed', 'App Bug', 'Other']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => issueType = v!,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Describe the problem...',
                  border: OutlineInputBorder(),
                  hintStyle: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: GrcColors.textLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('reported_issues').add({
                  'studentId': widget.userData['id'],
                  'studentName': widget.userData['name'],
                  'section': widget.userData['section'] ?? 'IRREGULAR',
                  'type': issueType,
                  'description': ctrl.text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'Open',
                });
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Issue reported to administration!'), backgroundColor: Colors.green));
                }
              }
            },
            child: const Text('SUBMIT', style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    Widget body = _buildBody(context);

    // Wrap in RefreshIndicator on mobile only
    if (isMobile) {
      body = RefreshIndicator(
        color: GrcColors.maroon,
        backgroundColor: GrcColors.surface,
        displacement: 50,
        onRefresh: _onRefresh,
        child: body,
      );
    }

    return SplitPanelScaffold(
      title: 'GRC EVALUATIONS',
      subtitle: _displayTitle,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.pending_actions_outlined), label: Text('Pending')),
        NavigationRailDestination(icon: Icon(Icons.history_outlined),         label: Text('History')),
        NavigationRailDestination(icon: Icon(Icons.person_outline),           label: Text('Profile')),
      ],
      floatingActionButton: FloatingActionButton(
        backgroundColor: GrcColors.maroon,
        tooltip: 'Report Issue',
        onPressed: () => _showReportIssueDialog(context),
        child: const Icon(Icons.report_problem_outlined, color: GrcColors.gold),
      ),
      body: body,
    );
  }

  // ── body dispatcher ─────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context) {
    // Profile needs no streams
    if (_selectedIndex == 2) return _buildProfileTab(context, _enrolledSubjects);

    // Pending & History share the stream chain
    // Key changes when _refreshKey increments, forcing a fresh stream subscription
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('section_stream_$_refreshKey'),
      stream: FirebaseFirestore.instance
          .collection('section_assignments')
          .where(FieldPath.documentId, whereIn: _targetSections)
          .where('status', isEqualTo: 'AI_ACTIVE')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _scrollableCenter(
            context,
            const Center(child: CircularProgressIndicator(color: GrcColors.maroon)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (_selectedIndex == 0) {
            return _scrollableCenter(
              context,
              Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.auto_awesome, size: 50, color: GrcColors.maroon),
                  const SizedBox(height: 20),
                  Text('NO PENDING EVALUATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('You currently have no evaluation forms to complete.',
                      style: TextStyle(color: GrcColors.textLight, fontSize: 12)),
                ]),
              ),
            );
          }
          return _scrollableCenter(
            context,
            const Center(child: Text('No history available.', style: TextStyle(color: GrcColors.textLight))),
          );
        }

        List<String> allTeacherIds = [];
        Map<String, String> teacherToSection = {};
        Timestamp? deployedAt;
        Timestamp? deadlineTs;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final List<String> tIds = (data['teacherIds'] ?? []).map<String>((e) => e.toString()).toList();
          allTeacherIds.addAll(tIds);
          for (var id in tIds) {
            teacherToSection[id] = doc.id; // Map each teacher to the section ID they were found in
          }
          deployedAt ??= data['deployedAt'] as Timestamp?;
          deadlineTs ??= data['deadline'] as Timestamp?;
        }
        allTeacherIds = allTeacherIds.toSet().toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
          builder: (context, tSnapshot) {
            if (!tSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

            var assigned = tSnapshot.data!.docs.where((doc) {
              if (!allTeacherIds.contains(doc.id)) return false;
              final tSubId = (doc['subjectId'] ?? '').toString().trim().toUpperCase();
              if (_enrolledSubjects.isNotEmpty) {
                return _enrolledSubjects.any((sub) =>
                    (sub['code'] ?? '').toString().trim().toUpperCase() == tSubId);
              }
              return true;
            }).toList();

            if (assigned.isEmpty) {
              return const Center(
                  child: Text('No instructors assigned to this section.',
                      style: TextStyle(color: GrcColors.textLight)));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('evaluations')
                  .where('evaluatorId', isEqualTo: widget.userData['id'])
                  .snapshots(),
              builder: (context, evalSnap) {
                if (!evalSnap.hasData) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                final evaluatedIds = evalSnap.data!.docs.map((d) => d['teacherId'].toString()).toList();
                final pending   = assigned.where((i) => !evaluatedIds.contains(i.id)).toList();
                final completed = assigned.where((i) =>  evaluatedIds.contains(i.id)).toList();

                if (_selectedIndex == 0) {
                  return _buildPendingTab(context, pending, _enrolledSubjects, teacherToSection, deployedAt, deadlineTs);
                }
                return _buildHistoryTab(context, completed, evalSnap.data!.docs, teacherToSection);
              },
            );
          },
        );
      },
    );
  }

  // ── pending tab ─────────────────────────────────────────────────────────
  Widget _buildPendingTab(BuildContext context, List<QueryDocumentSnapshot> pendingInstructors,
      List<dynamic> enrolledSubjects, Map<String, String> teacherToSection, Timestamp? deployedAt, Timestamp? deadlineTs) {
    if (pendingInstructors.isEmpty) {
      final now = DateTime.now();
      final months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: GrcColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text('EVALUATION CLEARANCE GRANTED',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GrcColors.textDark, letterSpacing: 1),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(widget.userData['name'].toString().toUpperCase(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GrcColors.maroon),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Date Cleared: ${months[now.month - 1]} ${now.day}, ${now.year}',
                style: const TextStyle(fontSize: 12, color: GrcColors.textLight)),
            const SizedBox(height: 24),
            const Divider(color: GrcColors.border),
            const SizedBox(height: 24),
            const Text('You have successfully completed all your required evaluations.',
                style: TextStyle(color: GrcColors.textDark, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    String deadlineText = 'Evaluation Deadline: Open';
    Color deadlineColor = Colors.orange;
    DateTime? deadlineDate;
    if (deadlineTs != null) {
      deadlineDate = deadlineTs.toDate();
    } else if (deployedAt != null) {
      deadlineDate = deployedAt.toDate().add(const Duration(days: 7));
    }
    if (deadlineDate != null) {
      final daysLeft = deadlineDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        deadlineText = 'Deadline Passed! Please submit immediately.';
        deadlineColor = Colors.red;
      } else {
        deadlineText = 'Evaluation closes in $daysLeft day(s) (Due: ${deadlineDate.day}/${deadlineDate.month}/${deadlineDate.year})';
        deadlineColor = daysLeft <= 2 ? Colors.red : Colors.orange;
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final pad = constraints.maxWidth < 600 ? 14.0 : 24.0;
      return ListView(padding: EdgeInsets.all(pad), children: [
        // Deadline banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: deadlineColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: deadlineColor)),
          child: Row(children: [
            Icon(Icons.timer, color: deadlineColor, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(deadlineText,
                style: TextStyle(color: deadlineColor, fontWeight: FontWeight.bold, fontSize: 11))),
          ]),
        ),
        // Anonymity banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: GrcColors.gold.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GrcColors.gold)),
          child: const Row(children: [
            Icon(Icons.lock_outline, color: GrcColors.maroon, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
                'Your responses are 100% anonymous. Instructors cannot see who submitted an evaluation.',
                style: TextStyle(fontSize: 11, color: GrcColors.textDark, fontWeight: FontWeight.w600))),
          ]),
        ),
        ...pendingInstructors.map((instructor) {
          String specificSection = teacherToSection[instructor.id] ?? 'N/A';
          return _buildInstructorCard(context, instructor, false, null, specificSection);
        }),
      ]);
    });
  }

  // ── history tab ─────────────────────────────────────────────────────────
  Widget _buildHistoryTab(BuildContext context, List<QueryDocumentSnapshot> completedInstructors,
      List<QueryDocumentSnapshot> allEvals, Map<String, String> teacherToSection) {
    final now = DateTime.now();
    final List<QueryDocumentSnapshot> recent = [];
    final Map<String, Map<String, dynamic>> recentEvalData = {};

    for (var instructor in completedInstructors) {
      final evalDoc = allEvals.firstWhere((e) => e['teacherId'] == instructor.id);
      final evalData = evalDoc.data() as Map<String, dynamic>;
      final ts = evalData['timestamp'] as Timestamp?;
      if (ts == null || now.difference(ts.toDate()).inDays <= 15) {
        recent.add(instructor);
        recentEvalData[instructor.id] = evalData;
      }
    }

    if (recent.isEmpty) {
      return const Center(child: Text('No recent evaluations in the last 15 days.', style: TextStyle(color: GrcColors.textLight)));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final pad = constraints.maxWidth < 600 ? 14.0 : 24.0;
      return ListView(padding: EdgeInsets.all(pad), children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
                'History automatically clears 15 days after submission. Your records are securely saved in the database.',
                style: TextStyle(fontSize: 11, color: GrcColors.textDark))),
          ]),
        ),
        ...recent.map((instructor) =>
            _buildInstructorCard(context, instructor, true, recentEvalData[instructor.id]!, teacherToSection[instructor.id] ?? 'N/A')),
      ]);
    });
  }

  // ── profile tab ─────────────────────────────────────────────────────────
  Widget _buildProfileTab(BuildContext context, List<dynamic> enrolledSubjects) {
    final rawName = widget.userData['name'].toString().toUpperCase();
    final parts = rawName.split(' ');
    String initials = parts.isNotEmpty ? parts.first[0] : '';
    if (parts.length > 1) initials += parts.last[0];

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final pad = isMobile ? 14.0 : 24.0;
      final avatarRadius = isMobile ? 38.0 : 50.0;
      final nameFont = isMobile ? 18.0 : 22.0;

      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: GrcColors.maroon,
                child: Text(initials,
                    style: TextStyle(fontSize: avatarRadius * 0.72, fontWeight: FontWeight.bold,
                        color: GrcColors.gold, letterSpacing: 2)),
              ),
              const SizedBox(height: 16),
              Text(rawName, style: TextStyle(fontSize: nameFont, fontWeight: FontWeight.bold, color: GrcColors.textDark), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Student ID: ${widget.userData['id']}', style: const TextStyle(fontSize: 13, color: GrcColors.textLight)),
              const SizedBox(height: 28),
              Card(
                color: GrcColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: GrcColors.border)),
                child: Column(children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GrcColors.maroon.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.email, color: GrcColors.maroon, size: 20)),
                    title: const Text('Email Address', style: TextStyle(fontSize: 11, color: GrcColors.textLight)),
                    subtitle: Text(widget.userData['email'] ?? 'N/A', style: const TextStyle(fontSize: 14, color: GrcColors.textDark, fontWeight: FontWeight.w600)),
                  ),
                  const Divider(height: 1, color: GrcColors.border),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GrcColors.maroon.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.class_, color: GrcColors.maroon, size: 20)),
                    title: Text(enrolledSubjects.isNotEmpty ? 'Enrolled Subjects' : 'Section & Course',
                        style: const TextStyle(fontSize: 11, color: GrcColors.textLight)),
                    subtitle: Text(
                        enrolledSubjects.isNotEmpty
                            ? '${enrolledSubjects.length} Custom Subjects Found'
                            : '${widget.userData['section'] ?? 'N/A'} • ${widget.userData['department'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 14, color: GrcColors.textDark, fontWeight: FontWeight.w600)),
                  ),
                  if (enrolledSubjects.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
                      width: double.infinity,
                      child: Column(children: enrolledSubjects.map((s) {
                        final code = s['code']?.toString() ?? 'Unknown';
                        final title = s['title']?.toString() ?? '';
                        final displayTitle = title.isNotEmpty ? title : 'Custom Subject';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: GrcColors.border, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))]),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: GrcColors.maroon.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.menu_book, color: GrcColors.maroon, size: 18)),
                            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GrcColors.textDark)),
                              if (s['section'] != null)
                                Text('Section: ${s['section']}', style: const TextStyle(fontSize: 10, color: GrcColors.textLight)),
                            ]),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: GrcColors.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                              child: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: GrcColors.maroon)),
                            ),
                          ),
                        );
                      }).toList()),
                    ),
                  const Divider(height: 1, color: GrcColors.border),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.verified_user, color: Colors.green, size: 20)),
                    title: const Text('Account Status', style: TextStyle(fontSize: 11, color: GrcColors.textLight)),
                    subtitle: Text(widget.userData['status'] ?? 'APPROVED',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
    });
  }

  // ── instructor card ─────────────────────────────────────────────────────
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Completed recently';
    final dt = (timestamp as Timestamp).toDate();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$min $ampm';
  }

  Widget _buildInstructorCard(BuildContext context, QueryDocumentSnapshot instructor,
      bool isDone, Map<String, dynamic>? evalData, String section) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 500;
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(isMobile ? 12 : 18),
        decoration: BoxDecoration(
            color: GrcColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDone ? Colors.green.withOpacity(0.4) : GrcColors.border,
                width: isDone ? 1.5 : 1.0),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: isDone ? Colors.green.withOpacity(0.1) : GrcColors.maroon.withOpacity(0.1),
              radius: isMobile ? 18 : 22,
              child: Icon(isDone ? Icons.check_circle : Icons.person,
                  color: isDone ? Colors.green : GrcColors.maroon, size: isMobile ? 18 : 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(instructor['name'],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: isMobile ? 13 : 15, color: GrcColors.textDark)),
                const SizedBox(height: 3),
                Text('${instructor['subject']} • Sec: $section',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: isMobile ? 11 : 12, color: GrcColors.textLight)),
              ]),
            ),
            if (isDone)
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: Colors.green, size: 13),
                SizedBox(width: 3),
                Text('DONE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
          ]),
          if (!isDone) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: GrcColors.maroon, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (context) => EvaluationFormScreen(
                        instructorData: instructor, studentData: widget.userData, section: section))),
                child: const Text('EVALUATE',
                    style: TextStyle(color: GrcColors.gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_formatTimestamp(evalData?['timestamp']),
                  style: const TextStyle(fontSize: 10, color: GrcColors.textLight)),
            ),
        ]),
      );
    });
  }
}