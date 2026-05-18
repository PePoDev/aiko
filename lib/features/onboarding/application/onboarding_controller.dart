import '../../accounts/domain/account.dart';
import '../../settings/domain/profile.dart';

enum OnboardingStepKey {
  meetAiko,
  focus,
  currency,
  account,
  aiConsent,
  security,
  completed,
}

class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStepKey.meetAiko,
    this.focus = 'Track spending',
    this.baseCurrency = 'USD',
    this.country = 'US',
    this.aiConsentEnabled = false,
    this.firstAccount,
  });

  final OnboardingStepKey step;
  final String focus;
  final String baseCurrency;
  final String country;
  final bool aiConsentEnabled;
  final Account? firstAccount;

  bool get canComplete {
    return baseCurrency.isNotEmpty &&
        country.isNotEmpty &&
        firstAccount != null &&
        step == OnboardingStepKey.completed;
  }

  OnboardingState copyWith({
    OnboardingStepKey? step,
    String? focus,
    String? baseCurrency,
    String? country,
    bool? aiConsentEnabled,
    Account? firstAccount,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      focus: focus ?? this.focus,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      country: country ?? this.country,
      aiConsentEnabled: aiConsentEnabled ?? this.aiConsentEnabled,
      firstAccount: firstAccount ?? this.firstAccount,
    );
  }

  Profile toProfile(String userId, String email) {
    return Profile(
      id: userId,
      displayName: 'Aiko User',
      email: email,
      baseCurrency: baseCurrency,
      country: country,
      aiConsentEnabled: aiConsentEnabled,
      onboardingStatus: OnboardingStatus.completed,
      securityStatus: SecurityStatus.pinEnabled,
    );
  }
}

class OnboardingController {
  OnboardingState _state = const OnboardingState();

  OnboardingState get state => _state;

  void chooseFocus(String focus) {
    _state = _state.copyWith(focus: focus, step: OnboardingStepKey.currency);
  }

  void chooseCurrency(String currency, String country) {
    _state = _state.copyWith(
      baseCurrency: currency,
      country: country,
      step: OnboardingStepKey.account,
    );
  }

  void addFirstAccount(Account account) {
    _state = _state.copyWith(
      firstAccount: account,
      step: OnboardingStepKey.aiConsent,
    );
  }

  void setAiConsent(bool enabled) {
    _state = _state.copyWith(
      aiConsentEnabled: enabled,
      step: OnboardingStepKey.security,
    );
  }

  void completeSecurity() {
    _state = _state.copyWith(step: OnboardingStepKey.completed);
  }
}
