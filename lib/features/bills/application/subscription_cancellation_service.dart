import 'dart:async';
import 'package:share_plus/share_plus.dart';

class SubscriptionCancellationService {
  const SubscriptionCancellationService();

  /// Generates a formal legal cancellation letter.
  String generateCancellationLetter({
    required String merchantName,
    required String subscriberName,
    required String subscriberEmail,
    required String accountId,
    required String cancellationReason,
  }) {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    return '''
Date: $dateStr

To: Subscription Support Department, $merchantName

Subject: Request for Immediate Subscription Cancellation

Dear $merchantName Support Team,

Please accept this letter as formal notification that I am cancelling my subscription with $merchantName, effective immediately.

Here are the details associated with my account:
- Subscriber Name: $subscriberName
- Registered Email Address: $subscriberEmail
- Account/Subscription ID: $accountId
- Reason for Cancellation: $cancellationReason

I request that you immediately halt all future recurring billings, remove my payment method from your databases, and send a written confirmation of this cancellation within 3 business days, including the final statement confirming a zero balance.

Thank you for your prompt assistance.

Sincerely,

$subscriberName
$subscriberEmail
''';
  }

  /// Triggers standard system share sheets or email composition using share_plus
  Future<void> shareCancellationLetter({
    required String merchantName,
    required String subscriberName,
    required String subscriberEmail,
    required String accountId,
    required String cancellationReason,
  }) async {
    final body = generateCancellationLetter(
      merchantName: merchantName,
      subscriberName: subscriberName,
      subscriberEmail: subscriberEmail,
      accountId: accountId,
      cancellationReason: cancellationReason,
    );

    await Share.share(
      body,
      subject: 'Subscription Cancellation Request - $subscriberName',
    );
  }
}
