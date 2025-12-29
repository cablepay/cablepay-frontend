// lib/core/money_utils.dart
double paiseToRupees(int? paise) {
  if (paise == null) return 0.0;
  return paise / 100.0;
}

int rupeesToPaiseDoubleSafe(double rupees) {
  // Round to nearest paise (integer)
  return (rupees * 100).round();
}

String formatRupees(double value) {
  // Simple formatting — adapt to intl package if you want localized formatting
  return '₹' + value.toStringAsFixed(2);
}
