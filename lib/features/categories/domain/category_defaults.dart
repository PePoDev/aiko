import 'category.dart';

/// Fixed UUIDs for the 66 built-in system categories.
///
/// These ids are stable constants embedded in the SQL migration that inserts
/// the system category rows into Supabase with user_id = NULL. Any transaction
/// referencing one of these ids satisfies the foreign key without per-user
/// category rows. The UUIDs are intentionally patterned (c100… income,
/// c200… expense) to be recognisable in query logs.
abstract final class CategoryDefaults {
  // ── Income (…-c100-…) ───────────────────────────────────────────────────
  static const String salaryId = '00000000-0000-0000-c100-000000000001';
  static const String bonusId = '00000000-0000-0000-c100-000000000002';
  static const String freelanceId = '00000000-0000-0000-c100-000000000003';
  static const String businessId = '00000000-0000-0000-c100-000000000004';
  static const String interestId = '00000000-0000-0000-c100-000000000005';
  static const String dividendsId = '00000000-0000-0000-c100-000000000006';
  static const String rentalId = '00000000-0000-0000-c100-000000000007';
  static const String refundsId = '00000000-0000-0000-c100-000000000008';
  static const String giftId = '00000000-0000-0000-c100-000000000009';
  static const String otherIncomeId = '00000000-0000-0000-c100-00000000000a';
  static const String capitalGainsId = '00000000-0000-0000-c100-00000000000b';

  // ── Expense (…-c200-…) ──────────────────────────────────────────────────
  static const String groceriesId = '00000000-0000-0000-c200-000000000001';
  static const String diningId = '00000000-0000-0000-c200-000000000002';
  static const String coffeeId = '00000000-0000-0000-c200-000000000003';
  static const String transportId = '00000000-0000-0000-c200-000000000004';
  static const String fuelId = '00000000-0000-0000-c200-000000000005';
  static const String rentId = '00000000-0000-0000-c200-000000000006';
  static const String utilitiesId = '00000000-0000-0000-c200-000000000007';
  static const String phoneId = '00000000-0000-0000-c200-000000000008';
  static const String internetId = '00000000-0000-0000-c200-000000000009';
  static const String subscriptionsId = '00000000-0000-0000-c200-00000000000a';
  static const String shoppingId = '00000000-0000-0000-c200-00000000000b';
  static const String healthId = '00000000-0000-0000-c200-00000000000c';
  static const String insuranceId = '00000000-0000-0000-c200-00000000000d';
  static const String educationId = '00000000-0000-0000-c200-00000000000e';
  static const String travelId = '00000000-0000-0000-c200-00000000000f';
  static const String entertainmentId = '00000000-0000-0000-c200-000000000010';
  static const String feesId = '00000000-0000-0000-c200-000000000011';
  static const String taxesId = '00000000-0000-0000-c200-000000000012';
  static const String otherExpenseId = '00000000-0000-0000-c200-000000000013';
  static const String lunchId = '00000000-0000-0000-c200-000000000014';
  static const String dinnerId = '00000000-0000-0000-c200-000000000015';
  static const String dessertId = '00000000-0000-0000-c200-000000000016';
  static const String bubbleTeaId = '00000000-0000-0000-c200-000000000017';
  static const String drinksBarId = '00000000-0000-0000-c200-000000000018';
  static const String snacksId = '00000000-0000-0000-c200-000000000019';
  static const String taxiId = '00000000-0000-0000-c200-00000000001a';
  static const String parkingId = '00000000-0000-0000-c200-00000000001b';
  static const String vehicleMaintenanceId =
      '00000000-0000-0000-c200-00000000001c';
  static const String tollsId = '00000000-0000-0000-c200-00000000001d';
  static const String homeMaintenanceId =
      '00000000-0000-0000-c200-00000000001e';
  static const String furnitureId = '00000000-0000-0000-c200-00000000001f';
  static const String pharmacyId = '00000000-0000-0000-c200-000000000020';
  static const String dentalId = '00000000-0000-0000-c200-000000000021';
  static const String fitnessId = '00000000-0000-0000-c200-000000000022';
  static const String clothingId = '00000000-0000-0000-c200-000000000023';
  static const String electronicsId = '00000000-0000-0000-c200-000000000024';
  static const String personalCareId = '00000000-0000-0000-c200-000000000025';
  static const String moviesId = '00000000-0000-0000-c200-000000000026';
  static const String gamesId = '00000000-0000-0000-c200-000000000027';
  static const String musicId = '00000000-0000-0000-c200-000000000028';
  static const String concertsId = '00000000-0000-0000-c200-000000000029';
  static const String hobbiesId = '00000000-0000-0000-c200-00000000002a';
  static const String booksId = '00000000-0000-0000-c200-00000000002b';
  static const String coursesId = '00000000-0000-0000-c200-00000000002c';
  static const String flightsId = '00000000-0000-0000-c200-00000000002d';
  static const String accommodationId = '00000000-0000-0000-c200-00000000002e';
  static const String foreignFeesId = '00000000-0000-0000-c200-00000000002f';
  static const String giftsId = '00000000-0000-0000-c200-000000000030';
  static const String childcareId = '00000000-0000-0000-c200-000000000031';
  static const String petsId = '00000000-0000-0000-c200-000000000032';
  static const String donationsId = '00000000-0000-0000-c200-000000000033';
  static const String loanPaymentId = '00000000-0000-0000-c200-000000000034';
  static const String creditCardPaymentId =
      '00000000-0000-0000-c200-000000000035';
  static const String savingsContributionId =
      '00000000-0000-0000-c200-000000000036';
  // New additions from the design reference (pictures/system-category-defaults
  // round 2). Continue the c200… block.
  static const String foodDeliveryId = '00000000-0000-0000-c200-000000000037';
  static const String publicTransportId =
      '00000000-0000-0000-c200-000000000038';
  static const String waterId = '00000000-0000-0000-c200-000000000039';
  static const String electricityId = '00000000-0000-0000-c200-00000000003a';
  static const String homeLoanInterestId =
      '00000000-0000-0000-c200-00000000003b';
  static const String socialSecurityId = '00000000-0000-0000-c200-00000000003c';
  static const String jewelryId = '00000000-0000-0000-c200-00000000003d';
  static const String shoesId = '00000000-0000-0000-c200-00000000003e';
  static const String workshopId = '00000000-0000-0000-c200-00000000003f';
  static const String doctorId = '00000000-0000-0000-c200-000000000040';
  static const String medicineTreatmentId =
      '00000000-0000-0000-c200-000000000041';
  static const String lifeInsuranceId = '00000000-0000-0000-c200-000000000042';
  static const String gymBoxingId = '00000000-0000-0000-c200-000000000043';
  static const String fitnessClassId = '00000000-0000-0000-c200-000000000044';
  static const String fitnessEquipmentId =
      '00000000-0000-0000-c200-000000000045';
  static const String supplementsId = '00000000-0000-0000-c200-000000000046';

  static const Set<String> allIds = {
    // Income
    salaryId,
    bonusId,
    freelanceId,
    businessId,
    interestId,
    dividendsId,
    rentalId,
    refundsId,
    giftId,
    otherIncomeId,
    capitalGainsId,
    // Expense
    groceriesId,
    diningId,
    coffeeId,
    transportId,
    fuelId,
    rentId,
    utilitiesId,
    phoneId,
    internetId,
    subscriptionsId,
    shoppingId,
    healthId,
    insuranceId,
    educationId,
    travelId,
    entertainmentId,
    feesId,
    taxesId,
    otherExpenseId,
    lunchId,
    dinnerId,
    dessertId,
    bubbleTeaId,
    drinksBarId,
    snacksId,
    taxiId,
    parkingId,
    vehicleMaintenanceId,
    tollsId,
    homeMaintenanceId,
    furnitureId,
    pharmacyId,
    dentalId,
    fitnessId,
    clothingId,
    electronicsId,
    personalCareId,
    moviesId,
    gamesId,
    musicId,
    concertsId,
    hobbiesId,
    booksId,
    coursesId,
    flightsId,
    accommodationId,
    foreignFeesId,
    giftsId,
    childcareId,
    petsId,
    donationsId,
    loanPaymentId,
    creditCardPaymentId,
    savingsContributionId,
    foodDeliveryId,
    publicTransportId,
    waterId,
    electricityId,
    homeLoanInterestId,
    socialSecurityId,
    jewelryId,
    shoesId,
    workshopId,
    doctorId,
    medicineTreatmentId,
    lifeInsuranceId,
    gymBoxingId,
    fitnessClassId,
    fitnessEquipmentId,
    supplementsId,
  };

  /// The 66 system categories as domain objects. userId is empty because
  /// these are global — they belong to no user.
  static List<Category> get all => [..._income, ..._expense];

  // Income & Earnings (groupId: incomeEarningsId)
  static final List<Category> _income = [
    _sys(
      id: salaryId,
      name: 'Salary',
      type: CategoryType.income,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.incomeEarningsId,
      icon: 'salary',
      color: '#22C55E',
    ),
    _sys(
      id: bonusId,
      name: 'Bonus',
      type: CategoryType.income,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.incomeEarningsId,
      icon: 'gift',
      color: '#16A34A',
    ),
    _sys(
      id: freelanceId,
      name: 'Freelance',
      type: CategoryType.income,
      group: CategoryBudgetGroup.business,
      groupId: CategoryGroupDefaults.incomeEarningsId,
      icon: 'work',
      color: '#14B8A6',
    ),
    _sys(
      id: businessId,
      name: 'Business',
      type: CategoryType.income,
      group: CategoryBudgetGroup.business,
      groupId: CategoryGroupDefaults.incomeEarningsId,
      icon: 'business',
      color: '#0EA5E9',
    ),
    _sys(
      id: refundsId,
      name: 'Refunds',
      type: CategoryType.income,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.incomeEarningsId,
      icon: 'refund',
      color: '#10B981',
    ),
    _sys(
      id: giftId,
      name: 'Gift Received',
      type: CategoryType.income,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.incomeEarningsId,
      icon: 'gift',
      color: '#EC4899',
    ),
    _sys(
      id: otherIncomeId,
      name: 'Other Income',
      type: CategoryType.income,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.incomeEarningsId,
      icon: 'category',
      color: '#64748B',
    ),
    // Investments & Savings (income-side)
    _sys(
      id: interestId,
      name: 'Interest',
      type: CategoryType.income,
      group: CategoryBudgetGroup.savings,
      groupId: CategoryGroupDefaults.investmentsId,
      icon: 'savings',
      color: '#06B6D4',
    ),
    _sys(
      id: dividendsId,
      name: 'Dividends',
      type: CategoryType.income,
      group: CategoryBudgetGroup.investment,
      groupId: CategoryGroupDefaults.investmentsId,
      icon: 'investment',
      color: '#8B5CF6',
    ),
    _sys(
      id: rentalId,
      name: 'Rental Income',
      type: CategoryType.income,
      group: CategoryBudgetGroup.investment,
      groupId: CategoryGroupDefaults.investmentsId,
      icon: 'home',
      color: '#6366F1',
    ),
    _sys(
      id: capitalGainsId,
      name: 'Capital Gains',
      type: CategoryType.income,
      group: CategoryBudgetGroup.investment,
      groupId: CategoryGroupDefaults.investmentsId,
      icon: 'investing',
      color: '#7C3AED',
    ),
  ];

  static final List<Category> _expense = [
    // Food & Drink
    _sys(
      id: groceriesId,
      name: 'Groceries',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'groceries',
      color: '#F97316',
    ),
    _sys(
      id: diningId,
      name: 'Dining Out',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'dining',
      color: '#EF4444',
    ),
    _sys(
      id: coffeeId,
      name: 'Coffee',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'coffee',
      color: '#8B5A2B',
    ),
    _sys(
      id: lunchId,
      name: 'Lunch',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'lunch',
      color: '#FB923C',
    ),
    _sys(
      id: dinnerId,
      name: 'Dinner',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'dinner',
      color: '#DC2626',
    ),
    _sys(
      id: dessertId,
      name: 'Dessert',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'dessert',
      color: '#F472B6',
    ),
    _sys(
      id: bubbleTeaId,
      name: 'Bubble Tea',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'bubble_tea',
      color: '#A78BFA',
    ),
    _sys(
      id: drinksBarId,
      name: 'Drinks / Bar',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'drink',
      color: '#C084FC',
    ),
    _sys(
      id: snacksId,
      name: 'Snacks',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'snack',
      color: '#FBBF24',
    ),
    _sys(
      id: foodDeliveryId,
      name: 'Food Delivery',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.foodAndDrinkId,
      icon: 'food_delivery',
      color: '#F97316',
    ),
    // Transport
    _sys(
      id: transportId,
      name: 'Transport',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.transportId,
      icon: 'transport',
      color: '#3B82F6',
    ),
    _sys(
      id: publicTransportId,
      name: 'Public Transport',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.transportId,
      icon: 'public_transport',
      color: '#1E40AF',
    ),
    _sys(
      id: fuelId,
      name: 'Fuel',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.transportId,
      icon: 'fuel',
      color: '#2563EB',
    ),
    _sys(
      id: taxiId,
      name: 'Taxi / Rideshare',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.transportId,
      icon: 'taxi',
      color: '#1D4ED8',
    ),
    _sys(
      id: parkingId,
      name: 'Parking',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.transportId,
      icon: 'parking',
      color: '#0369A1',
    ),
    _sys(
      id: vehicleMaintenanceId,
      name: 'Vehicle Maintenance',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.transportId,
      icon: 'maintenance',
      color: '#0891B2',
    ),
    _sys(
      id: tollsId,
      name: 'Tolls',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.transportId,
      icon: 'tolls',
      color: '#0284C7',
    ),
    // Housing & Utilities
    _sys(
      id: rentId,
      name: 'Rent / Mortgage',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.housingId,
      icon: 'home',
      color: '#7C3AED',
    ),
    _sys(
      id: utilitiesId,
      name: 'Utilities',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.housingId,
      icon: 'utilities',
      color: '#0EA5E9',
    ),
    _sys(
      id: phoneId,
      name: 'Phone',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.housingId,
      icon: 'phone',
      color: '#06B6D4',
    ),
    _sys(
      id: internetId,
      name: 'Internet',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.housingId,
      icon: 'internet',
      color: '#0284C7',
    ),
    _sys(
      id: homeMaintenanceId,
      name: 'Home Maintenance',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.housingId,
      icon: 'maintenance',
      color: '#A855F7',
    ),
    _sys(
      id: furnitureId,
      name: 'Furniture & Appliances',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.housingId,
      icon: 'furniture',
      color: '#9333EA',
    ),
    // Health & Fitness
    _sys(
      id: healthId,
      name: 'Health',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'health',
      color: '#10B981',
    ),
    _sys(
      id: insuranceId,
      name: 'Insurance',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'insurance',
      color: '#14B8A6',
    ),
    _sys(
      id: pharmacyId,
      name: 'Pharmacy / Medicine',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'pharmacy',
      color: '#059669',
    ),
    _sys(
      id: dentalId,
      name: 'Dental',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'dental',
      color: '#0D9488',
    ),
    _sys(
      id: fitnessId,
      name: 'Fitness / Gym',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'gym',
      color: '#22C55E',
    ),
    _sys(
      id: doctorId,
      name: 'Doctor Visit',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'doctor',
      color: '#047857',
    ),
    _sys(
      id: medicineTreatmentId,
      name: 'Medicine & Treatment',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'medicine_treatment',
      color: '#065F46',
    ),
    _sys(
      id: lifeInsuranceId,
      name: 'Life Insurance',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'life_insurance',
      color: '#0F766E',
    ),
    _sys(
      id: gymBoxingId,
      name: 'Gym & Boxing',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'boxing',
      color: '#16A34A',
    ),
    _sys(
      id: fitnessClassId,
      name: 'Fitness Class',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'fitness_class',
      color: '#15803D',
    ),
    _sys(
      id: fitnessEquipmentId,
      name: 'Fitness Equipment',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'fitness_equipment',
      color: '#166534',
    ),
    _sys(
      id: supplementsId,
      name: 'Supplements',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.healthFitnessId,
      icon: 'supplements',
      color: '#84CC16',
    ),
    // Shopping & Personal
    _sys(
      id: shoppingId,
      name: 'Shopping',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.shoppingPersonalId,
      icon: 'shopping',
      color: '#EC4899',
    ),
    _sys(
      id: clothingId,
      name: 'Clothing',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.shoppingPersonalId,
      icon: 'clothing',
      color: '#DB2777',
    ),
    _sys(
      id: electronicsId,
      name: 'Electronics',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.shoppingPersonalId,
      icon: 'electronics',
      color: '#BE185D',
    ),
    _sys(
      id: personalCareId,
      name: 'Personal Care',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.shoppingPersonalId,
      icon: 'personal_care',
      color: '#F472B6',
    ),
    _sys(
      id: jewelryId,
      name: 'Jewelry & Accessories',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.shoppingPersonalId,
      icon: 'jewelry',
      color: '#C084FC',
    ),
    _sys(
      id: shoesId,
      name: 'Shoes & Sneakers',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.shoppingPersonalId,
      icon: 'shoes',
      color: '#9333EA',
    ),
    // Entertainment & Leisure
    _sys(
      id: entertainmentId,
      name: 'Entertainment',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.entertainmentId,
      icon: 'entertainment',
      color: '#F43F5E',
    ),
    _sys(
      id: subscriptionsId,
      name: 'Subscriptions',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.entertainmentId,
      icon: 'subscriptions',
      color: '#A855F7',
    ),
    _sys(
      id: moviesId,
      name: 'Movies',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.entertainmentId,
      icon: 'movie',
      color: '#BE123C',
    ),
    _sys(
      id: gamesId,
      name: 'Games',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.entertainmentId,
      icon: 'game',
      color: '#9F1239',
    ),
    _sys(
      id: musicId,
      name: 'Music / Streaming',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.entertainmentId,
      icon: 'music',
      color: '#E11D48',
    ),
    _sys(
      id: concertsId,
      name: 'Concerts / Events',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.entertainmentId,
      icon: 'concert',
      color: '#FB7185',
    ),
    _sys(
      id: hobbiesId,
      name: 'Hobbies',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.entertainmentId,
      icon: 'hobby',
      color: '#F59E0B',
    ),
    // Education
    _sys(
      id: educationId,
      name: 'Education',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.educationId,
      icon: 'education',
      color: '#F59E0B',
    ),
    _sys(
      id: booksId,
      name: 'Books',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.educationId,
      icon: 'book',
      color: '#D97706',
    ),
    _sys(
      id: coursesId,
      name: 'Courses',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.educationId,
      icon: 'courses',
      color: '#B45309',
    ),
    _sys(
      id: workshopId,
      name: 'Workshops',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.educationId,
      icon: 'workshop',
      color: '#92400E',
    ),
    // Travel
    _sys(
      id: travelId,
      name: 'Travel',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.travelId,
      icon: 'travel',
      color: '#38BDF8',
    ),
    _sys(
      id: flightsId,
      name: 'Flights',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.travelId,
      icon: 'flights',
      color: '#0EA5E9',
    ),
    _sys(
      id: accommodationId,
      name: 'Accommodation',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.travelId,
      icon: 'hotel',
      color: '#0284C7',
    ),
    _sys(
      id: foreignFeesId,
      name: 'Foreign Fees',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.travelId,
      icon: 'foreign_fees',
      color: '#0EA5E9',
    ),
    // Family & Giving
    _sys(
      id: giftsId,
      name: 'Gifts',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: CategoryGroupDefaults.familyGivingId,
      icon: 'gifts',
      color: '#6366F1',
    ),
    _sys(
      id: childcareId,
      name: 'Childcare',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.familyGivingId,
      icon: 'childcare',
      color: '#8B5CF6',
    ),
    _sys(
      id: petsId,
      name: 'Pets',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.familyGivingId,
      icon: 'pets',
      color: '#A855F7',
    ),
    _sys(
      id: donationsId,
      name: 'Donations / Charity',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.familyGivingId,
      icon: 'donation',
      color: '#4F46E5',
    ),
    // Bills & Financial
    _sys(
      id: feesId,
      name: 'Fees',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'fee',
      color: '#64748B',
    ),
    _sys(
      id: taxesId,
      name: 'Taxes',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.tax,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'tax',
      color: '#DC2626',
    ),
    _sys(
      id: loanPaymentId,
      name: 'Loan Payment',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.debt,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'loan',
      color: '#B91C1C',
    ),
    _sys(
      id: creditCardPaymentId,
      name: 'Credit Card Payment',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.debt,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'credit_card',
      color: '#991B1B',
    ),
    _sys(
      id: savingsContributionId,
      name: 'Savings Contribution',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.savings,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'savings',
      color: '#16A34A',
    ),
    _sys(
      id: waterId,
      name: 'Water',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'water',
      color: '#0EA5E9',
    ),
    _sys(
      id: electricityId,
      name: 'Electricity',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'electricity',
      color: '#FACC15',
    ),
    _sys(
      id: homeLoanInterestId,
      name: 'Home Loan Interest',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.debt,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'loan_interest',
      color: '#7C2D12',
    ),
    _sys(
      id: socialSecurityId,
      name: 'Social Security',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.billsFinancialId,
      icon: 'social_security',
      color: '#1E40AF',
    ),
    // Other (catch-all / absorber)
    _sys(
      id: otherExpenseId,
      name: 'Other',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.custom,
      groupId: CategoryGroupDefaults.otherId,
      icon: 'category',
      color: '#64748B',
    ),
  ];

  static Category _sys({
    required String id,
    required String name,
    required CategoryType type,
    required CategoryBudgetGroup group,
    required String groupId,
    required String icon,
    required String color,
  }) {
    return Category(
      id: id,
      userId: '',
      name: name,
      type: type,
      group: group,
      groupId: groupId,
      icon: icon,
      color: color,
      budgetEnabled: type == CategoryType.expense,
    );
  }
}

/// The 13 global default category groups (Food & Drink, Transport, …, Other).
///
/// Each id is a stable constant embedded in the SQL migration that inserts the
/// global `category_groups` rows with `user_id = NULL`. They are injected
/// in-memory at the provider layer and never stored per-user in Brick. The
/// "Other" group (c300…0001, formerly "System") is the catch-all that absorbs
/// any unfiled custom category — see [CategoryGroupDefaults.unfiledGroupId].
///
/// [CategoryGroupDefaults.system] is kept as a back-compat alias pointing at
/// "Other".
abstract final class CategoryGroupDefaults {
  // ── Group ids (…-c300-…) ────────────────────────────────────────────────
  /// The renamed "Other" group (was "System"). Catch-all + unfiled absorber.
  static const String otherId = '00000000-0000-0000-c300-000000000001';

  /// Income & Earnings — salary, freelance, bonuses, refunds, …
  static const String incomeEarningsId = '00000000-0000-0000-c300-000000000002';

  /// Investments & Savings — interest, dividends, rental income, capital gains.
  static const String investmentsId = '00000000-0000-0000-c300-000000000003';

  /// Food & Drink — groceries, dining, coffee, lunch, dinner, …
  static const String foodAndDrinkId = '00000000-0000-0000-c300-000000000004';

  /// Transport — fuel, taxi, parking, vehicle maintenance, tolls.
  static const String transportId = '00000000-0000-0000-c300-000000000005';

  /// Housing & Utilities — rent, utilities, phone, internet, maintenance.
  static const String housingId = '00000000-0000-0000-c300-000000000006';

  /// Health & Fitness — health, insurance, pharmacy, dental, gym.
  static const String healthFitnessId = '00000000-0000-0000-c300-000000000007';

  /// Shopping & Personal — shopping, clothing, electronics, personal care.
  static const String shoppingPersonalId =
      '00000000-0000-0000-c300-000000000008';

  /// Entertainment & Leisure — entertainment, subscriptions, movies, games, …
  static const String entertainmentId = '00000000-0000-0000-c300-000000000009';

  /// Education — education, books, courses.
  static const String educationId = '00000000-0000-0000-c300-00000000000a';

  /// Travel — travel, flights, accommodation, foreign fees.
  static const String travelId = '00000000-0000-0000-c300-00000000000b';

  /// Family & Giving — gifts, childcare, pets, donations.
  static const String familyGivingId = '00000000-0000-0000-c300-00000000000c';

  /// Bills & Financial — fees, taxes, loan payment, credit card payment, savings.
  static const String billsFinancialId = '00000000-0000-0000-c300-00000000000d';

  /// Back-compat alias for the catch-all group. Was "System"; now renamed
  /// "Other". The id is identical to [otherId].
  static const String systemId = otherId;

  /// The id of the group that absorbs every unfiled custom category
  /// (`groupId == null/empty`). Today this is the renamed "Other" group.
  static const String unfiledGroupId = otherId;

  /// Sort orders place user-created groups first, then the 13 default groups
  /// in deliberate internal order (income → investments → expense groups →
  /// Other last). All defaults share the 1<<20 base so they sort after any
  /// user-defined `sortOrder`.
  static const int _base = 1 << 20;
  static const int _otherSort = _base + 99;

  /// The set of every default group id. Used by [CategoryGroup.isSystem] to
  /// distinguish read-only defaults from user-defined groups.
  static const Set<String> systemIds = {
    otherId,
    incomeEarningsId,
    investmentsId,
    foodAndDrinkId,
    transportId,
    housingId,
    healthFitnessId,
    shoppingPersonalId,
    entertainmentId,
    educationId,
    travelId,
    familyGivingId,
    billsFinancialId,
  };

  /// The 13 default groups as domain objects, in display order. userId is
  /// empty because each is global — they belong to no user.
  static List<CategoryGroup> get all => const [
    CategoryGroup(
      id: incomeEarningsId,
      userId: '',
      name: 'Income & Earnings',
      icon: 'salary',
      color: '#16A34A',
      sortOrder: _base + 1,
    ),
    CategoryGroup(
      id: investmentsId,
      userId: '',
      name: 'Investments & Savings',
      icon: 'investing',
      color: '#8B5CF6',
      sortOrder: _base + 2,
    ),
    CategoryGroup(
      id: foodAndDrinkId,
      userId: '',
      name: 'Food & Drink',
      icon: 'food',
      color: '#F97316',
      sortOrder: _base + 3,
    ),
    CategoryGroup(
      id: transportId,
      userId: '',
      name: 'Transport',
      icon: 'transport',
      color: '#3B82F6',
      sortOrder: _base + 4,
    ),
    CategoryGroup(
      id: housingId,
      userId: '',
      name: 'Housing & Utilities',
      icon: 'home',
      color: '#7C3AED',
      sortOrder: _base + 5,
    ),
    CategoryGroup(
      id: healthFitnessId,
      userId: '',
      name: 'Health & Fitness',
      icon: 'health',
      color: '#10B981',
      sortOrder: _base + 6,
    ),
    CategoryGroup(
      id: shoppingPersonalId,
      userId: '',
      name: 'Shopping & Personal',
      icon: 'shopping',
      color: '#EC4899',
      sortOrder: _base + 7,
    ),
    CategoryGroup(
      id: entertainmentId,
      userId: '',
      name: 'Entertainment & Leisure',
      icon: 'entertainment',
      color: '#F43F5E',
      sortOrder: _base + 8,
    ),
    CategoryGroup(
      id: educationId,
      userId: '',
      name: 'Education',
      icon: 'education',
      color: '#F59E0B',
      sortOrder: _base + 9,
    ),
    CategoryGroup(
      id: travelId,
      userId: '',
      name: 'Travel',
      icon: 'travel',
      color: '#38BDF8',
      sortOrder: _base + 10,
    ),
    CategoryGroup(
      id: familyGivingId,
      userId: '',
      name: 'Family & Giving',
      icon: 'gift',
      color: '#6366F1',
      sortOrder: _base + 11,
    ),
    CategoryGroup(
      id: billsFinancialId,
      userId: '',
      name: 'Bills & Financial',
      icon: 'fee',
      color: '#DC2626',
      sortOrder: _base + 12,
    ),
    CategoryGroup(
      id: otherId,
      userId: '',
      name: 'Other',
      icon: 'category',
      color: '#64748B',
      sortOrder: _otherSort,
    ),
  ];

  /// Back-compat alias for the renamed "System" group. Prefer [otherId] in
  /// new code — kept so existing call sites keep compiling.
  static CategoryGroup get system => other;

  /// The renamed "Other" group as a domain object.
  static CategoryGroup get other => const CategoryGroup(
    id: otherId,
    userId: '',
    name: 'Other',
    icon: 'category',
    color: '#64748B',
    sortOrder: _otherSort,
  );
}
