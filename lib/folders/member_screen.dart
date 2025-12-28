import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'folder_screen.dart';

class MemberScreen extends StatefulWidget {
  final String userId;
  final String familyId;
  final bool isMe;

  const MemberScreen(
      {super.key,
      required this.userId,
      required this.familyId,
      required this.isMe});

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  List<Map<String, dynamic>> _personalFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPersonalFolders();
  }

  Future<void> _fetchPersonalFolders() async {
    setState(() => _isLoading = true);

    // 1. CLEAR the list so old data doesn't stay behind
    _personalFolders.clear();

    try {
      // 2. Fetch from Supabase
      final data = await Supabase.instance.client
          .from('folders')
          .select()
          .eq('family_id', widget.familyId) // Only folders for this family
          .eq('owner_id', widget.userId) // Only folders owned by this user
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _personalFolders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'badge':
        return Icons.badge;
      case 'school':
        return Icons.school;
      case 'receipt':
        return Icons.receipt;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'medical_services':
        return Icons.medical_services;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.folder_shared;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.isMe ? "My Profile" : "Member Profile")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10),
                itemCount: _personalFolders.length,
                itemBuilder: (ctx, i) {
                  final f = _personalFolders[i];
                  return InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FolderScreen(
                                folderId: f['id'], folderName: f['name']))),
                    child: Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getIcon(f['icon'] ?? 'folder'),
                              size: 40, color: Colors.blue),
                          const SizedBox(height: 10),
                          Text(f['name'], textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
