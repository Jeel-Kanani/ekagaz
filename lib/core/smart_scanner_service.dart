import 'dart:io';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class SmartScannerService {
  
  // 1. Start the Pro Scanner UI
  Future<DocumentScanningResult?> scanDocument() async {
    try {
      final options = DocumentScannerOptions(
        mode: ScannerMode.full, // Camera + Gallery + Filter + Crop
        pageLimit: 100, // Multi-page scanning
        documentFormat: DocumentFormat.pdf, // We want a PDF result
      );

      final scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();
      return result;
    } catch (e) {
      print("Error scanning: $e");
      return null;
    }
  }

  // 2. Helper: If you need to manually create a PDF from images (Optional fallback)
  Future<File> createPdfFromImages(List<File> images) async {
    final pdf = pw.Document();

    for (var img in images) {
      final image = pw.MemoryImage(img.readAsBytesSync());
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image)); // Auto Fit
          },
        ),
      );
    }

    final outputDir = await getTemporaryDirectory();
    final file = File("${outputDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}