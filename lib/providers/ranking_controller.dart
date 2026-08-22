import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/avaliacao/mvp_calculator.dart';
import '../models/racha_model.dart';
import '../models/ranking_model.dart';
import 'firebase_providers.dart';

/// Mantém o Ranking (docs/estrutura.md) em dia: recalcula a média de
/// avaliação de um User a partir da fonte de verdade (todas as avaliações
/// que ele recebeu) e calcula/credita o MVP de um racha.
class RankingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Refaz `mediaAvaliacoes` e `totalRachas` de um User do zero, a partir
  /// de todas as avaliações que ele já recebeu (qualquer racha). Preserva
  /// `totalMvps`/`totalGols`/`totalAssistencias`, que são creditados por
  /// outros fluxos (`calcularMvpDaRodada` e, futuramente, Estatísticas).
  Future<void> recalcularParaAvaliado(String userId) async {
    final avaliacaoRepo = ref.read(avaliacaoRepositoryProvider);
    final rankingRepo = ref.read(rankingRepositoryProvider);

    final recebidas = await avaliacaoRepo.buscarRecebidasPor(userId);
    final existente = await rankingRepo.buscarPorUserId(userId);

    final media = recebidas.isEmpty
        ? 0.0
        : recebidas.map((a) => a.nota).reduce((a, b) => a + b) / recebidas.length;
    final totalRachas = recebidas.map((a) => a.rachaId).toSet().length;

    await rankingRepo.salvar(
      (existente ?? RankingModel(userId: userId)).copyWith(
        mediaAvaliacoes: media,
        totalRachas: totalRachas,
      ),
    );
  }

  /// Refaz `totalGols`/`totalAssistencias` de um User do zero, a partir de
  /// todas as estatísticas que ele já acumulou (qualquer racha). Mesma
  /// lógica de `recalcularParaAvaliado`, mas pra Estatísticas em vez de
  /// Avaliações — preserva os demais campos do Ranking.
  Future<void> recalcularEstatisticas(String userId) async {
    final estatisticaRepo = ref.read(estatisticaRepositoryProvider);
    final rankingRepo = ref.read(rankingRepositoryProvider);

    final registros = await estatisticaRepo.buscarTodasDe(userId);
    final existente = await rankingRepo.buscarPorUserId(userId);

    final totalGols = registros.fold<int>(0, (soma, e) => soma + e.gols);
    final totalAssistencias =
        registros.fold<int>(0, (soma, e) => soma + e.assistencias);

    await rankingRepo.salvar(
      (existente ?? RankingModel(userId: userId)).copyWith(
        totalGols: totalGols,
        totalAssistencias: totalAssistencias,
      ),
    );
  }

  /// Calcula o MVP de um racha a partir das avaliações já recebidas e
  /// credita/descredita `totalMvps` de quem ganhou/perdeu o título — pode
  /// ser chamado de novo se mais avaliações chegarem depois (idempotente:
  /// se o MVP não mudou, não mexe em nada).
  Future<void> calcularMvpDaRodada(RachaModel racha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final avaliacaoRepo = ref.read(avaliacaoRepositoryProvider);
      final rachaRepo = ref.read(rachaRepositoryProvider);
      final rankingRepo = ref.read(rankingRepositoryProvider);

      final avaliacoes = await avaliacaoRepo.observarPorRacha(racha.id).first;
      final resultado = calcularMvpDoRacha(avaliacoes);
      if (resultado == null) {
        throw Exception('Ainda não há avaliações suficientes pra calcular o MVP.');
      }
      if (racha.mvpUserId == resultado.avaliadoId) return;

      // Incrementos atômicos (`FieldValue.increment`), não leitura seguida
      // de escrita — dois admins acionando isso ao mesmo tempo (ou um
      // clique duplo) não perdem incremento nem decrementam duas vezes.
      if (racha.mvpUserId != null) {
        await rankingRepo.incrementarMvp(racha.mvpUserId!, -1);
      }
      await rankingRepo.incrementarMvp(resultado.avaliadoId, 1);

      await rachaRepo.atualizarMvp(rachaId: racha.id, mvpUserId: resultado.avaliadoId);
    });
  }
}

final rankingControllerProvider =
    AsyncNotifierProvider<RankingController, void>(RankingController.new);
