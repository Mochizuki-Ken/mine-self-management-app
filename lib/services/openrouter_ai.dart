import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterAi {
  OpenRouterAi({
    required this.apiKey,
    this.appTitle = 'MineApp',
    this.referer = 'http://localhost',
    this.model = 'stepfun-ai/step-3.5-flash',
  });

  final String apiKey;
  final String model;

  /// Optional but recommended by OpenRouter
  final String appTitle;
  final String referer;

  Future<String> chat({
    required String userPrompt,
    String? systemPrompt,
    double temperature = 0.3,
  }) async {
    final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final messages = <Map<String, dynamic>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        // OpenRouter recommended headers:
        'HTTP-Referer': referer,
        'X-Title': appTitle,
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('OpenRouter error ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = (json['choices'] as List?) ?? const [];
    if (choices.isEmpty) return '';

    final message = (choices.first as Map)['message'] as Map?;
    final content = message?['content'];
    return content is String ? content : '';
  }
}