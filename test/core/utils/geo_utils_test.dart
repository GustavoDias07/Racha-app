import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/utils/geo_utils.dart';

void main() {
  test('distância entre o mesmo ponto é zero', () {
    const ponto = GeoPoint(-23.5505, -46.6333);
    expect(distanciaKm(ponto, ponto), 0);
  });

  test('distância aproximada entre São Paulo e Rio de Janeiro (~360km)', () {
    const saoPaulo = GeoPoint(-23.5505, -46.6333);
    const rioDeJaneiro = GeoPoint(-22.9068, -43.1729);

    final distancia = distanciaKm(saoPaulo, rioDeJaneiro);

    expect(distancia, greaterThan(350));
    expect(distancia, lessThan(370));
  });

  test('distância é simétrica', () {
    const a = GeoPoint(-23.5505, -46.6333);
    const b = GeoPoint(-22.9068, -43.1729);

    expect(distanciaKm(a, b), closeTo(distanciaKm(b, a), 0.0001));
  });

  group('distanciaLegivel', () {
    test('abaixo de 1 km usa metros, arredondados de 50 em 50', () {
      // Arredondar evita fingir uma precisão que a posição do aparelho não
      // tem — no navegador o erro é de quilômetros.
      expect(distanciaLegivel(0.32), '300 m');
      expect(distanciaLegivel(0.38), '400 m');
      expect(distanciaLegivel(0.925), '950 m');
    });

    test('a partir de 1 km usa km com vírgula decimal', () {
      expect(distanciaLegivel(1.0), '1,0 km');
      expect(distanciaLegivel(4.94), '4,9 km');
      expect(distanciaLegivel(12.35), '12,3 km');
    });

    test('distância desprezível vira texto, não "0 m"', () {
      expect(distanciaLegivel(0.0), 'aqui perto');
      expect(distanciaLegivel(0.01), 'aqui perto');
    });
  });
}
