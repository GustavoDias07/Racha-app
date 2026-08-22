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
