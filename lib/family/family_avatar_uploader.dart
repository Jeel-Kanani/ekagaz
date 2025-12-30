import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'family_service.dart';

class FamilyAvatarUploader extends StatefulWidget {
  final String familyId;
  final String? currentUrl;
  const FamilyAvatarUploader({super.key, required this.familyId, this.currentUrl});

  @override
  State<FamilyAvatarUploader> createState() => _FamilyAvatarUploaderState();
}

class _FamilyAvatarUploaderState extends State<FamilyAvatarUploader> {
  double _progress = 0; // 0..100
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    if (_busy) return;
    setState(() => _busy = true);

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image == null) {
      setState(() => _busy = false);
      return;
    }

    final bytes = await image.readAsBytes();
    final ext = p.extension(image.path).toLowerCase();
    // Best-effort progress: set 25 during prepare, 50 during upload, 100 on finish
    setState(() => _progress = 5);

    final success = await FamilyService().updateFamilyAvatar(
      familyId: widget.familyId,
      oldImageUrl: widget.currentUrl,
      fileBytes: bytes,
      fileExt: ext,
      onProgress: (percent) => mounted ? setState(() => _progress = percent) : null,
    );

    if (success) {
      // give a quick success view then reset
      setState(() => _progress = 100);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _progress = 0);
    } else {
      if (mounted) setState(() => _progress = 0);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red));
    }

    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteOnly() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete family photo?'),
      content: const Text('This will remove the family photo from storage and the families table.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))],
    ));

    if (confirm != true) return;

    setState(() => _busy = true);
    final removed = await FamilyService().deleteFamilyAvatar(familyId: widget.familyId, oldImageUrl: widget.currentUrl);
    if (removed) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family photo removed'), backgroundColor: Colors.green));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = 92.0;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xff06b6d4), Color(0xff7c3aed)]),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
              ),
              padding: const EdgeInsets.all(3),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.grey[100],
                backgroundImage: widget.currentUrl != null ? NetworkImage(widget.currentUrl!) : null,
                child: widget.currentUrl == null ? Text(widget.familyId.isNotEmpty ? widget.familyId[0].toUpperCase() : '', style: const TextStyle(fontSize: 28, color: Colors.white)) : null,
              ),
            ),

            if (_progress > 0 && _progress < 100)
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: _progress / 100,
                  strokeWidth: 4,
                  color: Colors.white,
                ),
              ),

            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.camera_alt, size: 18, color: Colors.indigo), onPressed: _pickAndUpload),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: _deleteOnly),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_progress > 0) Text('Uploading... ${_progress.toStringAsFixed(0)}%'),
      ],
    );
  }
}
