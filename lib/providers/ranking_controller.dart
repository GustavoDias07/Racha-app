import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/avaliacao/mvp_calculator.dart';
import '../core/ranking/agregador_ranking.dart';
import '../models/racha_model.dart';
import '../models/ranking_model.dart';
import 'firebase_providers.dart';

/// Mantém `rankings/{userId}` em dia — o recorte **global** do jogador
/// (tudo o que ele já fez, em qualquer grupo), usado pela tela de Perfil e
/// pelo balanceamento, que precisa da média de vinte e poucos jogadores no
/// clique de "Gerar times" e não pode pagar uma agregação por pessoa ali.
///
/// O recorte **por grupo** é outra coisa e vive em `rankingDoGrupoProvider`,
/// calculado na hora. Os dois passam pelo mesmo `agregarRanking`, então a
/// conta é a mesma dos dois lados.
class RankingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Refaz o ranking de um jogador **inteiro**, do zero, a partir da fonte
  /// de verdade: todas as avaliações que ele recebeu, todas as estatísticas
  /// registradas em nome dele e todos os rachas em que foi eleito MVP.
  ///
  /// Antes havia dois recálculos parciais (um só pra média, outro só pra
  /// gols/assistências) e um incremento atômico separado pro MVP — três
  /// caminhos que precisavam preservar os campos uns dos outros pra não se
  /// atropelarem. Um recálculo completo dispensa esse cuidado e ainda se
  /// autocorrige: se um valor tiver ficado errado por qualquer motivo, a
  /// próxima chamada conserta, porque nada é derivado do valor anterior.
  Future<void> recalcularRanking(String userId) async {
    final avaliacoes =
        await ref.read(avaliacaoRepositoryProvider).buscarRecebidasPor(userId);
    final estatisticas =
        await ref.read(estatisticaRepositoryProvider).buscarTodasDe(userId);
    final rachasComMvp =
        await ref.read(rachaRepositoryProvider).buscarPorMvp(userId);

    final agregado = agregarRanking(
      avaliacoes: avaliacoes,
      estatisticas: estatisticas,
      mvpUserIds: [for (var i = 0; i < rachasComMvp.length; i++) userId],
    );

    // Sem nenhum dado, grava o ranking zerado em vez de não gravar nada: o
    // documento pode existir de antes (o jogador teve avaliação que depois
    // foi reatribuída a outra pessoa, por exemplo) e precisa refletir isso.
    await ref
        .read(rankingRepositoryProvider)
        .salvar(agregado[userId] ?? RankingModel(userId: userId));
  }

  /// Elege o MVP da rodada a partir das avaliações já recebidas e atualiza o
  /// ranking de quem ganhou — e de quem perdeu o título, quando o MVP muda
  /// porque mais avaliações chegaram depois.
  Future<void> calcularMvpDaRodada(RachaModel racha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final avaliacoes = await ref
          .read(avaliacaoRepositoryProvider)
          .observarPorRacha(racha.id)
          .first;

      final resultado = calcularMvpDoRacha(avaliacoes);
      if (resultado == null) {
        throw Exception('Ainda não há avaliações suficientes pra calcular o MVP.');
      }
      if (racha.mvpUserId == resultado.avaliadoId) return;

      // O racha é gravado primeiro de propósito: o recálculo conta os
      // títulos consultando `rachas.mvpUserId`, então precisa enxergar o
      // estado novo pra chegar no número certo.
      final mvpAnterior = racha.mvpUserId;
      await ref
          .read(rachaRepositoryProvider)
          .atualizarMvp(rachaId: racha.id, mvpUserId: resultado.avaliadoId);

      await recalcularRanking(resultado.avaliadoId);
      if (mvpAnterior != null) await recalcularRanking(mvpAnterior);
    });
  }
}

final rankingControllerProvider =
    AsyncNotifierProvider<RankingController, void>(RankingController.new);
