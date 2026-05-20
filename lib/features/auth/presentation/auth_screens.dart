import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';

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
    await _authRepository.restoreSession();
    if (!mounted) {
      return;
    }

    if (_authRepository.hasActiveSession()) {
      context.go('/home');
      return;
    }

    if (await _authRepository.hasKnownAccount()) {
      if (!mounted) {
        return;
      }
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Semantics(
                header: true,
                child: Text(
                  'Aiko',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Grow wealth with Aiko.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const FinanceCard(
                title: 'Meet your AI financial companion',
                icon: Icons.auto_awesome,
                accentColor: AikoColors.premiumPurple,
                prominent: true,
                child: Text(
                  'Track money, plan goals, and get friendly guidance without judgment.',
                ),
              ),
              const Spacer(),
              PrimaryActionButton(
                label: 'Get started',
                onPressed: () => context.push('/onboarding'),
              ),
            ],
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
      if (!mounted) {
        return;
      }
      context.go('/home');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }

      await _authRepository.restoreSession();
      if (!mounted) {
        return;
      }
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
      if (!mounted) {
        return;
      }

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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiko sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const FinanceCard(
            title: 'Welcome back',
            icon: Icons.lock_outline,
            child: Text('Sign in to sync your private financial workspace.'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            enabled: !_isSubmitting,
            onSubmitted: (_) => _handleSignIn(),
          ),
          const SizedBox(height: 20),
          PrimaryActionButton(
            label: _isSubmitting ? 'Signing in...' : 'Continue securely',
            icon: Icons.lock_open,
            onPressed: _isSubmitting ? null : _handleSignIn,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _handleSignUp,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(
              _isSubmitting ? 'Creating account...' : 'Create account',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _handleGoogleSignIn,
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _handleResetPassword,
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
  }
}

class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AikoScreenState.locked(key: const Key('locked-state')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home'),
        icon: const Icon(Icons.lock_open),
        label: const Text('Unlock'),
      ),
    );
  }
}
