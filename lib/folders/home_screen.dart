import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'folder_screen.dart';
import 'member_screen.dart';
import '../core/smart_scanner_service.dart';
import 'package:image/image.dart' as img;
import '../family/family_service.dart';
import '../family/family_setup_screen.dart';
import '../profile/edit_profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../core/local_db_service.dart';
 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _familyName = ""; // Default empty to show loading state cleanly
  String _familyDpUrl = "";
  String _currentFamilyId = "";
  String _inviteCode = "";
  String _myRole = "";
  bool _isAdmin = false;
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

    final prefs = await SharedPreferences.getInstance();

    try {
      // --- TRY ONLINE FETCH ---

      // 1. Get Membership & Family Info
      final myMembership = await Supabase.instance.client
          .from('family_members')
          .select('family_id, role, families(name, dp_url, invite_code)')
          .eq('user_id', user.id)
          .maybeSingle();

      if (myMembership != null) {
        final familyId = myMembership['family_id'];
        final familyData = myMembership['families'];

        // 2. CACHE IDENTITY (Fixes "Not Member" offline)
        await prefs.setString('cached_family_id', familyId);
        await prefs.setString('cached_family_name', familyData?['name'] ?? "My Family");
        await prefs.setString('cached_role', myMembership['role'] ?? 'member');
        await prefs.setString('cached_invite_code', familyData?['invite_code'] ?? "");

        // 3. Update UI
        setState(() {
          _currentFamilyId = familyId;
          _familyName = familyData?['name'] ?? "My Family";
          _familyDpUrl = familyData?['dp_url'] ?? "";
          _inviteCode = familyData?['invite_code'] ?? "";
          _myRole = myMembership['role'] ?? 'member';
          _isAdmin = _myRole == 'admin';
        });

        // 4. Fetch & Cache General Folders
        final generalData = await Supabase.instance.client
            .from('folders')
            .select()
            .eq('family_id', familyId)
            .filter('owner_id', 'is', null)
            .order('created_at');

        // Save to SQLite (Fixes "Cant fetch folder" offline)
        await LocalDBService().cacheFolders(List<Map<String, dynamic>>.from(generalData));

        // --- FETCH & CACHE FAMILY MEMBERS ---
        final membersData = await Supabase.instance.client
            .from('family_members')
            .select('user_id, role, profiles(full_name, avatar_url)')
            .eq('family_id', familyId);

        debugPrint("Fetched ${membersData.length} family members online");

        // Cache family members to SQLite
        await LocalDBService().cacheFamilyMembers(List<Map<String, dynamic>>.from(membersData), familyId);

        if (mounted) {
          setState(() {
            _generalFolders = List<Map<String, dynamic>>.from(generalData);
            _members = List<Map<String, dynamic>>.from(membersData);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // --- OFFLINE MODE (FALLBACK) ---
      debugPrint("Offline Error: $e");

      // 1. Restore Identity from Cache
      final cachedFamilyId = prefs.getString('cached_family_id');
      final cachedName = prefs.getString('cached_family_name');

      if (cachedFamilyId != null && mounted) {
        setState(() {
          _currentFamilyId = cachedFamilyId;
          _familyName = cachedName ?? "Offline Family";
          _myRole = prefs.getString('cached_role') ?? 'member';
          _inviteCode = prefs.getString('cached_invite_code') ?? "";
          _isAdmin = _myRole == 'admin';
        });

        // 2. Load Folders and Members from SQLite
        final localFolders = await LocalDBService().getFolders(cachedFamilyId);
        final localMembers = await LocalDBService().getFamilyMembers(cachedFamilyId);

        debugPrint("Loaded ${localFolders.length} folders and ${localMembers.length} members from local DB");

        setState(() {
          _generalFolders = localFolders;
          _members = localMembers;
          _isLoading = false;
        });

        // Show "Offline" message instead of Red Screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You are offline. Viewing saved data."),
            backgroundColor: Colors.grey
          )
        );
      } else {
        // Only show error if we have NO cached data at all
        if (mounted) {
          setState(() {
            _isLoading = false;
            _familyName = "Offline (No Data)";
          });
        }
      }
    }
  }

  // ... [Keep _copyFamilyId, _showInviteDialog, _handleScan, _showSaveDialog, _saveScan as they were] ...
  // Re-paste them from your original file or previous working version.
  // For brevity I am including the critical Helper methods below:

 

  void _showInviteDialog() {
    if (_currentFamilyId.isEmpty) return;
    
    // Use stored invite code or fallback to ID if none exists (though Join screen prefers code)
    final displayCode = _inviteCode.isNotEmpty ? _inviteCode : _currentFamilyId;
    final invite = 'famvault://join/$displayCode';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160, width: 160,
              child: PrettyQrView.data(
                data: invite,
                decoration: const PrettyQrDecoration(shape: PrettyQrSmoothSymbol(color: Colors.black)),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(invite, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            SelectableText('Code: $displayCode', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_inviteCode.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text("(Using Family ID)", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _handleScan() async {
    // Show quality selection dialog
    ScanQuality selectedQuality = ScanQuality.medium; // Default

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Scan Quality'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose scan quality:'),
              const SizedBox(height: 10),
              RadioListTile<ScanQuality>(
                title: const Text('High Quality (Best for important documents)'),
                subtitle: const Text('Larger file size, best clarity'),
                value: ScanQuality.high,
                groupValue: selectedQuality,
                onChanged: (value) => setState(() => selectedQuality = value!),
              ),
              RadioListTile<ScanQuality>(
                title: const Text('Medium Quality (Balanced)'),
                subtitle: const Text('Good quality, reasonable file size'),
                value: ScanQuality.medium,
                groupValue: selectedQuality,
                onChanged: (value) => setState(() => selectedQuality = value!),
              ),
              RadioListTile<ScanQuality>(
                title: const Text('Low Quality (Fast upload)'),
                subtitle: const Text('Smaller file size, acceptable quality'),
                value: ScanQuality.low,
                groupValue: selectedQuality,
                onChanged: (value) => setState(() => selectedQuality = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performScan(selectedQuality);
              },
              child: const Text('Scan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performScan(ScanQuality quality) async {
    final scanner = SmartScannerService();
    final result = await scanner.scanDocument(quality: quality);
    if (result == null || result.pdf == null) return;
    final scannedPdf = File(result.pdf!.uri);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing Scan...")));
    await _showSaveDialog(scannedPdf);
  }

  Future<void> _showSaveDialog(File file) async {
    String fileName = "Scan_${DateTime.now().hour}_${DateTime.now().minute}";
    String? selectedFolderId;
    if (_generalFolders.isNotEmpty) selectedFolderId = _generalFolders.first['id'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Save Document"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 const Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                 const SizedBox(height: 10),
                 TextFormField(
                  initialValue: fileName,
                  decoration: const InputDecoration(labelText: "File Name", border: OutlineInputBorder()),
                  onChanged: (val) => fileName = val,
                ),
                const SizedBox(height: 15),
                const Text("Save To:", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  initialValue: selectedFolderId,
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
                  _saveScan(file, fileName, selectedFolderId!);
                }
              },
              child: const Text("Save"),
            )
          ],
        );
      }),
    );
  }

  Future<void> _saveScan(File file, String fileName, String folderId) async {
    // ... [Same logic as before] ...
    // Assuming standard upload/insert logic here
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final fileExt = file.path.split('.').last;
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$cleanName.$fileExt';
      await Supabase.instance.client.storage.from('documents').upload(storagePath, file);
      await Supabase.instance.client.from('documents').insert({
        'name': '$fileName.$fileExt',
        'folder_id': folderId,
        'family_id': _currentFamilyId,
        'file_path': storagePath,
        'file_type': fileExt,
        'uploaded_by': user.id,
      });
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"), backgroundColor: Colors.green));
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showFamilyDpOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Family Picture Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Change Picture'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
                if (picked == null) return;
                final bytes = await picked.readAsBytes();
                final ext = picked.name.split('.').last.toLowerCase();
                try {
                  final url = await FamilyService().updateFamilyDp(_currentFamilyId, bytes, ext);
                  if (mounted) {
                    setState(() => _familyDpUrl = url);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Family picture updated"), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                }
              },
            ),
            if (_familyDpUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Picture', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await FamilyService().deleteFamilyDp(_currentFamilyId);
                    if (mounted) setState(() => _familyDpUrl = "");
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Family picture removed"), backgroundColor: Colors.green));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                },
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
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
      // backgroundColor: Colors.grey[50], // REMOVED: Let theme handle it
      appBar: AppBar(
        toolbarHeight: 70, // Increase height for avatar
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: _showFamilyDpOptions,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: _familyDpUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _familyDpUrl,
                        key: ValueKey(_familyDpUrl),
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Failed to load family DP: $error');
                          // On error, clear the URL to show initial
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _familyDpUrl = "");
                          });
                          return Center(child: Text(_familyName.isNotEmpty ? _familyName[0].toUpperCase() : "F", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)));
                        },
                      ),
                    )
                  : Center(child: Text(_familyName.isNotEmpty ? _familyName[0].toUpperCase() : "F", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_familyName.isEmpty ? "Loading..." : _familyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_familyName.isNotEmpty) const Text("Family Dashboard", style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.build_circle, color: Colors.orange),
            tooltip: "Repair Dashboard",
            onPressed: () async {
               await _fetchData();
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dashboard Refreshed & Repaired")));
            },
          ),
          // Removed Copy Icon
          IconButton(onPressed: _showInviteDialog, icon: const Icon(Icons.person_add_alt_1)),
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
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🏠 General Documents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    if (_generalFolders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                        child: const Text("No general folders found. Click the orange 'Repair' tool in the top right.", textAlign: TextAlign.center),
                      )
                    else
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
                    const Text("👨‍👩‍👧‍👦 Family Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    if (_members.isEmpty)
                      const Padding(padding: EdgeInsets.all(10), child: Text("No members found."))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final member = _members[i];
                          final isMe = member['user_id'] == Supabase.instance.client.auth.currentUser?.id;
                          
                          // SAFE ACCESS to Profile Data
                          final profile = member['profiles'] ?? {}; 
                          String displayName = profile['full_name'] ?? "Unknown Member";
                          final avatarUrl = profile['avatar_url'];

                          if (isMe) displayName += " (Me)";

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isMe ? Colors.blue[100] : Colors.orange[100],
                                backgroundImage: (avatarUrl != null && avatarUrl.toString().isNotEmpty) ? NetworkImage(avatarUrl) : null,
                                child: (avatarUrl == null || avatarUrl.toString().isEmpty) 
                                    ? Icon(Icons.person, color: isMe ? Colors.blue : Colors.orange) 
                                    : null,
                              ),
                              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(member['role'].toString().toUpperCase()),
                              trailing: (_isAdmin && !isMe)
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'admin') {
                                          await FamilyService().changeMemberRole(_currentFamilyId, member['user_id'], 'admin');
                                        } else if (value == 'member') {
                                          await FamilyService().changeMemberRole(_currentFamilyId, member['user_id'], 'member');
                                        } else if (value == 'viewer') {
                                          await FamilyService().changeMemberRole(_currentFamilyId, member['user_id'], 'viewer');
                                        } else if (value == 'remove') {
                                          await FamilyService().removeMember(_currentFamilyId, member['user_id']);
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated"), backgroundColor: Colors.green));
                                          _fetchData();
                                        }
                                      },
                                      itemBuilder: (ctx) => const [
                                        PopupMenuItem(value: 'admin', child: Text("Promote to Admin")),
                                        PopupMenuItem(value: 'member', child: Text("Make Member")),
                                        PopupMenuItem(value: 'viewer', child: Text("Make Viewer")),
                                        PopupMenuDivider(),
                                        PopupMenuItem(value: 'remove', child: Text("Remove Member")),
                                      ],
                                    )
                                  : const Icon(Icons.arrow_forward_ios, size: 16),
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
            ),
    );
  }

  Widget _buildFolderCard(String title, String iconString, String folderId) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderScreen(folderId: folderId, folderName: title))),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // Adaptive color
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
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
