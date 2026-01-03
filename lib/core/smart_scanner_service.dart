import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

enum ScanQuality { high, medium, low }

class SmartScannerService {

  // 1. Start the Pro Scanner UI with configurable quality
  Future<DocumentScanningResult?> scanDocument({ScanQuality quality = ScanQuality.high}) async {
    try {
      final options = DocumentScannerOptions(
        mode: ScannerMode.full, // Camera + Gallery + Filter + Crop
        pageLimit: 100, // Multi-page scanning
        documentFormat: DocumentFormat.pdf, // We want a PDF result
      );

      final scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();

      // Apply quality settings if result contains images
      if (result.images.isNotEmpty) {
        return await _processScannedImages(result, quality);
      }

      return result;
    } catch (e) {
      print("Error scanning: $e");
      return null;
    }
  }

  // Process scanned images with quality settings
  Future<DocumentScanningResult?> _processScannedImages(DocumentScanningResult result, ScanQuality quality) async {
    try {
      List<String> processedImages = [];

      for (String imagePath in result.images) {
        File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          File processedImage = await _compressImage(imageFile, quality);
          processedImages.add(processedImage.path);
        } else {
          processedImages.add(imagePath); // Keep original if processing fails
        }
      }

      // Create new result with processed images
      return DocumentScanningResult(
        images: processedImages,
        pdf: result.pdf,
      );
    } catch (e) {
      print("Error processing images: $e");
      return result; // Return original result if processing fails
    }
  }

  // Compress image based on quality setting
  Future<File> _compressImage(File imageFile, ScanQuality quality) async {
    try {
      Uint8List bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      int qualityValue;
      int maxWidth;
      int maxHeight;

      switch (quality) {
        case ScanQuality.high:
          qualityValue = 95;
          maxWidth = 2048;
          maxHeight = 2048;
          break;
        case ScanQuality.medium:
          qualityValue = 80;
          maxWidth = 1536;
          maxHeight = 1536;
          break;
        case ScanQuality.low:
          qualityValue = 60;
          maxWidth = 1024;
          maxHeight = 1024;
          break;
      }

      // Resize if necessary
      if (image.width > maxWidth || image.height > maxHeight) {
        image = img.copyResize(image, width: maxWidth, height: maxHeight, maintainAspect: true);
      }

      // Compress and save
      List<int> compressedBytes = img.encodeJpg(image, quality: qualityValue);
      String tempDir = (await getTemporaryDirectory()).path;
      String fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File compressedFile = File('$tempDir/$fileName');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      print("Error compressing image: $e");
      return imageFile; // Return original if compression fails
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