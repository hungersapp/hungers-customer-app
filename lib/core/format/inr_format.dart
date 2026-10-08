String formatInr(double amount, {int fractionDigits = 2}) {
  return '\u20B9${amount.toStringAsFixed(fractionDigits)}';
}

String formatInrWhole(double amount) {
  return formatInr(amount, fractionDigits: 0);
}
