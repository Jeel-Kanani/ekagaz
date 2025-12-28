import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PdfCreatorService {
  final picker = ImagePicker();

  Future<File?> createPdfFromGallery() async {
    // 1. Pick Multiple Images
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty) return null;

    final pdf = pw.Document();

    // 2. Add pages to PDF
    for (var img in images) {
      final imageBytes = await File(img.path).readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pdfImage)); // Auto-fit
          },
        ),
      );
    }

    // 3. Save PDF
    final outputDir = await getTemporaryDirectory();
    final file = File(
        "${outputDir.path}/Converted_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
