import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/balanceamento/jogador_elegivel.dart';
import 'package:racha_app/core/balanceamento/setores.dart';
import 'package:racha_app/models/enums.dart';

JogadorElegivel _jogador(
  String id, {
  Posicao? posicaoMain,
  Posicao? posicaoUsual,
  double nota = 3.0,
}) {
  return JogadorElegivel(
    id: id,
    tipo: TipoJogador.user,
    nome: id,
    posicaoMain: posicaoMain,
    posicaoUsual: posicaoUsual ?? posicaoMain,
    nota: nota,
    idade: 25,
    peso: 75,
  );
}

List<String> _ids(Iterable<JogadorElegivel> jogadores) =>
    jogadores.map((j) => j.id).toList();

void main() {
  group('distribuicaoIdeal', () {
    test('society (6 de linha) pede 2-2-2', () {
      expect(distribuicaoIdeal(6), {
        SetorCampo.defesa: 2,
        SetorCampo.meio: 2,
        SetorCampo.ataque: 2,
      });
    });

    test('campão (10 de linha) pede 4-4-2', () {
      expect(distribuicaoIdeal(10), {
        SetorCampo.defesa: 4,
        SetorCampo.meio: 4,
        SetorCampo.ataque: 2,
      });
    });

    test('formação fora da tabela cai na proporção, sem perder jogador', () {
      final ideal = distribuicaoIdeal(14);
      expect(ideal.values.reduce((a, b) => a + b), 14);
    });
  });

  group('distribuirPorSetor', () {
    test('sem falta em lugar nenhum, todo mundo joga na posição main', () {
      final linha = [
        for (var i = 0; i < 4; i++)
          _jogador('z$i', posicaoMain: Posicao.zagueiro, posicaoUsual: Posicao.meia),
        for (var i = 0; i < 4; i++) _jogador('m$i', posicaoMain: Posicao.meia),
        for (var i = 0; i < 4; i++) _jogador('a$i', posicaoMain: Posicao.atacante),
      ];

      final escalacao = distribuirPorSetor(linha, qtdJogadoresLinha: 6);

      expect(escalacao.porSetor[SetorCampo.defesa]!.length, 4);
      expect(escalacao.porSetor[SetorCampo.meio]!.length, 4);
      expect(escalacao.porSetor[SetorCampo.ataque]!.length, 4);
      expect(escalacao.semSetor, isEmpty);
    });

    test('meio vazio é reforçado por atacantes que jogam de meia', () {
      final linha = [
        for (var i = 0; i < 4; i++) _jogador('z$i', posicaoMain: Posicao.zagueiro),
        // Oito atacantes, nenhum meia: quatro deles também jogam de meia.
        for (var i = 0; i < 4; i++)
          _jogador('a-versatil$i',
              posicaoMain: Posicao.atacante, posicaoUsual: Posicao.meia),
        for (var i = 0; i < 4; i++) _jogador('a-fixo$i', posicaoMain: Posicao.atacante),
      ];

      final escalacao = distribuirPorSetor(linha, qtdJogadoresLinha: 6);

      // O alvo de meio é 2 por time = 4 no total, e existem exatamente 4
      // atacantes que jogam ali.
      expect(escalacao.porSetor[SetorCampo.meio]!.length, 4);
      expect(
        _ids(escalacao.porSetor[SetorCampo.meio]!)..sort(),
        ['a-versatil0', 'a-versatil1', 'a-versatil2', 'a-versatil3'],
      );
      // Quem só joga na frente não foi mexido.
      expect(_ids(escalacao.porSetor[SetorCampo.ataque]!)..sort(),
          ['a-fixo0', 'a-fixo1', 'a-fixo2', 'a-fixo3']);
    });

    test('quem tem nota menor é o remanejado, os melhores ficam na main', () {
      final linha = [
        for (var i = 0; i < 4; i++) _jogador('z$i', posicaoMain: Posicao.zagueiro),
        for (var i = 0; i < 4; i++) _jogador('m$i', posicaoMain: Posicao.meia),
        _jogador('craque',
            posicaoMain: Posicao.atacante, posicaoUsual: Posicao.meia, nota: 5),
        _jogador('reserva',
            posicaoMain: Posicao.atacante, posicaoUsual: Posicao.meia, nota: 2),
        for (var i = 0; i < 4; i++) _jogador('a$i', posicaoMain: Posicao.atacante),
      ];

      // Meio já tem 4 (o alvo), ataque tem 6 e sobra: ninguém precisa sair.
      final semFalta = distribuirPorSetor(linha, qtdJogadoresLinha: 6);
      expect(_ids(semFalta.porSetor[SetorCampo.meio]!), ['m0', 'm1', 'm2', 'm3']);

      // Já num campão (4 meias por time = 8 no total) faltam 4 no meio, e o
      // ataque tem só dois candidatos com a usual lá.
      final comFalta = distribuirPorSetor(linha, qtdJogadoresLinha: 10);
      final meio = _ids(comFalta.porSetor[SetorCampo.meio]!);
      expect(meio, contains('reserva'));
      expect(meio, contains('craque'));
      // Os dois foram porque não havia mais ninguém — o de menor nota sai
      // primeiro.
      expect(meio.indexOf('reserva'), lessThan(meio.indexOf('craque')));
    });

    test('quem não declarou posição tapa o buraco antes de mexer nos outros', () {
      final linha = [
        for (var i = 0; i < 4; i++) _jogador('z$i', posicaoMain: Posicao.zagueiro),
        for (var i = 0; i < 6; i++)
          _jogador('a$i', posicaoMain: Posicao.atacante, posicaoUsual: Posicao.meia),
        _jogador('sem-posicao'),
      ];

      final escalacao = distribuirPorSetor(linha, qtdJogadoresLinha: 6);

      expect(_ids(escalacao.porSetor[SetorCampo.meio]!), contains('sem-posicao'));
      expect(escalacao.semSetor, isEmpty);
      // São 11 jogadores para 12 vagas ideais (4-4-4 somando os dois times),
      // então alguém tinha que ficar em falta. O ataque cede jogadores até
      // chegar no próprio alvo e para por aí: tapar o meio abrindo um buraco
      // no ataque não resolveria nada.
      expect(escalacao.porSetor[SetorCampo.ataque]!.length, 4);
      expect(escalacao.porSetor[SetorCampo.meio]!.length, 3);
    });

    test('sem ninguém que jogue no setor em falta, o racha entra desfalcado', () {
      final linha = [
        for (var i = 0; i < 4; i++) _jogador('z$i', posicaoMain: Posicao.zagueiro),
        for (var i = 0; i < 8; i++) _jogador('a$i', posicaoMain: Posicao.atacante),
      ];

      final escalacao = distribuirPorSetor(linha, qtdJogadoresLinha: 6);

      expect(escalacao.porSetor[SetorCampo.meio], isEmpty);
      expect(escalacao.porSetor[SetorCampo.ataque]!.length, 8);
    });

    test('goleiro excedente vira linha pela posição usual', () {
      final linha = [
        _jogador('g3', posicaoMain: Posicao.goleiro, posicaoUsual: Posicao.zagueiro),
      ];

      final escalacao = distribuirPorSetor(linha, qtdJogadoresLinha: 6);

      expect(_ids(escalacao.porSetor[SetorCampo.defesa]!), ['g3']);
    });
  });
}
