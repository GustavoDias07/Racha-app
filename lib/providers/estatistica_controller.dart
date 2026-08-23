import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/estatistica_model.dart';
import 'firebase_providers.dart';
import 'ranking_controller.dart';

/// Registra gols, assistências e cartões de um jogador (User ou Convidado)
/// num racha e, se for User, atualiza o Ranking na sequência.
class EstatisticaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> salvar({
    required String rachaId,
    required String? grupoId,
    required String jogadorId,
    required TipoJogador jogadorTipo,
    required int gols,
    required int assistencias,
    required int cartoesAmarelos,
    required int cartoesVermelhos,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(estatisticaRepositoryProvider).salvar(EstatisticaModel(
            id: jogadorId,
            rachaId: rachaId,
            grupoId: grupoId,
            jogadorId: jogadorId,
            jogadorTipo: jogadorTipo,
            gols: gols,
            assistencias: assistencias,
            cartoesAmarelos: cartoesAmarelos,
            cartoesVermelhos: cartoesVermelhos,
          ));

      if (jogadorTipo == TipoJogador.user) {
        await ref
            .read(rankingControllerProvider.notifier)
            .recalcularRanking(jogadorId);
      }
    });
  }
}

final estatisticaControllerProvider =
    AsyncNotifierProvider<EstatisticaController, void>(EstatisticaController.new);
