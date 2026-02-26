import 'package:intl/intl.dart';

class PriceFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###');

  static String formatNum(num value) {
    return _formatter.format(value);
  }

  static String formatString(String value) {
    final cleaned = value.replaceAll(',', '').trim();
    final num? parsed = num.tryParse(cleaned);
    if (parsed == null) return value; // if not numeric, return original
    return formatNum(parsed);
  }

  static double parseToDouble(String value) {
    final cleaned = value.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }
}
