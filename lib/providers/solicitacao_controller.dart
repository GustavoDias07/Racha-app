import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/grupo_model.dart';
import '../models/solicitacao_model.dart';
import 'firebase_providers.dart';

class SolicitacaoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Pedido de entrada de um User cadastrado num grupo aberto (aba "Rachas
  /// Próximos"). Sem efeito se ele já é membro fixo ou já tem um pedido
  /// pendente — evita solicitação duplicada.
  Future<void> solicitar(GrupoModel grupo) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      if (grupo.membrosFixos.contains(uid)) return;

      final repo = ref.read(solicitacaoRepositoryProvider);
      final existente = await repo.buscarMinhaSolicitacao(grupo.id, uid);
      if (existente != null) return;

      await repo.criar(SolicitacaoModel(
        id: '',
        grupoId: grupo.id,
        solicitanteId: uid,
        criadoEm: DateTime.now(),
      ));
    });
  }

  /// Aprova o pedido: o solicitante vira membro fixo do grupo (passa a ser
  /// convidado automaticamente toda vez que uma nova rodada nascer — Fluxo
  /// 5, docs/estrutura.md) e, se houver rodada aberta agora, já entra nela
  /// também como participante pendente, em vez de esperar a próxima semana.
  Future<void> aprovar(GrupoModel grupo, SolicitacaoModel solicitacao) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final grupoRepo = ref.read(grupoRepositoryProvider);
      if (!grupo.membrosFixos.contains(solicitacao.solicitanteId)) {
        await grupoRepo.atualizarMembrosFixos(
          grupo.id,
          [...grupo.membrosFixos, solicitacao.solicitanteId],
        );
      }

      await ref.read(solicitacaoRepositoryProvider).atualizarStatus(
            grupoId: grupo.id,
            solicitacaoId: solicitacao.id,
            status: StatusAprovacao.aprovado,
          );

      final rachaAtual =
          await ref.read(rachaRepositoryProvider).observarAtualPorGrupo(grupo.id).first;
      if (rachaAtual != null) {
        await ref.read(participanteRepositoryProvider).convidar(
              rachaId: rachaAtual.id,
              userId: solicitacao.solicitanteId,
            );
      }
    });
  }

  Future<void> recusar(GrupoModel grupo, SolicitacaoModel solicitacao) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(solicitacaoRepositoryProvider).atualizarStatus(
            grupoId: grupo.id,
            solicitacaoId: solicitacao.id,
            status: StatusAprovacao.recusado,
          );
    });
  }
}

final solicitacaoControllerProvider =
    AsyncNotifierProvider<SolicitacaoController, void>(SolicitacaoController.new);
