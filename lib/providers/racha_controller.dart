import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/racha_model.dart';
import 'firebase_providers.dart';

/// Cria rachas avulsos (sem Grupo). O fluxo de racha recorrente (Grupo,
/// membros fixos) fica para uma próxima etapa.
class RachaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> criar({
    required String nome,
    required String local,
    required DateTime dataHora,
    required TipoCampo tipoCampo,
    required int qtdJogadoresLinha,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = ref.read(firebaseAuthProvider).currentUser!.uid;
      final racha = RachaModel(
        id: '',
        nome: nome,
        local: local,
        dataHora: dataHora,
        tipoCampo: tipoCampo,
        qtdJogadoresLinha: qtdJogadoresLinha,
        adminId: adminId,
      );
      await ref.read(rachaRepositoryProvider).criar(racha);
    });
  }
}

final rachaControllerProvider =
    AsyncNotifierProvider<RachaController, void>(RachaController.new);
