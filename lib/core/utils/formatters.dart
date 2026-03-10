import 'package:intl/intl.dart';

final currencyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '',
  decimalDigits: 2,
);

String money(num value) => currencyFormat.format(value).trim();
