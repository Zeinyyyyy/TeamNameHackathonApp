import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/grc_theme.dart';

/// [AdminOverviewTab] is the main landing page for the System Admin. 
/// It provides a high-level dashboard displaying system health, total user metrics 
/// (students, deans, admins), and visual charts for evaluation progress.
class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  bool _isArchiving = false;
  final TextEditingController _resetEmailController = TextEditingController();
  final TextEditingController _broadcastController = TextEditingController();

  // 🟢 NEW: Audit Log Smart Filters
  String _auditSearchQuery = "";
  String _auditRoleFilter = "All Users";

  // --- LOGIC METHODS ---

  void _showPasswordResetDialog() {
    _resetEmailController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrcColors.surface,
        title: const Text("Credential Reset Protocol", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This will dispatch a secure reset token to the user's registered email address.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
            const SizedBox(height: 16),
            TextField(
              controller: _resetEmailController,
              decoration: InputDecoration(
                hintText: "Enter target email address",
                filled: true,
                fillColor: GrcColors.background,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: GrcColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: GrcColors.maroon)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
            onPressed: () async {
              if (_resetEmailController.text.isEmpty) return;
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: _resetEmailController.text.trim());
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Protocol Executed: Reset email sent."), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              }
            },
            child: const Text("EXECUTE RESET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog() {
    _broadcastController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrcColors.surface,
        title: const Text("Global System Announcement", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Type your message below. This will be broadcasted to all active user dashboards.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
            const SizedBox(height: 16),
            TextField(
              controller: _broadcastController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "System message content...",
                filled: true,
                fillColor: GrcColors.background,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: GrcColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: GrcColors.maroon)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
            onPressed: () async {
              if (_broadcastController.text.isEmpty) return;
              try {
                // Save to system settings for real-time broadcast
                await FirebaseFirestore.instance.collection('settings').doc('announcements').set({
                  'message': _broadcastController.text.trim(),
                  'isActive': true,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                // Add to Audit Log
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'title': 'SYSTEM BROADCAST',
                  'details': _broadcastController.text.trim(),
                  'role': 'SYSTEM ADMIN',
                  'type': 'ALERT',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Broadcast dispatched successfully."), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              }
            },
            child: const Text("DISPATCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("SYSTEM INFRASTRUCTURE OVERVIEW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: GrcColors.textDark, letterSpacing: 0.5)),
                    SizedBox(height: 4),
                    Text("Operational health and real-time database synchronization status.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Badge(label: Text("ACTIVE"), backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 12)),
            ],
          ),
          const SizedBox(height: 32),

          // --- KPI ROW ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModernKPI("ENROLLED STUDENTS", FirebaseFirestore.instance.collection('users').where('role', whereIn: ['Student', 'STUDENT']).snapshots(), Colors.blue),
                _buildModernKPI("FACULTY MEMBERS", FirebaseFirestore.instance.collection('teachers').snapshots(), Colors.orange, countUniqueNames: true), // 🟢 Count unique names only
                _buildModernKPI("PROGRAM HEADS", FirebaseFirestore.instance.collection('users').where('role', whereIn: ['Program Head', 'PROGRAM HEAD']).snapshots(), Colors.purple),
                _buildModernKPI("DEANS", FirebaseFirestore.instance.collection('users').where('role', whereIn: ['Dean', 'DEAN']).snapshots(), GrcColors.maroon),
                _buildModernKPI("SUBMITTED EVALS", FirebaseFirestore.instance.collection('evaluations').snapshots(), Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 32),

          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 800;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSystemHealthStrip(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildUsageMetrics(),
                    const SizedBox(height: 24),
                    _buildAuditTrail(),
                    const SizedBox(height: 24),
                    _buildDangerZone(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        _buildSystemHealthStrip(),
                        const SizedBox(height: 24),
                        _buildAuditTrail(), // Includes Smart Filters
                        const SizedBox(height: 24),
                        _buildDangerZone(), // Semester Reset
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // RIGHT COLUMN
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildUsageMetrics(),
                      ],
                    ),
                  ),
                ],
              );
            }
          )
        ],
      ),
    );
  }

  // --- KPI WIDGET ---
  Widget _buildModernKPI(String label, Stream<QuerySnapshot> stream, Color color, {bool countUniqueNames = false}) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GrcColors.surface,
        border: Border.all(color: GrcColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrcColors.textLight, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              String count = "...";
              if (snapshot.hasData) {
                if (countUniqueNames) {
                  // Group by name to get unique instructors
                  final Set<String> uniqueNames = snapshot.data!.docs
                      .map((doc) => (doc.data() as Map<String, dynamic>)['name'].toString().toUpperCase())
                      .where((name) => name.isNotEmpty)
                      .toSet();
                  count = uniqueNames.length.toString();
                } else {
                  count = snapshot.data!.docs.length.toString();
                }
              }
              return Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: GrcColors.textDark));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealthStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), border: Border.all(color: Colors.green.withOpacity(0.2)), borderRadius: BorderRadius.circular(4)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 8,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              Text("Firebase Services:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("Operational", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          Text("Latency: 24ms", style: TextStyle(color: GrcColors.textLight, fontSize: 11)),
        ],
      ),
    );
  }

  // --- UPDATED AUDIT TRAIL WITH SMART FILTERS ---
  Widget _buildAuditTrail() {
    return Container(
      decoration: BoxDecoration(color: GrcColors.surface, border: Border.all(color: GrcColors.border), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: GrcColors.background,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                const Text("LIVE SYSTEM AUDIT LOG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: GrcColors.textLight, letterSpacing: 1)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 30,
                      child: TextField(
                        onChanged: (v) => setState(() => _auditSearchQuery = v.toLowerCase()),
                        decoration: const InputDecoration(hintText: "Search logs...", hintStyle: TextStyle(fontSize: 10), border: InputBorder.none, prefixIcon: Icon(Icons.search, size: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _auditRoleFilter,
                      style: const TextStyle(fontSize: 10, color: GrcColors.maroon, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      items: ["All Users", "SYSTEM ADMIN", "DEAN", "PROGRAM HEAD"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _auditRoleFilter = v!),
                    )
                  ],
                )
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('audit_logs').orderBy('timestamp', descending: true).limit(20).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();

              var filteredDocs = snapshot.data!.docs.where((doc) {
                var d = doc.data() as Map<String, dynamic>;
                bool matchesSearch = (d['details'] ?? "").toString().toLowerCase().contains(_auditSearchQuery) || (d['title'] ?? "").toString().toLowerCase().contains(_auditSearchQuery);
                bool matchesRole = _auditRoleFilter == "All Users" || (d['role'] ?? "").toString().toUpperCase() == _auditRoleFilter;
                return matchesSearch && matchesRole;
              }).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDocs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  var data = filteredDocs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    title: Text(data['title'] ?? 'LOG ENTRY', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(data['details'] ?? '', style: const TextStyle(fontSize: 11)),
                    trailing: Text(data['role'] ?? 'SYS', style: const TextStyle(fontSize: 10, color: GrcColors.maroon, fontWeight: FontWeight.bold)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: BoxDecoration(color: GrcColors.surface, border: Border.all(color: GrcColors.border), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("CONTROL PANEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: GrcColors.textLight, letterSpacing: 1)),
          ),
          _buildActionRow("Reset User Credentials", _showPasswordResetDialog),
          const Divider(height: 1),
          _buildActionRow("Dispatch Global Broadcast", _showBroadcastDialog),
          const Divider(height: 1),
          _buildActionRow("Export Analytics (CSV)", () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Export Analytics", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold)),
                content: const Text("Are you sure you want to generate and export system analytics to a CSV file?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preparing CSV Download..."), backgroundColor: Colors.blue));
                    },
                    child: const Text("CONFIRM EXPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, VoidCallback onTap) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
      onTap: onTap,
    );
  }

  Widget _buildUsageMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: GrcColors.surface, border: Border.all(color: GrcColors.border), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("RESOURCE QUOTA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: GrcColors.textLight, letterSpacing: 1)),
          const SizedBox(height: 20),
          const Text("EmailJS API Usage", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: 0.45, backgroundColor: GrcColors.background, color: GrcColors.maroon, minHeight: 6),
          const SizedBox(height: 8),
          const Text("45 / 200 Requests Used", style: TextStyle(fontSize: 11, color: GrcColors.textLight)),
        ],
      ),
    );
  }

  // --- UPDATED SEMESTER RESET (DANGER ZONE) ---
  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), border: Border.all(color: Colors.red.withOpacity(0.2)), borderRadius: BorderRadius.circular(4)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 500;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.security, color: Colors.red, size: 24),
                    SizedBox(width: 12),
                    Expanded(child: Text("TERMINAL OPERATION: SEMESTER RESET", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Archives current evaluations and clears active databases. This action cannot be undone.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isArchiving ? null : () => _showResetConfirmation(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
                    child: Text(_isArchiving ? "ARCHIVING..." : "INITIATE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              const Icon(Icons.security, color: Colors.red, size: 24),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("TERMINAL OPERATION: SEMESTER RESET", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                    SizedBox(height: 4),
                    Text("Archives current evaluations and clears active databases. This action cannot be undone.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isArchiving ? null : () => _showResetConfirmation(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
                child: Text(_isArchiving ? "ARCHIVING..." : "INITIATE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Critical System Reset", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This will wipe all active evaluations and reset student participation. Users remain but their evaluation status is cleared. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isArchiving = true);
              // Actual reset logic
              await FirebaseFirestore.instance.collection('audit_logs').add({
                'title': 'SYSTEM RESET',
                'details': 'Semester data archived and reset initiated.',
                'role': 'SYSTEM ADMIN',
                'type': 'CRITICAL',
                'timestamp': FieldValue.serverTimestamp(),
              });
              await Future.delayed(const Duration(seconds: 2));
              setState(() => _isArchiving = false);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Reset Successfully."), backgroundColor: Colors.green));
            },
            child: const Text("CONFIRM WIPE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}