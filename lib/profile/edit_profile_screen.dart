import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _avatarUrl; // ✅ Explicitly typed as String?

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      if (data != null) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _avatarUrl = data['avatar_url'] as String?; // ✅ Safe cast
        });
      }
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    
    if (imageFile == null) return;

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${user!.id}/avatar.$fileExt';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'avatar_url': imageUrl
      });

      setState(() {
        _avatarUrl = imageUrl;
        _isLoading = false;
      });
      
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user!.id,
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _uploadAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                // ✅ FIX: Correctly check for null and wrap in NetworkImage
                backgroundImage: _avatarUrl != null 
                    ? NetworkImage(_avatarUrl!) 
                    : null,
                child: _avatarUrl == null 
                  ? (_isLoading ? const CircularProgressIndicator() : const Icon(Icons.camera_alt, size: 40, color: Colors.grey))
                  : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap to change photo", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Changes"),
              ),
            )
          ],
        ),
      ),
    );
  }
}