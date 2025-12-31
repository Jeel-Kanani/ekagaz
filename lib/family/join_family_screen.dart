import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'family_service.dart';
import '../layout/main_layout.dart';
import '../auth/login_screen.dart';
import '../profile/edit_profile_screen.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  bool _isJoining = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinByCode(String code) async {
    setState(() => _isJoining = true);
    try {
      // Calls the logic to add the user to the family in Supabase
      await FamilyService().joinFamily(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Joined family!'), backgroundColor: Colors.green));

        // Open profile edit so user can set their identity in the new family
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainLayout()),
              (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Join failed: $msg'), backgroundColor: Colors.red));

        if (msg.contains('Not authenticated')) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Scan QR'), Tab(text: 'Enter Code')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: QR Scanner
          Column(
            children: [
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) async {
                    if (_scanned) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;

                    final String rawValue = barcodes.first.rawValue ?? '';
                    if (rawValue.isEmpty) return;

                    setState(() => _scanned = true);

                    // Extract ID whether it's a link or a raw string
                    String targetId = rawValue;
                    if (rawValue.contains('famvault://join/')) {
                      targetId = rawValue.split('famvault://join/').last;
                    }

                    await _joinByCode(targetId);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _scanned = false),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text(
                            'Point camera at a Family QR code or Invite Link.')),
                  ],
                ),
              ),
            ],
          ),

          // TAB 2: Manual Code Entry
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Enter Invite Code",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Paste the invite link or enter the Family ID provided by your family admin.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Family ID or Invite Link',
                    hintText: 'e.g. famvault://join/your-id',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isJoining
                        ? null
                        : () async {
                            final raw = _codeController.text.trim();
                            if (raw.isEmpty) return;

                            String familyId = raw;

                            // Parse link if pasted instead of raw ID
                            if (raw.contains('://')) {
                              final uri = Uri.tryParse(raw);
                              if (uri != null && uri.pathSegments.isNotEmpty) {
                                familyId = uri.pathSegments.last;
                              }
                            }

                            await _joinByCode(familyId);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                    ),
                    child: _isJoining
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Join Family',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
