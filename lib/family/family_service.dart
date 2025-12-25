import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyService {
  final SupabaseClient _client = Supabase.instance.client;

  // 1. CREATE FAMILY
  Future<void> createFamily(String familyName) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final familyResponse = await _client
        .from('families')
        .insert({'name': familyName, 'created_by': user.id})
        .select()
        .single();

    final String newFamilyId = familyResponse['id'];

    await _client.from('family_members').insert({
      'user_id': user.id,
      'family_id': newFamilyId,
      'role': 'admin',
    });

    // GENERAL Folders
    await _client.from('folders').insert([
      {'name': '🏠 Property/House Deeds', 'icon': 'home', 'family_id': newFamilyId, 'owner_id': null},
      {'name': '💡 Light/Gas/Water Bills', 'icon': 'lightbulb', 'family_id': newFamilyId, 'owner_id': null},
      {'name': '🚗 Vehicle RC/Insurance', 'icon': 'directions_car', 'family_id': newFamilyId, 'owner_id': null},
      {'name': '🏥 Family Health Insurance', 'icon': 'security', 'family_id': newFamilyId, 'owner_id': null},
      {'name': '📺 Appliances Warranty', 'icon': 'receipt_long', 'family_id': newFamilyId, 'owner_id': null},
    ]);
    
    await createPersonalFolders(user.id, newFamilyId);
  }

  // 2. JOIN FAMILY
  Future<void> joinFamily(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final familyCheck = await _client.from('families').select().eq('id', familyId).maybeSingle();
    if (familyCheck == null) throw "Family ID does not exist";

    await _client.from('family_members').insert({
      'user_id': user.id,
      'family_id': familyId,
      'role': 'member',
    });

    await createPersonalFolders(user.id, familyId);
  }

  // 3. HELPER (Public so we can call it from Repair button)
  Future<void> createPersonalFolders(String userId, String familyId) async {
    final indianLifecycleFolders = [
      {'name': 'Aadhaar Card', 'icon': 'badge', 'family_id': familyId, 'owner_id': userId},
      {'name': 'PAN Card', 'icon': 'credit_card', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Voter ID / License', 'icon': 'how_to_reg', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Passport', 'icon': 'flight', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Birth Certificate', 'icon': 'child_care', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Caste / Domicile Cert', 'icon': 'category', 'family_id': familyId, 'owner_id': userId},
      {'name': '10th/12th Marksheets', 'icon': 'school', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Degree / LC', 'icon': 'workspace_premium', 'family_id': familyId, 'owner_id': userId},
      {'name': 'School/Hostel Fees', 'icon': 'receipt', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Bank Passbooks', 'icon': 'account_balance', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Medical Reports', 'icon': 'medical_services', 'family_id': familyId, 'owner_id': userId},
      {'name': 'Other Docs', 'icon': 'folder_shared', 'family_id': familyId, 'owner_id': userId},
    ];

    await _client.from('folders').insert(indianLifecycleFolders);
  }
}