import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/grupo_model.dart';
import '../models/solicitacao_model.dart';
import 'firebase_providers.dart';

/// Desfecho de um pedido de entrada, devolvido pro botão da aba "Rachas
/// Próximos" poder dizer o que aconteceu. Sem isso os dois casos de
/// "não fez nada" (já é membro / já pediu) ficavam indistinguíveis de um
/// pedido enviado com sucesso, porque a tela só via `AsyncData(null)`.
enum ResultadoSolicitacao { enviada, jaEraMembro, jaSolicitou, recusadoAntes, erro }

class SolicitacaoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Pedido de entrada de um User cadastrado num grupo aberto (aba "Rachas
  /// Próximos"). Sem efeito se ele já é membro fixo ou já tem um pedido
  /// pendente — evita solicitação duplicada.
  Future<ResultadoSolicitacao> solicitar(GrupoModel grupo) async {
    state = const AsyncLoading();
    var resultado = ResultadoSolicitacao.enviada;

    state = await AsyncValue.guard(() async {
      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      if (grupo.membrosFixos.contains(uid)) {
        resultado = ResultadoSolicitacao.jaEraMembro;
        return;
      }

      final repo = ref.read(solicitacaoRepositoryProvider);
      final ultima = await repo.buscarUltimaSolicitacao(grupo.id, uid);

      if (ultima?.status == StatusAprovacao.pendente) {
        resultado = ResultadoSolicitacao.jaSolicitou;
        return;
      }
      // Recusa não expira: só o admin reabre. Um prazo fixo ("pode pedir de
      // novo em 7 dias") erraria nos dois sentidos — curto demais pra quem
      // foi recusado por encher o racha naquela semana, e longo demais pra
      // quando o grupo precisa da pessoa no sábado seguinte. Deixando a
      // reabertura na mão do admin, vale tanto pra um dia quanto pra um ano.
      if (ultima?.status == StatusAprovacao.recusado) {
        resultado = ResultadoSolicitacao.recusadoAntes;
        return;
      }

      await repo.criar(SolicitacaoModel(
        id: '',
        grupoId: grupo.id,
        solicitanteId: uid,
        criadoEm: DateTime.now(),
      ));
    });

    return state.hasError ? ResultadoSolicitacao.erro : resultado;
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

  /// Reabre um pedido recusado: ele volta pra fila de pendentes e o admin
  /// decide de novo. É o único caminho de volta pra quem foi recusado — a
  /// pessoa não consegue pedir sozinha outra vez.
  Future<void> reabrir(GrupoModel grupo, SolicitacaoModel solicitacao) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(solicitacaoRepositoryProvider).atualizarStatus(
            grupoId: grupo.id,
            solicitacaoId: solicitacao.id,
            status: StatusAprovacao.pendente,
          );
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
