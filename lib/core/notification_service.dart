import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. Initialize the plugin
  static Future<void> init() async {
    // Android Setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Uses your app icon

    // General Setup
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // When user taps the notification, open the file
        if (response.payload != null) {
          OpenFile.open(response.payload);
        }
      },
    );
  }

  // 2. Request Permissions (Android 13+)
  static Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 3. Show the Notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload, // The file path (so we can open it on tap)
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'downloads_channel', // Channel ID
      'Downloads', // Channel Name
      channelDescription: 'Notifications for downloaded files',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }
}