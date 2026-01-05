import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';
import 'dart:convert';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  final LocalDBService _db = LocalDBService();
  bool _isSyncing = false;

  Future<void> init() async {
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncPendingChanges();
      }
    });
  }

  Future<void> _syncPendingChanges() async {
    if (_isSyncing) return; // Prevent concurrent syncs
    _isSyncing = true;

    try {
      final pendingActions = await _db.getPendingSyncActions();
      
      for (var action in pendingActions) {
        try {
          final actionType = action['action_type'] as String;
          final entityType = action['entity_type'] as String;
          final entityId = action['entity_id'] as String;
          final data = jsonDecode(action['data'] as String) as Map<String, dynamic>;
          final queueId = action['id'] as int;

          if (entityType == 'document') {
            await _syncDocument(actionType, entityId, data);
          } else if (entityType == 'folder') {
            await _syncFolder(actionType, entityId, data);
          }

          await _db.markSyncActionComplete(queueId);
        } catch (e) {
          await _db.markSyncActionFailed(action['id'] as int, e.toString());
        }
      }

      // Clean up old completed actions
      await _db.clearCompletedSyncActions();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncDocument(String actionType, String entityId, Map<String, dynamic> data) async {
    final client = Supabase.instance.client;

    switch (actionType) {
      case 'create':
        // Document creation should already be handled during upload
        break;
      case 'update':
        await client.from('documents').update(data).eq('id', entityId);
        break;
      case 'delete':
        await client.from('documents').update({'is_deleted': true}).eq('id', entityId);
        break;
    }
  }

  Future<void> _syncFolder(String actionType, String entityId, Map<String, dynamic> data) async {
    final client = Supabase.instance.client;

    switch (actionType) {
      case 'create':
        await client.from('folders').insert(data);
        break;
      case 'update':
        await client.from('folders').update(data).eq('id', entityId);
        break;
      case 'delete':
        await client.from('folders').delete().eq('id', entityId);
        break;
    }
  }

  // Public method to trigger sync manually
  Future<void> syncNow() async {
    await _syncPendingChanges();
  }

  // Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    final pending = await _db.getPendingSyncActions();
    return {
      'pendingCount': pending.length,
      'isSyncing': _isSyncing,
    };
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
