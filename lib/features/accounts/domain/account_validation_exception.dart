class AccountValidationException implements Exception {
  const AccountValidationException(this.field, this.message);

  final String field;
  final String message;

  @override
  String toString() => 'AccountValidationException($field): $message';
}
