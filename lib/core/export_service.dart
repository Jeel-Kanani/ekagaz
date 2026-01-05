import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:archive/archive.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ExportService {
  final supabase = Supabase.instance.client;

  /// Request storage permissions
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission
  }

  /// Get local documents directory
  Future<Directory> getLocalDocumentsDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download/FamVault');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return Directory('${dir.path}/FamVault_Exports');
    }
  }

  /// Export all family documents to device
  Future<String?> exportAllToDevice(BuildContext context, String familyId) async {
    try {
      // Request permissions
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required for export'))
        );
        return null;
      }

      // Show progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting export...'))
      );

      // Get export directory
      final exportDir = await getLocalDocumentsDirectory();
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Get all documents for the family
      final documents = await supabase
          .from('documents')
          .select('name, file_path, folder_id, folders(name)')
          .eq('family_id', familyId);

      if (documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No documents found to export'))
        );
        return null;
      }

      // Create organized folder structure
      final archive = Archive();

      for (final doc in documents) {
        final filePath = doc['file_path'] as String;
        final fileName = doc['name'] as String;
        final folderName = doc['folders']?['name'] ?? 'General';

        try {
          // Download file from Supabase storage
          final bytes = await supabase.storage.from('documents').download(filePath);

          // Add to archive with folder structure
          final archivePath = '$folderName/$fileName';
          archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
        } catch (e) {
          debugPrint('Failed to download $fileName: $e');
        }
      }

      // Create ZIP file
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName = 'FamVault_Backup_$timestamp.zip';
      final zipFile = File('${exportDir.path}/$zipFileName');

      await zipFile.writeAsBytes(zipData!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export completed! Saved to: ${zipFile.path}'))
      );

      return zipFile.path;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'))
      );
      return null;
    }
  }

  /// Backup all documents to Google Drive
  Future<bool> backupToGoogleDrive(BuildContext context, String familyId) async {
    try {
      // Show progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting to Google Drive...'))
      );

      // Google Sign In
      final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
      final account = await googleSignIn.signIn();

      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in cancelled'))
        );
        return false;
      }

      final authHeaders = await account.authHeaders;
      final authenticateClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            authHeaders['Authorization']!.split(' ').last,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          null,
          [drive.DriveApi.driveFileScope],
        ),
      );

      final driveApi = drive.DriveApi(authenticateClient);

      // Get all documents
      final documents = await supabase
          .from('documents')
          .select('name, file_path, folder_id, folders(name)')
          .eq('family_id', familyId);

      if (documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No documents found to backup'))
        );
        return false;
      }

      // Create FamVault backup folder in Google Drive
      final folderRequest = drive.File()
        ..name = 'FamVault_Backup_${DateTime.now().millisecondsSinceEpoch}'
        ..mimeType = 'application/vnd.google-apps.folder';

      final folder = await driveApi.files.create(folderRequest);
      final folderId = folder.id;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading documents to Google Drive...'))
      );

      // Upload each document
      for (final doc in documents) {
        final filePath = doc['file_path'] as String;
        final fileName = doc['name'] as String;
        final folderName = doc['folders']?['name'] ?? 'General';

        try {
          // Download file from Supabase
          final bytes = await supabase.storage.from('documents').download(filePath);

          // Create subfolder if needed
          var subfolderId = folderId;
          if (folderName != 'General') {
            final subfolderRequest = drive.File()
              ..name = folderName
              ..mimeType = 'application/vnd.google-apps.folder'
              ..parents = [folderId!];

            final subfolder = await driveApi.files.create(subfolderRequest);
            subfolderId = subfolder.id;
          }

          // Upload file to Google Drive
          final driveFile = drive.File()
            ..name = fileName
            ..parents = [subfolderId!];

          final media = drive.Media(Stream.value(bytes), bytes.length);
          await driveApi.files.create(driveFile, uploadMedia: media);

        } catch (e) {
          debugPrint('Failed to upload $fileName: $e');
        }
      }

      await googleSignIn.signOut();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup to Google Drive completed successfully!'))
      );

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Drive backup failed: $e'))
      );
      return false;
    }
  }

  /// Export specific folder to device
  Future<String?> exportFolderToDevice(BuildContext context, String folderId, String folderName) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required'))
        );
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting folder...'))
      );

      // Get documents in folder
      final documents = await supabase
          .from('documents')
          .select('name, file_path')
          .eq('folder_id', folderId);

      if (documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No documents in this folder'))
        );
        return null;
      }

      final exportDir = await getLocalDocumentsDirectory();
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Create folder-specific archive
      final archive = Archive();

      for (final doc in documents) {
        final filePath = doc['file_path'] as String;
        final fileName = doc['name'] as String;

        try {
          final bytes = await supabase.storage.from('documents').download(filePath);
          archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        } catch (e) {
          debugPrint('Failed to download $fileName: $e');
        }
      }

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName = '${folderName}_$timestamp.zip';
      final zipFile = File('${exportDir.path}/$zipFileName');

      await zipFile.writeAsBytes(zipData!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder exported! Saved to: ${zipFile.path}'))
      );

      return zipFile.path;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder export failed: $e'))
      );
      return null;
    }
  }
}
