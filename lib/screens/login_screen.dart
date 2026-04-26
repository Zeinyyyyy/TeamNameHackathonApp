// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/grc_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'student/student_eval_screen.dart';
import 'program_head/program_head_dashboard.dart';
import 'dean/dean_dashboard.dart' show DeanDashboard;
import 'admin/admin_dashboard.dart';

/// [LoginScreen] handles user authentication and session persistence.
/// It verifies credentials against Firebase Auth, retrieves the user's role
/// and approval status from Firestore, and routes them to the appropriate 
/// dashboard (Admin, Dean, Program Head, or Student).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedRole = 'STUDENT';
  bool isRegistering  = false;

  final TextEditingController _idController       = TextEditingController();
  final TextEditingController _nameController     = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedDept;

  final List<String> _colleges = [
    'College of Business Administration',
    'College of Entrepreneurship',
    'College of Accountancy',
    'College of Education',
    'College of Computer Studies',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _clearFields() {
    _idController.clear();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() { _selectedDept = null; isRegistering = false; });
  }

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('saved_user_data');
    if (userJson != null) {
      Map<String, dynamic> userData = jsonDecode(userJson);
      if (!mounted) return;
      String role = userData['role']?.toString().toUpperCase() ?? '';
      if (role == 'STUDENT') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeacherListScreen(userData: userData)));
      } else if (role == 'PROGRAM HEAD') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProgramHeadDashboard(userData: userData)));
      } else if (role == 'DEAN') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DeanDashboard(userData: userData)));
      } else if (role == 'ADMIN') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboard(userData: userData)));
      }
    }
  }

  Future<void> handleAction() async {
    String id    = _idController.text.trim();
    String email = _emailController.text.trim();

    try {
      if (selectedRole == 'ADMIN') {
        if (_emailController.text == "adminmaya@gmail.com" && _passwordController.text == "admin123") {
          Map<String, dynamic> adminData = {'id': 'ADMIN-001', 'name': 'Super Admin', 'role': 'ADMIN', 'email': 'adminmaya@gmail.com'};
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_user_data', jsonEncode(adminData));
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboard(userData: adminData)));
        } else {
          throw "Invalid Admin Credentials";
        }
        return;
      }

      if (id.isEmpty) throw "Please enter your ID Number";

      if (isRegistering) {
        if (_nameController.text.isEmpty) throw "Please enter your Full Name";
        if (email.isEmpty) throw "Please enter your Email Address";
        if (_selectedDept == null) throw "Please select a College";

        var existingDoc = await _firestore.collection('users').doc(id).get();
        if (existingDoc.exists) throw "Error: ID number already registered.";

        await _firestore.collection('users').doc(id).set({
          'id': id, 'name': _nameController.text.trim(), 'email': email,
          'role': selectedRole, 'status': 'PENDING', 'department': _selectedDept,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _showMsg("Request sent to Admin. Account is pending approval.", Colors.green);
        _clearFields();
      } else {
        var doc = await _firestore.collection('users').doc(id).get();

        if (!doc.exists) {
          if (selectedRole == 'STUDENT') throw "ID not found. Please wait for the System Admin to create your account.";
          else throw "ID not found. Please register to request access.";
        }

        var userData = doc.data() as Map<String, dynamic>;

        if (userData['role']?.toString().toUpperCase() == selectedRole.toUpperCase()) {
          if (userData['status']?.toString().toUpperCase() == 'APPROVED' || selectedRole == 'STUDENT') {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            Map<String, dynamic> safeData = {};
            userData.forEach((key, value) {
              if (value is String || value is int || value is double || value is bool) {
                safeData[key] = value;
              }
            });
            await prefs.setString('saved_user_data', jsonEncode(safeData));

            if (!mounted) return;
            if (selectedRole == 'STUDENT') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeacherListScreen(userData: userData)));
            } else if (selectedRole == 'PROGRAM HEAD') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProgramHeadDashboard(userData: userData)));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DeanDashboard(userData: userData)));
            }
          } else {
            throw "Your account is currently PENDING Admin approval. (Status is: ${userData['status']})";
          }
        } else {
          throw "ID is registered, but not as a $selectedRole.";
        }
      }
    } catch (e) {
      _showMsg(e.toString(), GrcColors.danger);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canRegister = selectedRole == 'DEAN' || selectedRole == 'PROGRAM HEAD';
    final size = MediaQuery.of(context).size;
    final bool isNarrow = size.width < 700;

    return Scaffold(
      backgroundColor: GrcColors.background,
      body: isNarrow ? _buildMobileLayout(canRegister) : _buildDesktopLayout(canRegister),
    );
  }

  // ─── DESKTOP: TRUE SPLIT PANEL ───────────────────────────────────────────
  Widget _buildDesktopLayout(bool canRegister) {
    return Row(
      children: [
        // LEFT: Maroon Brand Panel — enhanced
        Expanded(
          flex: 2,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B1A3E), Color(0xFF6B1029)],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                // ── SYSTEM TITLE ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "EVALUATION SYSTEM",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GrcColors.leftPanelText, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 20),

                // ── TAGLINE enhanced ─────────────────────────────────
                const Text(
                  "Touching Hearts,",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: GrcColors.leftPanelText, height: 1.5, fontStyle: FontStyle.italic),
                ),
                const Text(
                  "Renewing Minds,",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: GrcColors.leftPanelText, height: 1.5, fontStyle: FontStyle.italic),
                ),
                const Text(
                  "Transforming Lives.",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: GrcColors.leftPanelText, height: 1.5, fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 36),

                // ── DIVIDER ──────────────────────────────────────────
                Container(height: 1, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 28),

                // ── WHO CAN LOGIN ────────────────────────────────────
                const Text("PORTAL ACCESS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: GrcColors.leftPanelSub, letterSpacing: 2)),
                const SizedBox(height: 14),
                _buildRolePill("Students",      Icons.school_outlined),
                const SizedBox(height: 10),
                _buildRolePill("Program Heads", Icons.assignment_ind_outlined),
                const SizedBox(height: 10),
                _buildRolePill("Deans",         Icons.account_balance_outlined),
                const SizedBox(height: 10),
                _buildRolePill("System Admin",  Icons.admin_panel_settings_outlined),

                const Spacer(),

                // ── FOOTER ───────────────────────────────────────────
                Container(height: 1, color: Colors.white.withOpacity(0.10)),
                const SizedBox(height: 16),
                Text(
                  "© ${DateTime.now().year} Global Reciprocal Colleges",
                  style: const TextStyle(fontSize: 10, color: GrcColors.leftPanelSub, letterSpacing: 0.3),
                ),
                const SizedBox(height: 4),
                const Text(
                  "grc.edu.ph",
                  style: TextStyle(fontSize: 10, color: GrcColors.leftPanelSub, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),

        // RIGHT: White Form Panel — enhanced
        Expanded(
          flex: 3,
          child: Container(
            color: GrcColors.surface,
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 52),
                  child: _buildForm(canRegister),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── MOBILE: STACKED ────────────────────────────────────────────────────
  Widget _buildMobileLayout(bool canRegister) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mini brand header — enhanced
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B1A3E), Color(0xFF6B1029)],
              ),
            ),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Removed Logo Row
                // Tagline
                const Text(
                  "Touching Hearts, Renewing Minds,\nTransforming Lives.",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300, color: GrcColors.leftPanelText, fontStyle: FontStyle.italic, height: 1.6),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text("EVALUATION SYSTEM",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: GrcColors.leftPanelText, letterSpacing: 1.5)),
                ),
              ],
            ),
          ),
          // Form area
          Container(
            color: GrcColors.surface,
            padding: const EdgeInsets.all(24),
            child: _buildForm(canRegister),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePill(String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: GrcColors.leftPanelText.withOpacity(0.8), size: 15),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 12, color: GrcColors.leftPanelSub, letterSpacing: 0.3, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ─── SHARED FORM ────────────────────────────────────────────────────────
  Widget _buildForm(bool canRegister) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Welcome label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: GrcColors.maroon.withOpacity(0.07),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GrcColors.maroon.withOpacity(0.15)),
          ),
          child: Text(
            isRegistering ? "NEW ACCOUNT REQUEST" : "SECURE PORTAL",
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: GrcColors.maroon, letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 14),
        Text(isRegistering ? "Request Access" : "Welcome Back",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: GrcColors.textDark, letterSpacing: -0.5, height: 1.1)),
        const SizedBox(height: 8),
        Text(isRegistering ? "Submit a request to the System Admin." : "Sign in to your GRC evaluation portal.",
            style: const TextStyle(fontSize: 12, color: GrcColors.textLight, height: 1.5)),
        const SizedBox(height: 28),

        // Role dropdown
        _label("ROLE"),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedRole,
          isExpanded: true,
          decoration: _dec("Select role", Icons.layers_outlined),
          style: const TextStyle(fontSize: 13, color: GrcColors.textDark, fontFamily: 'Roboto'),
          items: ['STUDENT', 'PROGRAM HEAD', 'DEAN', 'ADMIN'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (val) => setState(() { selectedRole = val!; if (!canRegister) isRegistering = false; }),
        ),
        const SizedBox(height: 16),

        // Register toggle
        if (canRegister) ...[
          Row(
            children: [
              _label("MODE"),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => isRegistering = !isRegistering),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRegistering ? GrcColors.maroon.withOpacity(0.08) : GrcColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isRegistering ? GrcColors.maroon : GrcColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(isRegistering ? "Request Access" : "Login",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: isRegistering ? GrcColors.maroon : GrcColors.textLight)),
                      const SizedBox(width: 4),
                      Icon(isRegistering ? Icons.how_to_reg : Icons.login,
                          size: 12, color: isRegistering ? GrcColors.maroon : GrcColors.textLight),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Fields
        if (selectedRole == 'ADMIN') ...[
          _label("EMAIL"),
          const SizedBox(height: 6),
          _field(_emailController, "admin@grc.edu", Icons.email_outlined),
          const SizedBox(height: 14),
          _label("PASSWORD"),
          const SizedBox(height: 6),
          _field(_passwordController, "••••••••", Icons.lock_outline, obscure: true),
        ] else ...[
          _label("ID NUMBER"),
          const SizedBox(height: 6),
          _field(_idController, "e.g. 2024-00001", Icons.badge_outlined),
        ],

        if (isRegistering && canRegister) ...[
          const SizedBox(height: 14),
          _label("FULL NAME"),
          const SizedBox(height: 6),
          _field(_nameController, "Juan Dela Cruz", Icons.person_outline),
          const SizedBox(height: 14),
          _label("EMAIL ADDRESS"),
          const SizedBox(height: 6),
          _field(_emailController, "juan@grc.edu", Icons.alternate_email),
          const SizedBox(height: 14),
          _label("COLLEGE"),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedDept,
            hint: const Text("Select your college", style: TextStyle(fontSize: 12)),
            items: _colleges.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (val) => setState(() => _selectedDept = val),
            decoration: _dec("College", Icons.account_balance_outlined),
            style: const TextStyle(fontSize: 12, color: GrcColors.textDark, fontFamily: 'Roboto'),
          ),
        ],

        const SizedBox(height: 28),

        // CTA Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: handleAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: GrcColors.maroon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: Text(
              selectedRole == 'ADMIN' ? "AUTHORIZE" : (isRegistering ? "SUBMIT REQUEST" : "SIGN IN"),
              style: const TextStyle(color: GrcColors.leftPanelText, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GrcColors.textLight, letterSpacing: 1.5));

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13, color: GrcColors.textDark),
      decoration: _dec(hint, icon),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: GrcColors.textLight, fontSize: 12),
    prefixIcon: Icon(icon, color: GrcColors.maroon.withOpacity(0.5), size: 17),
    filled: true,
    fillColor: GrcColors.surfaceAlt,
    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: GrcColors.border), borderRadius: BorderRadius.circular(6)),
    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: GrcColors.maroon, width: 1.5), borderRadius: BorderRadius.circular(6)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

// ── GRC SPIRAL LOGO PAINTER ────────────────────────────────────────────────
// Recreates the GRC concentric spiral icon in white for use on the maroon panel.
class _GrcSpiralPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double cx = size.width  * 0.44;
    final double cy = size.height * 0.50;

    // Three concentric arcs — outer, mid, inner — mimicking the GRC spiral
    // Outer arc
    paint.strokeWidth = size.width * 0.075;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.42),
      _deg(200), _deg(290), false, paint,
    );

    // Mid arc
    paint.strokeWidth = size.width * 0.07;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.28),
      _deg(185), _deg(310), false, paint,
    );

    // Inner arc
    paint.strokeWidth = size.width * 0.065;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.15),
      _deg(170), _deg(330), false, paint,
    );

    // Vertical tail stroke on the right side (the "f" stroke of the GRC mark)
    paint.strokeWidth = size.width * 0.075;
    final double tailX = cx + size.width * 0.42 * 0.62;
    canvas.drawLine(
      Offset(tailX, cy - size.height * 0.10),
      Offset(tailX, cy + size.height * 0.36),
      paint,
    );
  }

  double _deg(double degrees) => degrees * 3.141592653589793 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}