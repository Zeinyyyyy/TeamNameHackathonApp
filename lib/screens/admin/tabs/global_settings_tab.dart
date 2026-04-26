import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

/// [GlobalSettingsTab] serves as the master control center for the System Admin.
/// Here, admins can configure the academic calendar, broadcast system-wide 
/// announcements, lock evaluations, or perform a total data wipe.
class GlobalSettingsTab extends StatefulWidget {
  const GlobalSettingsTab({super.key});

  @override
  State<GlobalSettingsTab> createState() => _GlobalSettingsTabState();
}

class _GlobalSettingsTabState extends State<GlobalSettingsTab> {
  bool _isLocked = false;
  final TextEditingController _broadcastController = TextEditingController();

  // 🟢 NEW: Academic Calendar States
  bool _isSavingCalendar = false;
  String _sem1Start = 'August';
  String _sem1End = 'December';
  String _sem2Start = 'January';
  String _sem2End = 'May';

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // --- Fetch the current settings from Firebase ---
  /// Loads the existing configurations (calendar months and evaluation lock) 
  /// from the 'settings/system' document in Firestore when the tab initializes.
  Future<void> _loadSettings() async {
    var doc = await FirebaseFirestore.instance.collection('settings').doc('system').get();
    if (doc.exists && mounted) {
      var data = doc.data()!;
      setState(() {
        _isLocked = data['evaluationLock'] ?? false;
        // Load the saved calendar months, or fall back to defaults
        _sem1Start = data['sem1Start'] ?? 'August';
        _sem1End = data['sem1End'] ?? 'December';
        _sem2Start = data['sem2Start'] ?? 'January';
        _sem2End = data['sem2End'] ?? 'May';
      });
    }
  }

  // 🟢 NEW: Save the customized Academic Calendar to Firebase
  Future<void> _saveAcademicCalendar() async {
    setState(() => _isSavingCalendar = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('system').set({
        'sem1Start': _sem1Start,
        'sem1End': _sem1End,
        'sem2Start': _sem2Start,
        'sem2End': _sem2End,
      }, SetOptions(merge: true));

      // Log the action for the Admin Audit Trail
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'Updated Academic Calendar configuration',
        'user': 'System Admin',
        'date': DateTime.now().toString(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Academic Calendar updated successfully!"),
            backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error saving calendar: $e"),
            backgroundColor: Colors.red
        ));
      }
    } finally {
      if (mounted) setState(() => _isSavingCalendar = false);
    }
  }

  // --- Save the lock status to Firebase ---
  Future<void> _toggleLock(bool value) async {
    setState(() => _isLocked = value);

    await FirebaseFirestore.instance.collection('settings').doc('system').set({
      'evaluationLock': value
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': value ? 'Enabled Global Evaluation Lock' : 'Disabled Global Evaluation Lock',
      'user': 'System Admin',
      'date': DateTime.now().toString(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? "System evaluations locked!" : "System evaluations unlocked!"),
          backgroundColor: value ? Colors.orange : Colors.blue
      ));
    }
  }

  // --- Global Announcement Broadcast Logic ---
  /// Saves a system-wide announcement message into the 'settings/announcements'
  /// document. All user dashboards listen to this document and display the message.
  Future<void> _sendBroadcast() async {
    if (_broadcastController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('settings').doc('announcements').set({
      'message': _broadcastController.text.trim(),
      'isActive': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': 'Sent Global Broadcast: "${_broadcastController.text}"',
      'user': 'System Admin',
      'date': DateTime.now().toString(),
    });

    _broadcastController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Announcement Broadcasted to all users!"),
          backgroundColor: Colors.green
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SYSTEM SECURITY & GLOBAL SETTINGS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1, color: GrcColors.maroon)),
          const SizedBox(height: 6),
          const Text("Manage evaluation availability, announcements, and master database controls.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 32),

          // 🟢 NEW: ACADEMIC CALENDAR CONFIGURATION CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: const [
                        Icon(Icons.public, color: Colors.purple, size: 28),
                        Text("International Academic Calendar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      onPressed: _isSavingCalendar ? null : _saveAcademicCalendar,
                      icon: _isSavingCalendar
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save, color: Colors.white, size: 16),
                      label: Text(_isSavingCalendar ? "SAVING..." : "SAVE CALENDAR", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Define the starting and ending months for your institution's semesters. This automatically updates labels across all student and dean dashboards.", style: TextStyle(fontSize: 12, color: GrcColors.textDark)),
                const SizedBox(height: 24),

                // Semester 1 Row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    const SizedBox(width: 100, child: Text("1st Semester:", style: TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textDark))),
                    SizedBox(width: 130, child: _buildMonthDropdown(_sem1Start, (v) => setState(() => _sem1Start = v!))),
                    const Text("to", style: TextStyle(color: GrcColors.textLight, fontStyle: FontStyle.italic)),
                    SizedBox(width: 130, child: _buildMonthDropdown(_sem1End, (v) => setState(() => _sem1End = v!))),
                  ],
                ),
                const SizedBox(height: 16),

                // Semester 2 Row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    const SizedBox(width: 100, child: Text("2nd Semester:", style: TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textDark))),
                    SizedBox(width: 130, child: _buildMonthDropdown(_sem2Start, (v) => setState(() => _sem2Start = v!))),
                    const Text("to", style: TextStyle(color: GrcColors.textLight, fontStyle: FontStyle.italic)),
                    SizedBox(width: 130, child: _buildMonthDropdown(_sem2End, (v) => setState(() => _sem2End = v!))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // GLOBAL BROADCAST CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: const [
                    Icon(Icons.campaign, color: Colors.blue, size: 28),
                    Text("Global System Broadcast", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Push an urgent message to the top of every user's screen (e.g., 'Evaluations close tomorrow!').", style: TextStyle(fontSize: 12, color: GrcColors.textDark)),
                const SizedBox(height: 16),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 300,
                      child: TextField(
                        controller: _broadcastController,
                        decoration: InputDecoration(
                          hintText: "Type your announcement here...",
                          hintStyle: const TextStyle(fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      onPressed: _sendBroadcast,
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      label: const Text("BROADCAST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: GrcColors.border)),
            child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.lock_outline, color: Colors.orange, size: 30)),
                    SizedBox(
                      width: isMobile ? double.infinity : 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Global Evaluation Lock", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GrcColors.textDark)),
                          SizedBox(height: 4),
                          Text("Instantly lock all evaluations across the entire system. Students and staff will be unable to submit new forms.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isLocked,
                      activeColor: Colors.orange,
                      onChanged: _toggleLock,
                    )
                  ],
                ),
          ),
          const SizedBox(height: 24),

          // Danger Zone
          const Text("DANGER ZONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_forever, color: Colors.red, size: 30)),
                SizedBox(
                  width: isMobile ? double.infinity : 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Reset Semester Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                      SizedBox(height: 4),
                      Text("WARNING: This will permanently delete ALL evaluations, feedback, and audit logs. This is used only at the end of a semester to prepare for the next.", style: TextStyle(fontSize: 12, color: GrcColors.textDark)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: GrcColors.surface,
                        title: const Text("CRITICAL WARNING", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        content: const Text("Are you absolutely sure you want to wipe all evaluation data? This cannot be undone.", style: TextStyle(color: GrcColors.textDark)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: GrcColors.textLight, fontWeight: FontWeight.bold))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action restricted. Requires Super Admin verification code."), backgroundColor: Colors.red));
                            },
                            child: const Text("DELETE ALL DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.warning, color: Colors.white, size: 16),
                  label: const Text("RESET DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 🟢 Helper widget to keep the dropdowns looking clean
  Widget _buildMonthDropdown(String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.purple),
          style: const TextStyle(fontSize: 13, color: GrcColors.textDark, fontWeight: FontWeight.bold),
          items: _months.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}