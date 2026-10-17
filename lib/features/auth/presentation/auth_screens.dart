import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/user_session.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/aiko_idea_widgets.dart';
import '../../../theme/aiko_colors.dart';
import '../../onboarding/application/complete_onboarding.dart';
import '../data/auth_repository.dart';
import 'auth_error_message.dart';

/// One slide of the intro carousel.
class _IntroPage {
  const _IntroPage({
    required this.image,
    required this.title,
    required this.body,
  });

  final String image;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) body;
}

String _hiTitle(AppLocalizations l10n) => l10n.introHiTitle;
String _hiBody(AppLocalizations l10n) => l10n.introHiBody;
String _trackTitle(AppLocalizations l10n) => l10n.introTrackTitle;
String _trackBody(AppLocalizations l10n) => l10n.introTrackBody;
String _insightsTitle(AppLocalizations l10n) => l10n.introInsightsTitle;
String _insightsBody(AppLocalizations l10n) => l10n.introInsightsBody;
String _goalsTitle(AppLocalizations l10n) => l10n.introGoalsTitle;
String _goalsBody(AppLocalizations l10n) => l10n.introGoalsBody;
String _startTitle(AppLocalizations l10n) => l10n.introStartTitle;
String _startBody(AppLocalizations l10n) => l10n.introStartBody;

const _introPages = <_IntroPage>[
  _IntroPage(
    image: 'assets/images/aiko/aiko_welcome.png',
    title: _hiTitle,
    body: _hiBody,
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_happy.png',
    title: _trackTitle,
    body: _trackBody,
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_thinking.png',
    title: _insightsTitle,
    body: _insightsBody,
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_encouraging.png',
    title: _goalsTitle,
    body: _goalsBody,
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_celebrating.png',
    title: _startTitle,
    body: _startBody,
  ),
];

/// Starts using a cloud build without an account ([AuthRepository.
/// continueAsGuest]): records stay on this device, offline included, until
/// the user signs in. Guests get the same first-run Cash and Bank accounts
/// as local-only builds.
Future<void> _continueWithoutAccount(
  BuildContext context,
  AuthRepository authRepository,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    await authRepository.continueAsGuest();
  } catch (error) {
    // Still a guest for this run; the next launch shows Welcome again.
    debugPrint('[auth] guest mode not stored: $error');
  }
  try {
    await completeOnboarding(
      accountRepository: container.read(accountRepositoryProvider),
      profileRepository: container.read(profileRepositoryProvider),
    );
  } catch (error) {
    debugPrint('[auth] guest defaults not seeded: $error');
  }
  invalidateUserData(container.invalidate);
  if (!context.mounted) return;
  context.go('/home');
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  var _page = 0;
  var _startingAsGuest = false;

  Future<void> _startAsGuest() async {
    setState(() => _startingAsGuest = true);
    await _continueWithoutAccount(context, AuthRepository());
    if (mounted) setState(() => _startingAsGuest = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _introPages.length - 1;

  void _next() {
    if (_isLast) {
      context.go('/auth');
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: AikoSparkleBackdrop(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: clampIdeaWidth(context)),
              child: Column(
                children: [
                  // Skip — hidden on the final slide.
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        opacity: _isLast ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: _isLast ? null : () => context.go('/auth'),
                          child: Text(context.l10n.introSkip),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _introPages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, index) => _IntroSlide(
                        page: _introPages[index],
                        controller: _controller,
                        index: index,
                      ),
                    ),
                  ),
                  _Dots(count: _introPages.length, active: _page),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 4),
                    child: AikoPrimaryButton(
                      label: _isLast
                          ? context.l10n.introGetStarted
                          : context.l10n.introNext,
                      onPressed: _startingAsGuest ? null : _next,
                    ),
                  ),
                  // No account needed (and no connection): the app runs on
                  // this device until the user signs in.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                    child: TextButton(
                      onPressed: _startingAsGuest ? null : _startAsGuest,
                      child: Text(context.l10n.guestContinueWithoutAccount),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single slide: image scales/fades with the swipe offset for motion.
class _IntroSlide extends StatelessWidget {
  const _IntroSlide({
    required this.page,
    required this.controller,
    required this.index,
  });

  final _IntroPage page;
  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 720;
    final imageSize = compact ? 180.0 : 240.0;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // delta is 0 when this page is centered, ±1 at neighbours.
        final pageValue =
            controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? index.toDouble()
            : index.toDouble();
        final delta = (pageValue - index).abs().clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - delta * 0.6,
          child: Transform.scale(scale: 1 - delta * 0.12, child: child),
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (index == 0) ...[
              const AikoWordmark(size: 52),
              const SizedBox(height: 24),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AikoColors.primaryBlue.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  page.image,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              page.title(context.l10n),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              page.body(context.l10n),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AikoColors.primaryBlue
                : colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({AuthRepository? authRepository, super.key})
    : _authRepository = authRepository;

  final AuthRepository? _authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository _authRepository;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;
  var _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authRepository = widget._authRepository ?? AuthRepository();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows why signing in, signing up or a password reset failed. Without a
  /// connection, sign-in and sign-up say the app can be used without an
  /// account meanwhile.
  void _showError(
    Object error, {
    required String Function(AppLocalizations l10n) fallback,
    String Function(AppLocalizations l10n) offline = _signInNeedsConnection,
  }) {
    if (!mounted) return;
    final l10n = context.l10n;
    _showMessage(
      authErrorMessage(
        error,
        l10n,
        fallback: fallback(l10n),
        offline: offline(l10n),
      ),
    );
  }

  static String _signInNeedsConnection(AppLocalizations l10n) =>
      l10n.guestSignInNeedsConnection;

  /// Whether a sign-in should get the first-run Cash and Bank accounts: only
  /// a brand-new account (sign-up, or a first Google sign-in). On sign-in the
  /// local store is still empty (remote accounts haven't synced down yet), so
  /// seeding would duplicate an existing user's real accounts; and a guest
  /// who signs up keeps the accounts they already made.
  static bool _seedsDefaultAccounts(AuthSession session) =>
      session.isNewUser && session.claimedRecords == 0;

  Future<void> _routeAfterAuth({bool seedDefaults = false}) async {
    final container = ProviderScope.containerOf(context);
    if (seedDefaults) {
      await completeOnboarding(
        accountRepository: container.read(accountRepositoryProvider),
        profileRepository: container.read(profileRepositoryProvider),
      );
    }
    // Nothing from a previous user (data, Ask Aiko chat, LINE status) stays.
    invalidateUserData(container.invalidate);
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(context.l10n.authEnterEmailPassword);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authRepository.signIn(email: email, password: password);
      if (!mounted) return;
      await _routeAfterAuth();
    } catch (error) {
      _showError(error, fallback: (l10n) => l10n.authSignInFailed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(context.l10n.authEnterEmailForReset);
      return;
    }

    try {
      await _authRepository.resetPassword(email);
      if (!mounted) return;
      _showMessage(context.l10n.authResetEmailSent);
    } catch (error) {
      _showError(
        error,
        fallback: (l10n) => l10n.authResetFailed,
        offline: (l10n) => l10n.guestResetNeedsConnection,
      );
    }
  }

  Future<void> _handleContinueWithoutAccount() async {
    setState(() => _isSubmitting = true);
    await _continueWithoutAccount(context, _authRepository);
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSubmitting = true);
    try {
      final session = await _authRepository.signInWithGoogle();
      if (!mounted) return;
      if (session != null) {
        await _routeAfterAuth(seedDefaults: _seedsDefaultAccounts(session));
      }
      // A null session means the user dismissed the native picker, or (on web)
      // the page redirected away — either way there is nothing more to do here.
    } catch (error) {
      _showError(error, fallback: (l10n) => l10n.authGoogleFailed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(context.l10n.authEnterEmailPassword);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final session = await _authRepository.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;

      if (_authRepository.hasActiveSession()) {
        await _routeAfterAuth(seedDefaults: _seedsDefaultAccounts(session));
      } else {
        _showMessage(context.l10n.authAccountCreatedCheckEmail);
      }
    } catch (error) {
      _showError(error, fallback: (l10n) => l10n.authSignUpFailed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: clampIdeaWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              children: [
                const Center(child: AikoWordmark(size: 50)),
                const SizedBox(height: 48),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 46,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: AikoColors.deepBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.authWelcomeBack,
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.authLogInToContinue,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                // Lets password managers fill and offer to save the pair.
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: context.l10n.authEmail,
                          hintText: 'name@email.com', // l10n-ignore
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        autocorrect: false,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: context.l10n.authPassword,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? context.l10n.authShowPassword
                                : context.l10n.authHidePassword,
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        enabled: !_isSubmitting,
                        onSubmitted: (_) => _handleSignIn(),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _handleResetPassword,
                    child: Text(context.l10n.authForgotPassword),
                  ),
                ),
                const SizedBox(height: 22),
                AikoPrimaryButton(
                  label: _isSubmitting
                      ? context.l10n.authLoggingIn
                      : context.l10n.authLogIn,
                  onPressed: _isSubmitting ? null : _handleSignIn,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.authOrContinueWith,
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                _SocialButton(
                  icon: Icons.g_mobiledata,
                  label: context.l10n.authContinueWithGoogle,
                  onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                ),
                // Apple sign-in removed per request.
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      context.l10n.authNoAccount,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : _handleSignUp,
                      child: Text(context.l10n.authSignUp),
                    ),
                  ],
                ),
                // Also the way back for a guest who came here to sign in.
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : _handleContinueWithoutAccount,
                    child: Text(context.l10n.guestContinueWithoutAccount),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
