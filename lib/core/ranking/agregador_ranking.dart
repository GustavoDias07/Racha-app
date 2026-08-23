import '../../models/avaliacao_model.dart';
import '../../models/enums.dart';
import '../../models/estatistica_model.dart';
import '../../models/ranking_model.dart';

/// Consolida avaliações, estatísticas e títulos de MVP num `RankingModel`
/// por jogador.
///
/// É a **única** conta de desempenho do app. Antes ela existia duplicada em
/// dois lugares — no `RankingController` (recorte global, gravado em
/// `rankings/{userId}`) e no `rankingDoGrupoProvider` (recorte por grupo,
/// calculado na hora) — e as duas versões já tinham divergido entre si em
/// detalhes de contagem, que é exatamente como um ranking passa a mostrar
/// número diferente dependendo da tela em que você olha.
///
/// Não sabe de onde os dados vieram: quem chama é que decide o recorte,
/// passando ou tudo o que o jogador já fez, ou só o que aconteceu dentro de
/// um grupo. Por isso é função pura — dá pra testar sem Firestore.
///
/// Convidados ficam de fora: o id de um Convidado não sobrevive entre
/// rodadas (é um perfil daquela rodada específica), então não existe
/// "desempenho acumulado" que se possa atribuir a ele.
Map<String, RankingModel> agregarRanking({
  required List<AvaliacaoModel> avaliacoes,
  required List<EstatisticaModel> estatisticas,
  required List<String> mvpUserIds,
}) {
  final notasPorUser = <String, List<double>>{};
  final rachasPorUser = <String, Set<String>>{};
  final golsPorUser = <String, int>{};
  final assistenciasPorUser = <String, int>{};
  final mvpsPorUser = <String, int>{};

  for (final avaliacao in avaliacoes) {
    if (avaliacao.avaliadoTipo != TipoJogador.user) continue;
    notasPorUser.putIfAbsent(avaliacao.avaliadoId, () => []).add(avaliacao.nota);
    // Atenção (T7, decisão em aberto): isto conta rodadas em que o jogador
    // foi **avaliado**, não rodadas que ele jogou. As telas já exibem como
    // "racha(s) avaliado(s)", então o número na tela não mente — quem mente
    // é o nome do campo.
    rachasPorUser
        .putIfAbsent(avaliacao.avaliadoId, () => <String>{})
        .add(avaliacao.rachaId);
  }

  for (final estatistica in estatisticas) {
    if (estatistica.jogadorTipo != TipoJogador.user) continue;
    golsPorUser.update(
      estatistica.jogadorId,
      (total) => total + estatistica.gols,
      ifAbsent: () => estatistica.gols,
    );
    assistenciasPorUser.update(
      estatistica.jogadorId,
      (total) => total + estatistica.assistencias,
      ifAbsent: () => estatistica.assistencias,
    );
  }

  for (final userId in mvpUserIds) {
    mvpsPorUser.update(userId, (total) => total + 1, ifAbsent: () => 1);
  }

  final userIds = <String>{
    ...notasPorUser.keys,
    ...golsPorUser.keys,
    ...assistenciasPorUser.keys,
    ...mvpsPorUser.keys,
  };

  return {
    for (final userId in userIds)
      userId: RankingModel(
        userId: userId,
        mediaAvaliacoes: _media(notasPorUser[userId]),
        totalMvps: mvpsPorUser[userId] ?? 0,
        totalGols: golsPorUser[userId] ?? 0,
        totalAssistencias: assistenciasPorUser[userId] ?? 0,
        totalRachas: rachasPorUser[userId]?.length ?? 0,
      ),
  };
}

double _media(List<double>? notas) {
  if (notas == null || notas.isEmpty) return 0;
  return notas.reduce((a, b) => a + b) / notas.length;
}

/// Ordem de exibição do ranking: mais títulos de MVP primeiro e, em caso de
/// empate, a melhor média. Quem tem MVP ganhou rodada; a média é o critério
/// de regularidade que desempata.
List<RankingModel> ordenarRanking(Iterable<RankingModel> ranking) {
  return ranking.toList()
    ..sort((a, b) {
      final porMvp = b.totalMvps.compareTo(a.totalMvps);
      if (porMvp != 0) return porMvp;
      return b.mediaAvaliacoes.compareTo(a.mediaAvaliacoes);
    });
}
