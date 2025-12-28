import 'package:flutter/material.dart';
import 'family_service.dart';
import 'join_family_screen.dart';
import '../layout/main_layout.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final _familyService = FamilyService();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  bool _isLoading = false;
  bool _scanned = false;
  bool _showManualJoin = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _familyService.createFamily(name);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
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
      if (uri != null && uri.pathSegments.isNotEmpty)
        familyId = uri.pathSegments.last;

      await _familyService.joinFamily(familyId);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $msg")));
        if (msg.contains('Not authenticated')) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Opens a modal bottom sheet with the camera scanner. It closes the sheet and then calls _handleJoin.
  Future<void> _openScannerModal() async {
    _scanned = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Scan Invite'),
                actions: [
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop())
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) async {
                    if (_scanned) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final raw = barcodes.first.rawValue ?? '';
                    if (raw.isEmpty) return;
                    _scanned = true;
                    // Close scanner sheet before navigating
                    Navigator.of(ctx).pop();
                    await _handleJoin(raw);
                    _scanned = false;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCards() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 24),

        // Create Card
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.add_box, size: 28, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Create Your Vault',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Family Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreate,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Create Vault'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Join Card
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.qr_code_scanner, size: 28, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Join a Family',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan QR Code'),
                    onPressed: () => _openScannerModal(),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _showManualJoin = !_showManualJoin),
                  child: Text(_showManualJoin
                      ? 'Hide Code Input'
                      : 'Type code instead'),
                ),
                if (_showManualJoin) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                        labelText: 'Enter family ID or link',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _handleJoin(_idController.text),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Join by ID'),
                    ),
                  )
                ]
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
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
            child: _buildCards(),
          ),
        ),
      ), // close Scaffold
    ); // close WillPopScope
  }
}
