import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  final LocalDBService _db = LocalDBService();

  Future<void> init() async {
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncPendingChanges();
      }
    });
  }

  Future<void> _syncPendingChanges() async {
    // TODO: Implement sync logic for pending changes
    // This would sync any local changes back to server when online
  }

  Future<void> syncFolders(String familyId) async {
    try {
      final data = await Supabase.instance.client
          .from('folders')
          .select()
          .eq('family_id', familyId)
          .filter('owner_id', 'is', null);

      await _db.cacheFolders(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // Handle sync error
    }
  }

  Future<void> syncDocuments(String folderId) async {
    try {
      final data = await Supabase.instance.client
          .from('documents')
          .select()
          .eq('folder_id', folderId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      await _db.cacheDocuments(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // Handle sync error
    }
  }
}
