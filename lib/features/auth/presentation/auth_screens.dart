import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
                child: Text(
                  'Track money, plan goals, and get friendly guidance without judgment.',
                ),
              ),
              const Spacer(),
              PrimaryActionButton(
                label: 'Get started',
                onPressed: () => context.push('/onboarding'),
              ),
              TextButton(
                onPressed: () => context.push('/auth'),
                child: const Text('I already have an account'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiko sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onPressed: _isSubmitting ? null : () => context.push('/signup'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Sign up'),
            ),
            TextButton(
              onPressed: _isSubmitting ? null : _handleResetPassword,
              child: const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
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
        context.go('/auth');
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
      appBar: AppBar(title: const Text('Create your Aiko account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onSubmitted: (_) => _handleSignUp(),
            ),
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: _isSubmitting ? 'Creating account...' : 'Create account',
              icon: Icons.person_add_alt_1,
              onPressed: _isSubmitting ? null : _handleSignUp,
            ),
            TextButton(
              onPressed: _isSubmitting ? null : () => context.push('/auth'),
              child: const Text('I already have an account'),
            ),
          ],
        ),
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
