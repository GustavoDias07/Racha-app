import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/presenca/pontuacao_presenca.dart';
import 'package:racha_app/models/enums.dart';

CandidatoVaga _candidato(
  String id, {
  List<int>? historico,
  bool atrasou = false,
  int? confirmouNoMinuto,
}) {
  return CandidatoVaga(
    id: id,
    pontuacao: historico == null ? null : PontuacaoPresenca(historico),
    atrasou: atrasou,
    confirmadoEm: confirmouNoMinuto == null
        ? null
        : DateTime(2026, 10, 26, 10, confirmouNoMinuto),
  );
}

List<String> _ids(List<CandidatoVaga> lista) => [for (final c in lista) c.id];

void main() {
  group('pontosDaRodada', () {
    test('confirmou e foi vale +3, inclusive atrasado', () {
      expect(
        pontosDaRodada(
          confirmacao: StatusConfirmacao.confirmado,
          presenca: PresencaFinal.compareceu,
        ),
        3,
      );
      expect(
        pontosDaRodada(
          confirmacao: StatusConfirmacao.confirmado,
          presenca: PresencaFinal.atrasou,
        ),
        3,
      );
    });

    test('confirmou e faltou vale -1', () {
      expect(
        pontosDaRodada(
          confirmacao: StatusConfirmacao.confirmado,
          presenca: PresencaFinal.faltou,
        ),
        -1,
      );
    });

    test('disse que não vai, ou nem respondeu, vale 0', () {
      expect(
        pontosDaRodada(confirmacao: StatusConfirmacao.recusado, presenca: null),
        0,
      );
      expect(
        pontosDaRodada(confirmacao: StatusConfirmacao.pendente, presenca: null),
        0,
      );
    });

    test('confirmou mas ficou sem chamada não entra no histórico', () {
      expect(
        pontosDaRodada(confirmacao: StatusConfirmacao.confirmado, presenca: null),
        isNull,
      );
    });
  });

  test('o histórico guarda só as últimas 10 rodadas', () {
    var historico = <int>[];
    for (var i = 0; i < 12; i++) {
      historico = acrescentarAoHistorico(historico, i);
    }
    expect(historico, [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
  });

  test('a pontuação só vale a partir de 3 rodadas', () {
    expect(const PontuacaoPresenca([3, 3]).valida, isFalse);
    expect(const PontuacaoPresenca([3, 3, -1]).valida, isTrue);
    expect(const PontuacaoPresenca([3, 3, -1]).total, 5);
  });

  group('montarElenco', () {
    test('se cabe todo mundo, ninguém fica no banco', () {
      final elenco = montarElenco(
        [_candidato('a'), _candidato('b')],
        vagas: 2,
      );
      expect(elenco.banco, isEmpty);
    });

    test('quem tem menos pontos fica no banco', () {
      final elenco = montarElenco(
        [
          _candidato('assiduo', historico: [3, 3, 3]),
          _candidato('faltoso', historico: [-1, -1, 3]),
          _candidato('medio', historico: [3, 0, 3]),
        ],
        vagas: 2,
      );
      expect(_ids(elenco.titulares), ['assiduo', 'medio']);
      expect(_ids(elenco.banco), ['faltoso']);
    });

    test('dizer que não vai não derruba ninguém para o banco', () {
      // Quem recusou uma rodada (0) continua na frente de quem faltou (-1).
      final elenco = montarElenco(
        [
          _candidato('recusou', historico: [3, 3, 0]),
          _candidato('faltou', historico: [3, 3, -1]),
        ],
        vagas: 1,
      );
      expect(_ids(elenco.banco), ['faltou']);
    });

    test('quem atrasou perde a vaga nesta rodada, mesmo com mais pontos', () {
      final elenco = montarElenco(
        [
          _candidato('atrasado', historico: [3, 3, 3], atrasou: true),
          _candidato('pontual', historico: [3, 0, 0]),
        ],
        vagas: 1,
      );
      expect(_ids(elenco.titulares), ['pontual']);
      expect(_ids(elenco.banco), ['atrasado']);
    });

    test('empate de pontos: fica quem confirmou primeiro', () {
      final elenco = montarElenco(
        [
          _candidato('depois', historico: [3, 3, 3], confirmouNoMinuto: 30),
          _candidato('antes', historico: [3, 3, 3], confirmouNoMinuto: 5),
        ],
        vagas: 1,
      );
      expect(_ids(elenco.titulares), ['antes']);
    });

    test('quem ainda não tem pontuação entra com a média do grupo', () {
      // Média de quem tem pontuação válida: (9 + 3) / 2 = 6. O novato fica
      // entre os dois.
      final elenco = montarElenco(
        [
          _candidato('nove', historico: [3, 3, 3]),
          _candidato('tres', historico: [3, 0, 0]),
          _candidato('novato'),
        ],
        vagas: 2,
      );
      expect(_ids(elenco.titulares), ['nove', 'novato']);
      expect(_ids(elenco.banco), ['tres']);
    });
  });
}
