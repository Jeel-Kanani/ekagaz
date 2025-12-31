import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

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
