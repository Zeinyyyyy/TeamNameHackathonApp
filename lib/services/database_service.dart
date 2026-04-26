import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Admin creates PH or Dean account
  Future<void> createStaffAccount(String id, String name, String email, String role, String? dept) async {
    await _db.collection('users').doc(id).set({
      'id': id, 'name': name, 'email': email, 'role': role, 'department': dept, 'createdAt': DateTime.now(),
    });
  }

  // Submit Evaluation with Weights
  Future<void> submitEvaluation({
    required String teacherId,
    required String evaluatorId,
    required String role,
    required double score1,
    required double score2,
    required double score3,
  }) async {
    double rawAvg = (score1 + score2 + score3) / 3;
    double weightedScore = 0;

    if (role == 'STUDENT') weightedScore = rawAvg * 0.50;
    else if (role == 'PROGRAM HEAD') weightedScore = rawAvg * 0.30;
    else if (role == 'DEAN') weightedScore = rawAvg * 0.20;

    await _db.collection('evaluations').add({
      'teacherId': teacherId,
      'evaluatorId': evaluatorId, // For audit trail
      'role': role,
      'weightedScore': weightedScore,
      'timestamp': DateTime.now(),
    });
  }
}