import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

/// [RoomsManagementTab] manages the mapping of academic sections to physical
/// or logical classrooms. It supports auto-generating standard sections based 
/// on department codes, as well as manually adding custom overflow sections. 
/// It also handles soft-deleting (archiving) sections.
class RoomsManagementTab extends StatefulWidget {
  const RoomsManagementTab({super.key});

  @override
  State<RoomsManagementTab> createState() => _RoomsManagementTabState();
}

class _RoomsManagementTabState extends State<RoomsManagementTab> {
  // --- Search Bar Controllers ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // 🟢 NEW: State for Soft Delete toggle
  bool _showArchived = false;

  // This will hold all automatically generated sections
  final List<String> _allRooms = [];

  // Reusing your logic from main.dart to generate all sections automatically
  final Map<String, String> collegeToCode = {
    'College of Business Administration': 'BSBA',
    'College of Entrepreneurship': 'BSE',
    'College of Accountancy': 'BSA',
    'College of Education': 'BSED',
    'College of Computer Studies': 'BSIT',
  };

  @override
  void initState() {
    super.initState();
    _generateAllRooms();
    _fetchCustomRooms();
  }

  Future<void> _fetchCustomRooms() async {
    var snapshot = await FirebaseFirestore.instance.collection('custom_rooms').get();
    for (var doc in snapshot.docs) {
      if (!_allRooms.contains(doc.id)) {
        _allRooms.add(doc.id);
      }
    }
    if (mounted) setState(() {});
  }

  void _showAddRoomDialog() {
    final TextEditingController deptController = TextEditingController();
    final TextEditingController secController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Custom Room/Section", style: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Use this to manually add overload sections.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
            const SizedBox(height: 16),
            TextField(controller: deptController, decoration: const InputDecoration(labelText: "Department Prefix (e.g., BSIT)", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: secController, decoration: const InputDecoration(labelText: "Section Number (e.g., 501)", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
            onPressed: () async {
              String dept = deptController.text.trim().toUpperCase();
              String sec = secController.text.trim();
              if (dept.isEmpty || sec.isEmpty) return;
              
              String roomName = "$dept - $sec";
              await FirebaseFirestore.instance.collection('custom_rooms').doc(roomName).set({'created': true});
              
              if (!_allRooms.contains(roomName)) {
                _allRooms.add(roomName);
                // Sort to keep it organized
                _allRooms.sort();
              }
              
              if (mounted) {
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$roomName added successfully!"), backgroundColor: Colors.green));
              }
            },
            child: const Text("ADD ROOM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Generates every possible section (e.g., BSIT - 101 up to 410)
  void _generateAllRooms() {
    collegeToCode.forEach((collegeName, prefix) {
      for (int year = 1; year <= 4; year++) {
        for (int sec = 1; sec <= 10; sec++) {
          String sectionName = "$prefix - $year${sec.toString().padLeft(2, '0')}";
          _allRooms.add(sectionName);
        }
      }
    });
  }

  // 🟢 Archive/Restore Logic
  void _toggleRoomArchive(String sectionName, bool archive) async {
    // This creates a record mapping the section as 'Archived' so it hides from the main view
    await FirebaseFirestore.instance.collection('archived_rooms').doc(sectionName).set({'archived': archive});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(archive ? "$sectionName Archived" : "$sectionName Restored"), backgroundColor: archive ? Colors.orange : Colors.green));
    setState(() {}); // Refresh view
  }

  // 🟢 NEW: EMPTY TRASH LOGIC FOR ROOMS
  void _emptyRoomTrash() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Empty Room Recycle Bin", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove the archived status of all these rooms from the database. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);

              // Fetch all rooms currently marked as archived
              var snapshot = await FirebaseFirestore.instance.collection('archived_rooms').where('archived', isEqualTo: true).get();
              WriteBatch batch = FirebaseFirestore.instance.batch();

              for (var doc in snapshot.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();

              // Log the action
              await FirebaseFirestore.instance.collection('audit_logs').add({
                'action': 'Emptied Room Recycle Bin (${snapshot.docs.length} records purged)',
                'user': 'System Admin',
                'date': DateTime.now().toString(),
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room Recycle Bin Emptied!"), backgroundColor: Colors.green));
              }
            },
            child: const Text("PURGE ROOMS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isNarrow = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🟢 UPDATED: Header row with Wrap to prevent overflow
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              const Text("ROOM DIRECTORY",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showAddRoomDialog,
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text("ADD ROOM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: GrcColors.maroon),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Show Archived", style: TextStyle(fontSize: 12, color: _showArchived ? Colors.orange : GrcColors.textLight, fontWeight: FontWeight.bold)),
                      Switch(value: _showArchived, activeColor: Colors.orange, onChanged: (v) => setState(() => _showArchived = v)),
                    ],
                  ),
                  // 🟢 NEW: EMPTY TRASH BUTTON (Only visible when Archive is shown)
                  if (_showArchived)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
                      icon: const Icon(Icons.delete_forever, color: Colors.white, size: 16),
                      label: const Text("EMPTY TRASH", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _emptyRoomTrash,
                    ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),

          // --- SEARCH BAR ---
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search by Section (e.g., BSIT - 101)",
              prefixIcon: const Icon(Icons.search, color: GrcColors.maroon),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrcColors.maroon)),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toUpperCase();
              });
            },
          ),

          const SizedBox(height: 32),
          const Text("ALL SYSTEM SECTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GrcColors.textLight)),
          const SizedBox(height: 16),

          Expanded(
            // Wrapped in a StreamBuilder to listen to Archived Rooms
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('archived_rooms').snapshots(),
                builder: (context, archiveSnap) {

                  // Determine which rooms are archived
                  List<String> archivedList = archiveSnap.hasData
                      ? archiveSnap.data!.docs.where((d) => d['archived'] == true).map((d) => d.id).toList()
                      : [];

                  // Filter the generated rooms based on search bar AND archive status
                  List<String> displayedRooms = _allRooms.where((room) {
                    bool matchesSearch = room.toUpperCase().contains(_searchQuery);
                    bool isArchived = archivedList.contains(room);
                    return matchesSearch && (_showArchived ? isArchived : !isArchived);
                  }).toList();

                  if (displayedRooms.isEmpty) {
                    return Center(child: Text(_showArchived ? "No archived rooms." : "No sections match your search.", style: const TextStyle(color: GrcColors.textLight)));
                  }

                  return ListView.builder(
                    itemCount: displayedRooms.length,
                    itemBuilder: (context, index) {
                      String sectionName = displayedRooms[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: GrcColors.border),
                        ),
                        elevation: 0,
                        color: Colors.white,
                        child: ExpansionTile(
                          iconColor: GrcColors.maroon,
                          collapsedIconColor: Colors.grey,
                          leading: Icon(Icons.meeting_room, color: _showArchived ? Colors.orange : GrcColors.maroon),

                          // Title Row with Archive/Restore Button
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sectionName, style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textDark)),
                              IconButton(
                                tooltip: _showArchived ? "Restore Room" : "Archive Room",
                                icon: Icon(_showArchived ? Icons.restore : Icons.delete_outline, color: _showArchived ? Colors.green : Colors.red, size: 20),
                                onPressed: () => _toggleRoomArchive(sectionName, !_showArchived),
                              ),
                            ],
                          ),

                          // --- Display Enrolled Students when clicked ---
                          children: [
                            FutureBuilder<QuerySnapshot>(
                                future: (() async {
                                  List<String> parts = sectionName.split(" - ");
                                  String dept = parts.length > 1 ? parts[0] : sectionName;
                                  String sec = parts.length > 1 ? parts[1] : sectionName;
                                  return FirebaseFirestore.instance.collection('users')
                                      .where('role', whereIn: ['Student', 'STUDENT'])
                                      .where('department', isEqualTo: dept)
                                      .where('section', isEqualTo: sec).get();
                                })(),
                                builder: (context, studentSnap) {
                                  if (studentSnap.connectionState == ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(color: GrcColors.maroon),
                                    );
                                  }

                                  // --- Fallback text if no students are enrolled ---
                                  if (!studentSnap.hasData || studentSnap.data!.docs.isEmpty) {
                                    return Container(
                                      width: double.infinity,
                                      color: GrcColors.background,
                                      padding: const EdgeInsets.all(20.0),
                                      child: const Text(
                                        "No students are enrolled here yet.",
                                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }

                                  return Container(
                                    color: GrcColors.background,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      children: studentSnap.data!.docs.map((studentDoc) {
                                        var student = studentDoc.data() as Map<String, dynamic>;
                                        return ListTile(
                                          leading: const CircleAvatar(
                                              backgroundColor: GrcColors.maroon,
                                              radius: 16,
                                              child: Icon(Icons.person, color: GrcColors.gold, size: 16)),
                                          title: Text(student['name'] ?? "Unknown Student", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GrcColors.textDark)),
                                          subtitle: Text("Student ID: ${student['id']}", style: const TextStyle(fontSize: 11, color: GrcColors.textLight)),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                }
                            )
                          ],
                        ),
                      );
                    },
                  );
                }
            ),
          )
        ],
      ),
    );
  }
}