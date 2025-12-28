import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/file_viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  // 🔍 Filter States
  String _selectedFileType = 'All'; // Options: 'All', 'pdf', 'image'
  bool _isNewestFirst = true;

  @override
  void initState() {
    super.initState();
    _runSearch("");
  }

  void _runSearch(String query) async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // ✅ STEP 1: Create the base Filter Builder
    // We explicitly use 'PostgrestFilterBuilder' so Dart knows we can filter it.
    PostgrestFilterBuilder filterBuilder =
        Supabase.instance.client.from('documents').select();

    // ✅ STEP 2: Apply Filters (Chain them safely)
    if (query.isNotEmpty) {
      filterBuilder = filterBuilder.ilike('name', '%$query%');
    }

    if (_selectedFileType == 'pdf') {
      filterBuilder = filterBuilder.eq('file_type', 'pdf');
    } else if (_selectedFileType == 'image') {
      // "neq" means "Not Equal" -> Get everything that is NOT a pdf (so images)
      filterBuilder = filterBuilder.neq('file_type', 'pdf');
    }

    // ✅ STEP 3: Apply Sorting & Limits (This changes the type to TransformBuilder)
    // We create a NEW variable for this final step
    PostgrestTransformBuilder transformBuilder =
        filterBuilder.order('created_at', ascending: !_isNewestFirst).limit(50);

    try {
      final response = await transformBuilder;

      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  // --- HELPER TO OPEN FILES ---
  Future<void> _openFile(Map<String, dynamic> file) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Opening..."), duration: Duration(milliseconds: 800)));

      final path = file['file_path'];
      final name = file['name'];
      final ext = name.toString().split('.').last.toLowerCase();

      // Get Temporary Access URL
      final url = await Supabase.instance.client.storage
          .from('documents')
          .createSignedUrl(path, 3600);

      if (context.mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FileViewerScreen(
                    fileUrl: url, fileName: name, fileType: ext)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Could not open file"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search bills, IDs, etc...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white),
          ),
          onChanged: (val) => _runSearch(val),
        ),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
                _isNewestFirst ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: _isNewestFirst ? "Newest First" : "Oldest First",
            onPressed: () {
              setState(() {
                _isNewestFirst = !_isNewestFirst;
                _runSearch(_searchController.text);
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- FILTER BAR ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text("Filter: ",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 10),
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('PDF', value: 'pdf'),
                const SizedBox(width: 8),
                _buildFilterChip('Images', value: 'image'),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- SEARCH RESULTS ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.manage_search,
                                size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text("No documents found",
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 60),
                        itemBuilder: (ctx, i) {
                          final file = _results[i];
                          final isPdf = file['name']
                              .toString()
                              .toLowerCase()
                              .endsWith('pdf');

                          return ListTile(
                            tileColor: Colors.white,
                            leading: CircleAvatar(
                              backgroundColor:
                                  isPdf ? Colors.red[50] : Colors.blue[50],
                              child: Icon(
                                isPdf ? Icons.picture_as_pdf : Icons.image,
                                color: isPdf ? Colors.red : Colors.blue,
                                size: 20,
                              ),
                            ),
                            title: Text(file['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              "Uploaded: ${file['created_at'].toString().split('T')[0]}",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.grey),
                            onTap: () => _openFile(file),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {String? value}) {
    final targetValue = value ?? 'All';
    final isSelected = _selectedFileType == targetValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFileType = targetValue;
          _runSearch(_searchController.text);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
