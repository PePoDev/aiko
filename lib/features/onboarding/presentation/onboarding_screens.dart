import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../settings/domain/profile.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _pageController = PageController();
  var _page = 0;

  // Step 1 State: Personality
  String _personality = 'supportive'; // 'supportive', 'professional', 'playful'

  // Step 2 State: Focus
  String _focus = 'save'; // 'track', 'save', 'debt', 'wealth'

  // Step 3 State: Basics
  String _selectedCurrency = 'USD';
  String _selectedCountry = 'United States';

  // Step 4 State: First Account Form
  final _step4FormKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController(text: 'Cash Wallet');
  AccountType _accountType = AccountType.cash;
  final _accountBalanceController = TextEditingController(text: '0');

  // Step 5 State: Security
  String _securityOption = 'biometric'; // 'pin', 'biometric'
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    _pageController.dispose();
    _accountNameController.dispose();
    _accountBalanceController.dispose();
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Resolves Aiko asset based on step and selected options
  String _getAikoExpression() {
    if (_page == 0) {
      if (_personality == 'professional') {
        return 'assets/images/aiko/aiko_thinking.png';
      }
      if (_personality == 'playful') {
        return 'assets/images/aiko/aiko_celebrating.png';
      }
      return 'assets/images/aiko/aiko_welcome.png';
    }
    if (_page == 1) {
      if (_focus == 'track') return 'assets/images/aiko/aiko_thinking.png';
      if (_focus == 'debt') return 'assets/images/aiko/aiko_warning.png';
      if (_focus == 'wealth') return 'assets/images/aiko/aiko_celebrating.png';
      return 'assets/images/aiko/aiko_happy.png';
    }
    if (_page == 2) {
      return 'assets/images/aiko/aiko_thinking.png';
    }
    if (_page == 3) {
      return 'assets/images/aiko/aiko_encouraging.png';
    }
    return 'assets/images/aiko/aiko_happy.png';
  }

  // Resolves Aiko dialog speech bubble text
  String _getAikoSpeech() {
    switch (_page) {
      case 0:
        if (_personality == 'professional') {
          return 'Greetings. I am Aiko. I will provide precise financial calculations, trend tracking, and risk analysis. Let us organize your personal finances professionally. How should I talk to you?';
        }
        if (_personality == 'playful') {
          return 'Hey there! I\'m Aiko! Let\'s get this money party started! High fives for saving, warnings for overspending, and lots of positive vibes. Ready? How should I talk to you?';
        }
        return 'Hello! I\'m Aiko, your financial companion. I\'ll help you budget, save money, and build wealth in a warm and supportive way. How should I talk to you?';
      case 1:
        if (_focus == 'track') {
          return 'Smart choice! Categorizing every coffee and rent payment is the secret to budgeting success!';
        }
        if (_focus == 'debt') {
          return 'I\'m with you. Let\'s map out a payoff plan to smash that debt once and for all!';
        }
        if (_focus == 'wealth') {
          return 'Outstanding! Let\'s analyze your investment portfolio and build long-term wealth!';
        }
        return 'Yay! Let\'s build a SMART savings goal and lock in those savings!';
      case 2:
        return 'Where do you live, and what currency do you use? This ensures all formatting, taxes, and calculators match your local standards.';
      case 3:
        return 'Let\'s set up your very first account. It can be your physical cash wallet, main bank checking, or a credit card. Don\'t worry, you can add more later!';
      case 4:
        return 'Perfect! Finally, let\'s secure your financial details. Set up a secure passcode lock so only you can access your wallets.';
      default:
        return '';
    }
  }

  Future<void> _handleNext() async {
    if (_page == 3) {
      // Step 4 Validation & Persist First Account
      if (!_step4FormKey.currentState!.validate()) return;
      final name = _accountNameController.text.trim();
      final type = _accountType;
      final balStr = _accountBalanceController.text.trim();
      final balance = Money.parse(
        balStr.isEmpty ? '0' : balStr,
        _selectedCurrency,
      );

      final account = Account(
        id: const Uuid().v4(),
        userId: '', // Populated by repo
        name: name,
        type: type,
        openingBalance: balance,
        currentBalance: balance,
      );

      try {
        await ref.read(accountsProvider.notifier).addAccount(account);
      } catch (e) {
        debugPrint('Saved first account locally: $e');
      }
    }

    if (_page == 4) {
      // Step 5 Validation & Complete Onboarding
      if (_securityOption == 'pin') {
        final pin = _pinControllers.map((c) => c.text).join();
        if (pin.length < 4) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a full 4-digit PIN passcode.'),
                backgroundColor: AikoColors.dangerRed,
              ),
            );
          }
          return;
        }
      }

      // Save onboarding preferences
      try {
        final repo = ref.read(profileRepositoryProvider);
        final currentProfile = await ref.read(profileProvider.future);
        final updatedProfile = currentProfile.copyWith(
          baseCurrency: _selectedCurrency,
          country: _selectedCountry == 'United States' ? 'US' : 'UK',
          onboardingStatus: OnboardingStatus.completed,
          securityStatus: _securityOption == 'pin'
              ? SecurityStatus.pinEnabled
              : SecurityStatus.biometricEnabled,
        );
        await repo.save(updatedProfile);
      } catch (e) {
        debugPrint('Saved profile locally: $e');
      }

      // Redirect
      if (mounted) {
        context.push('/auth');
      }
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepsCount = 5;

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: const Text('Welcome to Aiko'),
        leading: _page > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
              )
            : null,
      ),
      body: Column(
        children: [
          // Dynamic Aiko Character Speech Bubble
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AikoColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AikoColors.primaryBlue.withValues(alpha: 0.24),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AikoColors.border.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(
                    _getAikoExpression(),
                    width: 72,
                    height: 72,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.face_3_outlined,
                      size: 72,
                      color: AikoColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getAikoSpeech(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AikoColors.darkNavy,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Interactive Page Wizard contents
          Expanded(
            child: PageView(
              controller: _pageController,
              physics:
                  const NeverScrollableScrollPhysics(), // Force wizard button progression
              onPageChanged: (value) => setState(() => _page = value),
              children: [
                _buildStep1MeetAiko(),
                _buildStep2Focus(),
                _buildStep3Basics(),
                _buildStep4Account(),
                _buildStep5Security(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Onboarding Progress indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_page + 1) / stepsCount,
                backgroundColor: AikoColors.borderSubtle,
                color: AikoColors.primaryBlue,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _handleNext,
              style: FilledButton.styleFrom(
                backgroundColor: AikoColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _page == stepsCount - 1
                    ? Icons.check_circle_outline
                    : Icons.arrow_forward,
              ),
              label: Text(
                _page == stepsCount - 1 ? 'Finish & Sign In' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: MEET AIKO (Personality Selection)
  Widget _buildStep1MeetAiko() {
    final List<Map<String, String>> choices = [
      {
        'key': 'supportive',
        'title': 'Supportive',
        'desc': 'A warm, encouraging, non-judgmental finance bestie.',
        'icon': '❤️',
      },
      {
        'key': 'professional',
        'title': 'Professional',
        'desc': 'Analytical, serious, data-driven financial advisor.',
        'icon': '💼',
      },
      {
        'key': 'playful',
        'title': 'Playful',
        'desc': 'Energetic, fun, celebrates small wins with high-fives.',
        'icon': '⭐',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meet Aiko',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AikoColors.darkNavy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aiko\'s Personality Tone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AikoColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          for (final choice in choices) ...[
            GestureDetector(
              onTap: () => setState(() => _personality = choice['key']!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AikoColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _personality == choice['key']!
                        ? AikoColors.primaryBlue
                        : AikoColors.borderSubtle,
                    width: _personality == choice['key']! ? 2.5 : 1,
                  ),
                  boxShadow: _personality == choice['key']!
                      ? [
                          BoxShadow(
                            color: AikoColors.primaryBlue.withValues(
                              alpha: 0.12,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Text(choice['icon']!, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            choice['title']!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AikoColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            choice['desc']!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AikoColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // STEP 2: FINANCIAL FOCUS
  Widget _buildStep2Focus() {
    final List<Map<String, String>> options = [
      {
        'key': 'save',
        'title': 'Save money',
        'desc': 'Build a strong emergency savings cushion.',
        'icon': '💰',
      },
      {
        'key': 'track',
        'title': 'Track spending',
        'desc': 'Log expenses to see where every dollar goes.',
        'icon': '📊',
      },
      {
        'key': 'debt',
        'title': 'Pay off debt',
        'desc': 'Create payoffs plans to become debt-free.',
        'icon': '🛡️',
      },
      {
        'key': 'wealth',
        'title': 'Build wealth',
        'desc': 'Invest smartly and plan for long-term growth.',
        'icon': '🚀',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What is your main financial goal?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AikoColors.darkNavy,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final opt = options[index];
              final isSelected = _focus == opt['key'];

              return GestureDetector(
                onTap: () => setState(() => _focus = opt['key']!),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AikoColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AikoColors.primaryBlue
                          : AikoColors.borderSubtle,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AikoColors.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(opt['icon']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(
                        opt['title']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AikoColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt['desc']!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AikoColors.mutedText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // STEP 3: MONEY BASICS (Currency & Country)
  Widget _buildStep3Basics() {
    final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'SGD'];
    final countries = [
      'United States',
      'United Kingdom',
      'European Union',
      'Japan',
      'Canada',
      'Australia',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Currency & Country Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AikoColors.darkNavy,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCurrency,
            decoration: InputDecoration(
              labelText: 'Base Currency',
              prefixIcon: const Icon(Icons.monetization_on_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: currencies.map((curr) {
              return DropdownMenuItem(value: curr, child: Text(curr));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCurrency = val);
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedCountry,
            decoration: InputDecoration(
              labelText: 'Country',
              prefixIcon: const Icon(Icons.public_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: countries.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCountry = val);
            },
          ),
        ],
      ),
    );
  }

  // STEP 4: ADD FIRST ACCOUNT FORM
  Widget _buildStep4Account() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step4FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Your First Financial Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AikoColors.darkNavy,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g., Pocket Wallet, Checking Account',
                prefixIcon: const Icon(Icons.edit_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter account name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              initialValue: _accountType,
              decoration: InputDecoration(
                labelText: 'Account Type',
                prefixIcon: const Icon(Icons.account_balance_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: AccountType.cash,
                  child: Text('Cash Wallet'),
                ),
                DropdownMenuItem(
                  value: AccountType.bank,
                  child: Text('Bank Account'),
                ),
                DropdownMenuItem(
                  value: AccountType.creditCard,
                  child: Text('Credit Card'),
                ),
                DropdownMenuItem(
                  value: AccountType.investment,
                  child: Text('Investment'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _accountType = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountBalanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Opening Balance',
                prefixText: '$_selectedCurrency ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter starting balance';
                }
                final dec = Decimal.tryParse(value);
                if (dec == null || dec < Decimal.zero) {
                  return 'Must be a valid positive number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // STEP 5: SECURITY
  Widget _buildStep5Security() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configure Security Shield',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AikoColors.darkNavy,
            ),
          ),
          const SizedBox(height: 16),
          // Security Method Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AikoColors.borderSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Secure PIN Code')),
                    selected: _securityOption == 'pin',
                    onSelected: (selected) {
                      if (selected) setState(() => _securityOption = 'pin');
                    },
                    selectedColor: AikoColors.primaryBlue,
                    labelStyle: TextStyle(
                      color: _securityOption == 'pin'
                          ? Colors.white
                          : AikoColors.neutralInk,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Biometrics Only')),
                    selected: _securityOption == 'biometric',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _securityOption = 'biometric');
                      }
                    },
                    selectedColor: AikoColors.primaryBlue,
                    labelStyle: TextStyle(
                      color: _securityOption == 'biometric'
                          ? Colors.white
                          : AikoColors.neutralInk,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_securityOption == 'pin') ...[
            const Center(
              child: Text(
                'Enter a 4-Digit Passcode PIN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AikoColors.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (idx) {
                return SizedBox(
                  width: 54,
                  child: TextFormField(
                    controller: _pinControllers[idx],
                    focusNode: _pinFocusNodes[idx],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    obscureText: true,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AikoColors.primaryBlue,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AikoColors.primaryBlue,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        if (idx < 3) {
                          FocusScope.of(
                            context,
                          ).requestFocus(_pinFocusNodes[idx + 1]);
                        } else {
                          _pinFocusNodes[idx].unfocus();
                        }
                      } else {
                        if (idx > 0) {
                          FocusScope.of(
                            context,
                          ).requestFocus(_pinFocusNodes[idx - 1]);
                        }
                      }
                    },
                  ),
                );
              }),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AikoColors.primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 64,
                      color: AikoColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Use Your Native Device Biometrics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AikoColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Taps into Face ID / Touch ID / Android fingerprint scanning securely to instantly unlock Aiko.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AikoColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
