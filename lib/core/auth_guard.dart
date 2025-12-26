import 'package:flutter/material.dart';
import 'biometric_service.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  final _service = BiometricService();
  bool _isLocked = true; // Default to locked while checking
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final enabled = await _service.isLockEnabled();
    setState(() => _isLockEnabled = enabled);

    if (enabled) {
      _authenticate();
    } else {
      // Not enabled, just open
      setState(() => _isLocked = false);
    }
  }

  Future<void> _authenticate() async {
    final authenticated = await _service.authenticate();
    if (authenticated) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLockEnabled) return widget.child;

    if (_isLocked) {
      return Scaffold(
        backgroundColor: Colors.blue[900],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text("FamVault Locked", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text("Unlock with Biometrics"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, 
                  foregroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
                ),
              )
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}