import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_actions.dart';

/// Simple provider that exposes AppActions to widgets/notifiers.
/// Replace AppActions() with any configured instance if needed.
final appActionsProvider = Provider<AppActions>((ref) {
  return AppActions();
});