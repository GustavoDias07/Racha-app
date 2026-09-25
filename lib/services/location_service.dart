import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Onde o aparelho acha que você está, **e o quanto ele confia nisso**.
///
/// A precisão não é detalhe: num celular com GPS ela fica na casa das
/// dezenas de metros, mas num computador o navegador estima pelo Wi-Fi ou
/// pelo IP e erra por quilômetros. Sem esse número, distâncias calculadas a
/// partir de uma posição ruim parecem simplesmente erradas, e não há como
/// explicar a diferença para quem está olhando.
class PosicaoAtual {
  const PosicaoAtual({required this.ponto, required this.precisaoMetros});

  final GeoPoint ponto;

  /// Raio de incerteza em metros: a posição real está, com alta
  /// probabilidade, dentro de um círculo desse raio em volta de [ponto].
  final double precisaoMetros;

  /// Acima de 1 km a posição não serve para distinguir bairros, que é
  /// justamente o que a aba "Rachas Próximos" precisa fazer.
  bool get imprecisa => precisaoMetros > 1000;

  /// A incerteza escrita de um jeito legível ("±350 m", "±4,9 km").
  String get precisaoLegivel => precisaoMetros < 1000
      ? '±${precisaoMetros.round()} m'
      : '±${(precisaoMetros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Wrapper fino sobre o `geolocator`: usado tanto pra capturar a localização
/// de um Grupo (tela de criar/editar) quanto pra pegar a posição do usuário
/// na aba "Rachas Próximos". Centraliza a checagem de permissão/serviço de
/// GPS pra não duplicar esse tratamento nas duas telas.
class LocationService {
  Future<PosicaoAtual> obterPosicaoAtual() async {
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

    // `high` em vez de `medium`: no celular liga o GPS de verdade em vez de
    // se contentar com a triangulação de antenas, e no navegador manda
    // `enableHighAccuracy`. Custa alguns segundos e um pouco de bateria, mas
    // é a diferença entre saber a rua e saber só a região da cidade.
    final posicao = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return PosicaoAtual(
      ponto: GeoPoint(posicao.latitude, posicao.longitude),
      precisaoMetros: posicao.accuracy,
    );
  }
}
