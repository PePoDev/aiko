enum AppFailureKind {
  notAuthenticated,
  permissionDenied,
  networkUnavailable,
  serverUnavailable,
  validation,
  conflict,
  fileUnsupported,
  unknown,
}

class AppFailure {
  const AppFailure(this.kind, this.message);

  final AppFailureKind kind;
  final String message;

  @override
  String toString() => 'AppFailure($kind, $message)';
}
