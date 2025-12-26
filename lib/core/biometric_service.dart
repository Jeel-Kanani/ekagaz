import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // Check if hardware is available
  Future<bool> isDeviceSupported() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  // Attempt to Authenticate
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please scan your fingerprint to open FamVault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // --- SETTINGS STORAGE ---
  
  // Turn Lock ON/OFF
  Future<void> setLockEnabled(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_app_lock_enabled', isEnabled);
  }

  // Check if Lock is ON
  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_app_lock_enabled') ?? false;
  }
}