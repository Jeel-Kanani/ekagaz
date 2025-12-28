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
