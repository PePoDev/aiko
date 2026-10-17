import 'dart:async';

import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/aiko_snack_bar.dart';
import '../../../shared/widgets/cached_avatar.dart';
import '../../../shared/widgets/discard_changes_guard.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/firebase_sync.dart';
import '../../../app/providers.dart';
import '../../../app/user_session.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../core/money/supported_currencies.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../../theme/aiko_status_colors.dart';
import '../application/profile_avatar_service.dart';
import '../data/line_link_repository.dart';
import '../domain/profile.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/connection_errors.dart';
import '../../auth/data/guest_mode.dart';
import '../../auth/presentation/auth_error_message.dart';
import '../../auth/presentation/guest_sign_in_tile.dart';

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

  /// A photo picked but not saved yet; it replaces the saved avatar on Save.
  PendingAvatar? _pendingAvatar;

  /// "Remove photo" was chosen; the saved photo goes on Save.
  bool _photoRemoved = false;
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
    // Not the draft's photo fields: a queued upload sets the saved URL later.
    if (_pendingAvatar != null) return true;
    if (_photoRemoved && profile.hasAvatar) return true;
    if (_draft.baseCurrency != profile.baseCurrency) return true;
    return false;
  }

  Future<void> _save(Profile current) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final pending = _pendingAvatar;
      // A queued upload may have stored the photo's URL since this screen
      // loaded: the photo fields come from the stored profile unless the
      // photo changed here.
      Profile stored;
      try {
        stored = await repo.load();
      } catch (_) {
        stored = current;
      }
      var avatarPath = stored.avatarPath;
      var avatarUrl = stored.avatarUrl;
      ProfileAvatar? committed;
      if (pending != null) {
        committed = await _avatarService.commit(
          pending,
          replacedPath: stored.avatarPath,
        );
        _pendingAvatar = null;
        // The previous URL stays (other devices keep the previous photo)
        // until the new photo is uploaded.
        avatarPath = committed.localPath;
      } else if (_photoRemoved) {
        avatarPath = null;
        avatarUrl = null;
      }
      final next = current.copyWith(
        displayName: _displayNameController.text.trim(),
        fullName: () => _nullIfBlank(_fullNameController.text),
        phoneNumber: () => _nullIfBlank(_phoneController.text),
        gender: _draft.gender,
        dateOfBirth: () => _draft.dateOfBirth,
        avatarPath: () => avatarPath,
        avatarUrl: () => avatarUrl,
        baseCurrency: _draft.baseCurrency,
      );
      await repo.save(next);
      if (committed != null) await _avatarService.queueUpload(committed);
      if (pending == null && _photoRemoved && stored.hasAvatar) {
        // "Remove photo" takes effect now that it's saved; the cloud copy is
        // deleted when online.
        await _avatarService.remove(
          localPath: stored.avatarPath,
          cloudUrl: stored.avatarUrl,
        );
      }
      _photoRemoved = false;
      ref.invalidate(profileProvider);
      if (!mounted) return;
      setState(() => _draft = next);
      messenger.showSnackBar(
        aikoSnackBar(l10n.profileUpdated, tone: AikoSnackTone.success),
      );
    } catch (error) {
      debugPrint('[profile] save failed: $error');
      messenger.showSnackBar(
        aikoSnackBar(l10n.profileSaveFailed, tone: AikoSnackTone.error),
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
      source = await showAikoSheet<AvatarAction>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.l10n.profileChooseFromGallery),
                onTap: () => Navigator.pop(sheetContext, AvatarAction.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AikoColors.dangerRed,
                ),
                title: Text(
                  context.l10n.profileRemovePhoto,
                  style: TextStyle(
                    color: AikoStatusColors.of(sheetContext).dangerText,
                  ),
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
      // Only the draft changes; the saved photo is deleted on Save.
      final pending = _pendingAvatar;
      setState(() {
        _pendingAvatar = null;
        _photoRemoved = true;
        _draft = _draft.copyWith(avatarPath: () => null, avatarUrl: () => null);
      });
      if (pending != null) await _avatarService.discard(pending);
      return;
    }

    setState(() => _avatarBusy = true);
    try {
      final picked = await _avatarService.pick(source: ImageSource.gallery);
      if (!mounted) {
        if (picked != null) unawaited(_avatarService.discard(picked));
        return;
      }
      if (picked == null) {
        return;
      }
      final previous = _pendingAvatar;
      if (previous != null && previous.previewPath != picked.previewPath) {
        unawaited(_avatarService.discard(previous));
      }
      setState(() {
        _pendingAvatar = picked;
        _photoRemoved = false;
        _draft = _draft.copyWith(
          avatarPath: () => picked.previewPath,
          avatarUrl: () => null,
        );
      });
    } catch (error) {
      debugPrint('[profile] photo pick failed: $error');
      if (!mounted) return;
      showAikoSnackBar(
        context,
        context.l10n.profilePhotoUpdateFailed,
        tone: AikoSnackTone.error,
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
    if (picked == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(dateOfBirth: () => picked));
  }

  Future<void> _pickGender() async {
    final picked = await showAikoSheet<Gender>(
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
    final picked = await showAikoSheet<String>(
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

  String _genderLabel(Gender gender) => gender.label(context.l10n);

  String _formatDate(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }

  Future<void> _handleLinkGoogle() async {
    try {
      await _authRepository.linkGoogle();
      // The OAuth flow opens a browser; googleLinkedProvider flips once the
      // deep-link callback fires authStateChanges. Nothing to await here.
    } catch (error) {
      debugPrint('[profile] Google link failed: $error');
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authErrorMessage(
              error,
              l10n,
              fallback: l10n.profileGoogleConnectFailed,
              offline: l10n.guestLinkGoogleNeedsConnection,
            ),
          ),
        ),
      );
    }
  }

  /// Firebase has no in-app password change; it emails a reset link.
  Future<void> _handleChangePassword(String email) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authRepository.resetPassword(email);
      messenger.showSnackBar(
        aikoSnackBar(
          l10n.profilePasswordResetSent(email),
          tone: AikoSnackTone.success,
        ),
      );
    } catch (error) {
      debugPrint('[profile] password reset failed: $error');
      messenger.showSnackBar(
        aikoSnackBar(
          authErrorMessage(
            error,
            l10n,
            fallback: l10n.authResetFailed,
            offline: l10n.guestResetNeedsConnection,
          ),
          tone: AikoSnackTone.error,
        ),
      );
    }
  }

  /// Asks before logging out with changes that haven't uploaded yet: they
  /// wait on this device until this account signs in here again, which needs
  /// a connection.
  Future<bool> _confirmLogoutWithPendingChanges() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.guestLogoutPendingTitle),
        content: Text(context.l10n.guestLogoutPendingMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.guestLogoutAnyway),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleLogout() async {
    // The app may leave this screen as soon as the session ends (AikoApp
    // watches sign-outs), so hold on to the container, not this widget's ref.
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _isSigningOut = true);
    if (await _authRepository.hasPendingWrites()) {
      if (!mounted) return;
      if (!await _confirmLogoutWithPendingChanges()) {
        if (mounted) setState(() => _isSigningOut = false);
        return;
      }
    }
    try {
      await _authRepository.signOut();
      // Nothing of this user (data, Ask Aiko chat, LINE status) stays.
      invalidateUserData(container.invalidate);
      if (!mounted) return;
      // Same place a session that ends elsewhere goes: this device knows the
      // account, so the login screen.
      context.go('/auth');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.profileLogOutFailed)));
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.profileDeleteAccountQuestion),
        content: Text(context.l10n.profileDeleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
            ),
            child: Text(context.l10n.profileDeleteAccount),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _isDeleting = true);
    try {
      // While the server deletes every document, collection updates must not
      // reload (and re-create) the profile.
      await FirebaseSyncPause.during(_authRepository.deleteAccount);
      invalidateUserData(container.invalidate);
      if (!mounted) return;
      context.go('/');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      // The server only deletes after a sign-in in the last 5 minutes.
      final needsRecentSignIn =
          error is FirebaseFunctionsException &&
          error.code == 'failed-precondition';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is NeedsConnectionException
                ? context.l10n.guestDeleteNeedsConnection
                : needsRecentSignIn
                ? context.l10n.profileDeleteNeedsRecentSignIn
                : context.l10n.profileDeleteAccountFailed,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    final pending = _pendingAvatar;
    if (pending != null) unawaited(_avatarService.discard(pending));
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
    final loadedProfile = profileAsync.value;
    // Local-only builds and guests (cloud builds used without an account)
    // have no cloud account: no email, linking, password, log out or account
    // deletion. Guests get a way to sign in instead.
    final guest = GuestMode.isCurrent;
    final cloud = FirebaseBackend.isConfigured && !guest;
    final passwordEmail = _authRepository.hasPasswordSignIn()
        ? _authRepository.cachedSession()?.email ?? ''
        : '';
    final dangerText = AikoStatusColors.of(context).dangerText;

    return AikoDiscardChangesGuard(
      hasUnsavedChanges: loadedProfile != null && _isDirty(loadedProfile),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.profileTitle),
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
                    label: Text(context.l10n.save),
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
          error: (error, _) {
            debugPrint('[profile] load failed: $error');
            return AikoScreenState.error(
              title: context.l10n.profileLoadFailed,
              message: context.l10n.somethingWentWrong,
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(profileProvider),
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retry),
              ),
            );
          },
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
                    title: context.l10n.profilePersonalInformation,
                    icon: Icons.person_outline,
                    child: Column(
                      children: [
                        _buildField(
                          controller: _displayNameController,
                          label: context.l10n.profileDisplayName,
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _fullNameController,
                          label: context.l10n.profileFullName,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _phoneController,
                          label: context.l10n.profilePhoneNumber,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 8),
                        _buildChoiceRow(
                          label: context.l10n.profileGender,
                          value: _genderLabel(_draft.gender),
                          icon: Icons.wc_outlined,
                          onTap: _pickGender,
                        ),
                        const SizedBox(height: 8),
                        _buildChoiceRow(
                          label: context.l10n.profileDateOfBirth,
                          value: _draft.dateOfBirth != null
                              ? _formatDate(_draft.dateOfBirth!)
                              : context.l10n.notSet,
                          icon: Icons.cake_outlined,
                          onTap: _pickDateOfBirth,
                          trailing: _draft.dateOfBirth != null
                              ? IconButton(
                                  tooltip: context.l10n.clear,
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(
                                    () => _draft = _draft.copyWith(
                                      dateOfBirth: () => null,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        _buildChoiceRow(
                          label: context.l10n.profileBaseCurrency,
                          value: _currencyLabel(_draft.baseCurrency),
                          icon: Icons.attach_money_outlined,
                          onTap: _pickBaseCurrency,
                        ),
                        if (cloud) ...[
                          const SizedBox(height: 8),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: Icon(
                              Icons.email_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              context.l10n.profileEmailAddress,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              context.l10n.profileUserId,
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
                              tooltip: context.l10n.profileCopyUserId,
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
                                  SnackBar(
                                    content: Text(
                                      context.l10n.profileUserIdCopied,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (guest) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FinanceCard(
                      title: context.l10n.guestBackupTitle,
                      icon: Icons.cloud_outlined,
                      child: const GuestSignInTile(
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
                if (cloud) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FinanceCard(
                      title: context.l10n.profileConnectedApps,
                      icon: Icons.hub_outlined,
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              // Loading or unknown (offline, never seen on
                              // this device) offers neither state.
                              final status = ref
                                  .watch(lineLinkedProvider)
                                  .value;
                              final linked = status == LineLinkStatus.linked;
                              final known =
                                  status != null &&
                                  status != LineLinkStatus.unknown;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: AikoColors.primaryBlue,
                                ),
                                title: !known
                                    ? const Text(
                                        'LINE', // l10n-ignore: brand name
                                      )
                                    : Text(
                                        linked
                                            ? context.l10n.profileLineConnected
                                            : context.l10n.profileConnectLine,
                                      ),
                                subtitle: status == null
                                    ? null
                                    : Text(switch (status) {
                                        LineLinkStatus.linked =>
                                          context
                                              .l10n
                                              .profileLineConnectedSubtitle,
                                        LineLinkStatus.notLinked =>
                                          context
                                              .l10n
                                              .profileConnectLineSubtitle,
                                        LineLinkStatus.unknown =>
                                          context.l10n.netLineStatusUnknown,
                                      }),
                                trailing: linked
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AikoColors.successGreen,
                                      )
                                    : known
                                    ? const Icon(Icons.chevron_right)
                                    : null,
                                onTap: switch (status) {
                                  LineLinkStatus.notLinked => () async {
                                    await context.push('/connect-line');
                                    ref.invalidate(lineLinkedProvider);
                                  },
                                  // Check again (for example back online).
                                  LineLinkStatus.unknown =>
                                    () => ref.invalidate(lineLinkedProvider),
                                  _ => null,
                                },
                              );
                            },
                          ),
                          const Divider(height: 1),
                          Builder(
                            builder: (context) {
                              final linked =
                                  ref.watch(googleLinkedProvider).value ??
                                  false;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.g_mobiledata,
                                  color: AikoColors.primaryBlue,
                                ),
                                title: Text(
                                  linked
                                      ? context.l10n.profileGoogleConnected
                                      : context.l10n.profileConnectGoogle,
                                ),
                                subtitle: Text(
                                  linked
                                      ? context
                                            .l10n
                                            .profileGoogleConnectedSubtitle
                                      : context
                                            .l10n
                                            .profileConnectGoogleSubtitle,
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
                      title: context.l10n.profileAccountActions,
                      icon: Icons.manage_accounts_outlined,
                      child: Column(
                        children: [
                          // Only accounts that sign in with a password have one
                          // to change; Firebase emails a reset link for it.
                          if (passwordEmail.isNotEmpty) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.lock_outline,
                                color: AikoColors.primaryBlue,
                              ),
                              title: Text(context.l10n.profileChangePassword),
                              subtitle: Text(
                                context.l10n.profileChangePasswordSubtitle,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _handleChangePassword(passwordEmail),
                            ),
                            const Divider(height: 1),
                          ],
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.logout,
                              color: AikoColors.primaryBlue,
                            ),
                            title: Text(context.l10n.profileLogOut),
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
                      title: context.l10n.profileDangerZone,
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
                            title: Text(
                              context.l10n.profileDeleteAccount,
                              style: TextStyle(color: dangerText),
                            ),
                            subtitle: Text(
                              context.l10n.profileDeleteAccountSubtitle,
                              style: TextStyle(color: dangerText),
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
              ],
            );
          },
        ),
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
      textCapitalization: keyboardType == TextInputType.phone
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
    final child = CachedAvatar(
      localPath: _draft.avatarPath,
      cloudUrl: _draft.avatarUrl,
      fallback: _initialsAvatar(displayName),
    );
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
