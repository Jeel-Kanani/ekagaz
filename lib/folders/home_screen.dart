import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import 'folder_screen.dart';
import '../core/scan_service.dart'; // Import the scanner
import 'dart:io'; // Needed for File handling

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _familyName = "Loading...";
  String _role = "...";
  bool _isLoading = true;
  
  // This will store the folders AND their file counts
  List<Map<String, dynamic>> _folders = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Get Family Details
      final memberData = await Supabase.instance.client
          .from('family_members')
          .select('role, family_id, families(name)')
          .eq('user_id', user.id)
          .single();

      final familyId = memberData['family_id'];

      // 2. Get Folders for this Family
      final folderData = await Supabase.instance.client
          .from('folders')
          .select()
          .eq('family_id', familyId)
          .order('created_at');

      // 3. Get All Documents (just the folder_id) to count them
      final documentData = await Supabase.instance.client
          .from('documents')
          .select('folder_id')
          .eq('family_id', familyId);

      // 4. Count files per folder in Dart
      Map<String, int> fileCounts = {};
      for (var doc in documentData) {
        final fid = doc['folder_id'] as String;
        fileCounts[fid] = (fileCounts[fid] ?? 0) + 1;
      }

      // 5. Merge the count into the folder list
      List<Map<String, dynamic>> finalFolders = [];
      for (var folder in folderData) {
        Map<String, dynamic> newFolder = Map.from(folder);
        newFolder['file_count'] = fileCounts[folder['id']] ?? 0;
        finalFolders.add(newFolder);
      }

      if (mounted) {
        setState(() {
          _role = memberData['role'].toString().toUpperCase();
          _familyName = memberData['families']['name'];
          _folders = finalFolders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _familyName = "Error loading";
          _isLoading = false;
        });
      }
    }
  }

  // --- NEW: ACTUAL SAVE LOGIC ---
  Future<void> _saveScan(File file, String fileName, String folderId) async {
    setState(() => _isLoading = true); // Show loading on home screen

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final fileExt = file.path.split('.').last; // jpg, png, etc.
      // Clean up filename (remove special characters)
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user!.id}/${DateTime.now().millisecondsSinceEpoch}_$cleanName.$fileExt';

      // 1. Upload Image to Supabase Storage
      await Supabase.instance.client.storage
          .from('documents')
          .upload(storagePath, file);

      // 2. Get Family ID from the selected folder
      // We could use the one from state, but this is safer
      final folderData = await Supabase.instance.client
          .from('folders')
          .select('family_id')
          .eq('id', folderId)
          .single();

      // 3. Insert Record into Database
      await Supabase.instance.client.from('documents').insert({
        'name': '$fileName.$fileExt', // Save with extension
        'folder_id': folderId,
        'family_id': folderData['family_id'],
        'file_path': storagePath,
        'file_type': fileExt,
        'uploaded_by': user.id,
      });

      // 4. Success & Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document Saved!"), backgroundColor: Colors.green),
        );
        _fetchData(); // Refresh the counts on the dashboard
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UPDATED: SCAN FLOW WITH SAVE DIALOG ---
  Future<void> _handleScan() async {
    final scanService = ScanService();

    // 1. Camera & Crop
    final photo = await scanService.pickImageFromCamera();
    if (photo == null) return;
    
    final cropped = await scanService.cropImage(photo.path);
    if (cropped == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reading text...")));
    }
    
    // 2. OCR
    final text = await scanService.analyzeText(cropped.path);

    // 3. Prepare Dialog Variables
    // Default to first folder if available, else empty string
    String selectedFolderId = _folders.isNotEmpty ? _folders.first['id'] : '';
    String fileName = "Scan_${DateTime.now().hour}_${DateTime.now().minute}"; // Default Name

    if (!mounted) return;

    // 4. Show "Save Details" Dialog
    await showDialog(
      context: context,
      barrierDismissible: false, // Force user to click Save or Cancel
      builder: (ctx) => StatefulBuilder( // Needed to update Dropdown inside Dialog
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Save Document"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Preview
                  Center(child: Image.file(File(cropped.path), height: 150)),
                  const SizedBox(height: 10),
                  
                  // OCR Result Preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[100],
                    child: Text(
                      text.isEmpty ? "No text detected" : "Detected: ${text.length > 30 ? text.substring(0,30)+'...' : text}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Name Input
                  TextFormField(
                    initialValue: fileName,
                    decoration: const InputDecoration(
                      labelText: "File Name",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => fileName = val,
                  ),
                  const SizedBox(height: 15),

                  // Folder Selector
                  const Text("Save To Folder:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    value: selectedFolderId.isNotEmpty ? selectedFolderId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _folders.map((folder) {
                      return DropdownMenuItem(
                        value: folder['id'] as String,
                        child: Text(folder['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedFolderId = val!);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("SAVE"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                onPressed: () {
                  if (fileName.isEmpty || selectedFolderId.isEmpty) return;
                  Navigator.pop(ctx); // Close Dialog
                  // Call the actual save function
                  _saveScan(File(cropped.path), fileName, selectedFolderId);
                },
              ),
            ],
          );
        }
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'badge': return Icons.badge;
      case 'local_hospital': return Icons.local_hospital;
      case 'receipt_long': return Icons.receipt_long;
      case 'school': return Icons.school;
      case 'folder': return Icons.folder;
      case 'more_horiz': return Icons.more_horiz;
      default: return Icons.folder;
    }
  }

  Color _getColor(String iconName) {
    switch (iconName) {
      case 'badge': return Colors.orange;
      case 'local_hospital': return Colors.red;
      case 'receipt_long': return Colors.green;
      case 'school': return Colors.blue;
      case 'folder': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("FamVault"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      // --- SCAN BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleScan, // Calls the Camera logic
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text("Scan New"),
      ),
      // -------------------
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Welcome Back,", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(_familyName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Text("ROLE: $_role", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("Documents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _folders.isEmpty
                        ? const Center(child: Text("No folders found"))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _folders.length,
                            itemBuilder: (context, index) {
                              final folder = _folders[index];
                              return _buildFolderCard(
                                folder['name'], 
                                folder['icon'] ?? 'folder',
                                folder['id'],
                                folder['file_count'] ?? 0
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFolderCard(String title, String iconString, String folderId, int count) {
    final IconData icon = _getIcon(iconString);
    final Color color = _getColor(iconString);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderScreen(
              folderId: folderId,
              folderName: title,
            ),
          ),
        ).then((_) => _fetchData());
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              "$count files", 
              style: TextStyle(color: Colors.grey[500], fontSize: 12)
            ),
          ],
        ),
      ),
    );
  }
}