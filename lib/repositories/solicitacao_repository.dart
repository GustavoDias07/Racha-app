import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/solicitacao_model.dart';

class SolicitacaoRepository {
  SolicitacaoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String grupoId) =>
      _firestore
          .collection(FirestorePaths.grupos)
          .doc(grupoId)
          .collection(FirestorePaths.solicitacoes);

  Future<void> criar(SolicitacaoModel solicitacao) {
    return _collection(solicitacao.grupoId).add(solicitacao.toMap());
  }

  Stream<List<SolicitacaoModel>> observarPendentes(String grupoId) {
    return _collection(grupoId)
        .where('status', isEqualTo: StatusAprovacao.pendente.name)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SolicitacaoModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Solicitação pendente do usuário nesse grupo, se houver — usado pela aba
  /// "Rachas Próximos" pra não deixar pedir entrada duas vezes.
  Future<SolicitacaoModel?> buscarMinhaSolicitacao(
      String grupoId, String userId) async {
    final snap = await _collection(grupoId)
        .where('solicitanteId', isEqualTo: userId)
        .where('status', isEqualTo: StatusAprovacao.pendente.name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return SolicitacaoModel.fromMap(doc.id, doc.data());
  }

  Future<void> atualizarStatus({
    required String grupoId,
    required String solicitacaoId,
    required StatusAprovacao status,
  }) {
    return _collection(grupoId).doc(solicitacaoId).update({'status': status.name});
  }
}
