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
  String _baseCurrency = 'USD';
  String _country = 'US';
  PreferredTheme _preferredTheme = PreferredTheme.system;
  bool _initialised = false;
  bool _saving = false;

  static const _currencies = [
    'USD', 'EUR', 'GBP', 'JPY', 'CNY', 'AUD', 'CAD', 'CHF',
    'HKD', 'SGD', 'SEK', 'KRW', 'NOK', 'NZD', 'INR', 'MXN',
    'TWD', 'ZAR', 'BRL', 'DKK', 'PLN', 'THB', 'IDR', 'CZK',
    'ILS', 'CLP', 'PHP', 'AED', 'COP', 'SAR', 'MYR', 'RON',
    'VND', 'TRY',
  ];

  static const _countries = {
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
    'TH': 'Thailand',
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
    _preferredTheme = profile.preferredTheme;
    _initialised = true;
  }

  Future<void> _save(Profile current) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.save(
        current.copyWith(
          displayName: _displayNameController.text.trim(),
          email: _emailController.text.trim(),
          baseCurrency: _baseCurrency,
          country: _country,
          preferredTheme: _preferredTheme,
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
                const Icon(Icons.error_outline, size: 48, color: AikoColors.dangerRed),
                const SizedBox(height: 12),
                Text(
                  'Could not load your profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AikoColors.mutedText,
                      ),
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
                      backgroundColor: AikoColors.primaryBlue.withValues(alpha: 0.12),
                      child: Text(
                        _initials(_displayNameController.text),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
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
                      value: _currencies.contains(_baseCurrency) ? _baseCurrency : 'USD',
                      decoration: const InputDecoration(
                        labelText: 'Base currency',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      items: _currencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _baseCurrency = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _countries.containsKey(_country) ? _country : 'US',
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

              // Appearance
              FinanceCard(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                accentColor: AikoColors.premiumPurple,
                child: Column(
                  children: [
                    for (final theme in PreferredTheme.values)
                      RadioListTile<PreferredTheme>(
                        contentPadding: EdgeInsets.zero,
                        value: theme,
                        groupValue: _preferredTheme,
                        onChanged: (value) {
                          if (value != null) setState(() => _preferredTheme = value);
                        },
                        title: Text(_themeLabel(theme)),
                        secondary: Icon(_themeIcon(theme)),
                      ),
                  ],
                ),
              ),
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

  String _themeLabel(PreferredTheme theme) {
    switch (theme) {
      case PreferredTheme.system:
        return 'System default';
      case PreferredTheme.light:
        return 'Light';
      case PreferredTheme.dark:
        return 'Dark';
    }
  }

  IconData _themeIcon(PreferredTheme theme) {
    switch (theme) {
      case PreferredTheme.system:
        return Icons.brightness_auto;
      case PreferredTheme.light:
        return Icons.light_mode;
      case PreferredTheme.dark:
        return Icons.dark_mode;
    }
  }
}
