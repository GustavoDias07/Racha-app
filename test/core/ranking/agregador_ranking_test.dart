import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/ranking/agregador_ranking.dart';
import 'package:racha_app/models/avaliacao_model.dart';
import 'package:racha_app/models/enums.dart';
import 'package:racha_app/models/estatistica_model.dart';

AvaliacaoModel _avaliacao(
  String avaliadoId,
  double nota, {
  String rachaId = 'racha1',
  TipoJogador tipo = TipoJogador.user,
}) {
  return AvaliacaoModel(
    id: '$avaliadoId-$rachaId-$nota',
    rachaId: rachaId,
    avaliadorId: 'quem-avaliou',
    avaliadoId: avaliadoId,
    avaliadoTipo: tipo,
    nota: nota,
  );
}

EstatisticaModel _estatistica(
  String jogadorId, {
  String rachaId = 'racha1',
  int gols = 0,
  int assistencias = 0,
  TipoJogador tipo = TipoJogador.user,
  bool confirmada = true,
}) {
  return EstatisticaModel(
    id: jogadorId,
    rachaId: rachaId,
    jogadorId: jogadorId,
    jogadorTipo: tipo,
    gols: gols,
    assistencias: assistencias,
    confirmada: confirmada,
  );
}

void main() {
  test('média é a das notas recebidas', () {
    final ranking = agregarRanking(
      avaliacoes: [
        _avaliacao('ana', 5),
        _avaliacao('ana', 4),
        _avaliacao('ana', 3),
      ],
      estatisticas: const [],
      mvpUserIds: const [],
    );

    expect(ranking['ana']!.mediaAvaliacoes, 4);
  });

  test('gols e assistências somam entre as rodadas', () {
    final ranking = agregarRanking(
      avaliacoes: const [],
      estatisticas: [
        _estatistica('bia', rachaId: 'r1', gols: 2, assistencias: 1),
        _estatistica('bia', rachaId: 'r2', gols: 3, assistencias: 2),
      ],
      mvpUserIds: const [],
    );

    expect(ranking['bia']!.totalGols, 5);
    expect(ranking['bia']!.totalAssistencias, 3);
    // Só estatística, sem nenhuma avaliação: a média fica zerada em vez de
    // dividir por zero.
    expect(ranking['bia']!.mediaAvaliacoes, 0);
  });

  test('títulos de MVP são contados por repetição na lista', () {
    final ranking = agregarRanking(
      avaliacoes: [_avaliacao('caio', 4)],
      estatisticas: const [],
      mvpUserIds: const ['caio', 'caio', 'duda'],
    );

    expect(ranking['caio']!.totalMvps, 2);
    expect(ranking['duda']!.totalMvps, 1);
  });

  test('convidado fica de fora: o id dele não sobrevive entre rodadas', () {
    final ranking = agregarRanking(
      avaliacoes: [
        _avaliacao('convidado1', 5, tipo: TipoJogador.convidado),
        _avaliacao('ana', 3),
      ],
      estatisticas: [
        _estatistica('convidado1', gols: 4, tipo: TipoJogador.convidado),
      ],
      mvpUserIds: const [],
    );

    expect(ranking.containsKey('convidado1'), isFalse);
    expect(ranking.keys, ['ana']);
  });

  test('jogador aparece mesmo tendo só MVP, sem avaliação nem estatística', () {
    final ranking = agregarRanking(
      avaliacoes: const [],
      estatisticas: const [],
      mvpUserIds: const ['eva'],
    );

    expect(ranking['eva']!.totalMvps, 1);
    expect(ranking['eva']!.mediaAvaliacoes, 0);
  });

  test('ordena por MVPs e usa a média como desempate', () {
    final ranking = agregarRanking(
      avaliacoes: [
        _avaliacao('regular', 5),
        _avaliacao('artilheiro', 3),
        _avaliacao('esforcado', 4),
      ],
      estatisticas: const [],
      mvpUserIds: const ['artilheiro', 'artilheiro'],
    );

    final ordenado = ordenarRanking(ranking.values);

    expect(ordenado.map((r) => r.userId).toList(),
        ['artilheiro', 'regular', 'esforcado']);
  });

  test('estatística ainda não conferida fica fora do ranking', () {
    final ranking = agregarRanking(
      avaliacoes: const [],
      estatisticas: [
        _estatistica('gabi', rachaId: 'r1', gols: 2),
        // Lançada pela própria jogadora e ninguém conferiu: não conta.
        _estatistica('gabi', rachaId: 'r2', gols: 10, confirmada: false),
      ],
      mvpUserIds: const [],
    );

    expect(ranking['gabi']!.totalGols, 2);
  });

  test('documento antigo, sem o campo de conferência, continua contando', () {
    final antiga = EstatisticaModel.fromMap('hugo', {
      'rachaId': 'r1',
      'jogadorId': 'hugo',
      'jogadorTipo': 'user',
      'gols': 3,
    });

    final ranking = agregarRanking(
      avaliacoes: const [],
      estatisticas: [antiga],
      mvpUserIds: const [],
    );

    expect(ranking['hugo']!.totalGols, 3);
  });
}
