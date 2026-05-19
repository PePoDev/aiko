enum SourceFreshnessStatus { current, stale, missing }

class SourceFreshness {
  const SourceFreshness({
    required this.sourceKey,
    required this.status,
    this.lastUpdatedAt,
    this.maxAge = const Duration(days: 1),
  });

  final String sourceKey;
  final SourceFreshnessStatus status;
  final DateTime? lastUpdatedAt;
  final Duration maxAge;

  bool isFresh(DateTime now) {
    final updatedAt = lastUpdatedAt;
    if (status != SourceFreshnessStatus.current || updatedAt == null) {
      return false;
    }

    return now.difference(updatedAt) <= maxAge;
  }
}
