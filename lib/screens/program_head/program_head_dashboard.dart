// lib/screens/program_head/program_head_dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/grc_theme.dart';
import '../../widgets/split_panel_scaffold.dart';
import 'tabs/evaluation_statistics_tab.dart';
import 'tabs/add_instructor_tab.dart';
import 'tabs/assign_section_tab.dart';
import 'tabs/ph_evaluate_tab.dart';

/// [ProgramHeadDashboard] serves as the primary navigation scaffold for Program Heads.
/// It uses the `SplitPanelScaffold` to render a sidebar menu, allowing Program Heads 
/// to manage their specific department's instructors, view statistics, and assign sections.
class ProgramHeadDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProgramHeadDashboard({required this.userData, super.key});

  @override
  State<ProgramHeadDashboard> createState() => _ProgramHeadDashboardState();
}

class _ProgramHeadDashboardState extends State<ProgramHeadDashboard> {
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
        _selectedIndex = prefs.getInt('ph_tab_index') ?? 0;
      });
    }
  }

  Future<void> _saveTab(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ph_tab_index', index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      EvaluationStatistics(userData: widget.userData),
      const AddInstructorTab(),
      AssignSectionTab(userData: widget.userData),
      PhEvaluateTab(userData: widget.userData),
    ];

    return SplitPanelScaffold(
      title: "PROGRAM HEAD",
      subtitle: widget.userData['name'].toString().toUpperCase(),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) {
        setState(() => _selectedIndex = i);
        _saveTab(i);
      },
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.analytics_outlined),      label: Text("Analytics")),
        NavigationRailDestination(icon: Icon(Icons.person_add_outlined),     label: Text("Faculty")),
        NavigationRailDestination(icon: Icon(Icons.assignment_ind_outlined), label: Text("Deploy")),
        NavigationRailDestination(icon: Icon(Icons.rate_review_outlined),    label: Text("Evaluate")),
      ],
      body: pages[_selectedIndex],
    );
  }
}