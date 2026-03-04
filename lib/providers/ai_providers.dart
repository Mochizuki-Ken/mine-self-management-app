import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/ai_frontend_orchestrator.dart';
import '../services/app_actions.dart';

// Provide AiService configured with your server URL
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(baseUrl: 'http://192.168.0.123:8000'); // set your base URL
});
/// Provide orchestrator.
///
/// IMPORTANT FIX:
/// - The FutureProvider's callback receives a Ref (or ProviderRef) which has a `.read` method.
/// - Do NOT cast `ref` to WidgetRef. Instead pass `ref.read` as the Reader to the orchestrator
///   (AiFrontendOrchestrator expects a `Reader`/function that can read providers).
final aiOrchestratorProvider = FutureProvider<AiFrontendOrchestrator>((ref) async {
  final service = ref.read(aiServiceProvider);
  // pass ref.read as the Reader to the orchestrator
  return AiFrontendOrchestrator(aiService: service, ref: ref.read);
});