import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(dynamic session) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUp = false;
  bool _showPassword = false;
  bool _isLoading = false;

  String _email = '';
  String _password = '';
  String _fullName = '';
  String _studentId = '';
  String _section = '';
  String _batch = DateTime.now().year.toString();
  String? _errorMessage;

  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _textDark = const Color(0xFF0F172A);

  /// --- TRANSLATES TECHNICAL ERRORS TO HUMAN SPEECH ---
  void _displayFriendlyError(dynamic e, {bool isWifiOnly = false}) {
    String message;
    final err = e.toString().toLowerCase();

    if (err.contains('socketexception') || err.contains('errno = 111') || err.contains('connection refused')) {
      message = isWifiOnly
          ? 'Wi‑Fi appears to be blocking the portal. Try another Wi‑Fi or use mobile data.'
          : 'Cannot reach the portal. Please check your internet or try again in a moment.';
    } else if (err.contains('network_error') || err.contains('connectivityresult.none')) {
      message = 'No internet connection detected.';
    } else if (e is AuthException) {
      message = e.message;
    } else if (err.contains('invalid_otp')) {
      message = 'The code you entered is incorrect or expired.';
    } else {
      message = 'Authentication failed. Please verify your details.';
    }

    setState(() => _errorMessage = message);
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);

    if (_email.isEmpty || (_isSignUp && (_fullName.isEmpty || _studentId.isEmpty))) {
      setState(() => _errorMessage = 'Please fill in all required fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Check Internet
      final connectivity = await Connectivity().checkConnectivity();
      final hasNetwork = connectivity.isNotEmpty && !connectivity.contains(ConnectivityResult.none);
      final isWifiOnly = connectivity.contains(ConnectivityResult.wifi) &&
          !connectivity.contains(ConnectivityResult.mobile) &&
          !connectivity.contains(ConnectivityResult.ethernet);

      if (!hasNetwork) {
        throw 'network_error';
      }

      final client = SupabaseService.client;

      // 2. Request OTP
      if (_isSignUp) {
        await client.auth.signInWithOtp(
          email: _email,
          shouldCreateUser: true,
          data: {
            'full_name': _fullName,
            'student_id': _studentId.toUpperCase(),
            'section': _section.trim().toUpperCase(),
            'batch': int.tryParse(_batch) ?? DateTime.now().year,
          },
        );
      } else {
        await client.auth.signInWithOtp(email: _email);
      }

      // 3. Show Verification Dialog
      final otp = await _promptOtpCode(
        title: _isSignUp ? 'Verify Email' : 'Welcome Back',
        subtitle: 'Enter the 6-digit code sent to $_email',
      );

      if (otp == null || otp.isEmpty) {
        setState(() => _isLoading = false);
        return; 
      }

      // 4. Verify OTP
      final res = await client.auth.verifyOTP(
        email: _email,
        token: otp,
        type: _isSignUp ? OtpType.signup : OtpType.email,
      );

      if (res.session != null) {
        // Set password if signing up (Handled as soft-fail)
        if (_isSignUp && _password.isNotEmpty) {
          try {
            await client.auth.updateUser(UserAttributes(password: _password));
          } catch (e) {
            debugPrint("Password update failed: $e");
          }
        }
        await widget.onLogin(res.session);
      } else {
        throw 'invalid_otp';
      }

    } catch (e) {
      final connectivity = await Connectivity().checkConnectivity();
      final isWifiOnly = connectivity.contains(ConnectivityResult.wifi) &&
          !connectivity.contains(ConnectivityResult.mobile) &&
          !connectivity.contains(ConnectivityResult.ethernet);
      _displayFriendlyError(e, isWifiOnly: isWifiOnly);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTabSwitcher(),
              const SizedBox(height: 24),
              if (_errorMessage != null) _buildErrorCard(_errorMessage!),
              _buildFormFields(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENT WIDGETS ---

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),
        Text('FidelShare', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: _textDark)),
        Text('Academic Network Portal', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _buildTabItem('Sign In', !_isSignUp),
          _buildTabItem('Sign Up', _isSignUp),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        if (_isSignUp) ...[
          _buildField('Full Name', Icons.person_outline, (v) => _fullName = v),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildField('Student ID', Icons.badge_outlined, (v) => _studentId = v)),
              const SizedBox(width: 12),
              Expanded(child: _buildField('Section', Icons.grid_view, (v) => _section = v)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _buildField('Academic Email', Icons.email_outlined, (v) => _email = v, keyboardType: TextInputType.emailAddress),
        if (_isSignUp) ...[
          const SizedBox(height: 12),
          _buildField('Password', Icons.lock_outline, (v) => _password = v, isPassword: true),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildField(String hint, IconData icon, Function(String) onChanged, {bool isPassword = false, TextInputType? keyboardType}) {
    return TextField(
      onChanged: onChanged,
      obscureText: isPassword && !_showPassword,
      keyboardType: keyboardType,
      style: TextStyle(color: _textDark, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        fillColor: _bgLight,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ) : null,
      ),
    );
  }

  Widget _buildTabItem(String title, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isSignUp = title == 'Sign Up'),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Text(title, style: TextStyle(color: active ? _primaryBlue : Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
        ],
      ),
    );
  }

  Future<String?> _promptOtpCode({required String title, required String subtitle}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofocus: true,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12, color: Color(0xFF2563EB)),
              decoration: InputDecoration(
                counterText: "", 
                hintText: "000000",
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.2), letterSpacing: 12),
                fillColor: const Color(0xFFF8FAFC), 
                filled: true, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                if (value.length == 6) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (context.mounted) Navigator.pop(context, value);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const Text("Verifying automatically...", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[600]))),
        ],
      ),
    );
  }
}