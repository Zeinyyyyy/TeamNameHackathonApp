import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class AddInstructorTab extends StatefulWidget {
  const AddInstructorTab({super.key});
  @override
  State<AddInstructorTab> createState() => _AddInstructorTabState();
}

class _AddInstructorTabState extends State<AddInstructorTab> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _sub  = TextEditingController();
  final TextEditingController _subId = TextEditingController();

  // --- Search & Filter State ---
  String _searchQuery = '';
  String _selectedFilterDept = 'ALL';

  final List<String> _filterOptions = ['ALL', 'BSIT', 'BSBA', 'BSE', 'BSA', 'BSED'];

  final Map<String, String> _chipToDbName = {
    'BSIT': 'College of Computer Studies',
    'BSBA': 'College of Business Administration',
    'BSE': 'College of Entrepreneurship',
    'BSA': 'College of Accountancy',
    'BSED': 'College of Education',
  };

  // --- Dropdown State ---
  String? _selectedDept;
  final List<String> _departments = [
    'College of Business Administration',
    'College of Entrepreneurship',
    'College of Accountancy',
    'College of Education',
    'College of Computer Studies',
  ];

  Future<void> _handleManualSave() async {
    if (_name.text.isEmpty || _sub.text.isEmpty || _subId.text.isEmpty || _selectedDept == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields including subject ID and course."), backgroundColor: Colors.red));
      return;
    }

    String formattedName = _name.text.trim().toUpperCase();
    String formattedSubj = _sub.text.trim().toUpperCase();
    String formattedSubjId = _subId.text.trim().toUpperCase();

    var dupCheck = await FirebaseFirestore.instance.collection('teachers')
        .where('name', isEqualTo: formattedName)
        .where('subject', isEqualTo: formattedSubj)
        .get();

    if (dupCheck.docs.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: This instructor is already registered for this exact subject!"), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
      return;
    }

    if (mounted) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: GrcColors.surface,
            title: const Text("Confirm Details", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Please verify the instructor details. Only the System Admin can delete records once saved.", style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text("Name: $formattedName", style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textDark)),
                const SizedBox(height: 8),
                Text("Course: $_selectedDept", style: const TextStyle(color: GrcColors.textDark)),
                const SizedBox(height: 8),
                Text("Subject: $formattedSubj ($formattedSubjId)", style: const TextStyle(color: GrcColors.textDark)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("EDIT", style: TextStyle(color: GrcColors.textLight))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance.collection('teachers').add({
                    'name': formattedName,
                    'subject': formattedSubj,
                    'subjectId': formattedSubjId,
                    'department': _selectedDept,
                  });
                  _name.clear();
                  _sub.clear();
                  _subId.clear();
                  setState(() => _selectedDept = null);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Instructor successfully saved!"), backgroundColor: Colors.green));
                },
                child: const Text("CONFIRM & SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          )
      );
    }
  }

  Future<void> _uploadCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final csvString = utf8.decode(result.files.single.bytes!);
        List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

        if (rows.isEmpty) return;

        var existingSnap = await FirebaseFirestore.instance.collection('teachers').get();
        Set<String> existingRecords = existingSnap.docs.map((d) => "${d['name']}_${d['subject']}").toSet();
        Set<String> batchRecords = {};

        int addedCount = 0;
        int skippedCount = 0;
        WriteBatch batch = FirebaseFirestore.instance.batch();

        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.length >= 4) {
            String tName = row[0].toString().trim().toUpperCase();
            String tDept = row[1].toString().trim();
            String tSubj = row[2].toString().trim().toUpperCase();
            String tSubjId = row[3].toString().trim().toUpperCase();

            String uniqueKey = "${tName}_${tSubj}_${tSubjId}";

            if (!existingRecords.contains(uniqueKey) && !batchRecords.contains(uniqueKey)) {
              var docRef = FirebaseFirestore.instance.collection('teachers').doc();
              batch.set(docRef, {
                'id': docRef.id,
                'name': tName,
                'department': tDept,
                'subject': tSubj,
                'subjectId': tSubjId,
                'totalScore': 0.0,
                'evaluationCount': 0,
                'currentAverage': 0.0,
              });
              batchRecords.add(uniqueKey);
              addedCount++;
            } else {
              skippedCount++;
            }
          }
        }

        await batch.commit();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Imported $addedCount new instructors. Skipped $skippedCount duplicates."), backgroundColor: Colors.green, duration: const Duration(seconds: 5)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Failed: $e"), backgroundColor: Colors.red));
    }
  }

  void _showReportIssueDialog(BuildContext context) {
    final TextEditingController issueCtrl = TextEditingController();
    String issueType = 'Wrong Instructor Details';

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: GrcColors.surface,
          title: const Text("Report an Issue", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Use this to contact the System Admin if you accidentally saved an instructor with typos.", style: TextStyle(fontSize: 11, color: GrcColors.textLight)),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: issueType,
                decoration: const InputDecoration(labelText: "Issue Type", border: OutlineInputBorder()),
                items: ['Wrong Instructor Details', 'Duplicate Data Error', 'App Bug', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => issueType = v!,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: issueCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: "E.g., Please delete John Doe from App Dev, it was a typo...", border: OutlineInputBorder(), hintStyle: TextStyle(fontSize: 13)),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: GrcColors.textLight))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
                onPressed: () async {
                  if (issueCtrl.text.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('reported_issues').add({
                      'studentId': 'PH-REGISTRY',
                      'studentName': 'Program Head',
                      'section': 'Faculty Registry Tab',
                      'type': issueType,
                      'description': issueCtrl.text,
                      'timestamp': FieldValue.serverTimestamp(),
                      'status': 'Open'
                    });
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue reported to System Admin!"), backgroundColor: Colors.green));
                    }
                  }
                },
                child: const Text("SUBMIT TO ADMIN", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold))
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrcColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GrcColors.maroon,
        icon: const Icon(Icons.bug_report, color: GrcColors.gold),
        label: const Text("REPORT MISTAKE", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
        onPressed: () => _showReportIssueDialog(context),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 40 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("FACULTY REGISTRY", style: TextStyle(fontWeight: FontWeight.bold, color: GrcColors.maroon, fontSize: 18)),
            const SizedBox(height: 30),

            LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 700;
                
                Widget manualEntry = Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: GrcColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Manual Entry", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        const Text("Add a single instructor to the database.", style: TextStyle(color: GrcColors.textLight, fontSize: 11)),
                        const SizedBox(height: 20),
                        TextField(controller: _name, decoration: const InputDecoration(labelText: "Instructor Full Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedDept),
                          initialValue: _selectedDept,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: "Program / Course",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_balance_outlined)
                          ),
                          items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => _selectedDept = val),
                        ),
                        const SizedBox(height: 15),

                        TextField(controller: _sub, decoration: const InputDecoration(labelText: "Subject Taught (e.g. App Dev)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.book_outlined))),
                        const SizedBox(height: 15),
                        TextField(controller: _subId, decoration: const InputDecoration(labelText: "Subject ID Code (e.g. IT303)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin_outlined))),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
                            onPressed: _handleManualSave,
                            child: const Text("SAVE INSTRUCTOR", style: TextStyle(color: GrcColors.gold, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  );

                Widget bulkImport = Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: GrcColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: GrcColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Bulk Import (CSV)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        const Text("Upload a CSV file with 4 columns: Full Name, Department, Subject, Subject ID.", style: TextStyle(color: GrcColors.textLight, fontSize: 11)),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: GrcColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrcColors.border, style: BorderStyle.solid),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.upload_file, size: 40, color: GrcColors.textLight),
                                const SizedBox(height: 10),
                                const Text("Drag & Drop CSV here", style: TextStyle(color: GrcColors.textDark, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                const Text("Format: Name, Dept, Subject", style: TextStyle(color: GrcColors.textLight, fontSize: 10)),
                                const SizedBox(height: 20),
                                OutlinedButton(
                                  onPressed: _uploadCSV,
                                  child: const Text("BROWSE FILES", style: TextStyle(color: GrcColors.maroon)),
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  );

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: manualEntry),
                      const SizedBox(width: 30),
                      Expanded(child: bulkImport),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      manualEntry,
                      const SizedBox(height: 20),
                      bulkImport,
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 40),
            const Divider(color: GrcColors.border),
            const SizedBox(height: 30),

            // --- BOTTOM SECTION: VISIBILITY TABLE WITH SEARCH & CHIPS ---
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 10,
              children: const [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CURRENT REGISTRY", style: TextStyle(fontWeight: FontWeight.bold, color: GrcColors.maroon, fontSize: 16)),
                    SizedBox(height: 4),
                    Text("List of all instructors currently saved in the database.", style: TextStyle(color: GrcColors.textLight, fontSize: 12)),
                  ],
                ),
                Text("Note: Deletion is restricted to System Admin.", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Chips
            LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 700;
                Widget searchField = TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search instructor name or subject...",
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18, color: GrcColors.maroon),
                      filled: true,
                      fillColor: GrcColors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
                    ),
                  );
                Widget filterChips = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((course) {
                        bool isSelected = _selectedFilterDept == course;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(course, style: TextStyle(color: isSelected ? GrcColors.gold : GrcColors.textDark, fontWeight: FontWeight.bold, fontSize: 11)),
                            selected: isSelected,
                            selectedColor: GrcColors.maroon,
                            backgroundColor: GrcColors.surface,
                            side: BorderSide(color: isSelected ? GrcColors.maroon : GrcColors.border),
                            onSelected: (bool selected) {
                              setState(() => _selectedFilterDept = course);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );

                if (isDesktop) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: searchField),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: filterChips),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 16),
                      filterChips,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                  color: GrcColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GrcColors.border)
              ),
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('teachers').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: GrcColors.maroon)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No instructors registered yet.", style: TextStyle(color: GrcColors.textLight))));
                    }

                    // --- FILTER LOGIC FOR SEARCH AND CHIPS ---
                    var filteredDocs = snapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String name = (data['name'] ?? '').toString().toLowerCase();
                      String subject = (data['subject'] ?? '').toString().toLowerCase();
                      String dept = (data['department'] ?? '').toString();

                      String query = _searchQuery.toLowerCase();
                      bool matchesSearch = name.contains(query) || subject.contains(query);

                      bool matchesDept = _selectedFilterDept == 'ALL' || dept == _chipToDbName[_selectedFilterDept];

                      return matchesSearch && matchesDept;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No matching instructors found.", style: TextStyle(color: GrcColors.textLight))));
                    }

                    return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: GrcColors.border),
                        itemBuilder: (context, index) {
                          var doc = filteredDocs[index];
                          var data = doc.data() as Map<String, dynamic>;

                          String deptDisplay = data['department'] ?? 'No Department Assigned';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: GrcColors.maroon.withOpacity(0.1),
                              child: const Icon(Icons.person, color: GrcColors.maroon),
                            ),
                            title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text("${data['subject']} • $deptDisplay", style: const TextStyle(fontSize: 11, color: GrcColors.textLight)),
                          );
                        }
                    );
                  }
              ),
            )
          ],
        ),
      ),
    );
  }
}