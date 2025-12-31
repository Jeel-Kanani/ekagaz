import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:typed_data';

class FamilyService {
  final SupabaseClient _client = Supabase.instance.client;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 0, 1 for clarity
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // 1. CREATE FAMILY
  Future<void> createFamily(String familyName, {String? description, String? dpUrl}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    String inviteCode = _generateInviteCode();

    // Loop to ensure uniqueness (unlikely collision but good practice)
    bool unique = false;
    while (!unique) {
      final existing = await _client
          .from('families')
          .select('id')
          .eq('invite_code', inviteCode)
          .maybeSingle();
      if (existing == null) {
        unique = true;
      } else {
        inviteCode = _generateInviteCode();
      }
    }

    final familyResponse = await _client
        .from('families')
        .insert({
          'name': familyName,
          'description': description,
          'dp_url': dpUrl,
          'created_by': user.id,
          'invite_code': inviteCode,
        })
        .select()
        .single();

    final String newFamilyId = familyResponse['id'];

    await _client.from('family_members').insert({
      'user_id': user.id,
      'family_id': newFamilyId,
      'role': 'admin',
    });

    // Create both sets of folders immediately
    await createGeneralFolders(newFamilyId);
    await createPersonalFolders(user.id, newFamilyId);
  }

  Future<void> changeMemberRole(String familyId, String userId, String role) async {
    await _client
        .from('family_members')
        .update({'role': role})
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  Future<void> removeMember(String familyId, String userId) async {
    await _client
        .from('family_members')
        .delete()
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  Future<String> updateFamilyDp(String familyId, Uint8List bytes, String ext) async {
    final user = _client.auth.currentUser;
    if (user == null) throw "Not authenticated";

    final path = 'family_dp/${familyId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('family-avatars').uploadBinary(path, bytes);
    final publicUrl = _client.storage.from('family-avatars').getPublicUrl(path);

    // Use RPC function to update family DP (bypasses RLS)
    final result = await _client.rpc('update_family_dp', params: {
      'p_family_id': familyId,
      'p_dp_url': publicUrl,
      'p_user_id': user.id,
    });

    if (result == null) {
      throw "Failed to update family DP";
    }

    return publicUrl;
  }

  Future<void> deleteFamilyDp(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw "Not authenticated";
    await _client.from('families').update({'dp_url': null}).eq('id', familyId);
  }

  Future<void> migrateFamilyDpsToAvatarsBucket() async {
    final user = _client.auth.currentUser;
    if (user == null) throw "Not authenticated";

    // Fetch families with dp_url containing 'documents/family_dp/'
    final families = await _client
        .from('families')
        .select('id, dp_url')
        .not('dp_url', 'is', null)
        .like('dp_url', '%documents/family_dp/%');

    for (final family in families) {
      final familyId = family['id'] as String;
      final oldUrl = family['dp_url'] as String;

      // Extract the file path from the URL
      final uri = Uri.parse(oldUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.sublist(pathSegments.indexOf('documents') + 1).join('/');

      try {
        // Download from old bucket
        final bytes = await _client.storage.from('documents').download(filePath);

        // Upload to new bucket
        final fileName = 'family_${familyId}_${DateTime.now().millisecondsSinceEpoch}.jpg'; // Assume jpg for simplicity
        await _client.storage.from('family-avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

        // Get new public URL
        final newUrl = _client.storage.from('family-avatars').getPublicUrl(fileName);

        // Update database
        await _client.from('families').update({'dp_url': newUrl}).eq('id', familyId);

        // Optionally delete from old bucket
        await _client.storage.from('documents').remove([filePath]);
      } catch (e) {
        print('Failed to migrate DP for family $familyId: $e');
        // Continue with next family
      }
    }
  }

  // 2. JOIN FAMILY
  Future<void> joinFamily(String input) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Use the secure RPC to find the family ID (works for both Code and UUID)
    // This bypasses RLS so we can find families we aren't members of yet.
    final String? familyId = await _client.rpc<String?>('find_family_id', params: {
      'identifier': input.toUpperCase().trim(),
    });

    if (familyId == null) {
      throw "Invalid invite code or family ID";
    }

    // Check if already member
    final membership = await _client
        .from('family_members')
        .select()
        .eq('family_id', familyId)
        .eq('user_id', user.id)
        .maybeSingle();
        
    if (membership != null) {
      // Already a member, just ensure folders exist
      await createPersonalFolders(user.id, familyId);
      return;
    }

    await _client.from('family_members').insert({
      'user_id': user.id,
      'family_id': familyId,
      'role': 'member',
    });

    await createPersonalFolders(user.id, familyId);
  }

  // 3. REPAIR: Create General Folders (The Blue Ones)
  Future<void> createGeneralFolders(String familyId) async {
    // We check if they exist first to avoid duplicates
    final existing = await _client
        .from('folders')
        .select()
        .eq('family_id', familyId)
        .filter(
            'owner_id', 'is', null); // <--- Make sure this line is exactly this

    if (existing.isNotEmpty) return;

    await _client.from('folders').insert([
      {
        'name': 'Property/House Deeds',
        'icon': 'home',
        'family_id': familyId,
        'owner_id': null
      },
      {
        'name': 'Light/Gas/Water Bills',
        'icon': 'lightbulb',
        'family_id': familyId,
        'owner_id': null
      },
      {
        'name': 'Vehicle RC/Insurance',
        'icon': 'directions_car',
        'family_id': familyId,
        'owner_id': null
      },
      {
        'name': 'Family Health Insurance',
        'icon': 'security',
        'family_id': familyId,
        'owner_id': null
      },
      {
        'name': 'Appliances Warranty',
        'icon': 'receipt_long',
        'family_id': familyId,
        'owner_id': null
      },
    ]);
  }

  // 4. REPAIR: Create Personal Folders (The Yellow/Personal Ones)
  Future<void> createPersonalFolders(String userId, String familyId) async {
    // Check for existing to prevent duplicates
    final existing = await _client
        .from('folders')
        .select()
        .eq('family_id', familyId)
        .eq('owner_id', userId);
    if (existing.isNotEmpty) return;

    final indianLifecycleFolders = [
      {
        'name': 'Aadhaar Card',
        'icon': 'badge',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'PAN Card',
        'icon': 'credit_card',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Voter ID / License',
        'icon': 'how_to_reg',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Passport',
        'icon': 'flight',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Birth Certificate',
        'icon': 'child_care',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Caste / Domicile Cert',
        'icon': 'category',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': '10th/12th Marksheets',
        'icon': 'school',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Degree / LC',
        'icon': 'workspace_premium',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'School/Hostel Fees',
        'icon': 'receipt',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Bank Passbooks',
        'icon': 'account_balance',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Medical Reports',
        'icon': 'medical_services',
        'family_id': familyId,
        'owner_id': userId
      },
      {
        'name': 'Other Docs',
        'icon': 'folder_shared',
        'family_id': familyId,
        'owner_id': userId
      },
    ];

    await _client.from('folders').insert(indianLifecycleFolders);
  }
}
