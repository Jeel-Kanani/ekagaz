import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import 'folder_screen.dart';
import 'member_screen.dart';
import '../core/smart_scanner_service.dart'; // Replaced old scan service with SmartScannerService
import '../family/family_service.dart';
import '../family/family_setup_screen.dart';
import '../profile/edit_profile_screen.dart'; // ✅ Import Profile Screen
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _familyName = "Loading...";
  String _currentFamilyId = "";
  List<Map<String, dynamic>> _generalFolders = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final myMemberProfile = await Supabase.instance.client
          .from('family_members')
          .select('family_id, families(name)')
          .eq('user_id', user.id)
          .maybeSingle();

      if (myMemberProfile == null) {
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const FamilySetupScreen()));
        return;
      }

      final familyId = myMemberProfile['family_id'];

      final generalData = await Supabase.instance.client
          .from('folders')
          .select()
          .eq('family_id', familyId)
          .filter('owner_id', 'is', null) 
          .order('created_at');

      // ✅ Fetch NAME and PROFILE_URL now
      final membersData = await Supabase.instance.client
          .from('family_members')
          .select('user_id, role, name, profile_url') 
          .eq('family_id', familyId);

      if (mounted) {
        setState(() {
          _familyName = myMemberProfile['families']['name'];
          _currentFamilyId = familyId;
          _generalFolders = List<Map<String, dynamic>>.from(generalData);
          _members = List<Map<String, dynamic>>.from(membersData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyFamilyId() {
    Clipboard.setData(ClipboardData(text: _currentFamilyId));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Family ID Copied!"), backgroundColor: Colors.green));
  }

  // --- SCANNING LOGIC (Upgraded to Smart Scanner) ---
  Future<void> _handleScan() async {
    // A. Start the Smart Scanner (Camera + Gallery + Filters + Multi-page PDF)
    final scanner = SmartScannerService();
    final result = await scanner.scanDocument();

    if (result == null || result.pdf == null) return; // User cancelled or no PDF returned

    // B. Get the scanned PDF file path
    final scannedPdf = File(result.pdf!.uri);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing Scan...")));
    }

    // C. Show Save Dialog and reuse existing save logic (now handles PDF files)
    await _showSaveDialog(scannedPdf);
  }

  // Show dialog specialized for saving scanned PDFs
  Future<void> _showSaveDialog(File file) async {
    String fileName = "Scan_${DateTime.now().hour}_${DateTime.now().minute}";
    String? selectedFolderId;
    if (_generalFolders.isNotEmpty) selectedFolderId = _generalFolders.first['id'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Save Document"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                   const SizedBox(height: 10),
                   Text("${(file.lengthSync() / 1024).toStringAsFixed(1)} KB", style: const TextStyle(color: Colors.grey)),
                   const SizedBox(height: 10),
                   TextFormField(
                    initialValue: fileName,
                    decoration: const InputDecoration(labelText: "File Name", border: OutlineInputBorder()),
                    onChanged: (val) => fileName = val,
                  ),
                  const SizedBox(height: 15),
                  const Text("Save To:", style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButtonFormField<String>(
                    value: selectedFolderId,
                    isExpanded: true,
                    items: _generalFolders.map((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['name']))).toList(),
                    onChanged: (val) => setDialogState(() => selectedFolderId = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  if (fileName.isNotEmpty && selectedFolderId != null) {
                    Navigator.pop(ctx);
                    // Pass the file, name, and folder ID to your save function (PDF file)
                    _saveScan(file, fileName, selectedFolderId!);
                  }
                },
                child: const Text("Save"),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _saveScan(File file, String fileName, String folderId) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated'), backgroundColor: Colors.red));
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final fileExt = file.path.split('.').last;
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$cleanName.$fileExt';
      await Supabase.instance.client.storage.from('documents').upload(storagePath, file);
      final inserted = await Supabase.instance.client.from('documents').insert({
        'name': '$fileName.$fileExt',
        'folder_id': folderId,
        'family_id': _currentFamilyId,
        'file_path': storagePath,
        'file_type': fileExt,
        'uploaded_by': user.id,
      }).select();

      final insertedRows = List<Map<String, dynamic>>.from(inserted);
      if (insertedRows.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Save failed (no row returned)"), backgroundColor: Colors.red));
        print('SaveScan failed for path: $storagePath');
      } else {
        final id = insertedRows.first['id'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved (id: $id)"), backgroundColor: Colors.green));
          _fetchData();
        }
        print('SaveScan inserted id=$id for path: $storagePath');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'home': return Icons.home;
      case 'lightbulb': return Icons.lightbulb;
      case 'security': return Icons.security;
      case 'directions_car': return Icons.directions_car;
      default: return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_familyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Family Dashboard", style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
           // ✅ EDIT PROFILE BUTTON
          IconButton(
            icon: const Icon(Icons.person_pin, color: Colors.white),
            tooltip: "Edit Profile",
            onPressed: () async {
              // Wait for result, if true, refresh data
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              if (result == true) _fetchData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.build_circle, color: Colors.orange),
            tooltip: "Generate Missing Folders",
            onPressed: () async {
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating Folders...")));
                try {
                  final memberData = await Supabase.instance.client.from('family_members').select('family_id').eq('user_id', user.id).single();
                  await FamilyService().createPersonalFolders(user.id, memberData['family_id']);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Done! Pull to refresh.")));
                  _fetchData(); 
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
          ),
          IconButton(onPressed: _copyFamilyId, icon: const Icon(Icons.copy), tooltip: "Copy Family ID"),
          IconButton(onPressed: () => Supabase.instance.client.auth.signOut().then((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))), icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleScan,
        label: const Text("Scan General"),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🏠 General Documents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
                    itemCount: _generalFolders.length,
                    itemBuilder: (ctx, i) {
                      final f = _generalFolders[i];
                      return _buildFolderCard(f['name'], f['icon'] ?? 'folder', f['id']);
                    },
                  ),
                  const SizedBox(height: 30),
                  const Text("👨‍👩‍👧‍👦 Family Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final member = _members[i];
                      final isMe = member['user_id'] == Supabase.instance.client.auth.currentUser?.id;
                      
                      // ✅ USE REAL NAME OR FALLBACK
                      String displayName = member['name'] ?? "Family Member ${i+1}";
                      if (isMe) displayName += " (Me)";
                      
                      final avatarUrl = member['profile_url'];

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isMe ? Colors.blue[100] : Colors.orange[100],
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null 
                                ? Icon(Icons.person, color: isMe ? Colors.blue : Colors.orange) 
                                : null,
                          ),
                          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(member['role'].toString().toUpperCase()),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => MemberScreen(userId: member['user_id'], familyId: _currentFamilyId, isMe: isMe)));
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFolderCard(String title, String iconString, String folderId) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(folderId: folderId, folderName: title))),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.1))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getIcon(iconString), size: 32, color: Colors.blue[800]),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}