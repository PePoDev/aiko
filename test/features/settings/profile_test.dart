import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profile = Profile(
    id: 'u1',
    displayName: 'Ann',
    email: 'ann@example.com',
    baseCurrency: 'THB',
    country: 'TH',
    securityStatus: SecurityStatus.notConfigured,
    fullName: 'Ann Lee',
    dateOfBirth: DateTime(1990, 5, 1),
    phoneNumber: '0812345678',
    avatarPath: 'aiko-cache:avatars/u1.jpg',
    avatarUrl: 'https://example.com/a.jpg',
  );

  test('copyWith clears optional fields passed as null', () {
    final cleared = profile.copyWith(
      fullName: () => null,
      dateOfBirth: () => null,
      phoneNumber: () => null,
      avatarPath: () => null,
      avatarUrl: () => null,
    );

    expect(cleared.fullName, isNull);
    expect(cleared.dateOfBirth, isNull);
    expect(cleared.phoneNumber, isNull);
    expect(cleared.avatarPath, isNull);
    expect(cleared.avatarUrl, isNull);
    expect(cleared.hasAvatar, isFalse);
    expect(cleared.displayName, 'Ann');
  });

  test('copyWith keeps optional fields that are not passed', () {
    final renamed = profile.copyWith(displayName: 'Annie');

    expect(renamed.displayName, 'Annie');
    expect(renamed.fullName, 'Ann Lee');
    expect(renamed.dateOfBirth, DateTime(1990, 5, 1));
    expect(renamed.phoneNumber, '0812345678');
    expect(renamed.avatarPath, 'aiko-cache:avatars/u1.jpg');
    expect(renamed.avatarUrl, 'https://example.com/a.jpg');
  });

  test('copyWith replaces optional fields with new values', () {
    final updated = profile.copyWith(
      fullName: () => 'Ann Smith',
      dateOfBirth: () => DateTime(1991, 1, 2),
      avatarPath: () => 'aiko-cache:avatars/pending/u1.png',
    );

    expect(updated.fullName, 'Ann Smith');
    expect(updated.dateOfBirth, DateTime(1991, 1, 2));
    expect(updated.avatarPath, 'aiko-cache:avatars/pending/u1.png');
    expect(updated.avatarUrl, 'https://example.com/a.jpg');
  });
}
