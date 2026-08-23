import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/data_utils.dart';
import '../models/enums.dart';
import '../models/racha_model.dart';
import 'criar_racha_com_admin.dart';
import 'firebase_providers.dart';

class RachaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Cria um racha avulso (sem Grupo). O admin entra como participante
  /// pendente e confirma presença como qualquer outro — ver
  /// `criarRachaComAdmin`, que é a mesma porta usada pelo
  /// `GrupoController.criar`.
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
      await criarRachaComAdmin(ref, racha);
    });
  }

  /// Marca o racha como finalizado e, se ele vier de um Grupo recorrente,
  /// já cria a próxima ocorrência com os membros fixos convidados
  /// automaticamente (Fluxo 5, docs/estrutura.md). Rachas avulsos só
  /// encerram, sem gerar sequência. Tudo num único batch (o encerramento e
  /// a criação da próxima rodada), pra nunca deixar o grupo sem nenhuma
  /// rodada aberta se a escrita cair no meio.
  Future<void> finalizar(RachaModel racha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rachaRepo = ref.read(rachaRepositoryProvider);
      final participanteRepo = ref.read(participanteRepositoryProvider);
      final batch = ref.read(firestoreProvider).batch();

      rachaRepo.atualizarStatusEmLote(batch, rachaId: racha.id, status: RachaStatus.finalizado);

      final grupoId = racha.grupoId;
      if (grupoId != null) {
        final grupo = await ref.read(grupoRepositoryProvider).buscarPorId(grupoId);
        if (grupo != null) {
          final proximaRef = rachaRepo.novoDocRef();
          final proxima = RachaModel(
            id: proximaRef.id,
            grupoId: grupo.id,
            nome: grupo.nome,
            local: grupo.localPadrao,
            dataHora: proximaOcorrencia(grupo.diaSemana, grupo.horario),
            tipoCampo: grupo.tipoCampoPadrao,
            qtdJogadoresLinha: grupo.qtdJogadoresLinhaPadrao,
            adminId: grupo.adminId,
            anotadores: grupo.auxiliares,
          );
          rachaRepo.criarEmLote(batch, proximaRef, proxima);
          // O admin é convidado como qualquer membro fixo: ele confirma
          // presença se for jogar. Organizar a rodada não é o mesmo que
          // estar em campo nela.
          for (final userId in {grupo.adminId, ...grupo.membrosFixos}) {
            participanteRepo.convidarEmLote(batch, rachaId: proximaRef.id, userId: userId);
          }
        }
      }

      await batch.commit();
    });
  }

  /// Edita um racha já criado — avulso ou rodada de um Grupo (Fluxo 2:
  /// "o admin ainda pode ajustar a ocorrência gerada automaticamente").
  Future<void> atualizar({
    required String rachaId,
    required String nome,
    required String local,
    required DateTime dataHora,
    required TipoCampo tipoCampo,
    required int qtdJogadoresLinha,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(rachaRepositoryProvider).atualizar(
            rachaId: rachaId,
            nome: nome,
            local: local,
            dataHora: dataHora,
            tipoCampo: tipoCampo,
            qtdJogadoresLinha: qtdJogadoresLinha,
          );
    });
  }

  /// Apaga um racha avulso (sem Grupo) — rodada de Grupo não tem esse
  /// caminho, ver `RachaRepository.remover`.
  Future<void> remover(String rachaId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(rachaRepositoryProvider).remover(rachaId);
    });
  }

  /// Entra num racha só sabendo o código — que é o próprio id do
  /// documento, igual um link compartilhável (não existe um campo "código"
  /// separado guardado em lugar nenhum). Quem entra assim já fica
  /// confirmado direto, sem passar por "pendente": foi a própria pessoa
  /// que decidiu entrar, diferente de ser convidada por alguém. Devolve o
  /// id do racha pra tela poder navegar pra ele.
  Future<String?> entrarComCodigo(String codigo) async {
    state = const AsyncLoading();
    String? rachaId;
    state = await AsyncValue.guard(() async {
      final codigoLimpo = codigo.trim();
      final racha = await ref.read(rachaRepositoryProvider).observar(codigoLimpo).first;
      if (racha == null) {
        throw Exception('Código inválido — nenhum racha encontrado.');
      }
      // Racha encerrado não recebe mais ninguém: entrar aqui só criaria um
      // participante confirmado num jogo que já aconteceu, que ainda por cima
      // entraria na conta de quem pode avaliar a rodada.
      if (racha.status == RachaStatus.finalizado) {
        throw Exception('Esse racha já foi encerrado.');
      }

      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      final participanteRepo = ref.read(participanteRepositoryProvider);
      final existente = await participanteRepo.buscarPorUserId(racha.id, uid);
      if (existente == null) {
        await participanteRepo.convidar(
          rachaId: racha.id,
          userId: uid,
          status: StatusConfirmacao.confirmado,
        );
      } else if (existente.statusConfirmacao != StatusConfirmacao.confirmado) {
        await participanteRepo.atualizarStatus(
          rachaId: racha.id,
          participanteId: existente.id,
          status: StatusConfirmacao.confirmado,
        );
      }
      rachaId = racha.id;
    });
    return rachaId;
  }
}

final rachaControllerProvider =
    AsyncNotifierProvider<RachaController, void>(RachaController.new);
