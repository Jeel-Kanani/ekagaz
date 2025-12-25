import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // NEW IMPORT

class FolderScreen extends StatefulWidget {
  final String folderId;
  final String folderName;

  const FolderScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _isUploading = false;
  List<Map<String, dynamic>> _files = [];

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    try {
      final data = await Supabase.instance.client
          .from('documents')
          .select()
          .eq('folder_id', widget.folderId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _files = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
    }
  }

  // --- NEW: FUNCTION TO OPEN FILE ---
  Future<void> _openFile(String filePath) async {
    try {
      // 1. Get a temporary secure link (valid for 60 seconds)
      final String publicUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 60);

      // 2. Open it in the browser / PDF viewer
      final Uri url = Uri.parse(publicUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $publicUrl';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.first.bytes == null) return;

    setState(() => _isUploading = true);
    final fileBytes = result.files.first.bytes;
    final fileName = result.files.first.name;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      // Sanitize filename to prevent errors with spaces/special chars
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final String filePath = '${user!.id}/${DateTime.now().millisecondsSinceEpoch}_$cleanName';

      await Supabase.instance.client.storage
          .from('documents')
          .uploadBinary(filePath, fileBytes!);

      final folderData = await Supabase.instance.client
          .from('folders')
          .select('family_id')
          .eq('id', widget.folderId)
          .single();
      
      await Supabase.instance.client.from('documents').insert({
        'name': fileName,
        'folder_id': widget.folderId,
        'family_id': folderData['family_id'],
        'file_path': filePath,
        'file_type': result.files.first.extension ?? 'file',
        'uploaded_by': user.id,
      });

      await _fetchFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload Successful!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No files in ${widget.folderName} yet", style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return ListTile(
                        leading: const Icon(Icons.description, color: Colors.blue),
                        title: Text(file['name']),
                        subtitle: Text(file['created_at'].toString().split('T')[0]),
                        trailing: const Icon(Icons.visibility), // Eye icon
                        onTap: () => _openFile(file['file_path']), // <--- CLICK TO OPEN
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                ),
                icon: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file),
                label: Text(_isUploading ? "Uploading..." : "Upload Document"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}