import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: \$e');
      return false;
    }
  }

  Future<bool> register(String name, String email, String phone, String password) async {
    try {
      final response = await _apiClient.post('/auth/register', {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      });

      return response.statusCode == 200;
    } catch (e) {
      print('Register error: \$e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await _apiClient.post('/auth/change-password', {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Kata sandi berhasil diubah'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['detail'] ?? 'Gagal mengubah kata sandi'};
      }
    } catch (e) {
      print('Change password error: \$e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }
}
