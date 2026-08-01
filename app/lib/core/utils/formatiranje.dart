import 'package:intl/intl.dart';

/// Formatiranje vrijednosti za prikaz. Lokalizovano na `bs_BA`.
class Formatiranje {
  const Formatiranje._();

  static final _novac = NumberFormat.currency(
    locale: 'bs_BA',
    symbol: 'KM',
    decimalDigits: 2,
  );
  static final _datum = DateFormat('dd.MM.yyyy.', 'bs');
  static final _datumVrijeme = DateFormat('dd.MM.yyyy. HH:mm', 'bs');

  /// Iznos sa valutom. Negativne vrijednosti dobijaju znak minus.
  static String novac(double iznos, {String valuta = 'KM'}) {
    final f = valuta == 'KM'
        ? _novac
        : NumberFormat.currency(
            locale: 'bs_BA', symbol: valuta, decimalDigits: 2,);
    return f.format(iznos);
  }

  static String datum(DateTime d) => _datum.format(d.toLocal());

  static String datumVrijeme(DateTime d) => _datumVrijeme.format(d.toLocal());

  static String procenat(double p) => '${p.toStringAsFixed(1)}%';

  /// Preostalo vrijeme u čitljivom obliku: "3 dana", "5 sati", "12 minuta".
  static String trajanje(Duration d) {
    if (d.isNegative) return 'isteklo';
    if (d.inDays > 0) return '${d.inDays} ${_oblik(d.inDays, 'dan', 'dana', 'dana')}';
    if (d.inHours > 0) return '${d.inHours} ${_oblik(d.inHours, 'sat', 'sata', 'sati')}';
    return '${d.inMinutes} ${_oblik(d.inMinutes, 'minut', 'minuta', 'minuta')}';
  }

  /// Slavenska množina: 1 dan / 2-4 dana / 5+ dana.
  /// Izuzetak su brojevi 11–14, koji uvijek idu u treći oblik.
  static String _oblik(int n, String jedan, String malo, String mnogo) {
    final zadnjeDvije = n % 100;
    if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return mnogo;
    return switch (n % 10) {
      1 => jedan,
      2 || 3 || 4 => malo,
      _ => mnogo,
    };
  }
}
