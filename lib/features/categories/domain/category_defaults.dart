import 'category.dart';

/// Fixed UUIDs for the 30 built-in system categories.
///
/// These ids are stable constants embedded in the SQL migration that inserts
/// the system category rows into Supabase with user_id = NULL. Any transaction
/// referencing one of these ids satisfies the foreign key without per-user
/// category rows. The UUIDs are intentionally patterned (c100… income,
/// c200… expense) to be recognisable in query logs.
abstract final class CategoryDefaults {
  // ── Income ──────────────────────────────────────────────────────────────
  static const String salaryId      = '00000000-0000-0000-c100-000000000001';
  static const String bonusId       = '00000000-0000-0000-c100-000000000002';
  static const String freelanceId   = '00000000-0000-0000-c100-000000000003';
  static const String businessId    = '00000000-0000-0000-c100-000000000004';
  static const String interestId    = '00000000-0000-0000-c100-000000000005';
  static const String dividendsId   = '00000000-0000-0000-c100-000000000006';
  static const String rentalId      = '00000000-0000-0000-c100-000000000007';
  static const String refundsId     = '00000000-0000-0000-c100-000000000008';
  static const String giftId        = '00000000-0000-0000-c100-000000000009';
  static const String otherIncomeId = '00000000-0000-0000-c100-00000000000a';

  // ── Expense ─────────────────────────────────────────────────────────────
  static const String groceriesId     = '00000000-0000-0000-c200-000000000001';
  static const String diningId        = '00000000-0000-0000-c200-000000000002';
  static const String coffeeId        = '00000000-0000-0000-c200-000000000003';
  static const String transportId     = '00000000-0000-0000-c200-000000000004';
  static const String fuelId          = '00000000-0000-0000-c200-000000000005';
  static const String rentId          = '00000000-0000-0000-c200-000000000006';
  static const String utilitiesId     = '00000000-0000-0000-c200-000000000007';
  static const String phoneId         = '00000000-0000-0000-c200-000000000008';
  static const String internetId      = '00000000-0000-0000-c200-000000000009';
  static const String subscriptionsId = '00000000-0000-0000-c200-00000000000a';
  static const String shoppingId      = '00000000-0000-0000-c200-00000000000b';
  static const String healthId        = '00000000-0000-0000-c200-00000000000c';
  static const String insuranceId     = '00000000-0000-0000-c200-00000000000d';
  static const String educationId     = '00000000-0000-0000-c200-00000000000e';
  static const String travelId        = '00000000-0000-0000-c200-00000000000f';
  static const String entertainmentId = '00000000-0000-0000-c200-000000000010';
  static const String feesId          = '00000000-0000-0000-c200-000000000011';
  static const String taxesId         = '00000000-0000-0000-c200-000000000012';
  static const String otherExpenseId  = '00000000-0000-0000-c200-000000000013';

  static const Set<String> allIds = {
    salaryId, bonusId, freelanceId, businessId, interestId,
    dividendsId, rentalId, refundsId, giftId, otherIncomeId,
    groceriesId, diningId, coffeeId, transportId, fuelId,
    rentId, utilitiesId, phoneId, internetId, subscriptionsId,
    shoppingId, healthId, insuranceId, educationId, travelId,
    entertainmentId, feesId, taxesId, otherExpenseId,
  };

  /// Maps old `default-*` slug ids (used before this migration) to the
  /// corresponding fixed UUID. Used during the one-time local cleanup that
  /// remaps legacy transaction category_ids on devices that had the old data.
  static const Map<String, String> legacySlugToUuid = {
    'default-income-salary':       salaryId,
    'default-income-bonus':        bonusId,
    'default-income-freelance':    freelanceId,
    'default-income-business':     businessId,
    'default-income-interest':     interestId,
    'default-income-dividends':    dividendsId,
    'default-income-rental':       rentalId,
    'default-income-refunds':      refundsId,
    'default-income-gift':         giftId,
    'default-income-other':        otherIncomeId,
    'default-expense-groceries':   groceriesId,
    'default-expense-dining':      diningId,
    'default-expense-coffee':      coffeeId,
    'default-expense-transport':   transportId,
    'default-expense-fuel':        fuelId,
    'default-expense-rent':        rentId,
    'default-expense-utilities':   utilitiesId,
    'default-expense-phone':       phoneId,
    'default-expense-internet':    internetId,
    'default-expense-subscriptions': subscriptionsId,
    'default-expense-shopping':    shoppingId,
    'default-expense-health':      healthId,
    'default-expense-insurance':   insuranceId,
    'default-expense-education':   educationId,
    'default-expense-travel':      travelId,
    'default-expense-entertainment': entertainmentId,
    'default-expense-fees':        feesId,
    'default-expense-taxes':       taxesId,
    'default-expense-other':       otherExpenseId,
  };

  /// The 30 system categories as domain objects. userId is empty because
  /// these are global — they belong to no user.
  static List<Category> get all => [
    ..._income,
    ..._expense,
  ];

  static final List<Category> _income = [
    _sys(id: salaryId,    name: 'Salary',    type: CategoryType.income, group: CategoryGroup.custom,     icon: 'salary',    color: '#22C55E'),
    _sys(id: bonusId,     name: 'Bonus',     type: CategoryType.income, group: CategoryGroup.custom,     icon: 'gift',      color: '#16A34A'),
    _sys(id: freelanceId, name: 'Freelance', type: CategoryType.income, group: CategoryGroup.business,   icon: 'work',      color: '#14B8A6'),
    _sys(id: businessId,  name: 'Business',  type: CategoryType.income, group: CategoryGroup.business,   icon: 'business',  color: '#0EA5E9'),
    _sys(id: interestId,  name: 'Interest',  type: CategoryType.income, group: CategoryGroup.savings,    icon: 'savings',   color: '#06B6D4'),
    _sys(id: dividendsId, name: 'Dividends', type: CategoryType.income, group: CategoryGroup.investment, icon: 'investment',color: '#8B5CF6'),
    _sys(id: rentalId,    name: 'Rental',    type: CategoryType.income, group: CategoryGroup.investment, icon: 'home',      color: '#6366F1'),
    _sys(id: refundsId,   name: 'Refunds',   type: CategoryType.income, group: CategoryGroup.custom,     icon: 'refund',    color: '#10B981'),
    _sys(id: giftId,      name: 'Gift',      type: CategoryType.income, group: CategoryGroup.custom,     icon: 'gift',      color: '#EC4899'),
    _sys(id: otherIncomeId, name: 'Other',   type: CategoryType.income, group: CategoryGroup.custom,     icon: 'category',  color: '#64748B'),
  ];

  static final List<Category> _expense = [
    _sys(id: groceriesId,    name: 'Groceries',     type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'groceries',     color: '#F97316'),
    _sys(id: diningId,       name: 'Dining',        type: CategoryType.expense, group: CategoryGroup.wants,     icon: 'dining',        color: '#EF4444'),
    _sys(id: coffeeId,       name: 'Coffee',        type: CategoryType.expense, group: CategoryGroup.wants,     icon: 'coffee',        color: '#8B5A2B'),
    _sys(id: transportId,    name: 'Transport',     type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'transport',     color: '#3B82F6'),
    _sys(id: fuelId,         name: 'Fuel',          type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'fuel',          color: '#2563EB'),
    _sys(id: rentId,         name: 'Rent',          type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'home',          color: '#7C3AED'),
    _sys(id: utilitiesId,    name: 'Utilities',     type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'utilities',     color: '#0EA5E9'),
    _sys(id: phoneId,        name: 'Phone',         type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'phone',         color: '#06B6D4'),
    _sys(id: internetId,     name: 'Internet',      type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'internet',      color: '#0284C7'),
    _sys(id: subscriptionsId,name: 'Subscriptions', type: CategoryType.expense, group: CategoryGroup.wants,     icon: 'subscriptions', color: '#A855F7'),
    _sys(id: shoppingId,     name: 'Shopping',      type: CategoryType.expense, group: CategoryGroup.wants,     icon: 'shopping',      color: '#EC4899'),
    _sys(id: healthId,       name: 'Health',        type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'health',        color: '#10B981'),
    _sys(id: insuranceId,    name: 'Insurance',     type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'insurance',     color: '#14B8A6'),
    _sys(id: educationId,    name: 'Education',     type: CategoryType.expense, group: CategoryGroup.needs,     icon: 'education',     color: '#F59E0B'),
    _sys(id: travelId,       name: 'Travel',        type: CategoryType.expense, group: CategoryGroup.wants,     icon: 'travel',        color: '#38BDF8'),
    _sys(id: entertainmentId,name: 'Entertainment', type: CategoryType.expense, group: CategoryGroup.wants,     icon: 'entertainment', color: '#F43F5E'),
    _sys(id: feesId,         name: 'Fees',          type: CategoryType.expense, group: CategoryGroup.custom,    icon: 'fee',           color: '#64748B'),
    _sys(id: taxesId,        name: 'Taxes',         type: CategoryType.expense, group: CategoryGroup.tax,       icon: 'tax',           color: '#DC2626'),
    _sys(id: otherExpenseId, name: 'Other',         type: CategoryType.expense, group: CategoryGroup.custom,    icon: 'category',      color: '#64748B'),
  ];

  static Category _sys({
    required String id,
    required String name,
    required CategoryType type,
    required CategoryGroup group,
    required String icon,
    required String color,
  }) {
    return Category(
      id: id,
      userId: '',
      name: name,
      type: type,
      group: group,
      icon: icon,
      color: color,
      budgetEnabled: type == CategoryType.expense,
    );
  }
}
