import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'ocr_service.dart';
import 'share_service.dart'; // Share helper (share files / text)

class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String fileType;

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
  String? _localFilePath;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _downloadFile();
  }

  bool get _isPdf => widget.fileType.toLowerCase().contains('pdf');

  Future<void> _downloadFile() async {
    try {
      final response = await http.get(Uri.parse(widget.fileUrl));
      final dir = await getTemporaryDirectory();
      final safeName = widget.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(response.bodyBytes);
      
      if (mounted) {
        setState(() {
          _localFilePath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error loading file: $e");
    }
  }

  Future<void> _runOCR() async {
    if (_localFilePath == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Scanning text...")));
    
    final ocr = OCRService();
    // ✅ Just call processImage without language options
    final text = await ocr.processImage(_localFilePath!);
    ocr.dispose();

    if (!mounted) return;
    _showTextResult(text);
  }

  void _showTextResult(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Extracted Text"),
        content: SingleChildScrollView(
          child: SelectableText(text.isEmpty ? "No text found." : text),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text("Copy"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
            },
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.fileName, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (!_isPdf) 
            IconButton(
              icon: const Icon(Icons.text_snippet_outlined, color: Colors.white),
              tooltip: "Scan Text (OCR)",
              onPressed: _runOCR, // ✅ Direct call
            ),
          // ✅ SHARE BUTTON (Replaces Download)
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: "Share Document",
            onPressed: () async {
              if (_localFilePath != null) {
                await ShareService.shareFile(_localFilePath!, text: "Shared via FamVault");
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File not ready yet.")));
              }
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
        filePath: _localFilePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) => setState(() => _errorMessage = error.toString()),
      );
    } else {
      return PhotoView(
        imageProvider: FileImage(File(_localFilePath!)),
        loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 50)),
      );
    }
  }
}