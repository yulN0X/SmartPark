import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../network/api_client.dart';

class GpsService {
  final ApiClient _apiClient = ApiClient();
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// Start tracking user location and sending updates to backend
  Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[GPS] Location services are disabled.');
        return;
      }

      // 2. Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[GPS] Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[GPS] Location permissions are permanently denied.');
        return;
      }

      // 3. Configure location settings (distanceFilter = 20 meters)
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      );

      // 4. Start listening to position stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _sendHeartbeat(position);
        },
        onError: (e) {
          print('[GPS] Error in position stream: $e');
        },
      );

      _isTracking = true;
      print('[GPS] Location tracking started successfully.');

      // Send initial location immediately
      final currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _sendHeartbeat(currentPos);

    } catch (e) {
      print('[GPS] Failed to start location tracking: $e');
    }
  }

  /// Stop tracking location
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    print('[GPS] Location tracking stopped.');
  }

  /// Send GPS coordinates to backend
  Future<void> _sendHeartbeat(Position position) async {
    try {
      final body = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toUtc().toIso8601String(),
      };
      
      print('[GPS] Sending heartbeat: lat=${position.latitude}, lon=${position.longitude}, acc=${position.accuracy}m');
      
      // Heartbeat endpoint path is /gps/heartbeat (api prefix is handled in ApiClient baseUrl)
      final response = await _apiClient.post('/gps/heartbeat', body);
      if (response.statusCode != 200) {
        print('[GPS] Failed to send heartbeat. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('[GPS] Heartbeat error: $e');
    }
  }
}
