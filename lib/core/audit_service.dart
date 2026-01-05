import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  Future<void> logAction({
    required String actionType, // 'create', 'update', 'delete', 'view', 'download'
    required String entityType, // 'document', 'folder', 'family'
    required String entityId,
    String? entityName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('audit_logs').insert({
        'user_id': user.id,
        'action_type': actionType,
        'entity_type': entityType,
        'entity_id': entityId,
        'entity_name': entityName,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail audit logging to not interrupt user flow
      debugPrint('Audit log failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? entityType,
    String? entityId,
    int limit = 100,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      var query = Supabase.instance.client
          .from('audit_logs')
          .select('*, profiles(full_name, avatar_url)');

      if (entityType != null) {
        query = query.eq('entity_type', entityType);
      }

      if (entityId != null) {
        query = query.eq('entity_id', entityId);
      }

      final transformQuery = query.order('created_at', ascending: false).limit(limit);
      final data = await transformQuery;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Failed to fetch audit logs: $e');
      return [];
    }
  }
}

