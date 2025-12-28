import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  // ✅ Only use the standard Latin (English) recognizer for now
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return "Error extracting text: $e";
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}