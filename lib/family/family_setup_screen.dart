import 'package:flutter/material.dart';
import 'package:famvault/family/family_service.dart';
import '../main.dart'; // Import main to access SplashScreen

class FamilySetupScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const FamilySetupScreen({Key? key, this.onSuccess}) : super(key: key);

  @override
  _FamilySetupScreenState createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final FamilyService _service = FamilyService();
  final TextEditingController _createController = TextEditingController();
  final TextEditingController _joinController = TextEditingController();

  bool _checking = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkFamily();
  }

  @override
  void dispose() {
    _createController.dispose();
    _joinController.dispose();
    super.dispose();
  }

  // --- NEW HELPER FUNCTION TO NAVIGATE ---
  void _navigateToSplash() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  Future<void> _checkFamily() async {
    try {
      final id = await _service.getMyFamilyId();
      if (id != null) {
        // If already in a family, go to Splash immediately
        _navigateToSplash();
        return;
      }
    } catch (_) {
      // ignore errors
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _createFamily() async {
    final name = _createController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.createFamily(name);
      // SUCCESS! Go to Splash Screen
      _navigateToSplash();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinFamily() async {
    final fid = _joinController.text.trim();
    if (fid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a family id')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.joinFamily(fid);
      // SUCCESS! Go to Splash Screen
      _navigateToSplash();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Family Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create Family'),
            const SizedBox(height: 8),
            TextField(
              controller: _createController,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Family name'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _createFamily,
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Family'),
            ),
            const SizedBox(height: 24),
            const Text('Join Family'),
            const SizedBox(height: 8),
            TextField(
              controller: _joinController,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Family ID'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _joinFamily,
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Join Family'),
            ),
          ],
        ),
      ),
    );
  }
}