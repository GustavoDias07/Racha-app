import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/balanceamento/balanceador_times.dart';
import 'package:racha_app/core/balanceamento/jogador_elegivel.dart';
import 'package:racha_app/core/balanceamento/setores.dart';
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

/// Quantos jogadores do time atuam neste setor, contando pela posição em que
/// eles foram efetivamente escalados (main, ou usual quando a main não é de
/// linha) — mesma conta que o balanceador faz.
int _noSetor(List<JogadorElegivel> time, SetorCampo setor) =>
    time.where((j) => !j.isGoleiro && setorDoJogador(j) == setor).length;

void main() {
  const balanceador = BalanceadorTimes();

  test('distribui um goleiro pra cada time quando há 2 ou mais', () {
    final elegiveis = [
      _jogador('g1', posicaoMain: Posicao.goleiro),
      _jogador('g2', posicaoMain: Posicao.goleiro),
      for (var i = 0; i < 8; i++) _jogador('l$i', posicaoMain: Posicao.zagueiro),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 4);

    expect(resultado.timeA.where((j) => j.isGoleiro).length, 1);
    expect(resultado.timeB.where((j) => j.isGoleiro).length, 1);
  });

  test('com um único goleiro, só um time fica com ele — ninguém é descartado', () {
    final elegiveis = [
      _jogador('g1', posicaoMain: Posicao.goleiro),
      for (var i = 0; i < 6; i++) _jogador('l$i', posicaoMain: Posicao.zagueiro),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 4);

    final totalGoleiros = resultado.timeA.where((j) => j.isGoleiro).length +
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

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 6);
    final idsResultado =
        [...resultado.timeA, ...resultado.timeB].map((j) => j.id).toSet();

    expect(resultado.timeA.length + resultado.timeB.length, elegiveis.length);
    expect(idsResultado.length, elegiveis.length);
  });

  test('tamanho dos times difere no máximo em 1 jogador', () {
    final elegiveis = [
      for (var i = 0; i < 13; i++) _jogador('l$i', posicaoMain: Posicao.meia),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 6);

    expect((resultado.timeA.length - resultado.timeB.length).abs(),
        lessThanOrEqualTo(1));
  });

  test('mesmo com setores desiguais, o tamanho dos times não desequilibra', () {
    // 3 de cada setor: se cada setor fosse dividido isoladamente, o time A
    // poderia levar os três "sobrando" e abrir 3 de diferença.
    final elegiveis = [
      for (var i = 0; i < 3; i++) _jogador('z$i', posicaoMain: Posicao.zagueiro),
      for (var i = 0; i < 3; i++) _jogador('m$i', posicaoMain: Posicao.meia),
      for (var i = 0; i < 3; i++) _jogador('a$i', posicaoMain: Posicao.atacante),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 6);

    expect((resultado.timeA.length - resultado.timeB.length).abs(),
        lessThanOrEqualTo(1));
  });

  test('cada setor fica dividido igualmente entre os dois times', () {
    final elegiveis = [
      _jogador('g1', posicaoMain: Posicao.goleiro),
      _jogador('g2', posicaoMain: Posicao.goleiro),
      for (var i = 0; i < 4; i++) _jogador('z$i', posicaoMain: Posicao.zagueiro),
      for (var i = 0; i < 4; i++) _jogador('m$i', posicaoMain: Posicao.meia),
      for (var i = 0; i < 4; i++) _jogador('a$i', posicaoMain: Posicao.atacante),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 6);

    for (final setor in SetorCampo.values) {
      expect(
        (_noSetor(resultado.timeA, setor) - _noSetor(resultado.timeB, setor))
            .abs(),
        lessThanOrEqualTo(1),
        reason: 'setor ${setor.label} ficou desequilibrado entre os times',
      );
    }
  });

  test('com notas bem diferentes, os times ficam com soma de nota parecida', () {
    final elegiveis = [
      for (var i = 0; i < 6; i++)
        _jogador('bom$i', posicaoMain: Posicao.atacante, nota: 5),
      for (var i = 0; i < 6; i++)
        _jogador('fraco$i', posicaoMain: Posicao.atacante, nota: 1),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 6);
    final somaA = resultado.timeA.fold<double>(0, (s, j) => s + j.nota);
    final somaB = resultado.timeB.fold<double>(0, (s, j) => s + j.nota);

    expect((somaA - somaB).abs(), lessThanOrEqualTo(4));
  });

  test('setores ímpares com notas desiguais ainda fecham com médias próximas', () {
    // Caso que quebrava antes do ajuste final por troca: cada setor com três
    // jogadores e notas muito diferentes. Os setores e os tamanhos ficavam
    // perfeitos, mas um time saía com média 3,9 contra 2,5 do outro.
    final elegiveis = [
      _jogador('zag1', posicaoMain: Posicao.zagueiro, nota: 5),
      _jogador('zag2', posicaoMain: Posicao.zagueiro, nota: 4),
      _jogador('zag3', posicaoMain: Posicao.zagueiro, nota: 1),
      _jogador('mei1', posicaoMain: Posicao.meia, nota: 5),
      _jogador('mei2', posicaoMain: Posicao.meia, nota: 1.5),
      _jogador('mei3', posicaoMain: Posicao.meia, nota: 1),
      _jogador('ata1', posicaoMain: Posicao.atacante, nota: 5),
      _jogador('ata2', posicaoMain: Posicao.atacante, nota: 4.5),
      _jogador('ata3', posicaoMain: Posicao.atacante, nota: 1),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 6);

    double media(List<JogadorElegivel> time) =>
        time.fold<double>(0, (s, j) => s + j.nota) / time.length;

    expect((media(resultado.timeA) - media(resultado.timeB)).abs(),
        lessThan(0.5));

    // O ajuste por troca não pode ter desfeito o equilíbrio de setor.
    for (final setor in SetorCampo.values) {
      expect(
        (_noSetor(resultado.timeA, setor) - _noSetor(resultado.timeB, setor))
            .abs(),
        lessThanOrEqualTo(1),
        reason: 'setor ${setor.label} desequilibrou depois da troca por nota',
      );
    }
    expect((resultado.timeA.length - resultado.timeB.length).abs(),
        lessThanOrEqualTo(1));
  });

  test('a troca por nota não muda o goleiro de função', () {
    final elegiveis = [
      _jogador('g1', posicaoMain: Posicao.goleiro, nota: 5),
      _jogador('g2', posicaoMain: Posicao.goleiro, nota: 1),
      for (var i = 0; i < 3; i++)
        _jogador('z$i', posicaoMain: Posicao.zagueiro, nota: 5),
      for (var i = 0; i < 3; i++)
        _jogador('a$i', posicaoMain: Posicao.atacante, nota: 1),
    ];

    final resultado = balanceador.gerar(elegiveis, qtdJogadoresLinha: 4);

    expect(resultado.timeA.where((j) => j.isGoleiro).length, 1);
    expect(resultado.timeB.where((j) => j.isGoleiro).length, 1);
  });

  test('lista vazia gera dois times vazios', () {
    final resultado = balanceador.gerar([], qtdJogadoresLinha: 6);

    expect(resultado.timeA, isEmpty);
    expect(resultado.timeB, isEmpty);
  });
}
