import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileProvider extends ChangeNotifier {
  String? id;
  String? name;
  String? avatarUrl;
  String? phone;
  String? email;
  bool phoneVerified = false;
  bool isLoading = false;

  final _client = Supabase.instance.client;

  Future<void> loadProfile() async {
    isLoading = true;
    notifyListeners();
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        // Not authenticated
        email = null;
        id = null;
        name = null;
        avatarUrl = null;
        phone = null;
        phoneVerified = false;
        return;
      }

      email = user.email;
      final data = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data != null) {
        id = data['id'];
        name = data['full_name'] ?? user.userMetadata?['full_name'] ?? '';
        avatarUrl = data['avatar_url'] as String?;
        phone = data['phone'] ?? user.phone;
        // Prefer explicit column in profiles if present
        try {
          phoneVerified = (data['phone_verified'] == true) || (user.phone != null);
        } catch (_) {
          phoneVerified = user.phone != null;
        }
      } else {
        id = user.id;
        name = user.userMetadata?['full_name'] ?? '';
        avatarUrl = user.userMetadata?['avatar_url'] as String?;
        phone = user.phone;
        phoneVerified = user.phone != null;
      }
    } catch (e) {
      // ignore errors
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Convenience update local cache
  void setProfile({String? name, String? avatarUrl, String? phone}) {
    if (name != null) this.name = name;
    if (avatarUrl != null) this.avatarUrl = avatarUrl;
    if (phone != null) this.phone = phone;
    notifyListeners();
  }
}
