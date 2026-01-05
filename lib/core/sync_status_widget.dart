import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncStatusProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();
  
  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _isOnline = true;

  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  SyncStatusProvider() {
    _init();
  }

  Future<void> _init() async {
    // Check connectivity status
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      if (_isOnline) {
        _syncService.syncNow();
      }
      notifyListeners();
    });

    // Load initial status
    await loadStatus();
  }

  Future<void> loadStatus() async {
    final status = await _syncService.getSyncStatus();
    _pendingCount = status['pendingCount'] as int;
    _isSyncing = status['isSyncing'] as bool;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!_isOnline) return;
    _isSyncing = true;
    notifyListeners();
    await _syncService.syncNow();
    await loadStatus();
  }
}

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncStatusProvider>(
      builder: (context, provider, child) {
        if (!provider.isOnline && provider.pendingCount > 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.cloud_off, size: 16, color: Colors.orange[900]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${provider.pendingCount} item(s) pending sync',
                    style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                  ),
                ),
              ],
            ),
          );
        }
        
        if (provider.isSyncing) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.blue[100],
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Syncing...',
                    style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.pendingCount > 0 && provider.isOnline) {
          return InkWell(
            onTap: () => provider.syncNow(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.amber[100],
              child: Row(
                children: [
                  Icon(Icons.sync, size: 16, color: Colors.amber[900]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${provider.pendingCount} item(s) pending - Tap to sync',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

