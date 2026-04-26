import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../../theme/grc_theme.dart';

/// [DataImportTab] handles the mass upload of Pre-Enrollment Forms (PEF).
/// It allows the System Admin to pick a local CSV file, parse the data,
/// and automatically populate the Firestore 'users' collection with
/// correctly mapped students, sections, and subjects.
class DataImportTab extends StatefulWidget {
  const DataImportTab({super.key});

  @override
  State<DataImportTab> createState() => _DataImportTabState();
}

class _DataImportTabState extends State<DataImportTab> {
  bool _isUploading = false;
  String _statusMessage = "Ready: Awaiting CSV data payload.";

  Future<void> _processCSV() async {
    setState(() {
      _isUploading = true;
      _statusMessage = "Opening file explorer...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null) {
        setState(() {
          _isUploading = false;
          _statusMessage = "Aborted: No file selected.";
        });
        return;
      }

      setState(() => _statusMessage = "Processing: Decoding file...");

      final bytes = result.files.single.bytes!;
      final csvString = utf8.decode(bytes);

      List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);

      if (csvTable.length <= 1) throw "Error: The file appears to be empty or missing data rows.";

      setState(() => _statusMessage = "Processing: Compiling student portfolios...");

      Map<String, Map<String, dynamic>> compiledStudents = {};

      for (int i = 1; i < csvTable.length; i++) {
        var row = csvTable[i];

        // 🟢 REQUIRED: 6 Columns for the full PEF layout
        if (row.length >= 6) {
          String id = row[0].toString().trim();
          String name = row[1].toString().trim();
          String subjectCode = row[2].toString().trim();
          String subjectTitle = row[3].toString().trim(); // New: Subject Title
          String section = row[4].toString().trim();
          String room = row[5].toString().trim();         // New: Room Number

          if (!compiledStudents.containsKey(id)) {
            compiledStudents[id] = {
              'id': id,
              'name': name,
              'role': 'STUDENT',
              'status': 'APPROVED',
              'enrolled_subjects': [],
              'createdAt': FieldValue.serverTimestamp(),
            };
          }

          // 🟢 Saves all the new data to the student's profile
          compiledStudents[id]!['enrolled_subjects'].add({
            'code': subjectCode,
            'title': subjectTitle,
            'section': section,
            'room': room,
          });
        }
      }

      if (compiledStudents.isEmpty) {
        throw "Error: No valid rows found. Ensure the CSV has 6 columns.";
      }

      setState(() => _statusMessage = "Uploading ${compiledStudents.length} profiles to database...");

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var studentData in compiledStudents.values) {
        var docRef = FirebaseFirestore.instance.collection('users').doc(studentData['id']);
        batch.set(docRef, studentData, SetOptions(merge: true));
      }

      await batch.commit();

      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'Bulk imported ${compiledStudents.length} student schedules via CSV (6-Column Format).',
        'user': 'System Admin',
        'date': DateTime.now().toString(),
      });

      setState(() {
        _isUploading = false;
        _statusMessage = "Success: ${compiledStudents.length} student profiles synchronized successfully.";
      });

    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusMessage = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BULK DATA IMPORT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: GrcColors.maroon, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Text("Upload Pre-Enrollment Forms (PEF) via CSV to assign students to their specific subjects, sections, and rooms.", style: TextStyle(color: GrcColors.textLight, fontSize: 13)),
            const SizedBox(height: 32),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: GrcColors.border),
              ),
              color: GrcColors.surface,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 40),
                child: Column(
                children: [
                  const Icon(Icons.upload_file, size: 64, color: GrcColors.maroon),
                  const SizedBox(height: 24),
                  const Text("UPLOAD PRE-ENROLLMENT DATA (.CSV)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GrcColors.textDark)),
                  const SizedBox(height: 12),
                  // 🟢 UI updated to show 6 columns
                  const Text(
                    "Ensure your file contains the following exact 6 columns:\nStudentID | FullName | SubjectCode | SubjectTitle | Section | Room",
                    style: TextStyle(fontSize: 13, color: GrcColors.textLight, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  _isUploading
                      ? const CircularProgressIndicator(color: GrcColors.maroon)
                      : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrcColors.maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _processCSV,
                    icon: const Icon(Icons.folder_open),
                    label: const FittedBox(child: Text("SELECT FILE & UPLOAD", style: TextStyle(fontWeight: FontWeight.bold))),
                  ),

                  const SizedBox(height: 40),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GrcColors.gold,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GrcColors.border),
                    ),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: GrcColors.textDark),
                      textAlign: TextAlign.center,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    ));
  }
}