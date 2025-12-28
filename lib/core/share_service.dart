import 'package:share_plus/share_plus.dart';

class ShareService {
  
  // Share a single file (PDF or Image)
  static Future<void> shareFile(String filePath, {String? text}) async {
    final file = XFile(filePath);
    await Share.shareXFiles([file], text: text);
  }

  // Share extracted text
  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
