import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/data_utils.dart';
import '../models/enums.dart';
import '../models/grupo_model.dart';
import '../models/racha_model.dart';
import 'criar_racha_com_admin.dart';
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
    GeoPoint? localizacao,
    bool abertoParaNovosMembros = false,
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
        localizacao: localizacao,
        abertoParaNovosMembros: abertoParaNovosMembros,
      );
      final grupoId = await ref.read(grupoRepositoryProvider).criar(grupo);

      // Toda vez que um Grupo recorrente é criado, a primeira rodada
      // (Racha) já nasce junto, com o admin convidado — ver Fluxo 5
      // (recorrência automática) em docs/estrutura.md.
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
      // A primeira rodada nasce sem anotadores porque o grupo acabou de ser
      // criado e ainda não tem membro nenhum pra delegar.
      await criarRachaComAdmin(ref, racha);
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

  /// Tira o jogador da lista de membros fixos e, por padrão, também da
  /// rodada aberta no momento — é o inverso exato de
  /// `SolicitacaoController.aprovar`, que faz as duas coisas na entrada. Sem
  /// isso, quem era removido do grupo continuava convidado na rodada em
  /// andamento e só parava de aparecer na semana seguinte.
  ///
  /// `removerDaRodadaAberta: false` cobre o caso em que o admin quer só
  /// interromper a recorrência, deixando a pessoa jogar a rodada que ela já
  /// confirmou.
  Future<void> removerMembroFixo(
    GrupoModel grupo,
    String userId, {
    bool removerDaRodadaAberta = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(grupoRepositoryProvider).atualizarMembrosFixos(
            grupo.id,
            grupo.membrosFixos.where((id) => id != userId).toList(),
          );

      if (!removerDaRodadaAberta) return;

      final rachaAtual = await ref
          .read(rachaRepositoryProvider)
          .observarAtualPorGrupo(grupo.id)
          .first;
      if (rachaAtual == null) return;

      final participanteRepo = ref.read(participanteRepositoryProvider);
      final participante =
          await participanteRepo.buscarPorUserId(rachaAtual.id, userId);
      if (participante == null) return;

      await participanteRepo.remover(
        rachaId: rachaAtual.id,
        participanteId: participante.id,
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
    GeoPoint? localizacao,
    bool abertoParaNovosMembros = false,
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
            localizacao: localizacao,
            abertoParaNovosMembros: abertoParaNovosMembros,
          );
    });
  }

  /// Liga/desliga a permissão de fazer a chamada para um membro do grupo.
  ///
  /// Grava nos dois lugares: na lista do grupo (vale pras próximas rodadas) e
  /// na rodada aberta agora. Sem o segundo, delegar a chamada só passaria a
  /// valer na semana seguinte — inútil justamente no dia em que o admin
  /// percebe que não vai conseguir apitar a lista sozinho.
  Future<void> alternarAnotador(GrupoModel grupo, String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auxiliares = grupo.auxiliares.contains(userId)
          ? grupo.auxiliares.where((id) => id != userId).toList()
          : [...grupo.auxiliares, userId];

      await ref
          .read(grupoRepositoryProvider)
          .atualizarAuxiliares(grupo.id, auxiliares);

      final rachaAtual = await ref
          .read(rachaRepositoryProvider)
          .observarAtualPorGrupo(grupo.id)
          .first;
      if (rachaAtual == null) return;

      await ref
          .read(rachaRepositoryProvider)
          .atualizarAnotadores(rachaId: rachaAtual.id, anotadores: auxiliares);
    });
  }

  /// Saída do próprio jogador de um grupo em que ele é só membro fixo. O
  /// admin não usa isso: dono de grupo não "sai", ele apaga (ver `remover`),
  /// e a regra do Firestore só libera essa escrita pra quem está tirando o
  /// próprio id da lista.
  Future<void> sair(GrupoModel grupo) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      return ref.read(grupoRepositoryProvider).sair(grupo.id, uid);
    });
  }

  /// Apaga o grupo (racha recorrente) — só o admin dono chega a essa tela, e
  /// a regra do Firestore também exige isso. As rodadas já geradas não somem
  /// junto (ver `GrupoRepository.removerEmLote`).
  ///
  /// Os pedidos de entrada vão junto: são uma subcoleção do grupo e não
  /// significam mais nada sem ele. Quem estava **esperando resposta** recebe
  /// um aviso, porque do lado dele o racha simplesmente sumiria da busca sem
  /// explicação nenhuma — ele nem saberia se foi recusado ou se o grupo
  /// acabou. Quem já foi recusado não é avisado: aquela conversa terminou.
  ///
  /// Tudo num commit só. Um aviso que sobrevivesse a uma falha na remoção
  /// diria que o grupo acabou quando ele ainda está lá.
  Future<void> remover(GrupoModel grupo) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final solicitacaoRepo = ref.read(solicitacaoRepositoryProvider);
      final solicitacoes = await solicitacaoRepo.buscarTodas(grupo.id);

      final batch = ref.read(firestoreProvider).batch();
      final avisoRepo = ref.read(avisoRepositoryProvider);

      for (final solicitacao in solicitacoes) {
        solicitacaoRepo.removerEmLote(
          batch,
          grupoId: grupo.id,
          solicitacaoId: solicitacao.id,
        );
        if (solicitacao.status != StatusAprovacao.pendente) continue;
        avisoRepo.criarEmLote(
          batch,
          userId: solicitacao.solicitanteId,
          mensagem: 'O racha "${grupo.nome}" não existe mais — o organizador '
              'apagou o grupo, e o seu pedido de entrada foi cancelado.',
        );
      }

      ref.read(grupoRepositoryProvider).removerEmLote(batch, grupo.id);
      await batch.commit();
    });
  }
}

final grupoControllerProvider =
    AsyncNotifierProvider<GrupoController, void>(GrupoController.new);
