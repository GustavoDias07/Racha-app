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

  /// Adiciona um User à lista de membros fixos do grupo — convidado
  /// automaticamente toda vez que uma nova rodada nascer (Fluxo 5).
  Future<void> adicionarMembroFixo(GrupoModel grupo, String userId) async {
    if (grupo.membrosFixos.contains(userId)) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(grupoRepositoryProvider).atualizarMembrosFixos(
            grupo.id,
            [...grupo.membrosFixos, userId],
          );
    });
  }

  Future<void> removerMembroFixo(GrupoModel grupo, String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(grupoRepositoryProvider).atualizarMembrosFixos(
            grupo.id,
            grupo.membrosFixos.where((id) => id != userId).toList(),
          );
    });
  }

  /// Edita a configuração padrão do grupo (nome, local, dia/horário, tipo
  /// de campo). Só afeta rodadas futuras — a atual não muda sozinha.
  Future<void> atualizar({
    required String grupoId,
    required String nome,
    required String localPadrao,
    required DiaSemana diaSemana,
    required String horario,
    required TipoCampo tipoCampoPadrao,
    required int qtdJogadoresLinhaPadrao,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(grupoRepositoryProvider).atualizar(
            grupoId: grupoId,
            nome: nome,
            localPadrao: localPadrao,
            diaSemana: diaSemana,
            horario: horario,
            tipoCampoPadrao: tipoCampoPadrao,
            qtdJogadoresLinhaPadrao: qtdJogadoresLinhaPadrao,
          );
    });
  }

  /// Apaga o grupo (racha recorrente) — só o admin dono chega a essa tela,
  /// e a regra do Firestore também exige isso. As rodadas já geradas não
  /// somem junto (ver `GrupoRepository.remover`).
  Future<void> remover(GrupoModel grupo) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(grupoRepositoryProvider).remover(grupo.id);
    });
  }
}

final grupoControllerProvider =
    AsyncNotifierProvider<GrupoController, void>(GrupoController.new);
