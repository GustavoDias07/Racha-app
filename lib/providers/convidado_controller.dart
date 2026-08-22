import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/convidado_model.dart';
import '../models/enums.dart';
import 'firebase_providers.dart';
import 'ranking_controller.dart';

class ConvidadoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> adicionar({
    required String rachaId,
    required String convidadoPor,
    required String nome,
    required int idadeAproximada,
    required double pesoAproximado,
    Posicao? posicaoMain,
    Posicao? posicaoUsual,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final convidado = ConvidadoModel(
        id: '',
        rachaId: rachaId,
        convidadoPor: convidadoPor,
        nome: nome,
        idadeAproximada: idadeAproximada,
        pesoAproximado: pesoAproximado,
        posicaoMain: posicaoMain,
        posicaoUsual: posicaoUsual,
      );
      return ref.read(convidadoRepositoryProvider).adicionar(convidado);
    });
  }

  Future<void> atualizarAprovacao({
    required String rachaId,
    required String convidadoId,
    required StatusAprovacao status,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(convidadoRepositoryProvider).atualizarAprovacao(
            rachaId: rachaId,
            convidadoId: convidadoId,
            status: status,
          );
    });
  }

  /// Fluxo 3.1 (docs/estrutura.md): o convidado já criou a própria conta
  /// (User, pelo Cadastro normal) e o admin vincula esse `userId` ao
  /// histórico que ele acumulou como convidado — migra avaliações e
  /// estatísticas, marca o perfil temporário como oficializado e recalcula
  /// o Ranking do User com esse histórico recém-herdado.
  Future<void> oficializar({
    required String rachaId,
    required String convidadoId,
    required String userId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(avaliacaoRepositoryProvider)
          .reatribuirParaUser(convidadoId: convidadoId, userId: userId);
      await ref
          .read(estatisticaRepositoryProvider)
          .copiarParaUser(convidadoId: convidadoId, userId: userId);
      await ref.read(convidadoRepositoryProvider).marcarOficializado(
            rachaId: rachaId,
            convidadoId: convidadoId,
            userId: userId,
          );

      final rankingController = ref.read(rankingControllerProvider.notifier);
      await rankingController.recalcularParaAvaliado(userId);
      await rankingController.recalcularEstatisticas(userId);
    });
  }
}

final convidadoControllerProvider =
    AsyncNotifierProvider<ConvidadoController, void>(ConvidadoController.new);
