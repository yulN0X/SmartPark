import 'dart:convert';
import '../network/api_client.dart';

class ParkingService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getActiveSession() async {
    try {
      final response = await _apiClient.get('/parking/active');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'active': false};
    } catch (e) {
      print('Get active session error: $e');
      return {'active': false};
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final response = await _apiClient.get('/parking/history');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get parking history error: $e');
      return [];
    }
  }

  /// Nearby parking venues with live availability, sorted by distance.
  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final response = await _apiClient.get('/parking/locations');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get parking locations error: $e');
      return [];
    }
  }
}
