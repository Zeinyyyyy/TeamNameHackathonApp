import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/grc_theme.dart';

/// [AdminSupportTab] is a static, read-only FAQ page designed to help
/// new System Admins understand the architecture and rules of the GRC 
/// Evaluation System, such as why Deans can't be deleted or how Rooms work.
class AdminSupportTab extends StatelessWidget {
  const AdminSupportTab({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SYSTEM SUPPORT & FAQ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: GrcColors.maroon, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text("Learn how to manage the GRC Evaluation System effectively.",
              style: TextStyle(color: GrcColors.textLight, fontSize: 13)),
          const SizedBox(height: 32),

          Expanded(
            child: ListView(
              children: [
                _buildFaqItem(
                  question: "Why is there a 'Rooms' tab in the Admin panel?",
                  answer: "The Rooms tab allows the system to map a specific Section (e.g., BSIT - 101) to a physical location. Even if no students are evaluated yet, this helps the system track where every section belongs inside the campus.",
                  icon: Icons.meeting_room,
                ),
                _buildFaqItem(
                  question: "How do I assign a Section to a Room?",
                  answer: "Go to the 'Rooms' tab. Search for the section or map them directly in the database to assign them to physical rooms. Once assigned, they appear in the directory.",
                  icon: Icons.add_location_alt,
                ),
                _buildFaqItem(
                  question: "How do I see who is inside a Room?",
                  answer: "In the 'Rooms' tab, simply click on the Room card in the list. It will drop down and show you a list of all students currently enrolled in that section.",
                  icon: Icons.people_alt_outlined,
                ),
                _buildFaqItem(
                  question: "How do I create accounts for Deans and Program Heads?",
                  answer: "Navigate to the 'Users' tab. Select their specific role from the menu, fill in their unique ID, Name, and Email, and click Create. They will now be able to log in to their specific dashboards.",
                  icon: Icons.person_add_alt_1,
                ),
                _buildFaqItem(
                  question: "Why can't I see the Student Evaluations (Ratings)?",
                  answer: "For privacy and system integrity, System Admins handle the 'architecture' (Accounts, Rooms, Sections) of the app. Only Deans and Program Heads have the clearance to view actual academic evaluation scores and comments.",
                  icon: Icons.privacy_tip_outlined,
                ),
                _buildFaqItem(
                  question: "How do I delete a Room or User if I made a mistake?",
                  answer: "Look for the red trash can (delete) icon next to the room or user in their respective lists. Clicking it will permanently remove that record from the database.",
                  icon: Icons.delete_outline,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // A reusable widget to make the FAQ look clean and match your theme
  Widget _buildFaqItem({required String question, required String answer, required IconData icon}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: GrcColors.border),
      ),
      color: Colors.white,
      child: ExpansionTile(
        iconColor: GrcColors.maroon,
        collapsedIconColor: Colors.grey,
        leading: Icon(icon, color: GrcColors.maroon),
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textDark, fontSize: 14)),
        children: [
          Container(
            width: double.infinity,
            color: GrcColors.background,
            padding: const EdgeInsets.all(20),
            child: Text(
              answer,
              style: const TextStyle(color: GrcColors.textDark, fontSize: 13, height: 1.5),
            ),
          )
        ],
      ),
    );
  }
}