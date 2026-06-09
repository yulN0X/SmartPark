import 'dart:convert';
import '../network/api_client.dart';

/// Pulls the user's live activity feed (active session + wallet
/// transactions) aggregated by the backend at /api/notifications.
class NotificationService {
  final ApiClient _apiClient = ApiClient();

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
