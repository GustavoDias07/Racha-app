import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

const double _raioTerraKm = 6371;

/// Distância aproximada, em km, entre dois pontos (fórmula de haversine).
/// Usada pra filtrar/ordenar a aba "Rachas Próximos" sem depender de geohash
/// ou de uma lib de geoquery — o volume de grupos do app não justifica isso,
/// então filtra tudo no cliente a partir de `GrupoRepository.observarAbertos`.
double distanciaKm(GeoPoint a, GeoPoint b) {
  final dLat = _paraRadianos(b.latitude - a.latitude);
  final dLon = _paraRadianos(b.longitude - a.longitude);

  final lat1 = _paraRadianos(a.latitude);
  final lat2 = _paraRadianos(b.latitude);

  final h = sin(dLat / 2) * sin(dLat / 2) +
      sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
  final c = 2 * atan2(sqrt(h), sqrt(1 - h));

  return _raioTerraKm * c;
}

double _paraRadianos(double graus) => graus * pi / 180;
