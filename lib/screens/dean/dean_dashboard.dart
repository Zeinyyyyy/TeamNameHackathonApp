// lib/screens/dean/dean_dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/grc_theme.dart';
import '../../widgets/split_panel_scaffold.dart';
import 'tabs/teacher_evaluation_tab.dart';
import 'tabs/anonymous_feedback_tab.dart';
import 'tabs/audit_logs_tab.dart';
import 'tabs/export_reminders_tab.dart';
import 'tabs/ai_insights_tab.dart';
import 'tabs/assign_evaluators_tab.dart';
import 'tabs/dean_evaluate_tab.dart';
import 'tabs/analytics_tab.dart';

/// [DeanDashboard] serves as the primary navigation scaffold for Deans.
/// It uses the `SplitPanelScaffold` to render a sidebar menu, and switches between 
/// tabs (Teacher Evaluations, Anonymous Feedback, AI Insights, etc.) 
/// while preserving navigation state.
class DeanDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DeanDashboard({required this.userData, super.key});

  @override
  State<DeanDashboard> createState() => _DeanDashboardState();
}

class _DeanDashboardState extends State<DeanDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedTab();
  }

  Future<void> _loadSavedTab() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedIndex = prefs.getInt('dean_tab_index') ?? 0;
      });
    }
  }

  Future<void> _saveTab(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dean_tab_index', index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      TeacherEvaluationPage(userData: widget.userData),
      AnonymousFeedbackTab(userData: widget.userData),
      const AuditLogsPage(),
      ExportAndRemindersPage(userData: widget.userData),
      const InstructorListTab(),
      const AssignEvaluatorsPage(),
      DeanEvaluateTab(userData: widget.userData),
      const AnalyticsPage(),
    ];

    return SplitPanelScaffold(
      title: "DEAN",
      subtitle: widget.userData['name'].toString().toUpperCase(),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) {
        setState(() => _selectedIndex = i);
        _saveTab(i);
      },
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined),      label: Text("Leaderboard")),
        NavigationRailDestination(icon: Icon(Icons.feedback_outlined),       label: Text("Feedback")),
        NavigationRailDestination(icon: Icon(Icons.history_outlined),        label: Text("Audit")),
        NavigationRailDestination(icon: Icon(Icons.send_to_mobile_outlined), label: Text("Export")),
        NavigationRailDestination(icon: Icon(Icons.psychology_outlined),     label: Text("AI")),
        NavigationRailDestination(icon: Icon(Icons.assignment_ind),          label: Text("Assign")),
        NavigationRailDestination(icon: Icon(Icons.rate_review_outlined),    label: Text("Evaluate")),
        NavigationRailDestination(icon: Icon(Icons.analytics_outlined),      label: Text("Reports")),
      ],
      body: pages[_selectedIndex],
    );
  }
}