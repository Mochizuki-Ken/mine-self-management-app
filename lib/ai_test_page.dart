import 'package:flutter/material.dart';
import '../services/openrouter_ai.dart';

class AiTestPage extends StatefulWidget {
  const AiTestPage({super.key});

  @override
  State<AiTestPage> createState() => _AiTestPageState();
}

class _AiTestPageState extends State<AiTestPage> {
  final _prompt = TextEditingController(text: 'Create a task: buy milk at 6pm today.');
  String _out = '';
  bool _loading = false;

  // WARNING: for testing only. Don’t ship real keys in the app.
  static const _openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');

  late final OpenRouterAi _ai = OpenRouterAi(
    apiKey: _openRouterKey,
    appTitle: 'MineApp (test)',
    referer: 'http://localhost',
    model: 'stepfun-ai/step-3.5-flash',
  );

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _out = '';
    });

    try {
      final res = await _ai.chat(
        systemPrompt: 'You are a helpful planner assistant. Reply with plain text.',
        userPrompt: _prompt.text,
      );
      setState(() => _out = res);
    } catch (e) {
      setState(() => _out = 'ERROR: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _run,
              child: Text(_loading ? 'Running...' : 'Call OpenRouter'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_out),
              ),
            ),
          ],
        ),
      ),
    );
  }
}