import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'verify_phone_screen.dart';
import '../auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'profile_provider.dart';
import 'package:http/http.dart' as http;
import '../core/constants/server_config.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _avatarUrl; 
  String? _initialFullPhone; // store initial full phone (+<cc><number>) to detect changes
  String _selectedCountryCode = '+91'; // default

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _nameController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      // Prefer profile phone column, fallback to user's auth phone
      final fullPhone = (data != null ? (data['phone'] as String?) : null) ?? user.phone;

      // Parse out country code and local 10-digit part if possible
      if (fullPhone != null && fullPhone.isNotEmpty) {
        _initialFullPhone = fullPhone;
        // very small parse: +<cc><local>
        final m = RegExp(r'^\+(\d{1,3})(\d+)').firstMatch(fullPhone);
        if (m != null) {
          final cc = '+${m.group(1)}';
          final rest = m.group(2) ?? '';
          _selectedCountryCode = cc;
          final local = rest.length <= 10 ? rest : rest.substring(rest.length - 10);
          _phoneController.text = local;
        } else {
          // fallback: try to keep last 10 digits
          final digits = RegExp(r'\d+').allMatches(fullPhone).map((e) => e.group(0)).join();
          final local = digits.length <= 10 ? digits : digits.substring(digits.length - 10);
          _phoneController.text = local;
        }
      } else {
        _initialFullPhone = null;
      }

      if (data != null) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _avatarUrl = data['avatar_url'] as String?;
        });
      }
    }
  }

  bool _isInputValid() {
    final nameValid = _nameController.text.trim().isNotEmpty;
    final phone = _phoneController.text.trim();
    // If phone is provided then it must be exactly 10 digits (local part)
    final simplePhoneValid = phone.isEmpty || RegExp(r'^\d{10}$').hasMatch(phone);
    return nameValid && simplePhoneValid;
  }

  void _onFormChanged() => setState((){});

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _phoneController.removeListener(_onFormChanged);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (imageFile == null) return;

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated'), backgroundColor: Colors.red));
        return;
      }

      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _avatarUrl = imageUrl;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    try {
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      // Build full phone +<cc><local>
      final local = _phoneController.text.trim();
      final fullPhone = local.isNotEmpty ? '$_selectedCountryCode$local' : '';

      // Update the database table (store full phone)
      await client.from('profiles').upsert({
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'phone': fullPhone,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Check if full phone changed to trigger OTP
      if (fullPhone.isNotEmpty && fullPhone != (_initialFullPhone ?? '')) {
        // Trigger phone update which will send OTP to the new number
        await client.auth.updateUser(
          UserAttributes(phone: fullPhone),
        );
        if (mounted) {
          debugPrint('[EditProfile] OTP requested for: $fullPhone');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent! Opening verification flow...'), backgroundColor: Colors.orange)
          );

          // Automatically navigate to verification screen
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyPhoneScreen(phone: fullPhone)));
          if (res == true) {
            // re-load profile to reflect verified phone
            await _loadProfile();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified'), backgroundColor: Colors.green));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
      // update the initial full phone to the currently stored value
      final local = _phoneController.text.trim();
      _initialFullPhone = local.isNotEmpty ? '$_selectedCountryCode$local' : _initialFullPhone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      // ✅ FIX: Added SingleChildScrollView to prevent overflow errors
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: _uploadAvatar,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
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

              // Read-only email
              TextField(
                controller: TextEditingController(text: Supabase.instance.client.auth.currentUser?.email),
                enabled: false,
                decoration: const InputDecoration(labelText: "Email Address (Permanent)", border: OutlineInputBorder(), filled: true),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  // Country code picker
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CountryCodePicker(
                      onChanged: (country) => setState(() => _selectedCountryCode = country.dialCode ?? '+91'),
                      initialSelection: 'IN',
                      favorite: const ['+91', 'US'],
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      showFlag: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(), hintText: '9876543210'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Phone verification indicator
                  Consumer<ProfileProvider>(
                    builder: (context, profile, _) {
                      final verified = profile.phoneVerified;
                      return Chip(
                        label: Text(verified ? 'Verified' : 'Unverified'),
                        backgroundColor: verified ? Colors.green[100] : Colors.orange[100],
                        avatar: Icon(verified ? Icons.check_circle : Icons.error, color: verified ? Colors.green : Colors.orange),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (!_isLoading && _isInputValid()) ? _updateProfile : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Changes"),
                ),
              ),
              
              if (_phoneController.text.isNotEmpty && '$_selectedCountryCode${_phoneController.text.trim()}' != (_initialFullPhone ?? ''))
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () async {
                        // Open OTP screen for the full number
                        final local = _phoneController.text.trim();
                        if (local.isEmpty || !RegExp(r'^\d{10}$').hasMatch(local)) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit phone number'), backgroundColor: Colors.orange));
                          return;
                        }

                        final fullPhone = '$_selectedCountryCode$local';
                        final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyPhoneScreen(phone: fullPhone)));
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
                
              const SizedBox(height: 12),
              // Delete account
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Account?'),
                        content: const Text('This will permanently delete your account and data. This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      setState(() => _isLoading = true);
                      try {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user == null) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No authenticated user found'), backgroundColor: Colors.red));
                          setState(() => _isLoading = false);
                          return;
                        }

                        // First, try calling a secure server-side delete if configured
                        try {
                          if (USER_DELETE_ENDPOINT != 'https://example.com/delete-user') {
                            final token = Supabase.instance.client.auth.currentSession?.accessToken;
                            if (token == null) throw 'No access token';

                            final uri = Uri.parse(USER_DELETE_ENDPOINT);
                            final resp = await http.post(uri, headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json'
                            });

                            if (resp.statusCode == 200) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted'), backgroundColor: Colors.green));
                              await Supabase.instance.client.auth.signOut();
                              if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                              return;
                            }
                          }
                        } catch (e) {
                          // Continue to client-side attempts as a fallback
                        }

                        // Fallback: try client SDK delete attempts
                        final d = Supabase.instance.client.auth as dynamic;
                        var deleted = false;
                        try {
                          await d.deleteUser();
                          deleted = true;
                        } catch (_) {}

                        try {
                          if (!deleted && d.api != null && d.api.deleteUser != null) {
                            await d.api.deleteUser(user.id);
                            deleted = true;
                          }
                        } catch (_) {}

                        if (deleted) {
                          await Supabase.instance.client.auth.signOut();
                          if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion is not supported from this client. Deploy the server delete function.'), backgroundColor: Colors.orange));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                  child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 30), // Extra bottom padding
            ],
          ),
        ),
      ),
    );
  }
}