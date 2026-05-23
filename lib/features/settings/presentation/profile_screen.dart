import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _baseCurrency = 'THB';
  String _country = 'TH';
  bool _initialised = false;
  bool _saving = false;

  static const _currencies = [
    'THB',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'CNY',
    'AUD',
    'CAD',
    'CHF',
    'HKD',
    'SGD',
    'SEK',
    'KRW',
    'NOK',
    'NZD',
    'INR',
    'MXN',
    'TWD',
    'ZAR',
    'BRL',
    'DKK',
    'PLN',
    'IDR',
    'CZK',
    'ILS',
    'CLP',
    'PHP',
    'AED',
    'COP',
    'SAR',
    'MYR',
    'RON',
    'VND',
    'TRY',
  ];

  static const _countries = {
    'TH': 'Thailand',
    'US': 'United States',
    'GB': 'United Kingdom',
    'JP': 'Japan',
    'DE': 'Germany',
    'FR': 'France',
    'CA': 'Canada',
    'AU': 'Australia',
    'BR': 'Brazil',
    'IN': 'India',
    'KR': 'South Korea',
    'MX': 'Mexico',
    'SG': 'Singapore',
    'ID': 'Indonesia',
    'PH': 'Philippines',
    'VN': 'Vietnam',
    'MY': 'Malaysia',
    'TW': 'Taiwan',
  };

  void _populateFrom(Profile profile) {
    if (_initialised) return;
    _displayNameController.text = profile.displayName;
    _emailController.text = profile.email;
    _baseCurrency = profile.baseCurrency;
    _country = profile.country;
    _initialised = true;
  }

  Future<void> _save(Profile current) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.save(
        current.copyWith(
          displayName: _displayNameController.text.trim(),
          email: current.email,
          baseCurrency: _baseCurrency,
          country: _country,
        ),
      );
      // Invalidate the profile provider to propagate changes
      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: AikoColors.successGreen,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: AikoColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AikoColors.dangerRed,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load your profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AikoColors.mutedText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(profileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          _populateFrom(profile);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              // Avatar & header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AikoColors.primaryBlue.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        _initials(_displayNameController.text),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AikoColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (profile.email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AikoColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Personal info
              FinanceCard(
                title: 'Personal information',
                icon: Icons.person_outline,
                child: Column(
                  children: [
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      enableInteractiveSelection: true,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        suffixIcon: Icon(Icons.lock_outline),
                        helperText: 'Email is managed by your sign-in account',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Regional preferences
              FinanceCard(
                title: 'Regional preferences',
                icon: Icons.public,
                accentColor: AikoColors.analyticsTeal,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _currencies.contains(_baseCurrency)
                          ? _baseCurrency
                          : 'THB',
                      decoration: const InputDecoration(
                        labelText: 'Base currency',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      items: _currencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _baseCurrency = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _countries.containsKey(_country)
                          ? _country
                          : 'TH',
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        prefixIcon: Icon(Icons.flag_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _countries.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.value} (${e.key})'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _country = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 24),

              // Save button
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(profile),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save changes'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
