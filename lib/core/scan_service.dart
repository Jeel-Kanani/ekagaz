import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanService {
  final ImagePicker _picker = ImagePicker();

  // 1. Take a Photo using the Native Camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90, // High quality for OCR
      );
      return photo;
    } catch (e) {
      debugPrint("Error opening camera: $e");
      return null;
    }
  }

  // 2. Crop the Document (Mobile UI)
  Future<CroppedFile?> cropImage(String path) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: path,
        // Mobile-specific UI settings
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Corners',
            toolbarColor: Colors.blue[900],
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Adjust Corners',
          ),
        ],
      );
      return croppedFile;
    } catch (e) {
      debugPrint("Error cropping: $e");
      return null;
    }
  }

  // 3. Read Text from Image (OCR)
  Future<String> analyzeText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      await textRecognizer.close();
      return recognizedText.text; // Returns all the text found on the document
    } catch (e) {
      debugPrint("Error reading text: $e");
      return "";
    }
  }
}
