import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfService {
  
  // Convert a single online image to a PDF file
  Future<String?> convertImageToPdf(String imageUrl, String fileName) async {
    try {
      final pdf = pw.Document();

      // 1. Download the Image Data
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw "Failed to download image";
      final imageBytes = response.bodyBytes;

      // 2. Create a PDF Page with the Image
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );

      // 3. Save to Device
      String savePath;
      if (Platform.isAndroid) {
        // Permissions check
        if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
           // Good
        } else if (await Permission.manageExternalStorage.request().isGranted || await Permission.storage.request().isGranted) {
           // Good
        } else {
           throw "Permission Denied";
        }
        
        // ✅ Uses exact filename (which already has .pdf from folder_screen)
        savePath = "/storage/emulated/0/Download/$fileName";
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savePath = "${dir.path}/$fileName";
      }

      final file = File(savePath);
      await file.writeAsBytes(await pdf.save());

      return savePath;
    } catch (e) {
      print("PDF Error: $e");
      return null;
    }
  }
}