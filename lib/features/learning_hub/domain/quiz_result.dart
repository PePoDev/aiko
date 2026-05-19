class QuizResult {
  const QuizResult({required this.correct, required this.total});

  final int correct;
  final int total;

  double get scorePercent => total == 0 ? 0 : correct / total * 100;
  bool get passed => scorePercent >= 70;
}
