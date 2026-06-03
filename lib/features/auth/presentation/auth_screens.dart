import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/aiko_idea_widgets.dart';
import '../../../theme/aiko_colors.dart';
import '../data/auth_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeReturningUser();
    });
  }

  Future<void> _routeReturningUser() async {
    if (_authRepository.hasActiveSession()) {
      _authRepository.restoreSessionInBackground();
      if (!mounted) return;
      context.go('/home');
      return;
    }

    await _authRepository.restoreSession();
    if (!mounted) return;

    if (_authRepository.hasActiveSession()) {
      context.go('/home');
      return;
    }

    if (await _authRepository.hasKnownAccount()) {
      if (!mounted) return;
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AikoColors.white,
      body: SafeArea(
        child: AikoSparkleBackdrop(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: clampIdeaWidth(context)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                    const Center(child: AikoWordmark(size: 60)),
                    const SizedBox(height: 4),
                    Text(
                      'Your Personal\nFinance Companion',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: AikoColors.neutralInk,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const Spacer(),
                    const Center(
                      child: AikoCharacterImage(
                        size: 214,
                        borderRadius: 44,
                        semanticLabel: 'Aiko holding a gold coin',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Smarter insights. Better habits.\nBrighter future.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AikoColors.deepBlue,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    AikoPrimaryButton(
                      label: 'Get Started',
                      onPressed: () => context.push('/onboarding'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = 'name@email.com';
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
      context.go('/home');
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
    setState(() => _isSubmitting = true);
    try {
      await _authRepository.signInWithGoogle();
      if (!mounted) return;

      await _authRepository.restoreSession();
      if (!mounted) return;
      if (_authRepository.hasActiveSession()) {
        context.go('/home');
      } else {
        _showMessage(
          'Continue Google sign-in in browser, then return to Aiko.',
        );
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
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
        context.go('/home');
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

    return Scaffold(
      backgroundColor: AikoColors.white,
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
                              color: AikoColors.darkNavy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log in to continue.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AikoColors.mutedText,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or continue with',
                        style: textTheme.labelMedium?.copyWith(
                          color: AikoColors.mutedText,
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
                const SizedBox(height: 10),
                _SocialButton(
                  icon: Icons.apple,
                  label: 'Continue with Apple',
                  onPressed: _isSubmitting
                      ? null
                      : () => _showMessage('Apple sign-in is coming soon.'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: textTheme.bodySmall?.copyWith(
                        color: AikoColors.mutedText,
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
          foregroundColor: AikoColors.neutralInk,
          side: const BorderSide(color: AikoColors.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
