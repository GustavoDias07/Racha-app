import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/avaliacao/mvp_calculator.dart';
import 'package:racha_app/models/avaliacao_model.dart';
import 'package:racha_app/models/enums.dart';

AvaliacaoModel _avaliacao({
  required String avaliadoId,
  required double nota,
  TipoJogador tipo = TipoJogador.user,
  String avaliadorId = 'qualquer',
}) {
  return AvaliacaoModel(
    id: '',
    rachaId: 'racha1',
    avaliadorId: avaliadorId,
    avaliadoId: avaliadoId,
    avaliadoTipo: tipo,
    nota: nota,
  );
}

void main() {
  test('sem avaliações, não há MVP', () {
    expect(calcularMvpDoRacha([]), isNull);
  });

  test('elege quem tem a maior média de nota', () {
    final resultado = calcularMvpDoRacha([
      _avaliacao(avaliadoId: 'a', nota: 5),
      _avaliacao(avaliadoId: 'a', nota: 4),
      _avaliacao(avaliadoId: 'b', nota: 3),
      _avaliacao(avaliadoId: 'b', nota: 3),
    ]);

    expect(resultado!.avaliadoId, 'a');
    expect(resultado.mediaNota, 4.5);
  });

  test('empate na média é resolvido por quem recebeu mais avaliações', () {
    final resultado = calcularMvpDoRacha([
      _avaliacao(avaliadoId: 'poucos-votos', nota: 5),
      _avaliacao(avaliadoId: 'muitos-votos', nota: 5),
      _avaliacao(avaliadoId: 'muitos-votos', nota: 5),
      _avaliacao(avaliadoId: 'muitos-votos', nota: 5),
    ]);

    expect(resultado!.avaliadoId, 'muitos-votos');
  });

  test('ignora avaliações de Convidados — só User pode ser MVP', () {
    final resultado = calcularMvpDoRacha([
      _avaliacao(avaliadoId: 'convidado1', nota: 5, tipo: TipoJogador.convidado),
      _avaliacao(avaliadoId: 'user1', nota: 3),
    ]);

    expect(resultado!.avaliadoId, 'user1');
  });

  test('só há avaliações de convidados: não há MVP', () {
    final resultado = calcularMvpDoRacha([
      _avaliacao(avaliadoId: 'convidado1', nota: 5, tipo: TipoJogador.convidado),
    ]);

    expect(resultado, isNull);
  });
}
