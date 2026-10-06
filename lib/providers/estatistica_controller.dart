import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/estatistica_model.dart';
import '../models/racha_model.dart';
import 'firebase_providers.dart';
import 'ranking_controller.dart';

/// Registra gols, assistências e cartões de um jogador (User ou Convidado)
/// num racha e, se for User, atualiza o Ranking na sequência.
///
/// Os números passam por conferência antes de contar (ver
/// `EstatisticaModel.confirmada`): o que o próprio jogador lança fica
/// pendente; o que admin ou anotador lança já nasce conferido, porque quem
/// lançou é justamente quem conferiria.
class EstatisticaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> salvar({
    required RachaModel racha,
    required String jogadorId,
    required TipoJogador jogadorTipo,
    required int gols,
    required int assistencias,
    required int cartoesAmarelos,
    required int cartoesVermelhos,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      final conferida = racha.podeConferirEstatistica(uid, jogadorId);

      await ref.read(estatisticaRepositoryProvider).salvar(EstatisticaModel(
            id: jogadorId,
            rachaId: racha.id,
            grupoId: racha.grupoId,
            jogadorId: jogadorId,
            jogadorTipo: jogadorTipo,
            gols: gols,
            assistencias: assistencias,
            cartoesAmarelos: cartoesAmarelos,
            cartoesVermelhos: cartoesVermelhos,
            // Editar depois de conferido volta para pendente: senão bastava
            // esperar a conferência e trocar o número.
            confirmada: conferida,
            conferidaPor: conferida ? uid : null,
          ));

      // Recalcula mesmo quando ficou pendente: se o jogador editou um número
      // que já estava conferido, o valor antigo precisa sair do ranking.
      if (jogadorTipo == TipoJogador.user) {
        await ref
            .read(rankingControllerProvider.notifier)
            .recalcularRanking(jogadorId);
      }
    });
  }

  /// Confere as estatísticas pendentes dos jogadores informados. Quem não
  /// pode conferir algum deles (o anotador nos próprios números) é
  /// ignorado em silêncio em vez de derrubar a conferência inteira.
  Future<void> confirmar(
    RachaModel racha,
    Iterable<EstatisticaModel> estatisticas,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      final aConferir = [
        for (final e in estatisticas)
          if (!e.confirmada && racha.podeConferirEstatistica(uid, e.jogadorId)) e,
      ];
      if (aConferir.isEmpty) return;

      await ref.read(estatisticaRepositoryProvider).confirmar(
            rachaId: racha.id,
            jogadorIds: aConferir.map((e) => e.jogadorId),
            conferidaPor: uid,
          );

      final rankingController = ref.read(rankingControllerProvider.notifier);
      for (final e in aConferir) {
        if (e.jogadorTipo == TipoJogador.user) {
          await rankingController.recalcularRanking(e.jogadorId);
        }
      }
    });
  }
}

final estatisticaControllerProvider =
    AsyncNotifierProvider<EstatisticaController, void>(EstatisticaController.new);
