import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mojzev/core/utils/formatiranje.dart';
import 'package:mojzev/shared/models/enumi.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('bs');
  });

  group('Formatiranje.trajanje — slavenska množina', () {
    test('jednina za 1', () {
      expect(Formatiranje.trajanje(const Duration(days: 1)), '1 dan');
      expect(Formatiranje.trajanje(const Duration(hours: 1)), '1 sat');
    });

    test('drugi oblik za 2–4', () {
      expect(Formatiranje.trajanje(const Duration(days: 3)), '3 dana');
      expect(Formatiranje.trajanje(const Duration(hours: 4)), '4 sata');
    });

    test('treći oblik za 5+', () {
      expect(Formatiranje.trajanje(const Duration(days: 7)), '7 dana');
      expect(Formatiranje.trajanje(const Duration(hours: 9)), '9 sati');
    });

    test('brojevi 11–14 idu u treći oblik', () {
      expect(Formatiranje.trajanje(const Duration(days: 11)), '11 dana');
      expect(Formatiranje.trajanje(const Duration(hours: 12)), '12 sati');
    });

    test('21 se ponaša kao 1', () {
      expect(Formatiranje.trajanje(const Duration(days: 21)), '21 dan');
    });

    test('isteklo trajanje', () {
      expect(Formatiranje.trajanje(const Duration(days: -1)), 'isteklo');
    });
  });

  group('Uloga', () {
    test('hijerarhija prati SQL nivoe', () {
      expect(Uloga.predsjednik.nivo, lessThan(Uloga.vlasnik.nivo));
      expect(Uloga.sistemAdmin.nivo, 0);
    });

    test('jeUprava odgovara pravilu nivo <= 30 iz je_uprava()', () {
      expect(Uloga.predsjednik.jeUprava, isTrue);
      expect(Uloga.clanUo.jeUprava, isTrue);
      expect(Uloga.blagajnik.jeUprava, isTrue);
      expect(Uloga.upravnik.jeUprava, isTrue);
      expect(Uloga.vlasnik.jeUprava, isFalse);
      expect(Uloga.podstanar.jeUprava, isFalse);
    });

    test('nepoznat kod pada na vlasnika, ne puca', () {
      expect(Uloga.izKoda('nepostojeca'), Uloga.vlasnik);
    });
  });

  group('TipTransakcije', () {
    test('predznak odgovara koloni iznos_predznakom u bazi', () {
      expect(TipTransakcije.zaduzenje.povecavaDug, isTrue);
      expect(TipTransakcije.kamata.povecavaDug, isTrue);
      expect(TipTransakcije.uplata.povecavaDug, isFalse);
      expect(TipTransakcije.popust.povecavaDug, isFalse);
      expect(TipTransakcije.storno.povecavaDug, isFalse);
    });
  });

  group('StatusKvara', () {
    test('zatvoreni statusi', () {
      expect(StatusKvara.rijesen.jeZatvoren, isTrue);
      expect(StatusKvara.odbijen.jeZatvoren, isTrue);
      expect(StatusKvara.duplikat.jeZatvoren, isTrue);
      expect(StatusKvara.uToku.jeZatvoren, isFalse);
      expect(StatusKvara.prijavljen.jeZatvoren, isFalse);
    });
  });
}
