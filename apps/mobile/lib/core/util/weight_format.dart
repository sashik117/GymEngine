String formatKg(double value, {String unit = 'KG'}) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()} $unit';
  }

  return '${value.toStringAsFixed(1)} $unit';
}
