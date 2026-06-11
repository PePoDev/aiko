import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../domain/dashboard_widget_preference.dart';

class DashboardLayoutRepository {
  DashboardLayoutRepository({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _storageKey = 'dashboard_layout';

  final SecureStorageService _storage;

  Future<List<DashboardWidgetPreference>> load() async {
    final raw = await _storage.read(_storageKey);
    if (raw == null || raw.isEmpty) {
      return DashboardWidgetPreference.defaultLayout;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return DashboardWidgetPreference.defaultLayout;
      }
      return _normalize(
        decoded
            .whereType<Map<String, Object?>>()
            .map(DashboardWidgetPreference.fromJson)
            .toList(growable: false),
      );
    } catch (_) {
      return DashboardWidgetPreference.defaultLayout;
    }
  }

  Future<void> save(List<DashboardWidgetPreference> layout) {
    return _storage.write(
      _storageKey,
      jsonEncode(_normalize(layout).map((item) => item.toJson()).toList()),
    );
  }

  List<DashboardWidgetPreference> _normalize(
    List<DashboardWidgetPreference> layout,
  ) {
    final byType = {for (final item in layout) item.type: item};
    final ordered = [
      for (final fallback in DashboardWidgetPreference.defaultLayout)
        byType[fallback.type] ?? fallback,
    ]..sort((a, b) => a.position.compareTo(b.position));

    return [
      for (var index = 0; index < ordered.length; index++)
        ordered[index].copyWith(position: index),
    ];
  }
}
