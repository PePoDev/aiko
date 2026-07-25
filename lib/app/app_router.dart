import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/accounts_screen.dart';
import '../features/accounts/presentation/account_form/account_form_screen.dart';
import '../features/accounts/domain/account.dart';
import '../features/aiko_assistant/presentation/aiko_assistant_screen.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/categories/presentation/category_management_screen.dart';
import '../features/calculators/presentation/calculator_library_screen.dart';
import '../features/dashboard/presentation/home_dashboard_screen.dart';
import '../features/export/presentation/export_screen.dart';

import '../features/learning_hub/presentation/learning_hub_screen.dart';
import '../features/overview/presentation/finance_detail_screens.dart';
import '../features/investments/domain/investment_holding.dart';
import '../features/investments/presentation/investments_screen.dart';
import '../features/settings/presentation/connect_line_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/transactions/presentation/transaction_list_screen.dart';
import '../features/transactions/presentation/transaction_rules_screen.dart';
import '../features/transaction_capture/transaction_capture_screen.dart';
import '../features/travel_mode/presentation/travel_mode_screen.dart';
import '../shared/widgets/screen_states.dart';
import 'authenticated_shell.dart';

Page<void> _fadePage(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

GoRouter createAikoRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AuthenticatedShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                _fadePage(context, state, const HomeDashboardScreen()),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsCenterScreen(),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (context, state) =>
                _fadePage(context, state, const TransactionListScreen()),
          ),
          GoRoute(
            path: '/transaction-rules',
            builder: (context, state) => const TransactionRulesScreen(),
          ),
          GoRoute(
            path: '/transaction-capture',
            builder: (context, state) => const TransactionCaptureScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoryManagementScreen(),
          ),
          // Planning sub-routes live under Settings and delegate to the
          // existing detail screens so data wiring stays shared.
          GoRoute(
            path: '/settings/safe-to-spend',
            builder: (context, state) => const SafeToSpendScreen(),
          ),
          GoRoute(
            path: '/settings/cash-flow',
            builder: (context, state) => const CashFlowOverviewScreen(),
          ),
          GoRoute(
            path: '/settings/cash-flow-sankey',
            builder: (context, state) => const CashFlowSankeyScreen(),
          ),

          GoRoute(
            path: '/settings/chance-of-success',
            builder: (context, state) {
              final extra = state.extra;
              return ChanceOfSuccessScreen(
                goal: extra is Account ? extra : null,
              );
            },
          ),
          GoRoute(
            path: '/reports/monthly',
            builder: (context, state) => const MonthlyReportScreen(),
          ),
          GoRoute(
            path: '/export',
            builder: (context, state) => const ExportScreen(),
          ),
          GoRoute(
            path: '/aiko',
            pageBuilder: (context, state) =>
                _fadePage(context, state, const AikoAssistantScreen()),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/account-form',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is Account) {
                return AccountFormScreen(account: extra);
              }
              return const AccountFormScreen();
            },
          ),
          GoRoute(
            path: '/calculators',
            builder: (context, state) => const CalculatorLibraryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/connect-line',
            builder: (context, state) => const ConnectLineScreen(),
          ),

          GoRoute(
            path: '/portfolio',
            builder: (context, state) => const InvestmentsScreen(),
          ),
          GoRoute(
            path: '/portfolio/allocation',
            builder: (context, state) => const AssetAllocationScreen(),
          ),
          GoRoute(
            path: '/portfolio/holding',
            builder: (context, state) {
              final extra = state.extra;
              return HoldingDetailScreen(
                holding: extra is InvestmentHolding ? extra : null,
              );
            },
          ),
          GoRoute(
            path: '/learning-hub',
            builder: (context, state) => const LearningHubScreen(),
          ),
          GoRoute(
            path: '/travel-mode',
            builder: (context, state) => const TravelModeScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Aiko')),
      body: AikoScreenState.error(
        title: 'Route not found',
        message: 'Aiko could not open ${state.uri}.',
      ),
    ),
  );
}
