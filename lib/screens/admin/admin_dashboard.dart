// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/grc_theme.dart';
import '../../widgets/split_panel_scaffold.dart';
import 'tabs/system_overview_tab.dart';
import 'tabs/user_management_tab.dart';
import 'tabs/global_settings_tab.dart';
import 'tabs/rooms_management_tab.dart';
import 'tabs/support_tickets_tab.dart';
import 'tabs/admin_support_tab.dart';
import 'tabs/data_import_tab.dart';

/// [AdminDashboard] serves as the primary navigation scaffold for System Admins.
/// It uses the `SplitPanelScaffold` to render a sidebar menu, and switches between 
/// the various management tabs (Overview, Users, Rooms, Import, Security, etc.)
/// while preserving navigation state via SharedPreferences.
class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminDashboard({required this.userData, super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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
        _selectedIndex = prefs.getInt('admin_tab_index') ?? 0;
      });
    }
  }

  Future<void> _saveTab(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('admin_tab_index', index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const AdminOverviewTab(),
      const UserManagementTab(),
      const RoomsManagementTab(),
      const DataImportTab(),
      const SupportTicketsTab(),
      const AdminSupportTab(),
      const GlobalSettingsTab(),
    ];

    return SplitPanelScaffold(
      title: "SYSTEM ADMIN",
      subtitle: widget.userData['name'].toString().toUpperCase(),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) {
        setState(() => _selectedIndex = i);
        _saveTab(i);
      },
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.dashboard_outlined),           label: Text("Overview")),
        NavigationRailDestination(icon: Icon(Icons.people_alt_outlined),          label: Text("Users")),
        NavigationRailDestination(icon: Icon(Icons.meeting_room_outlined),        label: Text("Rooms")),
        NavigationRailDestination(icon: Icon(Icons.upload_file),                  label: Text("Import")),
        NavigationRailDestination(icon: Icon(Icons.confirmation_number_outlined), label: Text("Tickets")),
        NavigationRailDestination(icon: Icon(Icons.help_outline),                 label: Text("Support")),
        NavigationRailDestination(icon: Icon(Icons.admin_panel_settings),         label: Text("Security")),
      ],
      body: pages[_selectedIndex],
    );
  }
}