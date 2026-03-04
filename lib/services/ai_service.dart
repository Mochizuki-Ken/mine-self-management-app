
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String baseUrl; // e.g., "https://your-server.example.com"
  final Map<String, String>? defaultHeaders;

  AiService({required this.baseUrl, this.defaultHeaders});

  /// Send user_input (and optional conversation history and optional function_result)
  /// Returns parsed JSON map (server response parsed to Map)
  Future<Map<String, dynamic>> chat({
    required String userInput,
    List<Map<String, dynamic>>? conversation,
    dynamic functionResult,
  }) async {
    final url = Uri.parse('$baseUrl/ai/chat');
    final body = {
      'user_input': userInput,
      if (conversation != null) 'conversation': conversation,
      if (functionResult != null) 'function_result': functionResult,
    };
    final headers = {
      'Content-Type': 'application/json',
      if (defaultHeaders != null) ...defaultHeaders!,
    };
    final resp = await http.post(url, body: jsonEncode(body), headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('AI service returned ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return decoded;
  }
}