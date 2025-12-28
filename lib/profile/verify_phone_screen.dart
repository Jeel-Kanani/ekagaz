import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        await d.verifyOTP(phone: widget.phone, token: code, type: 'sms');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified')));
        Navigator.pop(context, true);
        return;
      } catch (_) {}

      // 2) verifyOtp(phone: ..., token: ..., type: 'sms')
      try {
        await d.verifyOtp(phone: widget.phone, token: code, type: 'sms');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified')));
        Navigator.pop(context, true);
        return;
      } catch (_) {}

      // 3) confirmOTP(phone: ..., token: ...)
      try {
        await d.confirmOTP(phone: widget.phone, token: code);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified')));
        Navigator.pop(context, true);
        return;
      } catch (_) {}

      // 4) fallback: attempt verifyOTP(token: code, type: 'sms')
      try {
        await d.verifyOTP(token: code, type: 'sms');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified')));
        Navigator.pop(context, true);
        return;
      } catch (e) {
        throw e;
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
        await auth.signInWithOtp(phone: widget.phone);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent')));
        return;
      } catch (_) {}

      // fallback: signInWithOtp(phone: ... , options: ...)
      try {
        await auth.signInWithOtp(phone: widget.phone, options: {'shouldCreateUser': false});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent')));
        return;
      } catch (e) {
        throw e;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
