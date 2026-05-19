import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounting/presentation/accounting_screen.dart';
import '../features/aiko_assistant/presentation/aiko_assistant_screen.dart';
import '../features/aiko_character/presentation/aiko_character_settings_screen.dart';
import '../features/aiko_optimize/presentation/aiko_optimize_screen.dart';
import '../features/assets/presentation/assets_net_worth_screen.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/budgets/presentation/budget_overview_screen.dart';
import '../features/bills/presentation/bills_screen.dart';
import '../features/categories/presentation/category_management_screen.dart';
import '../features/calculators/presentation/calculator_library_screen.dart';
import '../features/credit_cards/presentation/credit_card_overview_screen.dart';
import '../features/export/presentation/export_screen.dart';
import '../features/dashboard/presentation/home_dashboard_screen.dart';
import '../features/debt_loans/presentation/debt_payoff_plan_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/goals/presentation/goals_overview_screen.dart';
import '../features/import_export/presentation/import_export_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/learning_hub/presentation/learning_hub_screen.dart';
import '../features/monetization/presentation/plan_matrix_screen.dart';
import '../features/onboarding/presentation/onboarding_screens.dart';
import '../features/portfolio/presentation/portfolio_screen.dart';
import '../features/reports/presentation/aiko_review_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/tax_center/presentation/tax_center_screen.dart';
import '../features/transactions/presentation/transaction_list_screen.dart';
import '../features/transactions/presentation/transaction_rules_screen.dart';
import '../features/travel_mode/presentation/travel_mode_screen.dart';
import 'authenticated_shell.dart';

GoRouter createAikoRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/locked',
        builder: (context, state) => const LockedScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AuthenticatedShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeDashboardScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionListScreen(),
          ),
          GoRoute(
            path: '/transaction-rules',
            builder: (context, state) => const TransactionRulesScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoryManagementScreen(),
          ),
          GoRoute(
            path: '/budget',
            builder: (context, state) => const BudgetOverviewScreen(),
          ),
          GoRoute(
            path: '/goals',
            builder: (context, state) => const GoalsOverviewScreen(),
          ),
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsScreen(),
          ),
          GoRoute(
            path: '/aiko-review',
            builder: (context, state) => const AikoReviewScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/export',
            builder: (context, state) => const ExportScreen(),
          ),
          GoRoute(
            path: '/aiko',
            builder: (context, state) => const AikoAssistantScreen(),
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
            path: '/aiko-character',
            builder: (context, state) => const AikoCharacterSettingsScreen(),
          ),
          GoRoute(
            path: '/import-export-backup',
            builder: (context, state) => const ImportExportScreen(),
          ),
          GoRoute(
            path: '/bills-subscriptions',
            builder: (context, state) => const BillsScreen(),
          ),
          GoRoute(
            path: '/notification-settings',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: '/credit-cards',
            builder: (context, state) => const CreditCardOverviewScreen(),
          ),
          GoRoute(
            path: '/debt-loans',
            builder: (context, state) => const DebtPayoffPlanScreen(),
          ),
          GoRoute(
            path: '/portfolio',
            builder: (context, state) => const PortfolioScreen(),
          ),
          GoRoute(
            path: '/assets-net-worth',
            builder: (context, state) => const AssetsNetWorthScreen(),
          ),
          GoRoute(
            path: '/tax-center',
            builder: (context, state) => const TaxCenterScreen(),
          ),
          GoRoute(
            path: '/accounting',
            builder: (context, state) => const AccountingScreen(),
          ),
          GoRoute(
            path: '/learning-hub',
            builder: (context, state) => const LearningHubScreen(),
          ),
          GoRoute(
            path: '/travel-mode',
            builder: (context, state) => const TravelModeScreen(),
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesScreen(),
          ),
          GoRoute(
            path: '/aiko-optimize',
            builder: (context, state) => const AikoOptimizeScreen(),
          ),
          GoRoute(
            path: '/subscription-plan',
            builder: (context, state) => const PlanMatrixScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Aiko')),
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
}
