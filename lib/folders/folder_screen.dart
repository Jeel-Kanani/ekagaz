import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:permission_handler/permission_handler.dart'; 
import 'package:gal/gal.dart'; 
import 'package:open_filex/open_filex.dart';

// ✅ Custom Imports

// ✅ Custom Imports
import '../core/file_viewer_screen.dart';
import '../core/pdf_service.dart';
import '../core/share_service.dart';
import '../core/notification_service.dart';
import '../core/pdf_creator_service.dart'; 
import '../debug/documents_debug_screen.dart';
import 'trash_screen.dart';

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
  bool _isDownloading = false;
  bool _isLoading = true;
  
  // ✅ SEARCH STATE
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _files = [];

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
    NotificationService.init();
    NotificationService.requestPermissions();
  }

  Future<void> _fetchDocuments() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      // 1. Start Builder
      var builder = Supabase.instance.client.from('documents').select();

      // 2. ✅ APPLY FILTERS FIRST
      // IMPORTANT: You CANNOT call .eq() after .order()
      builder = builder.eq('is_deleted', false); 
      builder = builder.eq('folder_id', widget.folderId);

      // Optional: apply search filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim();
        try {
          builder = builder.or('name.ilike.%$q%,file_name.ilike.%$q%');
        } catch (_) {
          // If the builder doesn't support .or or the format, ignore search
        }
      }
      
      // 3. ✅ APPLY SORT LAST
      final data = await builder.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _files = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // print("Error loading docs: $e");
      }
    }
  }

  // --- 1. VIEW FILE ---
  Future<void> _openFile(String filePath, String fileName) async {
    try {
      final String publicUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 3600);

      final fileExt = fileName.split('.').last.toLowerCase();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileViewerScreen(
              fileUrl: publicUrl,
              fileName: fileName,
              fileType: fileExt,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: $e')));
    }
  }

  // --- 2. DOWNLOAD FILE ---
  Future<void> _downloadFile(String filePath, String fileName) async {
    setState(() => _isDownloading = true);

    try {
      final String downloadUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 60);

      final ext = fileName.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);
      String finalSavePath = "";
      
      if (isImage) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$fileName';
        await Dio().download(downloadUrl, tempPath);
        await Gal.putImage(tempPath);
        finalSavePath = tempPath; 
      } else {
        bool hasPermission = false;
        if (Platform.isAndroid) {
          // Android 13+ check
          if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted || await Permission.photos.isGranted) {
            hasPermission = true;
          } else if (await Permission.manageExternalStorage.request().isGranted || await Permission.storage.request().isGranted) {
             hasPermission = true;
          }
        } else {
          hasPermission = true;
        }

        if (!hasPermission) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission Denied"), backgroundColor: Colors.red));
           return;
        }

        if (Platform.isAndroid) {
          finalSavePath = "/storage/emulated/0/Download/$fileName";
        } else {
          final dir = await getApplicationDocumentsDirectory();
          finalSavePath = "${dir.path}/$fileName";
        }

        await Dio().download(downloadUrl, finalSavePath);
      }

      await NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Download Complete',
        body: '$fileName saved.',
        payload: finalSavePath, 
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved: $fileName"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // --- 3. QUICK SHARE ---
  Future<void> _quickShare(String filePath, String fileName) async {
    try {
      final String publicUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 60);

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      await Dio().download(publicUrl, tempPath);

      await ShareService.shareFile(tempPath, text: 'Shared via FamVault');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red));
    }
  }

  // --- 4. TOGGLE FAVORITE ---
  Future<void> _toggleFavorite(String fileId, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('documents')
          .update({'is_favorite': !currentStatus})
          .eq('id', fileId);
      await _fetchDocuments(); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Favorite failed: $e'), backgroundColor: Colors.red));
    }
  }

  // --- UPDATED RENAME FILE ---
  Future<void> _renameFile(String fileId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename File"),
        content: TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              Navigator.pop(ctx);
              if (newName.isNotEmpty && newName != currentName) {
                try {
                  // Attempt update
                  await Supabase.instance.client
                      .from('documents')
                      .update({'name': newName})
                      .eq('id', fileId);

                  // Refresh UI immediately
                  _fetchDocuments();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Renamed successfully"), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rename failed: $e"), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Rename"),
          )
        ],
      ),
    );
  }

  // --- UPDATED SOFT DELETE ---
  Future<void> _deleteFile(String fileId) async {
    try {
      await Supabase.instance.client
          .from('documents')
          .update({'is_deleted': true})
          .eq('id', fileId);

      _fetchDocuments(); // Reload the list to hide the deleted item
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved to Trash"), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error moving to trash: $e"), backgroundColor: Colors.red));
    }
  }

  // --- 7. UPLOAD LOGIC ---
  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.first.bytes == null) return;

    setState(() => _isUploading = true);
    final fileBytes = result.files.first.bytes;
    final fileName = result.files.first.name;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated'), backgroundColor: Colors.red));
        return;
      }

      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final String filePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$cleanName';

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
        'is_deleted': false, // ✅ Explicitly Active
      });

      await _fetchDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload Successful!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- 8. CONVERT IMAGE TO PDF (Single) ---
  Future<void> _convertToPdf(String filePath, String fileName) async {
    setState(() => _isDownloading = true);
    try {
      final String publicUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 60);

      final pdfService = PdfService();
      final uniqueName = "${fileName.split('.').first}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final savePath = await pdfService.convertImageToPdf(publicUrl, uniqueName);

      if (savePath != null) {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'PDF Converted',
          body: '$uniqueName ready.',
          payload: savePath,
        );
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("PDF Created!"), 
            backgroundColor: Colors.green,
            action: SnackBarAction(label: "OPEN", textColor: Colors.white, onPressed: () => OpenFilex.open(savePath)),
          ));
        }
      } 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  // --- 9. GALLERY TO PDF (Multi) ---
  Future<void> _convertImagesToPdf() async {
    final pdfService = PdfCreatorService();
    final File? pdfFile = await pdfService.createPdfFromGallery();

    if (pdfFile != null && mounted) {
      await _showSaveDialog(pdfFile);
    }
  }

  // --- SAVE DIALOG FOR PDF ---
  Future<void> _showSaveDialog(File file) async {
    String fileName = "Scan_${DateTime.now().hour}_${DateTime.now().minute}";

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
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  if (fileName.isNotEmpty) {
                    Navigator.pop(ctx);
                    _savePdf(file, fileName, widget.folderId);
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

  Future<void> _savePdf(File file, String fileName, String folderId) async {
    setState(() => _isUploading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated'), backgroundColor: Colors.red));
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$cleanName.pdf';
      
      await Supabase.instance.client.storage.from('documents').upload(storagePath, file);
      
      final folderData = await Supabase.instance.client.from('folders').select('family_id').eq('id', folderId).single();

      final inserted = await Supabase.instance.client.from('documents').insert({
        'name': '$fileName.pdf',
        'folder_id': folderId,
        'family_id': folderData['family_id'],
        'file_path': storagePath,
        'file_type': 'pdf',
        'uploaded_by': user.id,
        'is_deleted': false,
      }).select();
      
      final insertedRows = List<Map<String, dynamic>>.from(inserted);
      if (insertedRows.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Save failed (no row returned)"), backgroundColor: Colors.red));
        print('Save PDF failed for path: $storagePath');
      } else {
        final id = insertedRows.first['id'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved (id: $id)"), backgroundColor: Colors.green));
          _fetchDocuments();
          print('Saved PDF inserted id=$id for path: $storagePath');
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ✅ SEARCH BAR IN TITLE
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                _searchQuery = val; 
                _fetchDocuments(); // Trigger search
              },
              decoration: const InputDecoration(
                hintText: "Search files...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
            )
          : Text(widget.folderName),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          // 🔍 Search Toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _searchQuery = "";
                _searchController.clear();
                if (!_isSearching) _fetchDocuments(); // Reset list
              });
            },
          ),
          // 🗑️ Trash Button
          IconButton(
            icon: const Icon(Icons.auto_delete_outlined),
            tooltip: "Trash Bin",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())).then((_) => _fetchDocuments()),
          ),
          // 🐞 Debug Documents Button (temporary)
          // Opens `DocumentsDebugScreen` — use it to inspect `documents` rows (search + refresh accessible there).
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: "Debug Documents",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsDebugScreen())),
          ),
          // 📄 PDF Convert Button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Images to PDF",
            onPressed: _convertImagesToPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isDownloading)
            const LinearProgressIndicator(color: Colors.green),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text("No files found", style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          final ext = file['name'].toString().split('.').last.toLowerCase();
                          final isImage = ['jpg','png','jpeg','webp'].contains(ext);
                          final isPdf = ext == 'pdf';

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isPdf ? Colors.red[50] : Colors.blue[50],
                                child: Icon(
                                  isPdf ? Icons.picture_as_pdf : (isImage ? Icons.image : Icons.description),
                                  color: isPdf ? Colors.red : Colors.blue
                                ),
                              ),
                              title: Text(file['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(file['created_at'].toString().split('T')[0]),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'view') _openFile(file['file_path'], file['name']);
                                  if (value == 'share') _quickShare(file['file_path'], file['name']);
                                  if (value == 'rename') _renameFile(file['id'].toString(), file['name']);
                                  if (value == 'delete') _deleteFile(file['id'].toString());
                                  if (value == 'fav') _toggleFavorite(file['id'].toString(), file['is_favorite'] ?? false);
                                  if (value == 'download') _downloadFile(file['file_path'], file['name']);
                                  if (value == 'pdf' && isImage) _convertToPdf(file['file_path'], file['name']);
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, color: Colors.blue), SizedBox(width: 8), Text("View")])),
                                  const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, color: Colors.green), SizedBox(width: 8), Text("Share")])),
                                  const PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.download, color: Colors.grey), SizedBox(width: 8), Text("Download")])),
                                  if (isImage) const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red), SizedBox(width: 8), Text("Convert to PDF")])),
                                  PopupMenuItem(value: 'fav', child: Row(children: [
                                    Icon(file['is_favorite'] == true ? Icons.star : Icons.star_border, color: Colors.amber), 
                                    const SizedBox(width: 8), 
                                    Text(file['is_favorite'] == true ? "Unfavorite" : "Favorite")
                                  ])),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, color: Colors.orange), SizedBox(width: 8), Text("Rename")])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Delete (Trash)")])),
                                ],
                              ),
                              onTap: () => _openFile(file['file_path'], file['name']),
                            ),
                          );
                        },
                      )),
          ),
          
          // ✅ UPLOAD BUTTON BAR
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