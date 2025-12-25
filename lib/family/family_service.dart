import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyService {
  final _supabase = Supabase.instance.client;

  Future<String?> getMyFamilyId() async {
    final userId = _supabase.auth.currentUser!.id;

    final res = await _supabase
        .from('family_members')
        .select('family_id')
        .eq('user_id', userId)
        .maybeSingle();

    return res?['family_id'];
  }

  Future<String> createFamily(String name) async {
    final userId = _supabase.auth.currentUser!.id;

    final family = await _supabase
        .from('families')
        .insert({
          'name': name,
          'created_by': userId,
        })
        .select()
        .single();

    await _supabase.from('family_members').insert({
      'family_id': family['id'],
      'user_id': userId,
      'role': 'admin',
    });

    return family['id'];
  }

  Future<void> joinFamily(String familyId) async {
    final userId = _supabase.auth.currentUser!.id;

    await _supabase.from('family_members').insert({
      'family_id': familyId,
      'user_id': userId,
      'role': 'member',
    });
  }
}
