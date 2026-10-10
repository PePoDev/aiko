import '../../../l10n/app_localizations.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';

/// Names for the built-in categories and groups in the user's language.
///
/// Built-in rows are stored with their English template name. Until the user
/// renames one, [CategoryDisplayName.displayName] shows the translated name;
/// a renamed row shows exactly what the user typed.
extension CategoryDisplayName on Category {
  String displayName(AppLocalizations l10n) {
    final templateId = effectiveTemplateId;
    if (templateId == null) return name;
    if (CategoryDefaults.byId[templateId]?.name != name) return name;
    return defaultCategoryName(templateId, l10n) ?? name;
  }
}

extension CategoryGroupDisplayName on CategoryGroup {
  String displayName(AppLocalizations l10n) {
    final templateId = effectiveTemplateId;
    if (templateId == null) return name;
    if (CategoryGroupDefaults.byId[templateId]?.name != name) return name;
    return defaultCategoryGroupName(templateId, l10n) ?? name;
  }
}

/// The display name of the category with [id] in [categories], or
/// "Uncategorized" when there is none: no id, or a category that no longer
/// exists. Look up in `allCategoriesProvider` so deleted categories keep
/// their name.
String categoryNameForId(
  String? id,
  Iterable<Category> categories,
  AppLocalizations l10n,
) {
  if (id != null) {
    for (final category in categories) {
      if (category.id == id) return category.displayName(l10n);
    }
  }
  return l10n.uncategorized;
}

/// The text to store when the user saves a name in an editor that started
/// from [displayName]: an unchanged translated name keeps the stored template
/// name, so it stays translatable.
String storedCategoryName({
  required String original,
  required String shown,
  required String edited,
}) => edited.trim() == shown ? original : edited.trim();

String? defaultCategoryName(
  String templateId,
  AppLocalizations l10n,
) => switch (templateId) {
  CategoryDefaults.salaryId => l10n.categoryNameSalary,
  CategoryDefaults.bonusId => l10n.categoryNameBonus,
  CategoryDefaults.freelanceId => l10n.categoryNameFreelance,
  CategoryDefaults.businessId => l10n.categoryNameBusiness,
  CategoryDefaults.refundsId => l10n.categoryNameRefunds,
  CategoryDefaults.giftId => l10n.categoryNameGift,
  CategoryDefaults.otherIncomeId => l10n.categoryNameOtherIncome,
  CategoryDefaults.interestId => l10n.categoryNameInterest,
  CategoryDefaults.dividendsId => l10n.categoryNameDividends,
  CategoryDefaults.rentalId => l10n.categoryNameRental,
  CategoryDefaults.capitalGainsId => l10n.categoryNameCapitalGains,
  CategoryDefaults.groceriesId => l10n.categoryNameGroceries,
  CategoryDefaults.diningId => l10n.categoryNameDining,
  CategoryDefaults.coffeeId => l10n.categoryNameCoffee,
  CategoryDefaults.lunchId => l10n.categoryNameLunch,
  CategoryDefaults.dinnerId => l10n.categoryNameDinner,
  CategoryDefaults.dessertId => l10n.categoryNameDessert,
  CategoryDefaults.bubbleTeaId => l10n.categoryNameBubbleTea,
  CategoryDefaults.drinksBarId => l10n.categoryNameDrinksBar,
  CategoryDefaults.snacksId => l10n.categoryNameSnacks,
  CategoryDefaults.foodDeliveryId => l10n.categoryNameFoodDelivery,
  CategoryDefaults.transportId => l10n.categoryNameTransport,
  CategoryDefaults.publicTransportId => l10n.categoryNamePublicTransport,
  CategoryDefaults.fuelId => l10n.categoryNameFuel,
  CategoryDefaults.taxiId => l10n.categoryNameTaxi,
  CategoryDefaults.parkingId => l10n.categoryNameParking,
  CategoryDefaults.vehicleMaintenanceId => l10n.categoryNameVehicleMaintenance,
  CategoryDefaults.tollsId => l10n.categoryNameTolls,
  CategoryDefaults.rentId => l10n.categoryNameRent,
  CategoryDefaults.utilitiesId => l10n.categoryNameUtilities,
  CategoryDefaults.phoneId => l10n.categoryNamePhone,
  CategoryDefaults.internetId => l10n.categoryNameInternet,
  CategoryDefaults.homeMaintenanceId => l10n.categoryNameHomeMaintenance,
  CategoryDefaults.furnitureId => l10n.categoryNameFurniture,
  CategoryDefaults.healthId => l10n.categoryNameHealth,
  CategoryDefaults.insuranceId => l10n.categoryNameInsurance,
  CategoryDefaults.pharmacyId => l10n.categoryNamePharmacy,
  CategoryDefaults.dentalId => l10n.categoryNameDental,
  CategoryDefaults.fitnessId => l10n.categoryNameFitness,
  CategoryDefaults.doctorId => l10n.categoryNameDoctor,
  CategoryDefaults.medicineTreatmentId => l10n.categoryNameMedicineTreatment,
  CategoryDefaults.lifeInsuranceId => l10n.categoryNameLifeInsurance,
  CategoryDefaults.gymBoxingId => l10n.categoryNameGymBoxing,
  CategoryDefaults.fitnessClassId => l10n.categoryNameFitnessClass,
  CategoryDefaults.fitnessEquipmentId => l10n.categoryNameFitnessEquipment,
  CategoryDefaults.supplementsId => l10n.categoryNameSupplements,
  CategoryDefaults.shoppingId => l10n.categoryNameShopping,
  CategoryDefaults.clothingId => l10n.categoryNameClothing,
  CategoryDefaults.electronicsId => l10n.categoryNameElectronics,
  CategoryDefaults.personalCareId => l10n.categoryNamePersonalCare,
  CategoryDefaults.jewelryId => l10n.categoryNameJewelry,
  CategoryDefaults.shoesId => l10n.categoryNameShoes,
  CategoryDefaults.entertainmentId => l10n.categoryNameEntertainment,
  CategoryDefaults.subscriptionsId => l10n.categoryNameSubscriptions,
  CategoryDefaults.moviesId => l10n.categoryNameMovies,
  CategoryDefaults.gamesId => l10n.categoryNameGames,
  CategoryDefaults.musicId => l10n.categoryNameMusic,
  CategoryDefaults.concertsId => l10n.categoryNameConcerts,
  CategoryDefaults.hobbiesId => l10n.categoryNameHobbies,
  CategoryDefaults.educationId => l10n.categoryNameEducation,
  CategoryDefaults.booksId => l10n.categoryNameBooks,
  CategoryDefaults.coursesId => l10n.categoryNameCourses,
  CategoryDefaults.workshopId => l10n.categoryNameWorkshop,
  CategoryDefaults.travelId => l10n.categoryNameTravel,
  CategoryDefaults.flightsId => l10n.categoryNameFlights,
  CategoryDefaults.accommodationId => l10n.categoryNameAccommodation,
  CategoryDefaults.foreignFeesId => l10n.categoryNameForeignFees,
  CategoryDefaults.giftsId => l10n.categoryNameGifts,
  CategoryDefaults.childcareId => l10n.categoryNameChildcare,
  CategoryDefaults.petsId => l10n.categoryNamePets,
  CategoryDefaults.donationsId => l10n.categoryNameDonations,
  CategoryDefaults.feesId => l10n.categoryNameFees,
  CategoryDefaults.taxesId => l10n.categoryNameTaxes,
  CategoryDefaults.loanPaymentId => l10n.categoryNameLoanPayment,
  CategoryDefaults.creditCardPaymentId => l10n.categoryNameCreditCardPayment,
  CategoryDefaults.savingsContributionId =>
    l10n.categoryNameSavingsContribution,
  CategoryDefaults.waterId => l10n.categoryNameWater,
  CategoryDefaults.electricityId => l10n.categoryNameElectricity,
  CategoryDefaults.homeLoanInterestId => l10n.categoryNameHomeLoanInterest,
  CategoryDefaults.socialSecurityId => l10n.categoryNameSocialSecurity,
  CategoryDefaults.otherExpenseId => l10n.categoryNameOtherExpense,
  _ => null,
};

String? defaultCategoryGroupName(
  String templateId,
  AppLocalizations l10n,
) => switch (templateId) {
  CategoryGroupDefaults.incomeEarningsId =>
    l10n.categoryGroupNameIncomeEarnings,
  CategoryGroupDefaults.investmentsId => l10n.categoryGroupNameInvestments,
  CategoryGroupDefaults.foodAndDrinkId => l10n.categoryGroupNameFoodAndDrink,
  CategoryGroupDefaults.transportId => l10n.categoryGroupNameTransport,
  CategoryGroupDefaults.housingId => l10n.categoryGroupNameHousing,
  CategoryGroupDefaults.healthFitnessId => l10n.categoryGroupNameHealthFitness,
  CategoryGroupDefaults.shoppingPersonalId =>
    l10n.categoryGroupNameShoppingPersonal,
  CategoryGroupDefaults.entertainmentId => l10n.categoryGroupNameEntertainment,
  CategoryGroupDefaults.educationId => l10n.categoryGroupNameEducation,
  CategoryGroupDefaults.travelId => l10n.categoryGroupNameTravel,
  CategoryGroupDefaults.familyGivingId => l10n.categoryGroupNameFamilyGiving,
  CategoryGroupDefaults.billsFinancialId =>
    l10n.categoryGroupNameBillsFinancial,
  CategoryGroupDefaults.otherId => l10n.categoryGroupNameOther,
  _ => null,
};
