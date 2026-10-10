import 'package:aiko/features/overview/domain/monthly_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('income and net: up is good, down is bad', () {
    expect(changeTone(12.5, higherIsBetter: true), ChangeTone.good);
    expect(changeTone(-30, higherIsBetter: true), ChangeTone.bad);
  });

  test('spending: down is good, up is bad', () {
    expect(changeTone(-8, higherIsBetter: false), ChangeTone.good);
    expect(changeTone(15, higherIsBetter: false), ChangeTone.bad);
  });

  test('no change is flat either way', () {
    expect(changeTone(0, higherIsBetter: true), ChangeTone.flat);
    expect(changeTone(0, higherIsBetter: false), ChangeTone.flat);
  });
}
