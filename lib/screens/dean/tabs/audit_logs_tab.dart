// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/grc_theme.dart';


class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL';
  DateTime? _selectedDate;

  final List<String> _filterOptions = ['ALL', 'EVALUATIONS', 'EXPORTS', 'REMINDERS'];

  // --- FULLY FUNCTIONAL CSV EXPORTER (WEB & MOBILE) ---
  Future<void> _exportToCSV(List<QueryDocumentSnapshot> filteredLogs) async {
    try {
      List<String> rows = ["LOG ID,DATE,TIME,TYPE,ROLE,TITLE,DETAILS"];

      for (var doc in filteredLogs) {
        var data = doc.data() as Map<String, dynamic>;
        String logId = "LOG-${doc.id.substring(0, 6).toUpperCase()}";

        DateTime dt = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();
        String date = "${dt.day}/${dt.month}/${dt.year}";
        String time = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";

        // Sanitize commas to prevent CSV breakage
        String type = (data['type'] ?? 'EVENT').toString().replaceAll(',', ' ');
        String role = (data['role'] ?? 'SYSTEM').toString().replaceAll(',', ' ');
        String title = (data['title'] ?? 'System Event').toString().replaceAll(',', ' ');
        String details = (data['details'] ?? data['subtitle1'] ?? '').toString().replaceAll(',', ' ');

        rows.add("$logId,$date,$time,$type,$role,$title,$details");
      }

      String csv = rows.join('\n');
      final bytes = utf8.encode(csv);

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "System_Audit_Logs_${DateTime.now().millisecondsSinceEpoch}.csv")
          ..click();
        html.Url.revokeObjectUrl(url);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CSV Exported Successfully!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = "System_Audit_Logs_${DateTime.now().millisecondsSinceEpoch}.csv";
        final file = io.File("${directory.path}/$fileName");
        await file.writeAsBytes(bytes);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text("CSV saved to Documents"),
               action: SnackBarAction(
                 label: "SHARE",
                 textColor: Colors.white,
                 onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'Audit Logs CSV'),
               ),
               backgroundColor: Colors.green,
             )
           );

        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.red));
      }
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: GrcColors.maroon, onPrimary: GrcColors.gold, onSurface: GrcColors.textDark),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    int m = dt.minute;
    String ampm = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return "$h:${m.toString().padLeft(2, '0')} $ampm";
  }

  String _formatDateShort(DateTime dt) => "${dt.day}/${dt.month}/${dt.year}";

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'DEAN': return GrcColors.maroon;
      case 'PROGRAM HEAD': return Colors.blueAccent;
      case 'STUDENT': return Colors.teal;
      case 'SYSTEM': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _getLogIcon(String type, Color color) {
    IconData icon = Icons.history;
    if (type.toUpperCase().contains('EVALUATION')) icon = Icons.assignment_turned_in;
    if (type.toUpperCase().contains('EXPORT')) icon = Icons.file_download;
    if (type.toUpperCase().contains('REMINDER')) icon = Icons.notifications_active;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildKPICard(String title, String count, IconData icon, Color color, {bool isMobile = false}) {
    Widget card = Container(
      margin: EdgeInsets.only(right: isMobile ? 0 : 16, bottom: isMobile ? 12 : 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GrcColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GrcColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: GrcColors.textLight, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GrcColors.textDark)),
              ],
            ),
          )
        ],
      ),
    );
    return isMobile ? card : Expanded(child: card);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("SYSTEM AUDIT TRAIL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
              SizedBox(height: 6),
              Text("Enterprise-level tracking for all administrative and user events.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
            ],
          ),
          const SizedBox(height: 24),

          // --- MASTER STREAM ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('audit_logs').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

                var allDocs = snapshot.data?.docs ?? [];

                // Metrics Calculation
                int evalCount = allDocs.where((d) => (d.data() as Map)['type'].toString().toUpperCase().contains('EVALUATION')).length;
                int alertCount = allDocs.where((d) => (d.data() as Map)['type'].toString().toUpperCase().contains('REMINDER')).length;

                // Apply Filters
                var filteredLogs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String title = (data['title'] ?? '').toString().toLowerCase();
                  String details = (data['details'] ?? '').toString().toLowerCase();
                  String type = (data['type'] ?? '').toString().toUpperCase();

                  bool matchesSearch = title.contains(_searchQuery.toLowerCase()) || details.contains(_searchQuery.toLowerCase());
                  bool matchesType = _selectedFilter == 'ALL' || type.contains(_selectedFilter.replaceAll('S', ''));

                  bool matchesDate = true;
                  if (_selectedDate != null && data['timestamp'] != null) {
                    DateTime logDate = (data['timestamp'] as Timestamp).toDate();
                    matchesDate = logDate.year == _selectedDate!.year && logDate.month == _selectedDate!.month && logDate.day == _selectedDate!.day;
                  }
                  return matchesSearch && matchesType && matchesDate;
                }).toList();

                return Column(
                  children: [
                    // --- RESPONSIVE LAYOUT BUILDER ---
                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isDesktop = constraints.maxWidth > 800;
                        
                        Widget kpis = isDesktop 
                          ? Row(
                              children: [
                                _buildKPICard("TOTAL RECORDS", allDocs.length.toString(), Icons.storage, GrcColors.maroon),
                                _buildKPICard("EVALUATIONS LOGGED", evalCount.toString(), Icons.assignment_turned_in, Colors.blueAccent),
                                _buildKPICard("SYSTEM ALERTS", alertCount.toString(), Icons.notifications_active, Colors.orange),
                              ],
                            )
                          : Column(
                              children: [
                                _buildKPICard("TOTAL RECORDS", allDocs.length.toString(), Icons.storage, GrcColors.maroon, isMobile: true),
                                _buildKPICard("EVALUATIONS LOGGED", evalCount.toString(), Icons.assignment_turned_in, Colors.blueAccent, isMobile: true),
                                _buildKPICard("SYSTEM ALERTS", alertCount.toString(), Icons.notifications_active, Colors.orange, isMobile: true),
                              ],
                            );

                        Widget searchBar = TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: "Search logs...",
                            prefixIcon: const Icon(Icons.search, size: 18, color: GrcColors.maroon),
                            filled: true,
                            fillColor: GrcColors.surface,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
                          ),
                        );

                        Widget datePicker = Tooltip(
                          message: "Filter by Date",
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                  color: _selectedDate != null ? GrcColors.maroon.withValues(alpha: 0.1) : GrcColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _selectedDate != null ? GrcColors.maroon : GrcColors.border)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today, size: 18, color: _selectedDate != null ? GrcColors.maroon : GrcColors.textLight),
                                  if (_selectedDate != null) ...[
                                    const SizedBox(width: 8),
                                    Text(_formatDateShort(_selectedDate!), style: const TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.close, size: 14, color: GrcColors.maroon),
                                      onPressed: () => setState(() => _selectedDate = null),
                                    )
                                  ]
                                ],
                              ),
                            ),
                          ),
                        );

                        Widget filterChips = SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _filterOptions.map((filter) {
                              bool isSelected = _selectedFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(filter, style: TextStyle(color: isSelected ? GrcColors.gold : GrcColors.textLight, fontWeight: FontWeight.bold, fontSize: 11)),
                                  selected: isSelected,
                                  selectedColor: GrcColors.maroon,
                                  backgroundColor: GrcColors.surface,
                                  showCheckmark: false,
                                  side: BorderSide(color: isSelected ? GrcColors.maroon : GrcColors.border),
                                  onSelected: (bool selected) => setState(() => _selectedFilter = filter),
                                ),
                              );
                            }).toList(),
                          ),
                        );

                        Widget exportBtn = ElevatedButton.icon(
                          onPressed: filteredLogs.isEmpty ? null : () => _exportToCSV(filteredLogs),
                          icon: const Icon(Icons.download, size: 16, color: GrcColors.gold),
                          label: const Text("EXPORT CSV", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GrcColors.maroon,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );

                        Widget actions = isDesktop
                            ? Row(
                                children: [
                                  Expanded(flex: 2, child: searchBar),
                                  const SizedBox(width: 8),
                                  datePicker,
                                  const SizedBox(width: 16),
                                  Expanded(flex: 3, child: filterChips),
                                  exportBtn
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  searchBar,
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: datePicker),
                                      const SizedBox(width: 8),
                                      Expanded(child: exportBtn),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  filterChips,
                                ],
                              );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            kpis,
                            const SizedBox(height: 24),
                            actions,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- ENTERPRISE ACTIVITY FEED UI ---
                    Expanded(
                      child: filteredLogs.isEmpty
                          ? const Center(child: Text("No logs match your current filters.", style: TextStyle(color: GrcColors.textLight)))
                          : ListView.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          var doc = filteredLogs[index];
                          var data = doc.data() as Map<String, dynamic>;

                          String logId = "LOG-${doc.id.substring(0, 6).toUpperCase()}";
                          String title = data['title'] ?? data['action'] ?? 'System Event';
                          String details = data['details'] ?? data['subtitle1'] ?? '';
                          String role = (data['role'] ?? data['user'] ?? 'SYSTEM').toString().toUpperCase();
                          String type = data['type'] ?? 'EVENT';

                          DateTime timestamp = data['timestamp'] != null 
                              ? (data['timestamp'] as Timestamp).toDate() 
                              : (data['date'] != null ? DateTime.tryParse(data['date']) ?? DateTime.now() : DateTime.now());
                          Color roleColor = _getRoleColor(role);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: GrcColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrcColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                    border: Border(left: BorderSide(color: roleColor, width: 4))
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _getLogIcon(type, roleColor),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.textDark)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: GrcColors.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: GrcColors.border)),
                                                child: Text(logId, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: GrcColors.textLight, fontWeight: FontWeight.bold)),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(details, style: const TextStyle(fontSize: 12, color: GrcColors.textLight, height: 1.4)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(_formatTime(timestamp), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13, color: GrcColors.textDark)),
                                        const SizedBox(height: 4),
                                        Text(_formatDateShort(timestamp), style: const TextStyle(fontSize: 10, color: GrcColors.textLight)),
                                        const SizedBox(height: 12),
                                        Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor, letterSpacing: 1)),
                                        const SizedBox(height: 12),
                                        InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text("Delete Request", style: TextStyle(color: Colors.red)),
                                                content: Text("Request deletion of log '$title'? This requires System Admin approval."),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () async {
                                                      Navigator.pop(ctx);
                                                      await FirebaseFirestore.instance.collection('audit_logs').add({
                                                        'title': 'DELETION REQUEST',
                                                        'details': 'Dean requested deletion of log $logId',
                                                        'role': 'DEAN',
                                                        'type': 'ALERT',
                                                        'timestamp': FieldValue.serverTimestamp(),
                                                      });
                                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deletion request sent to Admin."), backgroundColor: Colors.orange));
                                                    },
                                                    child: const Text("REQUEST DELETE", style: TextStyle(color: Colors.white)),
                                                  )
                                                ],
                                              )
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                            child: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}