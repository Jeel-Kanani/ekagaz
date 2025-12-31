import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'profile_provider.dart';

/// VerifyPhoneScreen
/// - Opened by `EditProfileScreen` after a phone update.
/// - Enter the SMS code you received and press Verify.
/// - Use Resend to request another code; the Send uses `signInWithOtp` or equivalent on the client.
/// NOTE: SMS delivery depends on your Supabase project's phone provider; test on a real device.
class VerifyPhoneScreen extends StatefulWidget {
  final String phone;
  const VerifyPhoneScreen({super.key, required this.phone});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _isLoading = true);

    final auth = Supabase.instance.client.auth; // use dynamic calls for compatibility
    try {
      // Try several possible method names to support different library versions
      final d = auth as dynamic;

      // 1) verifyOTP(phone: ..., token: ..., type: 'sms')
      try {
        print('[VerifyPhone] Trying verifyOTP(phone, token)');
        await d.verifyOTP(phone: widget.phone, token: code, type: 'sms');
        print('[VerifyPhone] verifyOTP succeeded');
        await _onVerified();
        return;
      } catch (e) {
        print('[VerifyPhone] verifyOTP failed: $e');
      }

      // 2) verifyOtp(phone: ..., token: ..., type: 'sms')
      try {
        print('[VerifyPhone] Trying verifyOtp(phone, token)');
        await d.verifyOtp(phone: widget.phone, token: code, type: 'sms');
        print('[VerifyPhone] verifyOtp succeeded');
        await _onVerified();
        return;
      } catch (e) {
        print('[VerifyPhone] verifyOtp failed: $e');
      }

      // 3) confirmOTP(phone: ..., token: ...)
      try {
        print('[VerifyPhone] Trying confirmOTP(phone, token)');
        await d.confirmOTP(phone: widget.phone, token: code);
        print('[VerifyPhone] confirmOTP succeeded');
        await _onVerified();
        return;
      } catch (e) {
        print('[VerifyPhone] confirmOTP failed: $e');
      }

      // 4) fallback: attempt verifyOTP(token: code, type: 'sms')
      try {
        print('[VerifyPhone] Trying verifyOTP(token) fallback');
        await d.verifyOTP(token: code, type: 'sms');
        print('[VerifyPhone] verifyOTP(token) succeeded');
        await _onVerified();
        return;
      } catch (e) {
        print('[VerifyPhone] verifyOTP fallback failed: $e');
        rethrow;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verify failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    final auth = Supabase.instance.client.auth as dynamic;
    try {
      // Many Supabase clients use signInWithOtp for sending SMS codes
      try {
        print('[VerifyPhone] Sending code via signInWithOtp(phone)');
        await auth.signInWithOtp(phone: widget.phone);
        print('[VerifyPhone] signInWithOtp sent');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent')));
        return;
      } catch (e) {
        print('[VerifyPhone] signInWithOtp failed: $e');
      }

      // fallback: signInWithOtp(phone: ... , options: ...)
      try {
        print('[VerifyPhone] Sending code via signInWithOtp(phone, options)');
        await auth.signInWithOtp(phone: widget.phone, options: {'shouldCreateUser': false});
        print('[VerifyPhone] signInWithOtp(options) sent');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent')));
        return;
      } catch (e) {
        print('[VerifyPhone] signInWithOtp(options) failed: $e');
        rethrow;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onVerified() async {
    // refresh user profile and provider state
    try {
      await Supabase.instance.client.auth.getUser();
    } catch (_) {}
    try {
      if (mounted) await context.read<ProfileProvider>().loadProfile();
    } catch (_) {}
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified'), backgroundColor: Colors.green));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('A verification code was sent to ${widget.phone}. Enter it below to verify your phone.'),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Verification code', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: _isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: _isLoading ? null : _resendCode, child: const Text('Resend'))
              ],
            )
          ],
        ),
      ),
    );
  }
}
