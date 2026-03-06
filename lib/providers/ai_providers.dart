import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/ai_frontend_orchestrator.dart';
// import '../services/app_actions.dart';

// Provide AiService configured with your server URL
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(baseUrl: 'https://kenmochizuki.pythonanywhere.com/'); // set your base URL
});

/// Provide orchestrator.
/// Pass the Ref itself; the orchestrator will call ref.read internally.
final aiOrchestratorProvider =
    FutureProvider<AiFrontendOrchestrator>((ref) async {
  final service = ref.read(aiServiceProvider);
  return AiFrontendOrchestrator(aiService: service, ref: ref);
});