import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/token_response.dart';

class ApiService {
  static const String _baseUrl = 'http://194.233.66.68:3001/api';

  static Future<TokenResponse> getToken({
    required String roomName,
    required String participantName,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/token'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'roomName': roomName,
        'participantName': participantName,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TokenResponse.fromJson(json);
    } else {
      throw Exception('Failed to get token: ${response.statusCode}');
    }
  }
}
