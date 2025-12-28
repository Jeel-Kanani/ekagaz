import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'verify_phone_screen.dart';

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
  String? _initialPhone; // store initial phone to detect changes

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
          _initialPhone = (data['phone'] as String?) ?? user.phone; // fallback to auth phone
        });
      } else {
        // If no profile row, still set initial phone from auth
        setState(() {
          _initialPhone = user.phone;
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
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    try {
      // 1) Update Auth metadata (name) and phone via updateUser
      try {
        await client.auth.updateUser(
          UserAttributes(
            data: {'full_name': _nameController.text},
            phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
          ),
        );
      } catch (authErr) {
        // show a helpful message but continue to upsert profile row
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auth update: $authErr'), backgroundColor: Colors.orange));
      }

      // 2) Upsert profiles table with canonical data for searching etc.
      await client.from('profiles').upsert({
        'id': user!.id,
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3) Notify about phone verification if phone changed
      if (_phoneController.text.isNotEmpty && _phoneController.text != (_initialPhone ?? '')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated. Phone change requires OTP verification; check your SMS.'), backgroundColor: Colors.orange));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
      // refresh initialPhone to current phone
      _initialPhone = _phoneController.text;
    }
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
            ),
            if (_phoneController.text.isNotEmpty && _phoneController.text != (_initialPhone ?? ''))
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () async {
                      // Open OTP screen
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyPhoneScreen(phone: _phoneController.text)));
                      if (res == true) {
                        // refresh profile/metadata
                        await _loadProfile();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified and updated'), backgroundColor: Colors.green));
                      }
                    },
                    child: const Text('Verify Phone'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}