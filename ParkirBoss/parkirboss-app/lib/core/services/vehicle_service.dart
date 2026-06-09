import 'dart:convert';
import '../network/api_client.dart';

class VehicleService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      final response = await _apiClient.get('/vehicles');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get vehicles error: $e');
      return [];
    }
  }

  Future<bool> addVehicle(String plateNumber, {String? color, String? brand}) async {
    try {
      final body = <String, dynamic>{
        'plate_number': plateNumber,
      };
      if (color != null) body['color'] = color;
      if (brand != null) body['brand'] = brand;

      final response = await _apiClient.post('/vehicles', body);
      return response.statusCode == 200;
    } catch (e) {
      print('Add vehicle error: $e');
      return false;
    }
  }

  Future<bool> deleteVehicle(String vehicleId) async {
    try {
      final response = await _apiClient.delete('/vehicles/$vehicleId');
      return response.statusCode == 200;
    } catch (e) {
      print('Delete vehicle error: $e');
      return false;
    }
  }
}
