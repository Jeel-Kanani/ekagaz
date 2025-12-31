import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class FamilyAvatarUploader extends StatefulWidget {
  final String familyId;
  final String? currentUrl;

  const FamilyAvatarUploader({
    super.key,
    required this.familyId,
    this.currentUrl,
  });

  @override
  State<FamilyAvatarUploader> createState() => _FamilyAvatarUploaderState();
}

class _FamilyAvatarUploaderState extends State<FamilyAvatarUploader> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUpload() async {
    try {
      // 1. Pick Image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      
      if (image == null) return;

      setState(() => _isLoading = true);

      // 2. Upload to Supabase Storage
      final fileExt = image.path.split('.').last;
      final fileName = 'family_${widget.familyId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final bytes = await File(image.path).readAsBytes();

      // Ensure you have a 'family-avatars' bucket created in Supabase
      const bucketName = 'family-avatars';
      
      await Supabase.instance.client.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // 3. Get Public URL
      final publicUrl = Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      // 4. Update Family Record
      await Supabase.instance.client
          .from('families')
          .update({'dp_url': publicUrl})
          .eq('id', widget.familyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Family photo updated!")),
        );
        Navigator.pop(context, true); // Close dialog and trigger refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.currentUrl != null)
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(widget.currentUrl!),
          )
        else
          const CircleAvatar(
            radius: 40,
            child: Icon(Icons.group, size: 40),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickAndUpload,
            icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.upload),
            label: Text(_isLoading ? "Uploading..." : "Upload New Photo"),
          ),
        ),
      ],
    );
  }
}