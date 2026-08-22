import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Wrapper fino sobre o `geolocator`: usado tanto pra capturar a localização
/// de um Grupo (tela de criar/editar) quanto pra pegar a posição do usuário
/// na aba "Rachas Próximos". Centraliza a checagem de permissão/serviço de
/// GPS pra não duplicar esse tratamento nas duas telas.
class LocationService {
  Future<GeoPoint> obterPosicaoAtual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Ative a localização (GPS) do aparelho e tente de novo.');
    }

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada.');
    }

    final posicao = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    return GeoPoint(posicao.latitude, posicao.longitude);
  }
}
