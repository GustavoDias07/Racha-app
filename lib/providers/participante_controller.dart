import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import 'firebase_providers.dart';

class ParticipanteController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> convidar({required String rachaId, required String userId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(participanteRepositoryProvider)
          .convidar(rachaId: rachaId, userId: userId);
    });
  }

  Future<void> atualizarStatus({
    required String rachaId,
    required String participanteId,
    required StatusConfirmacao status,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(participanteRepositoryProvider).atualizarStatus(
            rachaId: rachaId,
            participanteId: participanteId,
            status: status,
          );
    });
  }

  Future<void> remover({required String rachaId, required String participanteId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(participanteRepositoryProvider)
          .remover(rachaId: rachaId, participanteId: participanteId);
    });
  }

  Future<void> registrarPresenca({
    required String rachaId,
    required String participanteId,
    required PresencaFinal presenca,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(participanteRepositoryProvider).registrarPresenca(
            rachaId: rachaId,
            participanteId: participanteId,
            presenca: presenca,
          );
    });
  }

  Future<void> definirPosicoes({
    required String rachaId,
    required String participanteId,
    required Posicao posicaoMain,
    required Posicao posicaoUsual,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(participanteRepositoryProvider).definirPosicoes(
            rachaId: rachaId,
            participanteId: participanteId,
            posicaoMain: posicaoMain,
            posicaoUsual: posicaoUsual,
          );
    });
  }
}

final participanteControllerProvider =
    AsyncNotifierProvider<ParticipanteController, void>(ParticipanteController.new);
