import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/balanceamento/balanceador_times.dart';
import 'package:racha_app/core/balanceamento/jogador_elegivel.dart';
import 'package:racha_app/models/enums.dart';

JogadorElegivel _jogador(
  String id, {
  Posicao? posicaoMain,
  Posicao? posicaoUsual,
  double nota = 3.0,
  int idade = 25,
  double peso = 75,
}) {
  return JogadorElegivel(
    id: id,
    tipo: TipoJogador.user,
    nome: id,
    posicaoMain: posicaoMain,
    posicaoUsual: posicaoUsual ?? posicaoMain,
    nota: nota,
    idade: idade,
    peso: peso,
  );
}

void main() {
  final balanceador = const BalanceadorTimes();

  test('distribui um goleiro pra cada time quando há 2 ou mais', () {
    final elegiveis = [
      _jogador('g1', posicaoMain: Posicao.goleiro),
      _jogador('g2', posicaoMain: Posicao.goleiro),
      for (var i = 0; i < 8; i++) _jogador('l$i', posicaoMain: Posicao.zagueiro),
    ];

    final resultado = balanceador.gerar(elegiveis);

    expect(resultado.timeA.where((j) => j.isGoleiro).length, 1);
    expect(resultado.timeB.where((j) => j.isGoleiro).length, 1);
  });

  test('com um único goleiro, só um time fica com ele — ninguém é descartado', () {
    final elegiveis = [
      _jogador('g1', posicaoMain: Posicao.goleiro),
      for (var i = 0; i < 6; i++) _jogador('l$i', posicaoMain: Posicao.zagueiro),
    ];

    final resultado = balanceador.gerar(elegiveis);

    final totalGoleiros =
        resultado.timeA.where((j) => j.isGoleiro).length +
            resultado.timeB.where((j) => j.isGoleiro).length;
    expect(totalGoleiros, 1);
    expect(resultado.timeA.length + resultado.timeB.length, elegiveis.length);
  });

  test('nenhum jogador é perdido ou duplicado', () {
    final elegiveis = [
      _jogador('g1', posicaoMain: Posicao.goleiro),
      _jogador('g2', posicaoMain: Posicao.goleiro),
      _jogador('g3', posicaoMain: Posicao.goleiro),
      for (var i = 0; i < 11; i++)
        _jogador(
          'l$i',
          posicaoMain: Posicao.values[i % Posicao.values.length],
          posicaoUsual: Posicao.values[(i + 1) % Posicao.values.length],
        ),
    ];

    final resultado = balanceador.gerar(elegiveis);
    final idsResultado = [...resultado.timeA, ...resultado.timeB].map((j) => j.id).toSet();

    expect(resultado.timeA.length + resultado.timeB.length, elegiveis.length);
    expect(idsResultado.length, elegiveis.length);
  });

  test('tamanho dos times difere no máximo em 1 jogador', () {
    final elegiveis = [
      for (var i = 0; i < 13; i++) _jogador('l$i', posicaoMain: Posicao.meia),
    ];

    final resultado = balanceador.gerar(elegiveis);

    expect((resultado.timeA.length - resultado.timeB.length).abs(), lessThanOrEqualTo(1));
  });

  test('com notas bem diferentes, os times ficam com soma de nota parecida', () {
    final elegiveis = [
      for (var i = 0; i < 6; i++) _jogador('bom$i', posicaoMain: Posicao.atacante, nota: 5),
      for (var i = 0; i < 6; i++) _jogador('fraco$i', posicaoMain: Posicao.atacante, nota: 1),
    ];

    final resultado = balanceador.gerar(elegiveis);
    final somaA = resultado.timeA.fold<double>(0, (s, j) => s + j.nota);
    final somaB = resultado.timeB.fold<double>(0, (s, j) => s + j.nota);

    expect((somaA - somaB).abs(), lessThanOrEqualTo(4));
  });

  test('lista vazia gera dois times vazios', () {
    final resultado = balanceador.gerar([]);

    expect(resultado.timeA, isEmpty);
    expect(resultado.timeB, isEmpty);
  });
}
