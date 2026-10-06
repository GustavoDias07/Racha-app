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
  double? gols,
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
    golsPorJogo: gols,
  );
}

double _media(List<JogadorElegivel> time, double Function(JogadorElegivel) de) =>
    time.map(de).reduce((a, b) => a + b) / time.length;

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

  group('além da nota', () {
    // Nos testes abaixo a ordem de entrada é escolhida para que a
    // distribuição inicial (que só olha a nota) saia desequilibrada no
    // critério testado. Se o ajuste final ignorasse esse critério, os times
    // terminariam desequilibrados — que é exatamente o que o teste pega.

    test('com notas iguais, não junta os mais novos de um lado só', () {
      final elegiveis = [
        _jogador('novo1', posicaoMain: Posicao.zagueiro, idade: 18),
        _jogador('veterano1', posicaoMain: Posicao.zagueiro, idade: 40),
        _jogador('novo2', posicaoMain: Posicao.zagueiro, idade: 19),
        _jogador('veterano2', posicaoMain: Posicao.zagueiro, idade: 41),
      ];

      final r = balanceador.gerar(elegiveis, qtdJogadoresLinha: 2);

      final idadeA = _media(r.timeA, (j) => j.idade.toDouble());
      final idadeB = _media(r.timeB, (j) => j.idade.toDouble());
      // Sem o critério de idade a diferença seria de 21,5 anos.
      expect((idadeA - idadeB).abs(), lessThan(2));
    });

    test('com notas iguais, não junta os artilheiros no mesmo time', () {
      final elegiveis = [
        _jogador('artilheiro1', posicaoMain: Posicao.atacante, gols: 2.0),
        _jogador('pereba1', posicaoMain: Posicao.atacante, gols: 0.0),
        _jogador('artilheiro2', posicaoMain: Posicao.atacante, gols: 1.8),
        _jogador('pereba2', posicaoMain: Posicao.atacante, gols: 0.2),
      ];

      final r = balanceador.gerar(elegiveis, qtdJogadoresLinha: 2);

      final ids = {for (final j in r.timeA) j.id};
      // Cada time fica com exatamente um artilheiro.
      expect(
        ids.contains('artilheiro1') != ids.contains('artilheiro2'),
        isTrue,
        reason: 'os dois artilheiros caíram no mesmo time: $ids',
      );
    });

    test('a nota continua sendo o critério principal', () {
      // Conflito proposital: equilibrar a idade exigiria um time com nota
      // média 4 contra outro com 2. A nota pesa mais, então o algoritmo
      // aceita a diferença de idade para manter as notas iguais.
      final elegiveis = [
        _jogador('craque', posicaoMain: Posicao.meia, nota: 5, idade: 20),
        _jogador('fraco', posicaoMain: Posicao.meia, nota: 1, idade: 20),
        _jogador('medio1', posicaoMain: Posicao.meia, nota: 3, idade: 40),
        _jogador('medio2', posicaoMain: Posicao.meia, nota: 3, idade: 40),
      ];

      final r = balanceador.gerar(elegiveis, qtdJogadoresLinha: 2);

      final notaA = _media(r.timeA, (j) => j.nota);
      final notaB = _media(r.timeB, (j) => j.nota);
      expect((notaA - notaB).abs(), lessThan(0.5));
    });

    test('jogador sem histórico de gols não é tratado como quem não marca', () {
      // Se o desconhecido virasse zero, os três sem histórico seriam vistos
      // como "fracos no ataque" e empurrados todos contra o artilheiro.
      final elegiveis = [
        _jogador('artilheiro', posicaoMain: Posicao.atacante, gols: 2.0),
        _jogador('novo1', posicaoMain: Posicao.atacante),
        _jogador('novo2', posicaoMain: Posicao.atacante),
        _jogador('novo3', posicaoMain: Posicao.atacante),
      ];

      final r = balanceador.gerar(elegiveis, qtdJogadoresLinha: 2);

      expect(r.timeA.length + r.timeB.length, 4);
      expect((r.timeA.length - r.timeB.length).abs(), lessThanOrEqualTo(1));
    });

    test('a troca por critério secundário não desmonta os setores', () {
      final elegiveis = [
        _jogador('z1', posicaoMain: Posicao.zagueiro, idade: 18),
        _jogador('z2', posicaoMain: Posicao.zagueiro, idade: 40),
        _jogador('a1', posicaoMain: Posicao.atacante, idade: 19),
        _jogador('a2', posicaoMain: Posicao.atacante, idade: 41),
      ];

      final r = balanceador.gerar(elegiveis, qtdJogadoresLinha: 2);

      for (final setor in [SetorCampo.defesa, SetorCampo.ataque]) {
        expect(
          (_noSetor(r.timeA, setor) - _noSetor(r.timeB, setor)).abs(),
          lessThanOrEqualTo(1),
          reason: 'setor $setor desequilibrou',
        );
      }
    });
  });
}
