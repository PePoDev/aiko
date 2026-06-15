import 'package:aiko/core/monetization/feature_entitlement.dart';
import 'package:aiko/features/devices/application/device_session_service.dart';
import 'package:aiko/features/devices/domain/device_session.dart';
import 'package:aiko/features/learning_hub/application/lesson_recommendation_service.dart';
import 'package:aiko/features/learning_hub/domain/course_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('learning, device, and monetization wiring', () {
    const lesson = CourseLesson(
      key: 'budgeting',
      title: 'Budgeting basics',
      category: 'budgeting',
    );
    final recommendation = const LessonRecommendationService().recommend(
      [lesson],
      'budgeting',
    );
    final trusted = const DeviceSessionService().trust(
      const DeviceSession(deviceId: 'phone', deviceName: 'Phone'),
    );
    const entitlement = FeatureEntitlement(
      featureKey: 'advancedReports',
      requiredTier: PlanTier.premium,
    );

    expect(recommendation.key, 'budgeting');
    expect(trusted.canSync, isTrue);
    expect(entitlement.allows(PlanTier.free), isFalse);
  });
}
