import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Always dark for "Premium" feel
      body: Stack(
        children: [
          // Background Image or Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                const Text(
                  "Upgrade to FamVault PRO",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Remove ads, unlock PDF passwords, and get unlimited cloud storage.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildFeatureRow("🚫 Remove All Ads"),
                _buildFeatureRow("🔒 PDF Password Protection"),
                _buildFeatureRow("☁️ 100GB Cloud Storage"),
                _buildFeatureRow("🔤 Unlimited OCR (Hindi/Eng)"),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Gateway Coming Soon!")));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("Get PRO - ₹99/Year", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("No thanks, I'll keep ads", style: TextStyle(color: Colors.white54)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
