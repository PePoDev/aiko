import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categoriesAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (error, stack) => AikoScreenState.error(
          title: 'Categories are unavailable',
          message: 'Aiko could not load your categories right now.',
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const AikoScreenState.empty(
              title: 'No categories yet',
              message:
                  'Create categories to organize transactions and budgets.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              for (final category in categories) ...[
                FinanceCard(
                  title: category.name,
                  icon: Icons.category_outlined,
                  accentColor: _accentFor(category),
                  child: Text(
                    '${category.group.name} - ${category.budgetEnabled ? 'Budget enabled' : 'Budget off'}',
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  Color _accentFor(Category category) {
    return switch (category.type) {
      CategoryType.income => AikoColors.successGreen,
      CategoryType.expense => AikoColors.warningOrange,
      CategoryType.transfer => AikoColors.deepBlue,
      CategoryType.investment => AikoColors.analyticsTeal,
      CategoryType.tax => AikoColors.premiumPurple,
      _ => AikoColors.primaryBlue,
    };
  }
}
