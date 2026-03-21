import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CreditsService {
  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  Future<int> fetchBalance(String userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/credits/$userId'),
    );

    if (response.statusCode != 200) return 0;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['balance'] as int? ?? 0;
  }

  Future<bool> deductCredit(String userId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/credits/$userId/deduct'),
    );
    return response.statusCode == 200;
  }
}
