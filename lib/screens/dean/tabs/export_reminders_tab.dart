import 'package:flutter/material.dart';
import '../../../theme/grc_theme.dart';

class ExportAndRemindersPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ExportAndRemindersPage({this.userData, super.key});

  @override
  State<ExportAndRemindersPage> createState() => _ExportAndRemindersPageState();
}

class _ExportAndRemindersPageState extends State<ExportAndRemindersPage> {
  bool _isEmailing = false;
  bool _isExporting = false;

  // --- YOUR EXISTING FUNCTIONS GO HERE ---

  Future<void> _handleSendReminders() async {
    setState(() => _isEmailing = true);

    try {
      // 🟢 ---------------------------------------------------------
      // 🟢 PASTE YOUR WORKING EMAILJS LOGIC HERE!
      // 🟢 ---------------------------------------------------------

      // Simulating network delay so you can see the new loading button animation
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminders sent successfully!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isEmailing = false);
    }
  }

  Future<void> _handleExportCSV() async {
    setState(() => _isExporting = true);

    try {
      // 🟢 ---------------------------------------------------------
      // 🟢 PASTE YOUR WORKING EXPORT LOGIC HERE!
      // 🟢 ---------------------------------------------------------

      // Simulating network delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CSV Export downloaded!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ---------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 700 ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DATA EXPORT & REMINDERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GrcColors.maroon, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text("Manage reports and manually ping students with pending evaluations.", style: TextStyle(fontSize: 12, color: GrcColors.textLight)),
          const SizedBox(height: 24),

          // --- ENHANCEMENT 2: Best Practices Banner ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "System Note: EmailJS triggers count towards a monthly quota. Please use the automated reminder ping sparingly to avoid hitting system limits.",
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- ENHANCEMENT 1: Constrained Width Control Panel ---
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), // Prevents massive stretching on wide monitors
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // CARD 1: EMAIL REMINDERS
                    _buildActionCard(
                      title: "EmailJS Reminders",
                      subtitle: "Send an automated email to all students who have not completed their evaluations.",
                      icon: Icons.mark_email_unread_outlined,
                      buttonText: _isEmailing ? "SENDING..." : "SEND REMINDERS",
                      buttonIcon: Icons.send_rounded,
                      color: Colors.orange,
                      isLoading: _isEmailing,
                      onTap: _handleSendReminders,
                    ),
                    const SizedBox(height: 16),

                    // CARD 2: MASTER CSV EXPORT
                    _buildActionCard(
                      title: "Generate Master Report (CSV)",
                      subtitle: "Download a comprehensive Excel-ready CSV containing all evaluations and raw comments.",
                      icon: Icons.description_outlined,
                      buttonText: _isExporting ? "EXPORTING..." : "EXPORT CSV",
                      buttonIcon: Icons.download_rounded,
                      color: GrcColors.maroon,
                      isLoading: _isExporting,
                      onTap: _handleExportCSV,
                      isOutlined: true, // Makes this button look distinct from the primary ping button
                    ),
                  ],
                ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- ENHANCEMENT 3: Elevated "SaaS" Card Widget ---
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonText,
    required IconData buttonIcon,
    required Color color,
    required VoidCallback onTap,
    required bool isLoading,
    bool isOutlined = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 600;

        Widget actionButton = SizedBox(
          height: 44,
          width: isMobile ? double.infinity : 180,
          child: isOutlined
              ? OutlinedButton.icon(
            onPressed: isLoading ? null : onTap,
            icon: isLoading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: color, strokeWidth: 2))
                : Icon(buttonIcon, size: 18),
            label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
              : ElevatedButton.icon(
            onPressed: isLoading ? null : onTap,
            icon: isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(buttonIcon, size: 18, color: Colors.white),
            label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GrcColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GrcColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GrcColors.textDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: GrcColors.textLight, height: 1.4)),
                  const SizedBox(height: 20),
                  actionButton,
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GrcColors.textDark)),
                        const SizedBox(height: 6),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: GrcColors.textLight, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  actionButton,
                ],
              ),
        );
      }
    );
  }
}