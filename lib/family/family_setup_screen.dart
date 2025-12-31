import 'package:flutter/material.dart';
import 'create_family_screen.dart';
import 'join_family_screen.dart';

class FamilySetupScreen extends StatelessWidget {
  const FamilySetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Header
              const Icon(Icons.verified_user_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Welcome to FamVault",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Securely manage and share your family's important documents.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Spacer(),

              // Create Option
              _buildOptionCard(
                context,
                title: "Create New Family",
                subtitle: "Start a new vault for your family docs.",
                icon: Icons.add_home_work_outlined,
                color: Colors.blue.shade50,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateFamilyScreen()),
                ),
              ),
              
              const SizedBox(height: 20),

              // Join Option
              _buildOptionCard(
                context,
                title: "Join Existing Family",
                subtitle: "Use an invite code or scan a QR.",
                icon: Icons.group_add_outlined,
                color: Colors.orange.shade50,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinFamilyScreen()),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(icon, size: 32, color: Colors.black87),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
