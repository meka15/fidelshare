import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  final Student student;
  final EduSyncSettings settings;
  final void Function(EduSyncSettings newSettings) onUpdateSettings;
  final Future<void> Function() onLogout;

  const ProfileScreen({
    super.key,
    required this.student,
    required this.settings,
    required this.onUpdateSettings,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isResetting = false;
  String? _resetMessage;
  bool _resetSuccess = false;

  // Colors aligned with your Light SaaS Theme
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textGray = const Color(0xFF64748B);

  // --- UI Components ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 24),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: _textGray,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final initial = widget.student.name.isNotEmpty ? widget.student.name[0] : "?";
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- Logic ---

  Future<void> _handlePasswordReset() async {
    setState(() { _isResetting = true; _resetMessage = null; });
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user?.email == null) throw Exception('Email not found');
      
      await SupabaseService.client.auth.resetPasswordForEmail(user!.email!);
      
      if (!mounted) return;
      final input = await _promptRecoveryInput();
      if (input == null) return;

      if (input['password'] != input['confirm']) {
        setState(() { _resetSuccess = false; _resetMessage = 'Passwords do not match.'; });
        return;
      }

      await SupabaseService.client.auth.verifyOTP(
        email: user.email!,
        token: input['otp']!,
        type: OtpType.recovery,
      );

      await SupabaseService.client.auth.updateUser(UserAttributes(password: input['password']));
      setState(() { _resetSuccess = true; _resetMessage = 'Password updated!'; });
    } catch (e) {
      setState(() { _resetSuccess = false; _resetMessage = 'Error: ${e.toString()}'; });
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Profile', style: GoogleFonts.plusJakartaSans(color: _textDark, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Header Card
          const SizedBox(height: 20),
          Center(child: _buildAvatar()),
          const SizedBox(height: 16),
          Center(
            child: Text(widget.student.name, 
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark)),
          ),
          Center(
            child: Text('ID: ${widget.student.studentId} • Section ${widget.student.section}', 
              style: TextStyle(color: _textGray, fontSize: 14)),
          ),
          if (widget.student.isRepresentative)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('Representative', style: TextStyle(color: _primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),

          _buildSectionHeader('Notifications'),
          _buildSettingsTile(
            'Upcoming Classes', 
            'Alerts before sessions start', 
            widget.settings.notifications.upcomingClasses,
            (v) => _updateNotify(upcoming: v)
          ),
          _buildSettingsTile(
            'New Materials', 
            'Notify when PDFs are added', 
            widget.settings.notifications.newMaterials,
            (v) => _updateNotify(materials: v)
          ),
          _buildActionTile(
            'Send Test Alert', 
            'Triggers a local notification now', 
            Icons.notification_important_outlined,
            () => NotificationService.showLocalNotification(
              title: 'Test Notification', 
              body: 'If you see this, your alert system is working!'
            ),
          ),

          _buildSectionHeader('Security'),
          _buildActionTile(
            'Reset Password', 
            'Sends OTP to your email', 
            Icons.lock_outline,
            _isResetting ? null : _handlePasswordReset,
            isLoading: _isResetting
          ),
          if (_resetMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_resetMessage!, style: TextStyle(color: _resetSuccess ? Colors.green : Colors.red, fontSize: 12)),
            ),

          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: widget.onLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE2E2),
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- Modular UI Elements ---

  Widget _buildSettingsTile(String title, String sub, bool val, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(color: _textDark, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(sub, style: TextStyle(color: _textGray, fontSize: 12)),
        value: val,
        activeColor: _primaryBlue,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile(String title, String sub, IconData icon, VoidCallback? onTap, {bool isLoading = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: _primaryBlue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: _textDark, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(sub, style: TextStyle(color: _textGray, fontSize: 12)),
                ],
              ),
            ),
            isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.chevron_right, color: _textGray),
          ],
        ),
      ),
    );
  }

  void _updateNotify({bool? upcoming, bool? materials}) {
    widget.onUpdateSettings(EduSyncSettings(
      notifications: NotificationSettings(
        upcomingClasses: upcoming ?? widget.settings.notifications.upcomingClasses,
        newMaterials: materials ?? widget.settings.notifications.newMaterials,
        fingerprintEnabled: widget.settings.notifications.fingerprintEnabled,
      ),
      sync: widget.settings.sync,
      appearance: widget.settings.appearance,
    ));
  }

  // Reuse your Recovery Prompt logic but with the new UI style
  Future<Map<String, String>?> _promptRecoveryInput() async {
    final codeController = TextEditingController();
    final passController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Update Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeController, decoration: const InputDecoration(hintText: 'OTP from Email')),
            const SizedBox(height: 12),
            TextField(controller: passController, obscureText: true, decoration: const InputDecoration(hintText: 'New Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, {'otp': codeController.text, 'password': passController.text, 'confirm': passController.text}), 
            child: const Text('Confirm')
          ),
        ],
      ),
    );
  }
}