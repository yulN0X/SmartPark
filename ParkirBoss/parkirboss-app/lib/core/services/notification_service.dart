import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// Pulls the user's live activity feed (active session + wallet
/// transactions) and displays local push notifications for any new events.
class NotificationService {
  final ApiClient _apiClient = ApiClient();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  Timer? _pollingTimer;
  bool _isPolling = false;

  bool get isPolling => _isPolling;

  /// Initialize local notifications configuration
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification click if needed
      },
    );
  }

  /// Start polling notifications from backend every 15 seconds
  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;

    // Run initial poll
    _pollAndNotify();

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _pollAndNotify();
    });
    print('[NotificationService] Polling started.');
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    print('[NotificationService] Polling stopped.');
  }

  /// Fetch notifications and show local notification for any new ones
  Future<void> _pollAndNotify() async {
    try {
      final list = await getNotifications();
      if (list.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final List<String> seenIds = prefs.getStringList('seen_notification_ids') ?? [];

      bool hasNew = false;
      final List<String> newSeenIds = List.from(seenIds);

      // Iterate in reverse chronological order (oldest first of the new items)
      // so notifications appear in chronological sequence.
      for (var item in list.reversed) {
        final String? id = item['id'];
        final String title = item['title'] ?? 'Notifikasi Baru';
        final String body = item['body'] ?? '';

        if (id != null && !seenIds.contains(id)) {
          await _showLocalNotification(id.hashCode, title, body);
          newSeenIds.add(id);
          hasNew = true;
        }
      }

      if (hasNew) {
        // Keep seen list small (cap at 100)
        if (newSeenIds.length > 100) {
          newSeenIds.removeRange(0, newSeenIds.length - 100);
        }
        await prefs.setStringList('seen_notification_ids', newSeenIds);
      }
    } catch (e) {
      print('[NotificationService] Polling check failed: $e');
    }
  }

  /// Show a local push notification popup
  Future<void> _showLocalNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'smartpark_channel',
      'SmartPark Notifications',
      channelDescription: 'Notifications for parking session updates and wallet transactions',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
    );
  }

  /// Pull notifications list from backend
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await _apiClient.get('/notifications');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get notifications error: $e');
      return [];
    }
  }
}
