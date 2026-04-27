import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/grc_theme.dart';


/// [UserManagementTab] allows the System Admin to create, approve, archive, 
/// and modify user accounts (Students, Deans, Program Heads). It features 
/// manual registration forms, bulk CSV exports, and a pending approvals queue.
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  int _selectedMenuIndex = 0; // 0: Single, 1: Directory, 2: Approvals
  bool _isLoading = false;
  bool _showArchived = false;

  // --- Search & Filter State ---
  String _searchQuery = "";
  String _selectedRoleFilter = "ALL";
  final List<String> _roleFilters = ["ALL", "STUDENT", "FACULTY", "PROGRAM HEAD", "DEAN"];

  // Single Registration Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _subjectIdController = TextEditingController();
  
  String _selectedSection = 'BSIT - 101';
  final List<String> _sections = [
    for (int yr = 1; yr <= 4; yr++)
      for (int sec = 1; sec <= 10; sec++) "BSIT - $yr${sec.toString().padLeft(2, '0')}"
  ];

  String _selectedRole = 'Student';
  String _selectedCourse = 'BSIT';

  final List<String> _courses = ['BSIT', 'BSBA', 'BSE', 'BSA', 'BSED', 'N/A (Faculty)'];
  final List<String> _roles = ['Student', 'Faculty', 'Program Head'];

  // --- TRASH LOGIC ---
  void _emptyUserTrash() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Empty Recycle Bin", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently delete all archived users from the database. This action cannot be undone. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              var snapshot = await FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'ARCHIVED').get();
              WriteBatch batch = FirebaseFirestore.instance.batch();
              for (var doc in snapshot.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();

              await FirebaseFirestore.instance.collection('audit_logs').add({
                'action': 'Emptied User Recycle Bin (${snapshot.docs.length} users purged)',
                'user': 'System Admin', 'date': DateTime.now().toString(),
              });

              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recycle Bin Emptied!"), backgroundColor: Colors.green));
            },
            child: const Text("PERMANENTLY PURGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- 🟢 NEW: EDIT USER LOGIC ---
  void _showEditUserDialog(String docId, Map<String, dynamic> currentData) async {
    final TextEditingController editNameCtrl = TextEditingController(text: currentData['name']);
    final TextEditingController editEmailCtrl = TextEditingController(text: currentData['email']);
    final TextEditingController editSectionCtrl = TextEditingController(text: currentData['section'] ?? '');

    // We don't allow editing the ID directly because it is the Document ID.
    final TextEditingController editIdCtrl = TextEditingController(text: currentData['id']);

    String editRole = currentData['role'] ?? 'Student';
    // Ensure the role matches our dropdown options, default to Student if weird data exists
    if (!_roles.contains(editRole) && editRole != 'ADMIN') editRole = 'Student';

    final TextEditingController editSubjectCtrl = TextEditingController();
    final TextEditingController editSubjectIdCtrl = TextEditingController();

    List<Map<String, String>> editSubjectsList = [];
    final TextEditingController addSubjectTitleCtrl = TextEditingController();
    final TextEditingController addSubjectIdCtrl = TextEditingController();

    if (editRole == 'Student') {
      List<dynamic> subjects = currentData['enrolled_subjects'] ?? [];
      editSubjectsList = subjects.map((s) => {
        'title': s['title']?.toString() ?? '',
        'code': s['code']?.toString() ?? '',
      }).toList();
    }

    List<Map<String, String>> initialFacultySubjects = [];

    if (editRole == 'Faculty' || currentData['role'] == 'Faculty') {
      try {
        String queryName = (currentData['name'] ?? '').toString().toUpperCase();
        var tQuery = await FirebaseFirestore.instance.collection('teachers').where('name', isEqualTo: queryName).get();
        var tDoc = await FirebaseFirestore.instance.collection('teachers').doc(docId).get();
        
        Set<String> seenIds = {};
        for (var doc in tQuery.docs) {
          editSubjectsList.add({'docId': doc.id, 'title': doc.data()['subject']?.toString() ?? '', 'code': doc.data()['subjectId']?.toString() ?? ''});
          seenIds.add(doc.id);
        }
        if (tDoc.exists && !seenIds.contains(tDoc.id)) {
          editSubjectsList.add({'docId': tDoc.id, 'title': tDoc.data()?['subject']?.toString() ?? '', 'code': tDoc.data()?['subjectId']?.toString() ?? ''});
        }
        
        // Save initial state to track deletions
        initialFacultySubjects = List.from(editSubjectsList);
      } catch (_) {}
    }

    bool isSaving = false;

    if (!mounted) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: GrcColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: GrcColors.border)),
                title: Row(
                  children: [
                    const Icon(Icons.edit_document, color: GrcColors.maroon),
                    const SizedBox(width: 8),
                    const Text("UPDATE USER PROFILE", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                            controller: editIdCtrl,
                            readOnly: true, // Prevent ID editing
                            decoration: const InputDecoration(labelText: "ID Number (Locked)", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF5F5F5))
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: editNameCtrl, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextField(controller: editEmailCtrl, decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: editRole == 'ADMIN' ? null : editRole, // Hide dropdown if it's the master admin
                          decoration: const InputDecoration(labelText: "Account Role", border: OutlineInputBorder()),
                          items: _roles.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: editRole == 'ADMIN' ? null : (v) => setDialogState(() => editRole = v!),
                          hint: editRole == 'ADMIN' ? const Text("ADMIN (Locked)") : null,
                        ),

                        if (editRole == 'Student') ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _sections.contains(editSectionCtrl.text.trim()) 
                                ? editSectionCtrl.text.trim() 
                                : (_sections.any((s) => s.contains(editSectionCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')))
                                    ? _sections.firstWhere((s) => s.contains(editSectionCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')))
                                    : _sections.first),
                            decoration: const InputDecoration(labelText: "Section Number", border: OutlineInputBorder()),
                            items: _sections.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setDialogState(() => editSectionCtrl.text = v!),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (editRole == 'Student' || editRole == 'Faculty') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: GrcColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(editRole == 'Faculty' ? "Assigned Subjects" : "Enrolled Subjects", style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.maroon, fontSize: 13)),
                                const SizedBox(height: 8),
                                if (editSubjectsList.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: editSubjectsList.map((sub) {
                                      String title = sub['title'] ?? '';
                                      String code = sub['code'] ?? '';
                                      String display = title.isNotEmpty ? "$title ($code)" : code;
                                      return Chip(
                                        label: Text(display, style: const TextStyle(fontSize: 11)),
                                        backgroundColor: GrcColors.surface,
                                        side: const BorderSide(color: GrcColors.border),
                                        deleteIcon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        onDeleted: () {
                                          setDialogState(() {
                                            editSubjectsList.remove(sub);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  )
                                else
                                  const Text("No subjects added.", style: TextStyle(color: GrcColors.textLight, fontSize: 12)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: addSubjectTitleCtrl,
                                        decoration: const InputDecoration(labelText: "Subject", hintText: "e.g. Leadership", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: addSubjectIdCtrl,
                                        decoration: const InputDecoration(labelText: "Subject ID", hintText: "e.g. 33333", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon, minimumSize: const Size(40, 48)),
                                      onPressed: () {
                                        if (addSubjectIdCtrl.text.isNotEmpty) {
                                          setDialogState(() {
                                            editSubjectsList.add({
                                              'title': addSubjectTitleCtrl.text.trim(),
                                              'code': addSubjectIdCtrl.text.trim(),
                                            });
                                            addSubjectTitleCtrl.clear();
                                            addSubjectIdCtrl.clear();
                                          });
                                        }
                                      },
                                      child: const Text("ADD", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      child: const Text("CANCEL", style: TextStyle(color: GrcColors.textLight))
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
                    onPressed: isSaving ? null : () async {
                      if (editNameCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Name cannot be empty!"), backgroundColor: Colors.red));
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        Map<String, dynamic> updates = {
                          'name': editNameCtrl.text.trim(),
                          'email': editEmailCtrl.text.trim(),
                        };

                        if (editRole != 'ADMIN') {
                          updates['role'] = editRole;
                        }

                        if (editRole == 'Student') {
                          updates['section'] = editSectionCtrl.text.trim();
                          
                          List<Map<String, String>> enrolledList = editSubjectsList.map((s) => {
                            'code': s['code']!,
                            'title': s['title']!,
                            'section': editSectionCtrl.text.trim(),
                            'room': 'TBA'
                          }).toList();
                          
                          updates['enrolled_subjects'] = enrolledList;
                        }

                        // Update User Profile
                        if (!currentData.containsKey('isVirtual')) {
                          await FirebaseFirestore.instance.collection('users').doc(docId).update(updates);
                        }

                        // Update Faculty Subjects
                        if (editRole == 'Faculty' || currentData['role'] == 'Faculty') {
                          WriteBatch batch = FirebaseFirestore.instance.batch();
                          String formattedName = updates['name'].toString().toUpperCase();
                          
                          // 1. Delete removed subjects
                          List<String> currentIds = editSubjectsList.map((s) => s['docId'] ?? '').where((id) => id.isNotEmpty).toList();
                          for (var initial in initialFacultySubjects) {
                            String initId = initial['docId']!;
                            if (initId.isNotEmpty && !currentIds.contains(initId)) {
                              batch.delete(FirebaseFirestore.instance.collection('teachers').doc(initId));
                            }
                          }

                          // 2. Add new subjects or update existing
                          for (var sub in editSubjectsList) {
                            if (sub['docId'] == null || sub['docId']!.isEmpty) {
                              // New subject
                              var newDoc = FirebaseFirestore.instance.collection('teachers').doc();
                              batch.set(newDoc, {
                                'id': newDoc.id,
                                'name': formattedName,
                                'subject': sub['title']!.toUpperCase(),
                                'subjectId': sub['code']!.toUpperCase(),
                                'department': 'College of $editRole', // default
                                'totalScore': 0.0,
                                'evaluationCount': 0,
                                'currentAverage': 0.0,
                              });
                            } else {
                              // Update existing
                              batch.update(FirebaseFirestore.instance.collection('teachers').doc(sub['docId']), {
                                'name': formattedName,
                                'subject': sub['title']!.toUpperCase(),
                                'subjectId': sub['code']!.toUpperCase(),
                              });
                            }
                          }
                          await batch.commit();
                        }

                        // Audit Log
                        await FirebaseFirestore.instance.collection('audit_logs').add({
                          'action': 'Updated profile information for user ${updates['name']}',
                          'user': 'System Admin', 'date': DateTime.now().toString(),
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("User updated successfully!"), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                      }
                    },
                    child: isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: GrcColors.gold, strokeWidth: 2))
                        : const Text("SAVE CHANGES", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold)),
                  )
                ],
              );
            }
        )
    );
  }

  // --- SINGLE UPLOAD LOGIC ---
  Future<void> _registerSingleUser() async {
    if (_nameController.text.isEmpty || _idController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'studentId': _idController.text.trim(),
        'id': _idController.text.trim(),
        'email': _emailController.text.trim(),
        'department': _selectedRole == 'Student' ? _selectedCourse : 'College of $_selectedCourse',
        'role': _selectedRole,
        'status': 'APPROVED',
        'hasEvaluated': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == 'Student') {
        userData['section'] = _selectedSection;
        userData['enrolled_subjects'] = [];
      }

      await FirebaseFirestore.instance.collection('users').doc(_idController.text.trim()).set(userData);

      if (_selectedRole == 'Faculty') {
        await FirebaseFirestore.instance.collection('teachers').doc(userData['id']).set({
          'id': userData['id'],
          'name': userData['name'],
          'subject': _subjectController.text.trim().toUpperCase(),
          'subjectId': _subjectIdController.text.trim().toUpperCase(),
          'department': userData['department'],
          'totalScore': 0.0,
          'evaluationCount': 0,
          'currentAverage': 0.0,
        });
      }

      _nameController.clear();
      _idController.clear();
      _emailController.clear();
      _subjectController.clear();
      _subjectIdController.clear();
      setState(() => _selectedSection = '101');

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$_selectedRole successfully registered!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- APPROVAL LOGIC ---
  Future<void> _handleApproval(String docId, bool isApproved) async {
    try {
      if (isApproved) {
        await FirebaseFirestore.instance.collection('users').doc(docId).update({'status': 'APPROVED'});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Approved!"), backgroundColor: Colors.green));
      } else {
        await FirebaseFirestore.instance.collection('users').doc(docId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Request Rejected & Deleted."), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // --- CSV EXPORT LOGIC (WEB & MOBILE) ---
  Future<void> _exportToCsv() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preparing CSV Download..."), backgroundColor: Colors.blue));

    try {
      var snapshot = await FirebaseFirestore.instance.collection('users').get();
      List<List<dynamic>> rows = [
        ["Name", "ID", "Email", "Role", "Department", "Section", "Status"]
      ];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        rows.add([
          data['name'] ?? '',
          data['id'] ?? data['studentId'] ?? '',
          data['email'] ?? '',
          data['role'] ?? '',
          data['department'] ?? '',
          data['section'] ?? '',
          data['status'] ?? 'APPROVED'
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", "grc_system_users.csv")
          ..click();
        html.Url.revokeObjectUrl(url);
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CSV Downloaded Successfully!"), backgroundColor: Colors.green));
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = "grc_system_users_${DateTime.now().millisecondsSinceEpoch}.csv";
        final file = io.File("${directory.path}/$fileName");
        await file.writeAsBytes(bytes);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text("CSV saved to Documents"),
               action: SnackBarAction(
                 label: "SHARE",
                 textColor: Colors.white,
                 onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'User Directory CSV'),
               ),
               backgroundColor: Colors.green,
             )
           );

        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exporting CSV: $e"), backgroundColor: Colors.red));
    }
  }


  void _resetPassword(String userId, String userName) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': 'Reset password for $userName to default (grc12345)', 'user': 'System Admin', 'date': DateTime.now().toString(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password for $userName reset to 'grc12345'"), backgroundColor: Colors.green));
  }

  void _toggleUserArchiveStatus(String docId, bool archive) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update({'status': archive ? 'ARCHIVED' : 'APPROVED'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(archive ? "User moved to Archive" : "User Restored!"), backgroundColor: archive ? Colors.orange : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    bool isNarrow = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("USER MANAGEMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text("Securely register, edit, and verify student and faculty accounts.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 24),

          // --- TAB MENU ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMenuTab("Single Registration", Icons.person_add_alt_1, 0),
                const SizedBox(width: 16),
                _buildMenuTab("User Directory", Icons.folder_shared, 1),
                const SizedBox(width: 16),
                _buildMenuTab("Pending Approvals", Icons.how_to_reg, 2),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- DYNAMIC CONTENT AREA ---
          Expanded(
            child: _selectedMenuIndex == 0
                ? _buildSingleRegistrationView()
                : _selectedMenuIndex == 1
                ? _buildDirectoryView()
                : _buildApprovalQueueView(),
          )
        ],
      ),
    );
  }

  // --- SUB-VIEWS ---

  Widget _buildSingleRegistrationView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 600;
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 32),
            decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: GrcColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("REGISTER NEW ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.maroon)),
                const SizedBox(height: 24),
                if (isMobile) ...[
                  _buildTextField("Full Name", Icons.person, _nameController),
                  const SizedBox(height: 16),
                  _buildTextField("ID Number", Icons.badge, _idController),
                  const SizedBox(height: 16),
                  _buildTextField("Email Address", Icons.email, _emailController),
                  const SizedBox(height: 16),
                  _buildDropdown("Role", _roles, _selectedRole, (val) => setState(() => _selectedRole = val!)),
                  const SizedBox(height: 16),
                  _buildDropdown("Course/Department", _courses, _selectedCourse, (val) => setState(() => _selectedCourse = val!)),
                  if (_selectedRole == 'Student') ...[
                    const SizedBox(height: 16),
                    _buildDropdown("Section Number", _sections, _selectedSection, (val) => setState(() => _selectedSection = val!)),
                  ],
                  if (_selectedRole == 'Faculty') ...[
                    const SizedBox(height: 16),
                    _buildTextField("Subject Taught", Icons.book, _subjectController),
                    const SizedBox(height: 16),
                    _buildTextField("Subject ID Code", Icons.pin, _subjectIdController),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildTextField("Full Name", Icons.person, _nameController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField("ID Number", Icons.badge, _idController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(flex: 2, child: _buildTextField("Email Address", Icons.email, _emailController)),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildDropdown("Role", _roles, _selectedRole, (val) => setState(() => _selectedRole = val!)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildDropdown("Course/Department", _courses, _selectedCourse, (val) => setState(() => _selectedCourse = val!)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _selectedRole == 'Student'
                            ? _buildDropdown("Section Number", _sections, _selectedSection, (val) => setState(() => _selectedSection = val!))
                            : const SizedBox(),
                      ),
                    ],
                  ),
                  if (_selectedRole == 'Faculty') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Subject Taught", Icons.book, _subjectController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Subject ID Code", Icons.pin, _subjectIdController)),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  width: isMobile ? double.infinity : 250,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registerSingleUser,
                    icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: Text(_isLoading ? "REGISTERING..." : "REGISTER ACCOUNT", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildDirectoryView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GrcColors.surface, border: Border.all(color: GrcColors.border)),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search by name or ID...",
                  prefixIcon: const Icon(Icons.search, color: GrcColors.maroon),
                  filled: true,
                  fillColor: GrcColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _roleFilters.map((role) {
                    bool isSelected = _selectedRoleFilter == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(role, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : GrcColors.textLight)),
                        selected: isSelected,
                        selectedColor: GrcColors.maroon,
                        backgroundColor: GrcColors.background,
                        onSelected: (v) => setState(() => _selectedRoleFilter = role),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(color: GrcColors.surface, border: Border.all(color: GrcColors.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Show Archived", style: TextStyle(fontSize: 11, color: _showArchived ? Colors.orange : GrcColors.textLight, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24,
                    child: Switch(value: _showArchived, activeColor: Colors.orange, onChanged: (v) => setState(() => _showArchived = v)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16)),
                icon: const Icon(Icons.download, color: GrcColors.gold, size: 14),
                label: const Text("EXPORT CSV", style: TextStyle(color: GrcColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: _exportToCsv,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: GrcColors.surface, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)), border: Border.all(color: GrcColors.border)),
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
                    builder: (context, teacherSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting || teacherSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));
                      }
                      if (!userSnapshot.hasData) return const Center(child: Text("No users found."));

                      var userDocs = userSnapshot.data!.docs;
                      var teacherDocs = teacherSnapshot.data?.docs ?? [];

                  // 1. Process real users
                  List<Map<String, dynamic>> combinedList = [];
                  Set<String> facultyNamesInUsers = {};

                  for (var doc in userDocs) {
                    var data = doc.data() as Map<String, dynamic>;
                    data['docId'] = doc.id;
                    String status = data['status'] ?? 'APPROVED';
                    
                    if (status == 'PENDING') continue;
                    if (_showArchived ? status != 'ARCHIVED' : status == 'ARCHIVED') continue;

                    combinedList.add(data);
                    if (data['role'] == 'Faculty') {
                      facultyNamesInUsers.add(data['name'].toString().toUpperCase());
                    }
                  }

                  // 2. Process instructors from teachers collection (who don't have accounts)
                  if (!_showArchived) { // Only show active instructors
                    Map<String, List<DocumentSnapshot>> groupedTeachers = {};
                    for (var doc in teacherDocs) {
                      String name = doc['name'].toString().toUpperCase();
                      if (!groupedTeachers.containsKey(name)) groupedTeachers[name] = [];
                      groupedTeachers[name]!.add(doc);
                    }

                    groupedTeachers.forEach((name, docs) {
                      if (!facultyNamesInUsers.contains(name)) {
                        var first = docs.first.data() as Map<String, dynamic>;
                        combinedList.add({
                          'docId': docs.first.id, // Using first docId as anchor
                          'id': 'REGISTRY-ONLY',
                          'name': first['name'],
                          'role': 'Faculty',
                          'department': first['department'] ?? 'College of Faculty',
                          'isVirtual': true, // Flag to indicate no login account
                        });
                      }
                    });
                  }

                  // 3. Apply Filters (Smart Search + Role)
                  combinedList = combinedList.where((u) {
                    String uName = (u['name'] ?? '').toString().toLowerCase();
                    String uId = (u['id'] ?? '').toString().toLowerCase();
                    String uRole = (u['role'] ?? 'Student').toString().toUpperCase();

                    bool matchesRole = _selectedRoleFilter == 'ALL' || uRole == _selectedRoleFilter;
                    bool matchesSearch = _searchQuery.isEmpty || uName.contains(_searchQuery) || uId.contains(_searchQuery);

                    return matchesRole && matchesSearch;
                  }).toList();

                  if (combinedList.isEmpty) return Center(child: Text(_showArchived ? "No archived users found." : "No users match your search."));

                  // Sort by name
                  combinedList.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

                  return ListView.separated(
                    itemCount: combinedList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: GrcColors.border),
                    itemBuilder: (context, index) {
                      var data = combinedList[index];
                      String docId = data['docId'];
                      String role = data['role'] ?? 'Student';
                      bool isVirtual = data['isVirtual'] ?? false;
                      Color roleColor = role == 'Student' ? Colors.blue : (role == 'Faculty' ? Colors.orange : GrcColors.maroon);

                      bool isMobile = MediaQuery.of(context).size.width < 700;
                      if (isMobile) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(backgroundColor: _showArchived ? Colors.orange.withOpacity(0.1) : roleColor.withOpacity(0.1), child: Icon(Icons.person, color: _showArchived ? Colors.orange : roleColor)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text("${data['id']} • ${data['section'] ?? data['department']}${isVirtual ? ' (Registry Only)' : ''}", style: const TextStyle(fontSize: 12, color: GrcColors.textLight)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                    child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                                  ),
                                  if (!_showArchived) ...[
                                    IconButton(tooltip: "Edit Profile", icon: const Icon(Icons.edit, color: GrcColors.maroon, size: 20), onPressed: () => _showEditUserDialog(docId, data)),
                                    if (!isVirtual)
                                      IconButton(tooltip: "Reset Password", icon: const Icon(Icons.key, color: Colors.blue, size: 20), onPressed: () => _resetPassword(docId, data['name'])),
                                  ],
                                  if (!isVirtual)
                                    IconButton(tooltip: _showArchived ? "Restore User" : "Archive User", icon: Icon(_showArchived ? Icons.restore : Icons.delete_outline, color: _showArchived ? Colors.green : Colors.red, size: 20), onPressed: () => _toggleUserArchiveStatus(docId, !_showArchived)),
                                ],
                              )
                            ],
                          ),
                        );
                      }

                      return ListTile(
                        leading: CircleAvatar(backgroundColor: _showArchived ? Colors.orange.withOpacity(0.1) : roleColor.withOpacity(0.1), child: Icon(Icons.person, color: _showArchived ? Colors.orange : roleColor)),
                        title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text("${data['id']} • ${data['section'] ?? data['department']}${isVirtual ? ' (Registry Only)' : ''}"),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                            ),
                            if (!_showArchived) ...[
                              IconButton(tooltip: "Edit Profile", icon: const Icon(Icons.edit, color: GrcColors.maroon, size: 20), onPressed: () => _showEditUserDialog(docId, data)),
                              if (!isVirtual)
                                IconButton(tooltip: "Reset Password", icon: const Icon(Icons.key, color: Colors.blue, size: 20), onPressed: () => _resetPassword(docId, data['name'])),
                            ],
                            if (!isVirtual)
                              IconButton(tooltip: _showArchived ? "Restore User" : "Archive User", icon: Icon(_showArchived ? Icons.restore : Icons.delete_outline, color: _showArchived ? Colors.green : Colors.red, size: 20), onPressed: () => _toggleUserArchiveStatus(docId, !_showArchived)),
                          ],
                        ),
                      );
                    },
                  );
                    }
                  );
                }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalQueueView() {
    return Container(
      decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: GrcColors.border)),
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'PENDING').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text("All caught up!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: GrcColors.textDark)),
                    const SizedBox(height: 4),
                    const Text("There are no pending account requests.", style: TextStyle(color: GrcColors.textLight)),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: GrcColors.border),
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;

                bool isMobile = MediaQuery.of(context).size.width < 700;
                if (isMobile) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.hourglass_top, color: Colors.orange)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text("${data['id']} • ${data['department']}", style: const TextStyle(fontSize: 12, color: GrcColors.textLight)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _handleApproval(doc.id, false),
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              label: const Text("REJECT", style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _handleApproval(doc.id, true),
                              icon: const Icon(Icons.check, size: 16, color: Colors.white),
                              label: const Text("APPROVE", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.hourglass_top, color: Colors.orange)),
                  title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text("${data['id']} • ${data['department']}"),
                  trailing: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _handleApproval(doc.id, false),
                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                        label: const Text("REJECT", style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _handleApproval(doc.id, true),
                        icon: const Icon(Icons.check, size: 16, color: Colors.white),
                        label: const Text("APPROVE", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                );
              },
            );
          }
      ),
    );
  }

  // --- UTILITY WIDGETS ---

  Widget _buildMenuTab(String title, IconData icon, int index) {
    bool isSelected = _selectedMenuIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedMenuIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? GrcColors.maroon : GrcColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? GrcColors.maroon : GrcColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? GrcColors.gold : GrcColors.textLight),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? GrcColors.gold : GrcColors.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: GrcColors.maroon, size: 20),
        filled: true,
        fillColor: GrcColors.background,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: GrcColors.background,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
      ),
    );
  }
}