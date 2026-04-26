import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

class AssignEvaluatorsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const AssignEvaluatorsPage({this.userData, super.key});

  @override
  State<AssignEvaluatorsPage> createState() => _AssignEvaluatorsPageState();
}

class _AssignEvaluatorsPageState extends State<AssignEvaluatorsPage> {
  String? _selectedProgramHeadId;
  String? _selectedProgramHeadName;

  // Set to hold the IDs of the teachers assigned to the selected Program Head
  Set<String> _assignedTeacherIds = {};
  bool _isSaving = false;

  // Search controller for instructors
  String _instructorSearchQuery = "";

  // Function to save assignments to Firebase
  Future<void> _saveAssignments() async {
    if (_selectedProgramHeadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Program Head first."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('assignments').doc(_selectedProgramHeadId).set({
        'programHeadId': _selectedProgramHeadId,
        'programHeadName': _selectedProgramHeadName,
        'assignedTeachers': _assignedTeacherIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Assignments saved successfully!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Function to load existing assignments when a Program Head is clicked
  Future<void> _loadExistingAssignments(String programHeadId) async {
    var doc = await FirebaseFirestore.instance.collection('assignments').doc(programHeadId).get();
    if (doc.exists) {
      List<dynamic> existingIds = doc.data()?['assignedTeachers'] ?? [];
      setState(() {
        _assignedTeacherIds = Set<String>.from(existingIds.cast<String>());
      });
    } else {
      setState(() => _assignedTeacherIds = {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & SAVE BUTTON ---
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("ASSIGN EVALUATORS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
                  SizedBox(height: 6),
                  Text("Assign specific faculty members to be evaluated by a Program Head.", style: TextStyle(fontSize: 13, color: GrcColors.textLight)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAssignments,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, size: 18, color: Colors.white),
                label: Text(_isSaving ? "SAVING..." : "SAVE ASSIGNMENTS", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrcColors.maroon,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // --- DUAL PANEL LAYOUT ---
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 700;

                Widget leftPanel = _buildPanelContainer(
                      title: "1. Select Program Head",
                      child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('role', whereIn: ['PROGRAM HEAD', 'Program Head', 'ADMIN']) // Includes admin and program head
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(child: Text("No Program Heads found.", style: TextStyle(color: GrcColors.textLight)));
                            }

                            return ListView.separated(
                              itemCount: snapshot.data!.docs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: GrcColors.border),
                              itemBuilder: (context, index) {
                                var doc = snapshot.data!.docs[index];
                                var data = doc.data() as Map<String, dynamic>;
                                String id = doc.id;
                                String name = data['name'] ?? 'Unknown Head';
                                String dept = data['department'] ?? 'Department';
                                bool isSelected = _selectedProgramHeadId == id;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedProgramHeadId = id;
                                      _selectedProgramHeadName = name;
                                    });
                                    _loadExistingAssignments(id);
                                  },
                                  child: Container(
                                    color: isSelected ? GrcColors.maroon.withOpacity(0.05) : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isSelected ? GrcColors.maroon : GrcColors.border.withOpacity(0.5),
                                          child: Icon(Icons.person, color: isSelected ? Colors.white : GrcColors.textLight, size: 20),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? GrcColors.maroon : GrcColors.textDark)),
                                              const SizedBox(height: 4),
                                              StreamBuilder<DocumentSnapshot>(
                                                  stream: FirebaseFirestore.instance.collection('assignments').doc(id).snapshots(),
                                                  builder: (context, assignSnap) {
                                                    int count = 0;
                                                    if (assignSnap.hasData && assignSnap.data!.exists) {
                                                      List assigned = (assignSnap.data!.data() as Map<String, dynamic>)['assignedTeachers'] ?? [];
                                                      count = assigned.length;
                                                    }
                                                    return Text(
                                                        "$dept • $count Assigned",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                                            color: isSelected ? GrcColors.maroon.withOpacity(0.7) : GrcColors.textLight
                                                        )
                                                    );
                                                  }
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected) const Icon(Icons.check_circle, color: GrcColors.maroon, size: 20)
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                      ),
                );

                Widget rightPanel = _buildPanelContainer(
                      title: "2. Assign Target Instructors",
                      child: _selectedProgramHeadId == null
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back, size: 48, color: GrcColors.border.withOpacity(0.8)),
                            const SizedBox(height: 16),
                            const Text("Select a Program Head from the left to assign instructors.", style: TextStyle(color: GrcColors.textLight)),
                          ],
                        ),
                      )
                          : Column(
                        children: [
                          // Search Bar for Instructors
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              onChanged: (val) => setState(() => _instructorSearchQuery = val.trim().toLowerCase()),
                              decoration: InputDecoration(
                                hintText: "Search instructors by name or department...",
                                prefixIcon: const Icon(Icons.search, color: GrcColors.maroon),
                                filled: true,
                                fillColor: GrcColors.background,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: GrcColors.border),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: GrcColors.maroon));
                                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                    return const Center(child: Text("No Instructors found.", style: TextStyle(color: GrcColors.textLight)));
                                  }

                                  // Filter the list based on search
                                  var filteredDocs = snapshot.data!.docs.where((doc) {
                                    var d = doc.data() as Map<String, dynamic>;
                                    String name = (d['name'] ?? '').toLowerCase();
                                    String dept = (d['department'] ?? '').toLowerCase();
                                    return name.contains(_instructorSearchQuery) || dept.contains(_instructorSearchQuery);
                                  }).toList();

                                  if (filteredDocs.isEmpty) return const Center(child: Text("No instructors match your search.", style: TextStyle(color: GrcColors.textLight)));

                                  return ListView.separated(
                                    itemCount: filteredDocs.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: GrcColors.border),
                                    itemBuilder: (context, index) {
                                      var doc = filteredDocs[index];
                                      var data = doc.data() as Map<String, dynamic>;
                                      String id = doc.id;
                                      String name = data['name'] ?? 'Unknown Instructor';
                                      String subjectDept = "${data['subject'] ?? ''} • ${data['department'] ?? ''}";

                                      bool isChecked = _assignedTeacherIds.contains(id);

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isChecked) {
                                              _assignedTeacherIds.remove(id);
                                            } else {
                                              _assignedTeacherIds.add(id);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GrcColors.textDark)),
                                                    const SizedBox(height: 4),
                                                    Text(subjectDept, style: const TextStyle(fontSize: 12, color: GrcColors.textLight)),
                                                  ],
                                                ),
                                              ),
                                              Checkbox(
                                                value: isChecked,
                                                activeColor: GrcColors.maroon,
                                                onChanged: (bool? val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _assignedTeacherIds.add(id);
                                                    } else {
                                                      _assignedTeacherIds.remove(id);
                                                    }
                                                  });
                                                },
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }
                            ),
                          ),
                        ],
                      ),
                );

                if (isMobile) {
                  return Column(
                    children: [
                      Expanded(flex: 1, child: leftPanel),
                      const SizedBox(height: 16),
                      Expanded(flex: 2, child: rightPanel),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: leftPanel),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: rightPanel),
                  ],
                );
              }
            ),
          )
        ],
      ),
    );
  }

  // Helper widget to build the premium boxed panels
  Widget _buildPanelContainer({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: GrcColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GrcColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: GrcColors.maroon,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}