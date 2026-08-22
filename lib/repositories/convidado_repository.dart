import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/convidado_model.dart';
import '../models/enums.dart';

class ConvidadoRepository {
  ConvidadoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String rachaId) =>
      _firestore
          .collection(FirestorePaths.rachas)
          .doc(rachaId)
          .collection(FirestorePaths.convidados);

  Stream<List<ConvidadoModel>> observarPorRacha(String rachaId) {
    return _collection(rachaId).snapshots().map((snap) => snap.docs
        .map((d) => ConvidadoModel.fromMap(d.id, d.data()))
        .toList());
  }

  Future<void> adicionar(ConvidadoModel convidado) {
    return _collection(convidado.rachaId).add(convidado.toMap());
  }

  Future<void> atualizarAprovacao({
    required String rachaId,
    required String convidadoId,
    required StatusAprovacao status,
  }) {
    return _collection(rachaId)
        .doc(convidadoId)
        .update({'statusAprovacao': status.name});
  }

  /// Grava o time (A ou B) definido pelo algoritmo de balanceamento
  /// (`TimesController`) para este convidado.
  Future<void> definirTime({
    required String rachaId,
    required String convidadoId,
    required TimeRacha time,
  }) {
    return _collection(rachaId).doc(convidadoId).update({'time': time.name});
  }

  /// Fecha o Fluxo 3.1 (docs/estrutura.md): grava o `userId` da conta
  /// oficial pra qual o histórico deste convidado foi migrado
  /// (`ConvidadoController.oficializar`).
  Future<void> marcarOficializado({
    required String rachaId,
    required String convidadoId,
    required String userId,
  }) {
    return _collection(rachaId)
        .doc(convidadoId)
        .update({'oficializadoComoUserId': userId});
  }

  /// Mesma coisa que `definirTime`, mas adiciona a um `WriteBatch`
  /// compartilhado — ver `ParticipanteRepository.definirTimeEmLote`.
  void definirTimeEmLote(
    WriteBatch batch, {
    required String rachaId,
    required String convidadoId,
    required TimeRacha time,
  }) {
    batch.update(_collection(rachaId).doc(convidadoId), {'time': time.name});
  }
}
