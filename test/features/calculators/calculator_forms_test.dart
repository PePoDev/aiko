import 'package:aiko/features/calculators/presentation/calculator_form.dart';
import 'package:aiko/features/calculators/presentation/calculator_forms.dart';
import 'package:aiko/features/calculators/presentation/calculator_library_screen.dart';
import 'package:aiko/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Values for [form] with every choice at its first option, then every
/// combination of options. Hidden fields get text that isn't a number, so a
/// calculation that reads a field it doesn't show fails.
List<Map<String, String>> _scenarios(CalculatorForm form) {
  var scenarios = [
    {
      for (final field in form.fields)
        field.id: field.initialValue.isEmpty ? '1' : field.initialValue,
    },
  ];
  for (final field in form.fields.where((field) => field.isChoice)) {
    scenarios = [
      for (final scenario in scenarios)
        for (final option in field.options)
          {...scenario, field.id: option.value},
    ];
  }
  return [
    for (final scenario in scenarios)
      {
        for (final field in form.fields)
          field.id: form.isVisible(field, scenario)
              ? scenario[field.id]!
              : 'hidden',
      },
  ];
}

CalculatorResult _calculate(
  CalculatorForm form,
  AppLocalizations l10n, [
  Map<String, String> changes = const {},
]) {
  return form.calculate(
    CalculatorInputs(
      form: form,
      values: {..._scenarios(form).first, ...changes},
      l10n: l10n,
      currency: form.currency ?? 'USD',
    ),
  );
}

void main() {
  for (final language in ['en', 'th']) {
    final l10n = lookupAppLocalizations(Locale(language));

    test('every library calculator has its own form ($language)', () {
      final titles = <String>{};
      for (final id in CalculatorLibraryScreen.calculators) {
        final form = calculatorForm(id, l10n);
        expect(form, isNotNull, reason: id);
        expect(titles.add(form!.title), isTrue, reason: 'duplicate $id');
      }
    });

    test('every form calculates from its starting values ($language)', () {
      for (final id in CalculatorLibraryScreen.calculators) {
        final form = calculatorForm(id, l10n)!;
        for (final values in _scenarios(form)) {
          final result = form.calculate(
            CalculatorInputs(
              form: form,
              values: values,
              l10n: l10n,
              currency: form.currency ?? 'USD',
            ),
          );
          expect(result.title, isNotEmpty, reason: '$id $values');
          expect(result.value, isNotEmpty, reason: '$id $values');
          for (final row in result.rows) {
            expect(row.label, isNotEmpty, reason: id);
            expect(row.value, isNotEmpty, reason: id);
          }
        }
      }
    });
  }

  final l10n = lookupAppLocalizations(const Locale('en'));

  test('fields are unique and conditions name a choice and its options', () {
    for (final id in CalculatorLibraryScreen.calculators) {
      final form = calculatorForm(id, l10n)!;
      final ids = form.fields.map((field) => field.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: id);
      for (final field in form.fields) {
        if (field.isChoice) {
          expect(
            field.options.map((option) => option.value),
            contains(field.initialValue),
            reason: '$id ${field.id}',
          );
        }
        final condition = field.showWhen;
        if (condition == null) continue;
        final choice = form.fieldFor(condition.field);
        expect(choice.isChoice, isTrue, reason: '$id ${field.id}');
        expect(
          choice.options.map((option) => option.value),
          containsAll(condition.values),
          reason: '$id ${field.id}',
        );
      }
    }
  });

  test('calculators built on Thai rules work in baht', () {
    for (final id in [
      'Income tax',
      'Capital gains tax',
      'Tax-saving funds',
      'Social Security pension',
    ]) {
      expect(calculatorForm(id, l10n)!.currency, 'THB', reason: id);
    }
    expect(calculatorForm('Loan', l10n)!.currency, isNull);
  });

  test('income tax shows the monthly take-home pay and the year in rows', () {
    final result = _calculate(calculatorForm('Income tax', l10n)!, l10n);
    // 600,000 − 100,000 − 60,000 − 12 × 875 = 429,500 taxable.
    expect(result.value, '฿47,420.83');
    expect(
      result.rows.map((row) => row.value),
      containsAll(['฿600,000.00', '฿429,500.00', '฿20,450.00', '10.00%']),
    );
  });

  test('social security switches between pension and lump sum', () {
    final form = calculatorForm('Social Security pension', l10n)!;
    final pension = _calculate(form, l10n);
    expect(pension.title, l10n.calcResultMonthlyPension);
    expect(pension.value, '฿4,812.50');

    final lumpSum = _calculate(form, l10n, {'months': '120'});
    expect(lumpSum.title, l10n.calcResultLumpSum);
    expect(lumpSum.value, '฿126,000.00');
    expect(lumpSum.rows.first.value, l10n.monthsCount(60));
  });

  test('capital gains are exempt unless taxed as other income', () {
    final form = calculatorForm('Capital gains tax', l10n)!;
    expect(_calculate(form, l10n).value, '฿50,000.00');
    final taxed = _calculate(form, l10n, {
      'assetType': 'taxable',
      'otherNetIncome': '480000',
    });
    // 50,000 gain: 20,000 at 10% and 30,000 at 15%.
    expect(taxed.value, '฿43,500.00');
  });

  test('invalid input names the field', () {
    final form = calculatorForm('Income tax', l10n)!;
    expect(
      () => _calculate(form, l10n, {'monthlySalary': 'abc'}),
      throwsA(
        isA<CalculatorInputException>().having(
          (error) => error.message,
          'message',
          l10n.calcEnterValid(l10n.calcFieldMonthlySalary),
        ),
      ),
    );
    expect(
      () => _calculate(calculatorForm('Rent vs. buy', l10n)!, l10n, {
        'downPayment': '120',
      }),
      throwsA(isA<CalculatorInputException>()),
    );
    expect(
      () => _calculate(calculatorForm('Home affordability', l10n)!, l10n, {
        'monthlyDebts': '30000',
      }),
      throwsA(
        isA<CalculatorInputException>().having(
          (error) => error.message,
          'message',
          l10n.calcAffordabilityNoRoom,
        ),
      ),
    );
  });

  test('service errors map to localized messages', () {
    final form = calculatorForm('Bond yield', l10n)!;
    expect(
      () => _calculate(form, l10n, {'price': '1'}),
      throwsA(
        isA<ArgumentError>().having(
          (error) => calculatorErrorMessage(error, l10n),
          'message',
          l10n.calcErrorBondPrice,
        ),
      ),
    );
    expect(
      calculatorErrorMessage(ArgumentError('Something else.'), l10n),
      l10n.calcErrorGeneric,
    );
  });
}
