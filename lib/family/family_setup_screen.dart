import 'package:flutter/material.dart';
import 'family_service.dart';
import '../layout/main_layout.dart';

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

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _familyService.createFamily(name);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoin() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _familyService.joinFamily(id);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Setup Family", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Create: Family Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: _isLoading ? null : _handleCreate, child: const Text("Create Family")),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 40),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: "Join: Family ID", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _isLoading ? null : _handleJoin, child: const Text("Join Family")),
            ],
          ),
        ),
      ),
    );
  }
}