import 'package:aiko/core/monetization/feature_entitlement.dart';
import 'package:aiko/core/sync/sync_state.dart';
import 'package:aiko/features/devices/application/device_session_service.dart';
import 'package:aiko/features/devices/domain/device_session.dart';
import 'package:aiko/features/aiko_optimize/application/aiko_optimize_service.dart';
import 'package:aiko/features/aiko_optimize/domain/optimization_suggestion.dart';
import 'package:aiko/features/learning_hub/data/course_progress_repository.dart';
import 'package:aiko/features/learning_hub/domain/course_lesson.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('learning, device sync, and monetization flow', (tester) async {
    final repo = CourseProgressRepository()
      ..saveProgress('budgeting', LessonProgress.completed);
    final trusted = const DeviceSessionService().trust(
      const DeviceSession(deviceId: 'phone', deviceName: 'Phone'),
    );
    const entitlement = FeatureEntitlement(
      featureKey: 'advancedReports',
      requiredTier: PlanTier.premium,
    );
    const sync = DeviceSyncState(deviceId: 'phone', status: SyncStatus.synced);
    final optimize = const AikoOptimizeService().rank([
      const OptimizationSuggestion(title: 'Tune budget', score: 0.9),
    ]);

    expect(repo.progressFor('budgeting'), LessonProgress.completed);
    expect(trusted.canSync, isTrue);
    expect(entitlement.allows(PlanTier.free), isFalse);
    expect(sync.needsUserAttention, isFalse);
    expect(optimize.single.dismiss().status, OptimizationStatus.dismissed);
  });
}
