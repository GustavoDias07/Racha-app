import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/racha_model.dart';

class RachaRepository {
  RachaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.rachas);

  Future<String> criar(RachaModel racha) async {
    final docRef = _collection.doc();
    await docRef.set(racha.toMap());
    return docRef.id;
  }

  Stream<RachaModel?> observar(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RachaModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Rachas criados pelo usuário, ordenados por data. Rachas para os quais
  /// o usuário só foi convidado (participante, não admin) aparecem via
  /// `ParticipanteRepository.observarMeusConvites`, não aqui.
  Stream<List<RachaModel>> observarPorAdmin(String adminId) {
    return _collection
        .where('adminId', isEqualTo: adminId)
        .orderBy('dataHora')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => RachaModel.fromMap(d.id, d.data())).toList());
  }

  /// Grava o MVP calculado pelo `RankingController` a partir das
  /// avaliações recebidas na rodada.
  Future<void> atualizarMvp({required String rachaId, required String mvpUserId}) {
    return _collection.doc(rachaId).update({'mvpUserId': mvpUserId});
  }

  /// Transiciona o status do racha (ver Fluxo 5, docs/estrutura.md) —
  /// usado pelo `RachaController.finalizar` pra marcar a rodada como
  /// encerrada e, se ligada a um Grupo, disparar a próxima ocorrência.
  Future<void> atualizarStatus({required String rachaId, required RachaStatus status}) {
    return _collection.doc(rachaId).update({'status': status.name});
  }

  /// Referência de um novo doc de racha, sem escrever ainda — permite
  /// conhecer o id antes do `commit()` do batch, pra já criar os
  /// participantes na subcoleção certa (ver `RachaController.finalizar`).
  DocumentReference<Map<String, dynamic>> novoDocRef() => _collection.doc();

  void criarEmLote(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> ref,
    RachaModel racha,
  ) {
    batch.set(ref, racha.toMap());
  }

  void atualizarStatusEmLote(
    WriteBatch batch, {
    required String rachaId,
    required RachaStatus status,
  }) {
    batch.update(_collection.doc(rachaId), {'status': status.name});
  }

  /// Edita os campos que o admin pode ajustar depois de criado (nome,
  /// local, data/hora, tipo de campo, jogadores de linha) — ver Fluxo 2,
  /// docs/estrutura.md: "o admin ainda pode ajustar a ocorrência gerada
  /// automaticamente". Update parcial (não `set` do doc inteiro) de
  /// propósito: `status` e `mvpUserId` têm fluxo próprio e não devem ser
  /// sobrescritos por um formulário de edição que nem os exibe.
  Future<void> atualizar({
    required String rachaId,
    required String nome,
    required String local,
    required DateTime dataHora,
    required TipoCampo tipoCampo,
    required int qtdJogadoresLinha,
  }) {
    return _collection.doc(rachaId).update({
      'nome': nome,
      'local': local,
      'dataHora': Timestamp.fromDate(dataHora),
      'tipoCampo': tipoCampo.name,
      'qtdJogadoresLinha': qtdJogadoresLinha,
    });
  }

  /// Só rachas avulsos (sem Grupo) — uma rodada de um Grupo some quando o
  /// Grupo é apagado (`GrupoRepository.remover`), não individualmente, pra
  /// não quebrar `observarAtualPorGrupo` no meio da recorrência.
  Future<void> remover(String id) {
    return _collection.doc(id).delete();
  }

  /// Rodada aberta mais próxima de um Grupo recorrente — a que a tela de
  /// detalhe do grupo mostra (participantes, convidados, confirmação).
  Stream<RachaModel?> observarAtualPorGrupo(String grupoId) {
    return _collection
        .where('grupoId', isEqualTo: grupoId)
        .where('status', isEqualTo: RachaStatus.aberto.name)
        .orderBy('dataHora')
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : RachaModel.fromMap(snap.docs.first.id, snap.docs.first.data()));
  }
}
