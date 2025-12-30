import 'package:flutter/material.dart';
import 'family_service.dart';
import 'join_family_screen.dart';
import '../layout/main_layout.dart';
import '../profile/edit_profile_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen>
    with SingleTickerProviderStateMixin {
  final _familyService = FamilyService();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  bool _isLoading = false;

  bool _scanned = false; // kept for scanner debouncing
  // collapsed landing/detail state removed to simplify UI; always show a simple landing with Create and Join actions.

  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {

    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate([String? name]) async {
    final famName = (name ?? _nameController.text).trim();
    if (famName.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _familyService.createFamily(famName);
      if (mounted) {
        // After creating, route the user to profile editing first, then to the main dashboard.
        final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        // Regardless of whether they completed profile editing, proceed to dashboard so they can start using the app.
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainLayout()), (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoin(String raw) async {
    final id = raw.trim();
    if (id.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Accept raw ids or invite links like famvault://join/<id>
      var familyId = id;
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.pathSegments.isNotEmpty) familyId = uri.pathSegments.last;

      await _familyService.joinFamily(familyId);

      if (mounted) {
        // After joining, send the user to edit their profile first, then to the dashboard
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainLayout()), (route) => false);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg")));
        if (msg.contains('Not authenticated')) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLanding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text('Welcome to Famvault',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text(
            'Securely store family documents and invite members with a QR',
            textAlign: TextAlign.center),
        const SizedBox(height: 30),

        // Create family — open a small dialog to collect family name
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_box, size: 22),
            label: const Text('Create a New Family', style: TextStyle(fontSize: 16)),
            onPressed: _isLoading
                ? null
                : () async {
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) {
                        final controller = TextEditingController();
                        return AlertDialog(
                          title: const Text('Family Name'),
                          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'e.g., Martinez Family')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
                          ],
                        );
                      },
                    );

                    if (name != null && name.isNotEmpty) await _handleCreate(name);
                  },
          ),
        ),
        const SizedBox(height: 12),

        // Join family — open the dedicated join screen which supports scan, code, and link
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.group_add),
            label: const Text('Join a Family', style: TextStyle(fontSize: 16)),
            onPressed: () {
              if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinFamilyScreen()));
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Supabase.instance.client.auth.currentUser == null) {
          SystemNavigator.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Setup'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // Sign-out and return to login screen
                await Supabase.instance.client.auth.signOut();
                if (mounted)
                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false);
              },
            ),
            IconButton(
              tooltip: 'Open QR Scanner',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                if (mounted)
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const JoinFamilyScreen()));
              },
            )
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildLanding(),
          ),
        ),
      ), // close Scaffold
    ); // close WillPopScope
  }
}
