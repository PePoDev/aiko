import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingPieChart extends StatelessWidget {
  const SpendingPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(value: 45, title: 'Food'),
            PieChartSectionData(value: 30, title: 'Bills'),
            PieChartSectionData(value: 25, title: 'Goals'),
          ],
        ),
      ),
    );
  }
}
