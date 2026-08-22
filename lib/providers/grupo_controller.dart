import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/data_utils.dart';
import '../models/enums.dart';
import '../models/grupo_model.dart';
import '../models/racha_model.dart';
import 'firebase_providers.dart';

class GrupoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> criar({
    required String nome,
    required String localPadrao,
    required DiaSemana diaSemana,
    required String horario,
    required TipoCampo tipoCampoPadrao,
    required int qtdJogadoresLinhaPadrao,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = ref.read(firebaseAuthProvider).currentUser!.uid;
      final grupo = GrupoModel(
        id: '',
        nome: nome,
        localPadrao: localPadrao,
        tipoCampoPadrao: tipoCampoPadrao,
        qtdJogadoresLinhaPadrao: qtdJogadoresLinhaPadrao,
        diaSemana: diaSemana,
        horario: horario,
        adminId: adminId,
      );
      final grupoId = await ref.read(grupoRepositoryProvider).criar(grupo);

      // Toda vez que um Grupo recorrente é criado, a primeira rodada
      // (Racha) já nasce junto, com o admin como participante confirmado —
      // ver Fluxo 5 (recorrência automática) em docs/estrutura.md.
      final racha = RachaModel(
        id: '',
        grupoId: grupoId,
        nome: nome,
        local: localPadrao,
        dataHora: proximaOcorrencia(diaSemana, horario),
        tipoCampo: tipoCampoPadrao,
        qtdJogadoresLinha: qtdJogadoresLinhaPadrao,
        adminId: adminId,
      );
      final rachaId = await ref.read(rachaRepositoryProvider).criar(racha);
      await ref.read(participanteRepositoryProvider).convidar(
            rachaId: rachaId,
            userId: adminId,
            status: StatusConfirmacao.confirmado,
          );
    });
  }
}

final grupoControllerProvider =
    AsyncNotifierProvider<GrupoController, void>(GrupoController.new);
