import 'dart:convert';
import 'dart:typed_data';

/// Converte uma foto em base64 para bytes **uma vez só** por foto.
///
/// Sem cache, cada redesenho de tela rodaria `base64Decode` de novo — numa
/// lista de participantes isso é dezenas de decodificações de ~200 KB a cada
/// `setState`. Pior: cada decodificação gera um `Uint8List` novo, e o
/// `MemoryImage` compara por identidade dos bytes, então o Flutter tomaria
/// cada um como imagem diferente e a foto piscaria a cada rebuild.
///
/// Limitado a 64 fotos: o suficiente para um racha cheio mais o ranking e a
/// tela inicial, sem crescer sem fim numa sessão longa.
final _cache = <int, Uint8List>{};

Uint8List? bytesDaFoto(String? fotoBase64) {
  if (fotoBase64 == null || fotoBase64.isEmpty) return null;
  final chave = Object.hash(fotoBase64.length, fotoBase64.hashCode);
  final emCache = _cache[chave];
  if (emCache != null) return emCache;

  try {
    final bytes = base64Decode(fotoBase64);
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    _cache[chave] = bytes;
    return bytes;
  } on FormatException {
    // Base64 corrompido não pode derrubar a tela inteira: quem chama mostra
    // o substituto (iniciais, ícone) como se não houvesse foto.
    return null;
  }
}
