import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alvo_avaliacao.dart';
import '../models/avaliacao_model.dart';
import '../models/enums.dart';
import 'firebase_providers.dart';
import 'ranking_controller.dart';

/// Grava as avaliações pós-jogo de um usuário (companheiros de time + 1
/// adversário escolhido) e, em seguida, atualiza o Ranking de cada User
/// avaliado — Convidados não têm Ranking (ver docs/estrutura.md, Fluxo 3.1).
class AvaliacaoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> enviarAvaliacoes({
    required String rachaId,
    required String avaliadorId,
    required List<(AlvoAvaliacao alvo, double nota)> alvosComNota,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final avaliacaoRepo = ref.read(avaliacaoRepositoryProvider);

      await avaliacaoRepo.avaliarEmLote([
        for (final (alvo, nota) in alvosComNota)
          AvaliacaoModel(
            id: '',
            rachaId: rachaId,
            avaliadorId: avaliadorId,
            avaliadoId: alvo.id,
            avaliadoTipo: alvo.tipo,
            nota: nota,
          ),
      ]);

      final rankingController = ref.read(rankingControllerProvider.notifier);
      final usuariosAfetados = <String>{
        for (final (alvo, _) in alvosComNota)
          if (alvo.tipo == TipoJogador.user) alvo.id,
      };
      for (final userId in usuariosAfetados) {
        await rankingController.recalcularParaAvaliado(userId);
      }
    });
  }
}

final avaliacaoControllerProvider =
    AsyncNotifierProvider<AvaliacaoController, void>(AvaliacaoController.new);
