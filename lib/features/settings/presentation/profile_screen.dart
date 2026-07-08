import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/supported_currencies.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../application/profile_avatar_service.dart';
import '../data/line_link_repository.dart';
import '../domain/profile.dart';
import '../../auth/data/auth_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _authRepository = AuthRepository();
  final _avatarService = ProfileAvatarService();

  final _displayNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  late Profile _draft;
  bool _initialised = false;
  bool _saving = false;
  bool _isSigningOut = false;
  bool _isDeleting = false;
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(_onTextChanged);
    _fullNameController.addListener(_onTextChanged);
    _phoneController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _populateFrom(Profile profile) {
    if (_initialised) return;
    _draft = profile;
    _displayNameController.text = profile.displayName;
    _fullNameController.text = profile.fullName ?? '';
    _phoneController.text = profile.phoneNumber ?? '';
    _emailController.text = profile.email;
    _initialised = true;
  }

  bool _isDirty(Profile profile) {
    if (!_initialised) return false;
    if (_displayNameController.text.trim() != profile.displayName) return true;
    if (_fullNameController.text.trim() != (profile.fullName ?? '')) {
      return true;
    }
    if (_phoneController.text.trim() != (profile.phoneNumber ?? '')) {
      return true;
    }
    if (_draft.gender != profile.gender) return true;
    if (_draft.dateOfBirth != profile.dateOfBirth) return true;
    if (_draft.avatarPath != profile.avatarPath) return true;
    if (_draft.avatarUrl != profile.avatarUrl) return true;
    if (_draft.baseCurrency != profile.baseCurrency) return true;
    return false;
  }

  Future<void> _save(Profile current) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final next = current.copyWith(
        displayName: _displayNameController.text.trim(),
        fullName: _nullIfBlank(_fullNameController.text),
        phoneNumber: _nullIfBlank(_phoneController.text),
        gender: _draft.gender,
        dateOfBirth: _draft.dateOfBirth,
        avatarPath: _draft.avatarPath,
        avatarUrl: _draft.avatarUrl,
        baseCurrency: _draft.baseCurrency,
      );
      await repo.save(next);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      setState(() => _draft = next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: AikoColors.successGreen,
        ),
      );
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

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _onAvatarTap() async {
    AvatarAction? source;

    if (_draft.hasAvatar) {
      source = await showModalBottomSheet<AvatarAction>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, AvatarAction.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AikoColors.dangerRed,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: AikoColors.dangerRed),
                ),
                onTap: () => Navigator.pop(sheetContext, AvatarAction.remove),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } else {
      source = AvatarAction.gallery;
    }

    if (source == null || !mounted) return;

    if (source == AvatarAction.remove) {
      final previousPath = _draft.avatarPath;
      setState(() {
        _draft = _draft.copyWith(avatarPath: null, avatarUrl: null);
      });
      await _avatarService.removeFromCache(previousPath);
      return;
    }

    setState(() => _avatarBusy = true);
    try {
      final picked = await _avatarService.pickAndUpload(
        source: ImageSource.gallery,
      );
      if (picked == null) {
        return;
      }
      setState(() {
        _draft = _draft.copyWith(
          avatarPath: picked.localPath,
          avatarUrl: picked.cloudUrl,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update photo right now.'),
          backgroundColor: AikoColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _draft.dateOfBirth ?? DateTime(now.year - 18, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _draft = _draft.copyWith(dateOfBirth: picked));
  }

  Future<void> _pickGender() async {
    final picked = await showModalBottomSheet<Gender>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in Gender.values)
              ListTile(
                title: Text(_genderLabel(option)),
                trailing: _draft.gender == option
                    ? const Icon(Icons.check, color: AikoColors.primaryBlue)
                    : null,
                onTap: () => Navigator.pop(sheetContext, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(gender: picked));
  }

  Future<void> _pickBaseCurrency() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final code in kAikoSupportedCurrencies)
              ListTile(
                title: Text(_currencyLabel(code)),
                trailing: _draft.baseCurrency == code
                    ? const Icon(Icons.check, color: AikoColors.primaryBlue)
                    : null,
                onTap: () => Navigator.pop(sheetContext, code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == _draft.baseCurrency) return;
    setState(() => _draft = _draft.copyWith(baseCurrency: picked));
  }

  String _currencyLabel(String code) {
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    return '$code · $symbol';
  }

  String _genderLabel(Gender gender) {
    switch (gender) {
      case Gender.preferNotToSay:
        return 'Prefer not to say';
      case Gender.female:
        return 'Female';
      case Gender.male:
        return 'Male';
      case Gender.nonBinary:
        return 'Non-binary';
      case Gender.other:
        return 'Other';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }

  Future<void> _handleLinkGoogle() async {
    try {
      await _authRepository.linkGoogle();
      // The OAuth flow opens a browser; googleLinkedProvider flips once the
      // deep-link callback fires authStateChanges. Nothing to await here.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to connect Google right now.')),
      );
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isSigningOut = true);
    try {
      await _authRepository.signOut();
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out right now.')),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This permanently deletes your account and all your data right now. '
          'This cannot be undone. You will be signed out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await _authRepository.deleteAccount();
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete account right now.')),
      );
    }
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onTextChanged);
    _fullNameController.removeListener(_onTextChanged);
    _phoneController.removeListener(_onTextChanged);
    _displayNameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          profileAsync.maybeWhen(
            data: (profile) {
              if (_isDirty(profile)) {
                return TextButton.icon(
                  onPressed: _saving ? null : () => _save(profile),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profileAsync.when(
        loading: () => const AikoScreenState.loading(),
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
                const SizedBox(height: 8),
                Text(
                  'Could not load your profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
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
            padding: const EdgeInsets.only(bottom: 72),
            children: [
              _buildHeader(profile),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FinanceCard(
                  title: 'Personal information',
                  icon: Icons.person_outline,
                  child: Column(
                    children: [
                      _buildField(
                        controller: _displayNameController,
                        label: 'Display name',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 8),
                      _buildField(
                        controller: _fullNameController,
                        label: 'Full name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 8),
                      _buildField(
                        controller: _phoneController,
                        label: 'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      _buildChoiceRow(
                        label: 'Gender',
                        value: _genderLabel(_draft.gender),
                        icon: Icons.wc_outlined,
                        onTap: _pickGender,
                      ),
                      const SizedBox(height: 8),
                      _buildChoiceRow(
                        label: 'Date of birth',
                        value: _draft.dateOfBirth != null
                            ? _formatDate(_draft.dateOfBirth!)
                            : 'Not set',
                        icon: Icons.cake_outlined,
                        onTap: _pickDateOfBirth,
                        trailing: _draft.dateOfBirth != null
                            ? IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(
                                  () => _draft = _draft.copyWith(
                                    dateOfBirth: null,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _buildChoiceRow(
                        label: 'Base currency',
                        value: _currencyLabel(_draft.baseCurrency),
                        icon: Icons.attach_money_outlined,
                        onTap: _pickBaseCurrency,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: Icon(
                          Icons.email_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          'Email address',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        subtitle: Text(
                          profile.email,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        trailing: Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: Icon(
                          Icons.fingerprint,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          'User ID',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        subtitle: Text(
                          profile.id,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: IconButton(
                          tooltip: 'Copy User ID',
                          icon: Icon(
                            Icons.copy_outlined,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: profile.id),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User ID copied')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FinanceCard(
                  title: 'Connected apps',
                  icon: Icons.hub_outlined,
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          final linked =
                              ref.watch(lineLinkedProvider).value ?? false;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.chat_bubble_outline,
                              color: AikoColors.primaryBlue,
                            ),
                            title: Text(
                              linked ? 'LINE connected' : 'Connect LINE',
                            ),
                            subtitle: Text(
                              linked
                                  ? 'Aiko can chat with you on LINE'
                                  : 'Chat with Aiko from LINE',
                            ),
                            trailing: linked
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AikoColors.successGreen,
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: linked
                                ? null
                                : () async {
                                    await context.push('/connect-line');
                                    ref.invalidate(lineLinkedProvider);
                                  },
                          );
                        },
                      ),
                      const Divider(height: 1),
                      Builder(
                        builder: (context) {
                          final linked =
                              ref.watch(googleLinkedProvider).value ?? false;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.g_mobiledata,
                              color: AikoColors.primaryBlue,
                            ),
                            title: Text(
                              linked ? 'Google connected' : 'Connect Google',
                            ),
                            subtitle: Text(
                              linked
                                  ? 'Sign in with Google too'
                                  : 'Add Google sign-in to this account',
                            ),
                            trailing: linked
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AikoColors.successGreen,
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: linked ? null : _handleLinkGoogle,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FinanceCard(
                  title: 'Account Actions',
                  icon: Icons.manage_accounts_outlined,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.lock_outline,
                          color: AikoColors.primaryBlue,
                        ),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password flow opened.'),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.logout,
                          color: AikoColors.primaryBlue,
                        ),
                        title: const Text('Log out'),
                        trailing: _isSigningOut
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isSigningOut || _isDeleting
                            ? null
                            : _handleLogout,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FinanceCard(
                  title: 'Danger Zone',
                  icon: Icons.warning_amber_rounded,
                  accentColor: AikoColors.dangerRed,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.delete_forever_outlined,
                          color: AikoColors.dangerRed,
                        ),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(color: AikoColors.dangerRed),
                        ),
                        subtitle: const Text(
                          'Permanently remove your data',
                          style: TextStyle(color: AikoColors.dangerRed),
                        ),
                        trailing: _isDeleting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AikoColors.dangerRed,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right,
                                color: AikoColors.dangerRed,
                              ),
                        onTap: _isSigningOut || _isDeleting
                            ? null
                            : _handleDeleteAccount,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AikoColors.primaryBlue.withValues(alpha: 0.05),
      ),
      textCapitalization: label == 'Phone number'
          ? TextCapitalization.none
          : TextCapitalization.words,
    );
  }

  Widget _buildChoiceRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: AikoColors.primaryBlue.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(value, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              ?trailing,
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Profile profile) {
    final displayName = _displayNameController.text.isEmpty
        ? profile.displayName
        : _displayNameController.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AikoColors.primaryBlue.withValues(alpha: 0.15),
            AikoColors.primaryBlue.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _avatarBusy ? null : _onAvatarTap,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                _buildAvatar(profile, displayName),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AikoColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: _avatarBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.edit, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Profile profile, String displayName) {
    final localPath = _draft.avatarPath;
    final cloudUrl = _draft.avatarUrl;
    final fallbackUrl = localPath == null || localPath.isEmpty
        ? cloudUrl
        : null;
    Widget child;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        child = Image.file(
          file,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsAvatar(displayName),
        );
      } else {
        child = _networkOrInitials(fallbackUrl, displayName);
      }
    } else {
      child = _networkOrInitials(fallbackUrl, displayName);
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AikoColors.primaryBlue.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(child: SizedBox(width: 72, height: 72, child: child)),
    );
  }

  Widget _networkOrInitials(String? url, String displayName) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialsAvatar(displayName),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _initialsAvatar(displayName);
        },
      );
    }
    return _initialsAvatar(displayName);
  }

  Widget _initialsAvatar(String displayName) {
    return Container(
      width: 72,
      height: 72,
      color: AikoColors.primaryBlue,
      alignment: Alignment.center,
      child: Text(
        _initials(displayName),
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
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

enum AvatarAction { gallery, remove }
