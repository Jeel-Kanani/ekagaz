import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Map<String, dynamic>> _trashFiles = [];
  final Set<String> _selectedIds = {}; 
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchTrash();
  }

  Future<void> _fetchTrash() async {
    setState(() => _isLoading = true);
    
    // ✅ CORRECT ORDER: Filter (.eq) -> Sort (.order)
    final data = await Supabase.instance.client
        .from('documents')
        .select()
        .eq('is_deleted', true) 
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _trashFiles = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _trashFiles.length) {
        _selectedIds.clear(); 
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(_trashFiles.map((f) => f['id'] as String));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedIds.isEmpty) return;
    
    // ✅ SAFE FIX: Use .filter() instead of .in_()
    await Supabase.instance.client
        .from('documents')
        .update({'is_deleted': false})
        .filter('id', 'in', _selectedIds.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${_selectedIds.length} files restored")));
      _clearSelection();
      _fetchTrash();
    }
  }

  Future<void> _deleteSelectedPermanently() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Forever?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final filesToDelete = _trashFiles.where((f) => _selectedIds.contains(f['id'])).toList();
    final paths = filesToDelete.map((f) => f['file_path'] as String).toList();

    try {
      if (paths.isNotEmpty) {
        await Supabase.instance.client.storage.from('documents').remove(paths);
      }
      
      // ✅ SAFE FIX: Use .filter() instead of .in_()
      await Supabase.instance.client
          .from('documents')
          .delete()
          .filter('id', 'in', _selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permanently deleted")));
        _clearSelection();
        _fetchTrash();
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          _clearSelection();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isSelectionMode ? "${_selectedIds.length} Selected" : "Trash Bin"),
          backgroundColor: _isSelectionMode ? Colors.grey[800] : Colors.red[900],
          foregroundColor: Colors.white,
          leading: _isSelectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection) : null,
          actions: [
            if (_isSelectionMode) ...[
              IconButton(icon: const Icon(Icons.restore), onPressed: _restoreSelected),
              IconButton(icon: const Icon(Icons.delete_forever), onPressed: _deleteSelectedPermanently),
              IconButton(icon: const Icon(Icons.select_all), onPressed: _selectAll),
            ]
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _trashFiles.isEmpty 
              ? const Center(child: Text("Trash is empty"))
              : ListView.builder(
                  itemCount: _trashFiles.length,
                  itemBuilder: (ctx, i) {
                    final file = _trashFiles[i];
                    final isSelected = _selectedIds.contains(file['id']);
                    return ListTile(
                      tileColor: isSelected ? Colors.blue[50] : null,
                      leading: _isSelectionMode 
                        ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(file['id']))
                        : const Icon(Icons.delete_outline),
                      title: Text(file['name'], style: const TextStyle(decoration: TextDecoration.lineThrough)),
                      onLongPress: () => _toggleSelection(file['id']),
                      onTap: () => _isSelectionMode ? _toggleSelection(file['id']) : null,
                    );
                  },
                ),
      ),
    );
  }
}