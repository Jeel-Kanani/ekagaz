import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Temporary debug screen to inspect `documents` table rows.
/// Open from Folder screen using the debug icon. Shows id, name, is_deleted, folder_id, file_path, uploaded_by, created_at.
class DocumentsDebugScreen extends StatefulWidget {
  const DocumentsDebugScreen({super.key});

  @override
  State<DocumentsDebugScreen> createState() => _DocumentsDebugScreenState();
}

class _DocumentsDebugScreenState extends State<DocumentsDebugScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rows = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchRows();
  }

  Future<void> _fetchRows() async {
    setState(() => _isLoading = true);
    try {
      var builder = Supabase.instance.client.from('documents').select();

      if (_query.trim().isNotEmpty) {
        final q = _query.trim();
        // try to search by name or id (partial)
        builder = builder.or('name.ilike.%$q%,id.ilike.%$q%');
      }

      final data = await builder.order('created_at', ascending: false);

      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      // Show a SnackBar so user sees the error
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetch error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    setState(() => _query = val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents Debug'),
        actions: [
          IconButton(onPressed: _fetchRows, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or id',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _fetchRows,
                  child: const Text('Search'),
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(child: Text('No documents found'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        separatorBuilder: (_, __) => const Divider(),
                        itemCount: _rows.length,
                        itemBuilder: (ctx, i) {
                          final r = _rows[i];
                          return ListTile(
                            dense: true,
                            title: Text(r['name'] ?? '(no name)'),
                            subtitle: Text('id: ${r['id']}\nfolder: ${r['folder_id']}\nis_deleted: ${r['is_deleted']}\npath: ${r['file_path']}\nuploaded_by: ${r['uploaded_by']}'),
                            isThreeLine: true,
                            trailing: Text(r['created_at']?.toString() ?? ''),
                            onTap: () async {
                              // Quick copy id to clipboard
                              final id = r['id']?.toString() ?? '';
                              if (id.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Id copied: ${id.substring(0, 8)}...')));
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
