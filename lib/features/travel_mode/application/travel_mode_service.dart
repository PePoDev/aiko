import '../../../core/money/money.dart';
import '../domain/trip.dart';

class TravelModeService {
  const TravelModeService();

  Money totalForeignFees(Trip trip) {
    return trip.foreignFees.fold(
      Money.zero(trip.budget.currency),
      (total, fee) => total + fee,
    );
  }
}
