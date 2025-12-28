import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'family_service.dart';
import '../layout/main_layout.dart';
import '../auth/login_screen.dart';

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
      await FamilyService().joinFamily(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Joined family!'), backgroundColor: Colors.green));
        // Navigate to the main dashboard and clear the back stack so the user cannot return to setup
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Join failed: $msg'), backgroundColor: Colors.red));
        // If the user is not authenticated, send them to the login screen to re-authenticate
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
          tabs: const [Tab(text: 'Scan'), Tab(text: 'Enter Code')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Scan Tab
          Column(
            children: [
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) async {
                    if (_scanned) return; // debounce
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final raw = barcodes.first.rawValue ?? '';
                    if (raw.isEmpty) return;

                    setState(() => _scanned = true);

                    // Expecting either raw family id or invite link like famvault://join/<id>
                    String familyId = raw;
                    final uri = Uri.tryParse(raw);
                    if (uri != null && uri.pathSegments.isNotEmpty) {
                      // Accept both famvault://join/<id> and https links
                      final id = uri.pathSegments.last;
                      if (id.isNotEmpty) familyId = id;
                    }

                    await _joinByCode(familyId);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => _scanned = false),
                      child: const Text('Scan Again'),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text(
                            'Point the camera at the family QR or invite link.')),
                  ],
                ),
              ),
            ],
          ),

          // Enter Code Tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                      labelText: 'Family ID or paste invite link',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isJoining
                        ? null
                        : () async {
                            final raw = _codeController.text.trim();
                            if (raw.isEmpty) return;
                            String familyId = raw;
                            final uri = Uri.tryParse(raw);
                            if (uri != null && uri.pathSegments.isNotEmpty)
                              familyId = uri.pathSegments.last;
                            await _joinByCode(familyId);
                          },
                    child: _isJoining
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Join Family'),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                    'Generate invite for your family (open Family Details to show this QR to others):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const FamilyInviteCard(sampleFamilyId: 'family_12345'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small widget to show a sample QR for a family id. Use in Family Details with the real id.
class FamilyInviteCard extends StatelessWidget {
  final String sampleFamilyId;
  const FamilyInviteCard({super.key, required this.sampleFamilyId});

  @override
  Widget build(BuildContext context) {
    final invite = 'famvault://join/$sampleFamilyId';
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            PrettyQr(
              data: invite,
              size: 160,
              roundEdges: true,
            ),
            const SizedBox(height: 12),
            SelectableText(invite, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
