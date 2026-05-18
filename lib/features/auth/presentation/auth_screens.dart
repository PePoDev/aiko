import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
                onPressed: () => context.go('/onboarding'),
              ),
              TextButton(
                onPressed: () => context.go('/auth'),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiko sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TextField(
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: 'Continue securely',
              icon: Icons.lock_open,
              onPressed: () => context.go('/home'),
            ),
            TextButton(onPressed: () {}, child: const Text('Reset password')),
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
