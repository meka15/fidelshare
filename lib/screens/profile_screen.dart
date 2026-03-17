import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import '../models/models.dart';
import '../models/update_info.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../services/storage_service.dart';

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
  bool _isCheckingUpdate = false;
  bool _isPublishing = false;
  String _currentVersion = "";
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = info.version;
      });
    }
  }

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

  Future<void> _handleUpdateCheck() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final update = await UpdateService.checkUpdate();
      if (!mounted) return;

      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your app is up to date!'), behavior: SnackBarBehavior.floating),
        );
      } else {
        _showUpdateDialog(update);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking update: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Update Available', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version (${update.latestVersion}) is available.'),
            if (update.releaseNotes != null) ...[
              const SizedBox(height: 12),
              const Text('What\'s new:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(update.releaseNotes!),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse(update.updateUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePublishUpdate() async {
    setState(() => _isPublishing = true);
    try {
      final latest = await UpdateService.getLatestVersion();
      final currentVersion = _currentVersion; // Gotten from package_info in initState
      
      if (latest != null && !UpdateService.isUpdateAvailable(latest.latestVersion, currentVersion)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Version $currentVersion is already published (or newer than published).'), 
              behavior: SnackBarBehavior.floating
            ),
          );
        }
        setState(() => _isPublishing = false);
        return;
      }

      const channel = MethodChannel('com.example.fidelshare/app_info');
      final String? apkPath = await channel.invokeMethod<String>('getApkPath');
      
      if (apkPath == null) {
        throw Exception('Could not locate app self-executable.');
      }
      
      final file = File(apkPath);
      if (!(await file.exists())) {
        throw Exception('App APK file not found at $apkPath');
      }

      if (!mounted) return;

      final details = await _promptUpdateDetails();
      if (details == null) {
        setState(() => _isPublishing = false);
        return;
      }

      _uploadProgress = 0;

      // 1. Upload to Alwaysdata
      final url = await uploadFile(file, (p) {
        if (mounted) setState(() => _uploadProgress = p.percentage / 100);
      }, customName: 'fidelshare_v${details['version']}.apk');

      // 2. Save to Supabase
      await SupabaseService.client.from('app_version').insert({
        'latest_version': details['version'],
        'min_version': details['minVersion'],
        'update_url': url,
        'release_notes': details['notes'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update published successfully!'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publish failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<Map<String, String>?> _promptUpdateDetails() async {
    final vController = TextEditingController(text: _currentVersion);
    final mvController = TextEditingController(text: _currentVersion);
    final nController = TextEditingController();
    
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('New Update Metadata'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: vController, decoration: const InputDecoration(labelText: 'App Version', hintText: 'e.g. 1.0.5')),
              TextField(controller: mvController, decoration: const InputDecoration(labelText: 'Min Requirement', hintText: 'To force update')),
              TextField(controller: nController, maxLines: 3, decoration: const InputDecoration(labelText: 'Release Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (vController.text.isEmpty) return;
              Navigator.pop(context, {
                'version': vController.text,
                'minVersion': mvController.text.isEmpty ? vController.text : mvController.text,
                'notes': nController.text,
              });
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Header (replaces AppBar)
        Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 10, left: 20, right: 20),
          color: Colors.white,
          child: Row(
            children: [
              Text('Profile', 
                style: GoogleFonts.plusJakartaSans(color: _textDark, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
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
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_primaryBlue, _primaryBlue.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: _primaryBlue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: const Text('Representative Account', 
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
          _buildSettingsTile(
            'Chat Messages', 
            'Notify of new class messages', 
            widget.settings.notifications.chatEnabled,
            (v) => _updateNotify(chat: v)
          ),
          _buildSettingsTile(
            'Announcements', 
            'Notify of new general alerts', 
            widget.settings.notifications.announcementsEnabled,
            (v) => _updateNotify(ann: v)
          ),
          _buildSettingsTile(
            'Schedule Updates', 
            'Notify when classes change', 
            widget.settings.notifications.scheduleEnabled,
            (v) => _updateNotify(schedule: v)
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
            'Update your login security', 
            Icons.lock_outline,
            _isResetting ? null : _handlePasswordReset,
            isLoading: _isResetting
          ),
          if (_resetMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12, top: -4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _resetSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_resetSuccess ? Icons.check_circle_outline : Icons.error_outline, 
                    size: 16, color: _resetSuccess ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_resetMessage!, 
                      style: TextStyle(color: _resetSuccess ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),

          _buildSectionHeader('App Info'),
          _buildActionTile(
            'Online Update', 
            _currentVersion.isEmpty ? 'Check for latest version' : 'Version $_currentVersion', 
            Icons.system_update_outlined,
            _isCheckingUpdate ? null : _handleUpdateCheck,
            isLoading: _isCheckingUpdate
          ),
          if (widget.student.isRepresentative) ...[
            _buildActionTile(
              'Publish New Version', 
              _isPublishing ? 'Uploading... ${(_uploadProgress * 100).toInt()}%' : 'Cloud-Sync this build to students', 
              Icons.cloud_upload_outlined,
              _isPublishing ? null : _handlePublishUpdate,
              isLoading: _isPublishing
            ),
            if (_isPublishing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: _bgLight,
                      color: _primaryBlue,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Text('${(_uploadProgress * 100).toInt()}% uploaded', 
                      style: TextStyle(color: _textGray, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],

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
          const SizedBox(height: 120), // Extra space for floating bottom nav
            ],
          ),
        ),
      ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
    );
  }

  void _updateNotify({bool? upcoming, bool? materials, bool? chat, bool? ann, bool? schedule}) {
    widget.onUpdateSettings(EduSyncSettings(
      notifications: NotificationSettings(
        upcomingClasses: upcoming ?? widget.settings.notifications.upcomingClasses,
        newMaterials: materials ?? widget.settings.notifications.newMaterials,
        chatEnabled: chat ?? widget.settings.notifications.chatEnabled,
        announcementsEnabled: ann ?? widget.settings.notifications.announcementsEnabled,
        scheduleEnabled: schedule ?? widget.settings.notifications.scheduleEnabled,
        fingerprintEnabled: widget.settings.notifications.fingerprintEnabled,
      ),
      sync: widget.settings.sync,
      appearance: widget.settings.appearance,
      facultyVisible: widget.settings.facultyVisible,
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