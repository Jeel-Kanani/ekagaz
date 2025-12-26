import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String fileType; // 'pdf', 'jpg', 'png', etc.

  const FileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  String? _localPdfPath;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _loadPdf();
    } else {
      setState(() => _isLoading = false);
    }
  }

  bool get _isPdf => widget.fileType.toLowerCase().contains('pdf');

  Future<void> _loadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.fileUrl));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_${widget.fileName}');
      await file.writeAsBytes(response.bodyBytes);
      
      if (mounted) {
        setState(() {
          _localPdfPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not load PDF: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Download Original",
            onPressed: () {
               // We can add download logic here later if needed
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download feature is separate.")));
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _buildViewer(),
    );
  }

  Widget _buildViewer() {
    if (_isPdf) {
      return PDFView(
        filePath: _localPdfPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          setState(() => _errorMessage = error.toString());
        },
      );
    } else {
      // It's an image
      return PhotoView(
        imageProvider: NetworkImage(widget.fileUrl),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white, size: 50)
        ),
      );
    }
  }
}