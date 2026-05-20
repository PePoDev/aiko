import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthenticatedShell extends StatelessWidget {
  const AuthenticatedShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
        onDestinationSelected: (index) => context.go(_locationFor(index)),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Budget',
          ),
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Aiko',
          ),
        ],
      ),
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/transactions')) {
      return 0;
    }
    if (location.startsWith('/budget')) {
      return 1;
    }
    if (location.startsWith('/insights')) {
      return 3;
    }
    if (location.startsWith('/aiko')) {
      return 4;
    }
    return 2;
  }

  String _locationFor(int index) {
    return switch (index) {
      0 => '/transactions',
      1 => '/budget',
      2 => '/home',
      3 => '/insights',
      4 => '/aiko',
      _ => '/home',
    };
  }
}
