import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Um endereço encontrado na busca, já com as coordenadas.
class EnderecoEncontrado {
  const EnderecoEncontrado({
    required this.descricao,
    required this.latitude,
    required this.longitude,
  });

  /// Texto mostrado na lista de resultados.
  final String descricao;
  final double latitude;
  final double longitude;
}

/// Converte endereço ou CEP em coordenadas, para a pessoa não precisar achar
/// o ponto no mapa arrastando.
///
/// Usa dois serviços gratuitos e sem cadastro, em vez da API do Google, que
/// exige chave e cartão de crédito:
///
///  - **ViaCEP** resolve o CEP para um endereço, mas **não devolve
///    coordenadas** — por isso ele sozinho não basta.
///  - **Nominatim**, o buscador do OpenStreetMap (o mesmo projeto dos tiles
///    que o mapa já usa), transforma o endereço em latitude/longitude.
///
/// Então um CEP faz o caminho `ViaCEP -> endereço -> Nominatim -> coordenadas`,
/// e um endereço digitado vai direto ao Nominatim.
///
/// A política de uso do Nominatim pede no máximo uma consulta por segundo e
/// que o app se identifique. Por isso a busca dispara só quando a pessoa
/// confirma o texto, nunca a cada tecla digitada.
class GeocodingService {
  GeocodingService(this._client);

  final http.Client _client;

  static const _viaCep = 'viacep.com.br';
  static const _nominatim = 'nominatim.openstreetmap.org';
  static const _photon = 'photon.komoot.io';

  /// Sugestões enquanto a pessoa digita o campo "Local".
  ///
  /// Usa o **Photon**, e não o Nominatim: a política de uso do Nominatim
  /// proíbe busca a cada tecla, e o Photon foi feito exatamente para isso
  /// (mesmos dados do OpenStreetMap, também gratuito e sem chave).
  ///
  /// Com [perto] (a posição do aparelho, quando a pessoa já permitiu a
  /// localização), o Photon põe primeiro os resultados mais próximos. A
  /// caixa `bbox` limita ao Brasil, pelo mesmo motivo do `countrycodes` da
  /// busca do mapa.
  Future<List<EnderecoEncontrado>> sugerir(
    String termo, {
    ({double latitude, double longitude})? perto,
  }) async {
    final limpo = termo.trim();
    if (limpo.length < 3) return const [];

    final uri = Uri.https(_photon, '/api/', {
      'q': limpo,
      'limit': '5',
      'bbox': '-74.0,-34.0,-34.0,5.5',
      if (perto != null) 'lat': '${perto.latitude}',
      if (perto != null) 'lon': '${perto.longitude}',
    });

    final resposta = await _client.get(uri);
    if (resposta.statusCode != 200) return const [];

    final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    if (dados is! Map || dados['features'] is! List) return const [];

    final achados = <EnderecoEncontrado>[];
    for (final item in dados['features'] as List) {
      if (item is! Map) continue;
      final coordenadas = (item['geometry'] as Map?)?['coordinates'];
      final props = item['properties'];
      if (coordenadas is! List || coordenadas.length < 2 || props is! Map) continue;

      // "Fatec Zona Leste, Rua X 123, Cidade Tiradentes, São Paulo, SP".
      final rua = [props['street'], props['housenumber']]
          .whereType<String>()
          .join(' ');
      final partes = <String>[
        if (props['name'] is String) props['name'] as String,
        if (rua.isNotEmpty && rua != props['name']) rua,
        if (props['district'] is String) props['district'] as String,
        if (props['city'] is String) props['city'] as String,
        if (props['state'] is String) props['state'] as String,
      ];
      if (partes.isEmpty) continue;

      achados.add(EnderecoEncontrado(
        descricao: partes.toSet().join(', '),
        latitude: (coordenadas[1] as num).toDouble(),
        longitude: (coordenadas[0] as num).toDouble(),
      ));
    }
    return achados;
  }

  /// Busca por CEP ou por endereço escrito. Devolve lista vazia quando não
  /// acha nada — quem chama decide o que mostrar.
  Future<List<EnderecoEncontrado>> buscar(String termo) async {
    final limpo = termo.trim();
    if (limpo.length < 3) return const [];

    // Oito dígitos é CEP, com ou sem hífen. A checagem é pelo formato, não
    // por um campo separado na tela: assim a pessoa digita no mesmo lugar.
    final digitos = limpo.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 8 && RegExp(r'^[\d\s-]+$').hasMatch(limpo)) {
      final endereco = await _enderecoDoCep(digitos);
      if (endereco != null) {
        final achados = await _coordenadasDe(endereco);
        if (achados.isNotEmpty) return achados;
      }
      // CEP não encontrado ou sem ponto no mapa: ainda vale tentar o texto
      // cru, que às vezes o Nominatim resolve sozinho.
    }

    return _coordenadasDe(limpo);
  }

  /// CEP -> "rua, bairro, cidade, UF". Nulo se o CEP não existir.
  Future<String?> _enderecoDoCep(String cep) async {
    final uri = Uri.https(_viaCep, '/ws/$cep/json/');
    final resposta = await _client.get(uri);
    if (resposta.statusCode != 200) return null;

    final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    if (dados is! Map) return null;
    // O ViaCEP responde 200 com `{"erro": true}` quando o CEP não existe —
    // não dá para confiar só no código HTTP.
    if (dados['erro'] == true || dados['erro'] == 'true') return null;

    final partes = [
      dados['logradouro'],
      dados['bairro'],
      dados['localidade'],
      dados['uf'],
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();

    return partes.isEmpty ? null : partes.join(', ');
  }

  /// Endereço -> coordenadas, pelo Nominatim.
  Future<List<EnderecoEncontrado>> _coordenadasDe(String endereco) async {
    final uri = Uri.https(_nominatim, '/search', {
      'q': endereco,
      'format': 'jsonv2',
      'limit': '5',
      // Restringe ao Brasil: sem isso, "Rua das Flores" traz resultado de
      // Portugal antes do brasileiro.
      'countrycodes': 'br',
      'accept-language': 'pt-BR',
    });

    // O Nominatim pede que o app se identifique. No navegador esse cabeçalho
    // é controlado pelo próprio browser e não pode ser definido aqui — lá o
    // Referer cumpre esse papel.
    final headers = kIsWeb
        ? <String, String>{}
        : {'User-Agent': 'com.gustavodias.rachaapp/1.0 (racha_app)'};

    final resposta = await _client.get(uri, headers: headers);
    if (resposta.statusCode != 200) return const [];

    final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    if (dados is! List) return const [];

    final achados = <EnderecoEncontrado>[];
    for (final item in dados) {
      if (item is! Map) continue;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      final nome = item['display_name'];
      if (lat == null || lon == null || nome is! String) continue;
      achados.add(EnderecoEncontrado(
        descricao: nome,
        latitude: lat,
        longitude: lon,
      ));
    }
    return achados;
  }
}
