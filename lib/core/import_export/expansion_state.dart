enum ExpansionLifecycleStatus { hidden, preview, enabled, locked, archived }

class ExpansionLifecycle {
  const ExpansionLifecycle({
    required this.featureKey,
    required this.status,
    this.reason,
    this.updatedAt,
  });

  final String featureKey;
  final ExpansionLifecycleStatus status;
  final String? reason;
  final DateTime? updatedAt;

  bool get isDiscoverable =>
      status == ExpansionLifecycleStatus.preview ||
      status == ExpansionLifecycleStatus.enabled ||
      status == ExpansionLifecycleStatus.locked;

  bool get isUsable => status == ExpansionLifecycleStatus.enabled;
}
