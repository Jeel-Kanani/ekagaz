import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../auth/login_screen.dart';
import 'premium_screen.dart';
import '../core/theme_service.dart';
import '../profile/edit_profile_screen.dart';
import '../core/biometric_service.dart'; // ✅ Import Service

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _biometricService = BiometricService();
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _biometricService.isLockEnabled();
    if (mounted) setState(() => _isLockEnabled = enabled);
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      // If turning ON, verify fingerprint first to ensure it works
      final success = await _biometricService.authenticate();
      if (success) {
        await _biometricService.setLockEnabled(true);
        setState(() => _isLockEnabled = true);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Authentication failed. Cannot enable lock.")));
      }
    } else {
      // If turning OFF, just do it
      await _biometricService.setLockEnabled(false);
      setState(() => _isLockEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          // GO PRO BANNER
          ListTile(
            tileColor: Colors.amber[100],
            leading: const Icon(Icons.workspace_premium, color: Colors.amber),
            title: const Text("Upgrade to PRO",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Remove ads & unlock features"),
            trailing: const Icon(Icons.arrow_forward, color: Colors.amber),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PremiumScreen())),
          ),

          const SizedBox(height: 10),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.email ?? "User"),
            subtitle: const Text("Manage Profile"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          const Divider(),

          // ✅ WORKING APP LOCK SWITCH
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Colors.purple),
            title: const Text("App Lock / Biometrics"),
            subtitle: Text(_isLockEnabled ? "Enabled" : "Disabled"),
            trailing: Switch(
                value: _isLockEnabled,
                activeColor: Colors.purple,
                onChanged: _toggleLock),
          ),

          // DARK MODE SWITCH
          ListTile(
            leading: const Icon(Icons.dark_mode, color: Colors.indigo),
            title: const Text("Dark Mode"),
            trailing: Switch(
              value: context.watch<ThemeService>().isDarkMode,
              onChanged: (val) => context.read<ThemeService>().toggleTheme(val),
            ),
          ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0),
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out?'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          )
        ],
      ),
    );
  }
}
