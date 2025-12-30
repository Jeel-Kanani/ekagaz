import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyService {
  final SupabaseClient _client = Supabase.instance.client;

  // 1. CREATE FAMILY
  Future<String> createFamily(String familyName) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'Not authenticated';

    String? newFamilyId;
    try {
      final familyResponse = await _client
          .from('families')
          .insert({'name': familyName, 'created_by': user.id})
          .select()
          .single();

      newFamilyId = familyResponse['id'] as String?;
      if (newFamilyId == null) throw 'Failed to create family (no id returned)';

      // Add member as admin
      await _client.from('family_members').insert({
        'user_id': user.id,
        'family_id': newFamilyId,
        'role': 'admin',
      });

      // Create default folders (if applicable)
      await _client.from('folders').insert([
        {
          'name': '🏠 Property/House Deeds',
          'icon': 'home',
          'family_id': newFamilyId,
          'owner_id': null
        },
        {
          'name': '💡 Light/Gas/Water Bills',
          'icon': 'lightbulb',
          'family_id': newFamilyId,
          'owner_id': null
        },
        {
          'name': '🚗 Vehicle RC/Insurance',
          'icon': 'directions_car',
          'family_id': newFamilyId,
          'owner_id': null
        },
        {
          'name': '🏥 Family Health Insurance',
          'icon': 'security',
          'family_id': newFamilyId,
          'owner_id': null
        },
        {
          'name': '📺 Appliances Warranty',
          'icon': 'receipt_long',
          'family_id': newFamilyId,
          'owner_id': null
        },
      ]);

      await createPersonalFolders(user.id, newFamilyId);
      return newFamilyId;
    } catch (e) {
      // Attempt cleanup if partial work succeeded
      if (newFamilyId != null) {
        try {
          await _client.from('families').delete().eq('id', newFamilyId);
        } catch (_) {}
      }

      // Helpful error message for debugging RLS/policy related fails
      if (e.toString().contains('permission')) {
        throw 'Database permission error: check Row-Level Security policies for families/family_members';
      }

      rethrow;
    }
  }

  // 2. JOIN FAMILY
  Future<void> joinFamily(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'Not authenticated';

    final familyCheck = await _client
        .from('families')
        .select()
        .eq('id', familyId)
        .maybeSingle();
    if (familyCheck == null) throw "Family ID does not exist";

    await _client.from('family_members').insert({
      'user_id': user.id,
      'family_id': familyId,
      'role': 'member',
    });

    await createPersonalFolders(user.id, familyId);
  }

  /// Update the family's display picture url. Requires you to pass the family id.
  Future<void> updateFamilyDpUrl(String familyId, String dpUrl) async {
    await _client.from('families').update({
      'dp_url': dpUrl,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', familyId);
  }

  /// Upload new family avatar bytes, delete old storage object if present, and update the family row.
  /// Returns true on success.
  Future<bool> updateFamilyAvatar({
    required String familyId,
    required List<int> fileBytes,
    required String fileExt,
    String bucket = 'family-avatars',
    String? oldImageUrl,
    void Function(double percent)? onProgress,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'Not authenticated';

    try {
      // delete previous if it was stored in the bucket
      if (oldImageUrl != null && oldImageUrl.contains('$bucket/')) {
        final oldPath = oldImageUrl.split('$bucket/').last;
        try {
          await _client.storage.from(bucket).remove([oldPath]);
        } catch (_) {
          // ignore remove errors
        }
      }

      // Best-effort progress callbacks (supabase_flutter's uploadBinary has no progress callback yet)
      try {
        onProgress?.call(15);
      } catch (_) {}

      final fileName = '$familyId-${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final path = 'avatars/$fileName';

      await _client.storage.from(bucket).uploadBinary(path, Uint8List.fromList(fileBytes), fileOptions: const FileOptions(upsert: true));

      try {
        onProgress?.call(70);
      } catch (_) {}

      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

      await _client.from('families').update({'dp_url': publicUrl, 'updated_at': DateTime.now().toIso8601String()}).eq('id', familyId);

      try {
        onProgress?.call(100);
      } catch (_) {}

      // small delay for UX
      await Future.delayed(const Duration(milliseconds: 300));
      onProgress?.call(0);
      return true;
    } catch (e) {
      onProgress?.call(0);
      return false;
    }
  }

  /// Delete only the family avatar (remove from storage + clear families dp_url)
  Future<bool> deleteFamilyAvatar({required String familyId, String? oldImageUrl, String bucket = 'family-avatars'}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'Not authenticated';

    try {
      if (oldImageUrl != null && oldImageUrl.contains('$bucket/')) {
        final oldPath = oldImageUrl.split('$bucket/').last;
        try {
          await _client.storage.from(bucket).remove([oldPath]);
        } catch (_) {}
      }

      await _client.from('families').update({'dp_url': null, 'updated_at': DateTime.now().toIso8601String()}).eq('id', familyId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 3. HELPER (Public so we can call it from Repair button)
  Future<void> createPersonalFolders(String userId, String familyId) async {
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
