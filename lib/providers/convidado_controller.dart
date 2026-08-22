import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/convidado_model.dart';
import '../models/enums.dart';
import 'firebase_providers.dart';

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
}

final convidadoControllerProvider =
    AsyncNotifierProvider<ConvidadoController, void>(ConvidadoController.new);
