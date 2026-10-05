import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:racha_app/services/geocoding_service.dart';

/// Toda resposta precisa declarar `charset=utf-8`, como ViaCEP e Nominatim
/// fazem de verdade. Sem o charset, o `http.Response` codifica o corpo em
/// **latin1**, e aí `utf8.decode(bodyBytes)` estoura no primeiro acento —
/// o serviço está certo, quem mentiria seria o teste.
http.Response _json(String corpo) => http.Response(
      corpo,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Resposta do Nominatim com um resultado. `lat`/`lon` vêm como **texto**,
/// não número — é assim que a API responde de verdade, e por isso o serviço
/// usa `double.tryParse` em vez de casting.
String _nominatimCom({String nome = 'Avenida Paulista, São Paulo'}) {
  return jsonEncode([
    {'lat': '-23.5646916', 'lon': '-46.6524691', 'display_name': nome}
  ]);
}

void main() {
  test('CEP válido passa pelo ViaCEP antes de buscar as coordenadas', () async {
    final chamadas = <String>[];
    final client = MockClient((req) async {
      chamadas.add(req.url.host);
      if (req.url.host.contains('viacep')) {
        return _json(jsonEncode({
          'logradouro': 'Avenida Paulista',
          'bairro': 'Bela Vista',
          'localidade': 'São Paulo',
          'uf': 'SP',
        }));
      }
      return _json(_nominatimCom());
    });

    final achados = await GeocodingService(client).buscar('01310-100');

    expect(chamadas, ['viacep.com.br', 'nominatim.openstreetmap.org']);
    expect(achados, hasLength(1));
    expect(achados.first.latitude, closeTo(-23.5646916, 0.0000001));
    expect(achados.first.longitude, closeTo(-46.6524691, 0.0000001));
  });

  test('CEP inexistente cai na busca por texto', () async {
    // O ViaCEP responde 200 mesmo quando o CEP não existe, com `erro` como
    // a STRING "true" — confiar no código HTTP daria um falso positivo.
    final client = MockClient((req) async {
      if (req.url.host.contains('viacep')) {
        return _json(jsonEncode({'erro': 'true'}));
      }
      return _json(_nominatimCom());
    });

    final achados = await GeocodingService(client).buscar('99999-999');

    expect(achados, hasLength(1));
  });

  test('endereço escrito vai direto ao Nominatim, sem passar pelo ViaCEP',
      () async {
    final hosts = <String>[];
    final client = MockClient((req) async {
      hosts.add(req.url.host);
      return _json(_nominatimCom());
    });

    await GeocodingService(client).buscar('Rua Paulo de Oliveira e Souza 425');

    expect(hosts, ['nominatim.openstreetmap.org']);
  });

  test('a busca é limitada ao Brasil', () async {
    Uri? consultada;
    final client = MockClient((req) async {
      consultada = req.url;
      return _json(_nominatimCom());
    });

    await GeocodingService(client).buscar('Rua das Flores');

    // Sem isso, "Rua das Flores" traz resultado de Portugal antes do
    // brasileiro.
    expect(consultada!.queryParameters['countrycodes'], 'br');
  });

  test('termo curto demais não chega a consultar a rede', () async {
    var chamou = false;
    final client = MockClient((_) async {
      chamou = true;
      return _json('[]');
    });

    final achados = await GeocodingService(client).buscar('ab');

    expect(chamou, isFalse);
    expect(achados, isEmpty);
  });

  test('resposta sem coordenada utilizável é descartada, não quebra', () async {
    final client = MockClient((_) async {
      return _json(jsonEncode([
        {'lat': 'nao-e-numero', 'lon': '-46.6', 'display_name': 'X'},
        {'lat': '-23.5', 'lon': '-46.6', 'display_name': 'Y'},
      ]));
    });

    final achados = await GeocodingService(client).buscar('Avenida Paulista');

    expect(achados, hasLength(1));
    expect(achados.first.descricao, 'Y');
  });
}
