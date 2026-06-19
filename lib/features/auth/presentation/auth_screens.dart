import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/aiko_idea_widgets.dart';
import '../../../theme/aiko_colors.dart';
import '../../onboarding/application/complete_onboarding.dart';
import '../../settings/domain/profile.dart';
import '../data/auth_repository.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 720;
    final imageSize = compact ? 140.0 : 190.0;
    final sectionGap = compact ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: AikoSparkleBackdrop(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: clampIdeaWidth(context)),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AikoWordmark(size: 56)),
                          const SizedBox(height: 6),
                          Text(
                            'Your personal\nfinance companion',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          Center(
                            child: AikoCharacterImage(
                              size: imageSize,
                              borderRadius: compact ? 32 : 40,
                              semanticLabel: 'Aiko waving hello',
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          Text(
                            "Hi, I'm Aiko! I'm your AI finance assistant — here to help you understand your money, build better habits, and reach your goals.",
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Column(
                              children: [
                                AikoFeatureRow(
                                  icon: Icons.psychology_alt_outlined,
                                  label: 'Personalized insights',
                                ),
                                SizedBox(height: 14),
                                AikoFeatureRow(
                                  icon: Icons.savings_outlined,
                                  label: 'Smart budgeting',
                                ),
                                SizedBox(height: 14),
                                AikoFeatureRow(
                                  icon: Icons.flag_outlined,
                                  label: 'Goal tracking',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                    child: AikoPrimaryButton(
                      label: 'Get Started',
                      onPressed: () => context.go('/auth'),
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
  StreamSubscription<AuthState>? _authSubscription;
  var _isSubmitting = false;
  var _isGoogleSignInPending = false;

  @override
  void initState() {
    super.initState();
    _authRepository = widget._authRepository ?? AuthRepository();
    _authSubscription = _authRepository.authStateChanges().listen((state) {
      if (state.event == AuthChangeEvent.signedIn && _isGoogleSignInPending) {
        unawaited(_completeGoogleSignIn());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _routeAfterAuth() async {
    final container = ProviderScope.containerOf(context);
    final profileRepo = container.read(profileRepositoryProvider);
    final profile = await profileRepo.load();
    // Onboarding is gone: on first entry just seed the default accounts and
    // mark the profile completed, then go straight to the dashboard.
    if (profile.onboardingStatus != OnboardingStatus.completed) {
      await completeOnboarding(
        accountRepository: container.read(accountRepositoryProvider),
        profileRepository: profileRepo,
      );
    }
    container.invalidate(profileProvider);
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
    } on AuthException catch (error) {
      _showMessage(error.message);
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
    } on AuthException catch (error) {
      _showMessage(error.message);
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to reset password right now.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSubmitting = true;
      _isGoogleSignInPending = true;
    });
    try {
      final launched = await _authRepository.signInWithGoogle();
      if (!mounted) return;
      if (launched) {
        _showMessage(
          'Continue Google sign-in in browser, then return to Aiko.',
        );
        setState(() => _isSubmitting = false);
      } else {
        _isGoogleSignInPending = false;
        setState(() => _isSubmitting = false);
        _showMessage('Unable to open Google sign-in.');
      }
    } on AuthException catch (error) {
      _isGoogleSignInPending = false;
      _showMessage(error.message);
      if (mounted) setState(() => _isSubmitting = false);
    } on StateError catch (error) {
      _isGoogleSignInPending = false;
      _showMessage(error.message);
      if (mounted) setState(() => _isSubmitting = false);
    } catch (_) {
      _isGoogleSignInPending = false;
      _showMessage('Unable to sign in with Google right now.');
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completeGoogleSignIn() async {
    if (!mounted) return;
    _isGoogleSignInPending = false;
    setState(() => _isSubmitting = true);
    try {
      await _authRepository.restoreSession();
      if (!mounted) return;
      if (_authRepository.hasActiveSession()) {
        await _routeAfterAuth();
      } else {
        _showMessage('Google sign-in completed, but no session was found.');
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to finish Google sign-in right now.');
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
        await _routeAfterAuth();
      } else {
        _showMessage('Account created. Check your email, then sign in.');
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
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
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
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
