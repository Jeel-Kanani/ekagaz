import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          OpenFile.open(response.payload);
        }
      },
    );
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // ✅ FIX: Use simple permission handler for Android 13+
      await Permission.notification.request();
      
      // Also init the specific android plugin implementation
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
              
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'downloads_channel',
      'Downloads',
      channelDescription: 'Notifications for downloaded files',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications.show(id, title, body, details, payload: payload);
  }
}