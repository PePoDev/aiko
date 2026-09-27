import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/aiko_idea_widgets.dart';
import '../../../theme/aiko_colors.dart';
import '../../onboarding/application/complete_onboarding.dart';
import '../data/auth_repository.dart';

/// One slide of the intro carousel.
class _IntroPage {
  const _IntroPage({
    required this.image,
    required this.title,
    required this.body,
  });

  final String image;
  final String title;
  final String body;
}

const _introPages = <_IntroPage>[
  _IntroPage(
    image: 'assets/images/aiko/aiko_welcome.png',
    title: "Hi, I'm Aiko 👋",
    body:
        'Your calm finance companion — here to help you understand your money '
        'without the stress or the judgment.',
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_happy.png',
    title: 'Track it all in one place',
    body:
        'Log income, expenses, and transfers across every account. I keep the '
        'numbers tidy so you don\'t have to.',
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_thinking.png',
    title: 'Insights that make sense',
    body:
        'Spending trends, budget pace, and friendly nudges — so you always '
        'know where you stand this month.',
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_encouraging.png',
    title: 'Reach your goals',
    body:
        'Set targets, watch your progress, and let me map a realistic plan to '
        'get you there.',
  ),
  _IntroPage(
    image: 'assets/images/aiko/aiko_celebrating.png',
    title: "Let's get started",
    body: 'Your data stays private and works offline. Ready whenever you are.',
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  var _page = 0;

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
                          child: const Text('Skip'),
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
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                    child: AikoPrimaryButton(
                      label: _isLast ? 'Get Started' : 'Next',
                      onPressed: _next,
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
              page.title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              page.body,
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

  // [seedDefaults] only on brand-new sign-up. On sign-in the local store is
  // still empty (remote accounts haven't synced down yet), so seeding would
  // duplicate an existing user's real accounts. ponytail: signup-only gate;
  // if Google ever needs first-run defaults, detect new users at that callsite.
  Future<void> _routeAfterAuth({bool seedDefaults = false}) async {
    final container = ProviderScope.containerOf(context);
    if (seedDefaults) {
      await completeOnboarding(
        accountRepository: container.read(accountRepositoryProvider),
        profileRepository: container.read(profileRepositoryProvider),
      );
    }
    container.invalidate(profileProvider);
    container.invalidate(accountsProvider);
    container.invalidate(transactionsProvider);
    container.invalidate(categoriesProvider);
    container.invalidate(categoryGroupsProvider);
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authRepository.signIn(email: email, password: password);
      if (!mounted) return;
      await _routeAfterAuth();
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Authentication failed. Please try again.');
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email first to reset password.');
      return;
    }

    try {
      await _authRepository.resetPassword(email);
      if (!mounted) return;
      _showMessage('Reset email sent. Check your inbox.');
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Authentication failed. Please try again.');
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to reset password right now.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSubmitting = true);
    try {
      final session = await _authRepository.signInWithGoogle();
      if (!mounted) return;
      if (session != null) {
        await _routeAfterAuth();
      }
      // A null session means the user dismissed the native picker, or (on web)
      // the page redirected away — either way there is nothing more to do here.
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Authentication failed. Please try again.');
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to sign in with Google right now.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authRepository.signUp(email: email, password: password);
      if (!mounted) return;

      if (_authRepository.hasActiveSession()) {
        await _routeAfterAuth(seedDefaults: true);
      } else {
        _showMessage('Account created. Check your email, then sign in.');
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Authentication failed. Please try again.');
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to create account right now.');
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
                            'Welcome back!',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log in to continue.',
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
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'name@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _handleResetPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 22),
                AikoPrimaryButton(
                  label: _isSubmitting ? 'Logging in...' : 'Log In',
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
                            'or continue with',
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
                  label: 'Continue with Google',
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
                      "Don't have an account?",
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : _handleSignUp,
                      child: const Text('Sign up'),
                    ),
                  ],
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
