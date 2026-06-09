import 'dart:convert';
import '../network/api_client.dart';

class WalletService {
  final ApiClient _apiClient = ApiClient();

  Future<double> getBalance() async {
    try {
      final response = await _apiClient.get('/wallet/balance');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['balance'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Get balance error: $e');
      return 0.0;
    }
  }

  Future<bool> topUp(double amount) async {
    try {
      final response = await _apiClient.post('/wallet/topup', {
        'amount': amount,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('Top up error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final response = await _apiClient.get('/wallet/transactions');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get transactions error: $e');
      return [];
    }
  }
}
