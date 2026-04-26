import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. STUDENT LOGIN (ID Based - Automatic Store)
  Future<void> studentLogin({
    required String id,
    required String name,
    required String section,
    required String email,
  }) async {
    // Check if student exists
    var doc = await _db.collection('users').doc(id).get();

    if (!doc.exists) {
      // Automatic store in DB if new
      await _db.collection('users').doc(id).set({
        'id': id,
        'name': name,
        'section': section,
        'email': email,
        'role': 'STUDENT',
        'createdAt': DateTime.now(),
      });
    }
  }

  // 2. ADMIN/DEAN LOGIN (Email/Pass)
  Future<UserCredential?> staffLogin(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // 3. ADMIN CREATING PH/DEAN ACCOUNTS
  Future<void> createStaffAccount({
    required String id,
    required String email,
    required String name,
    required String role, // PROGRAM_HEAD or DEAN
    String? department,
  }) async {
    // Note: Admin creates the record in Firestore.
    // You can use Firebase Functions or a secondary app to create the Auth Email/Pass.
    await _db.collection('users').doc(id).set({
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'department': department,
      'status': 'authorized', // Admin gives access
    });
  }
}