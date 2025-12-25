import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:permission_handler/permission_handler.dart'; 
import 'package:gal/gal.dart'; 
import 'package:open_file/open_file.dart';
import '../core/pdf_service.dart';
import '../core/notification_service.dart'; // ✅ Import Notification Service

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
  List<Map<String, dynamic>> _files = [];

  @override
  void initState() {
    super.initState();
    _fetchFiles();
    
    // ✅ Initialize Notifications on load
    NotificationService.init();
    NotificationService.requestPermissions();
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

  // --- 1. VIEW FILE ---
  Future<void> _openFile(String filePath) async {
    try {
      final String publicUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 60);

      final Uri url = Uri.parse(publicUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch URL";
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: $e')));
    }
  }

  // --- 2. DOWNLOAD FILE ---
  Future<void> _downloadFile(String filePath, String fileName) async {
    setState(() => _isDownloading = true);

    try {
      // A. Get Download URL
      final String downloadUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 60);

      // B. Check if it is an Image
      final ext = fileName.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);

      // C. Prepare Save Logic
      String finalSavePath = "";
      
      if (isImage) {
        // --- OPTION 1: IMAGE (Save to Gallery) ---
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$fileName';
        await Dio().download(downloadUrl, tempPath);
        await Gal.putImage(tempPath);
        finalSavePath = tempPath; // We use temp path just for the notification payload
      } else {
        // --- OPTION 2: DOCUMENTS ---
        bool hasPermission = false;
        if (Platform.isAndroid) {
          if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
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

      // ✅ D. SHOW NOTIFICATION
      await NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title: 'Download Complete',
        body: '$fileName downloaded successfully.',
        payload: finalSavePath, // Clicking notification opens file
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved: $fileName"), 
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  // --- 3. UPLOAD LOGIC ---
  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.first.bytes == null) return;

    setState(() => _isUploading = true);
    final fileBytes = result.files.first.bytes;
    final fileName = result.files.first.name;

    try {
      final user = Supabase.instance.client.auth.currentUser;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- 4. CONVERT TO PDF ---
  Future<void> _convertToPdf(String filePath, String fileName) async {
    setState(() => _isDownloading = true);
    
    try {
      // A. Get Signed URL
      final String publicUrl = await Supabase.instance.client
          .storage
          .from('documents')
          .createSignedUrl(filePath, 60);

      // B. Run Conversion
      final pdfService = PdfService();
      final uniqueName = "${fileName.split('.').first}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      
      final savePath = await pdfService.convertImageToPdf(publicUrl, uniqueName);

      if (savePath != null) {
        
        // ✅ C. SHOW NOTIFICATION
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'PDF Converted',
          body: '$uniqueName is ready.',
          payload: savePath,
        );

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("PDF Created Successfully!"), 
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: "OPEN NOW", 
                textColor: Colors.white, 
                onPressed: () => OpenFile.open(savePath)
              ),
            ),
          );
        }
      } else {
        throw "Conversion returned null";
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Conversion Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
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
          if (_isDownloading)
            const LinearProgressIndicator(color: Colors.green),

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
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final isImage = ['jpg','png','jpeg','webp'].contains(file['name'].split('.').last.toLowerCase());

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
                            backgroundColor: Colors.blue[50],
                            child: const Icon(Icons.description, color: Colors.blue),
                          ),
                          title: Text(file['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(file['created_at'].toString().split('T')[0]),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, color: Colors.grey),
                                onPressed: () => _openFile(file['file_path']),
                              ),
                              if (isImage)
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                                  onPressed: () => _convertToPdf(file['file_path'], file['name']),
                                ),
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.green),
                                onPressed: () => _downloadFile(file['file_path'], file['name']),
                              ),
                            ],
                          ),
                        ),
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