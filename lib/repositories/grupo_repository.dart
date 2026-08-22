import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/grupo_model.dart';

class GrupoRepository {
  GrupoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.grupos);

  Future<String> criar(GrupoModel grupo) async {
    final docRef = _collection.doc();
    await docRef.set(grupo.toMap());
    return docRef.id;
  }

  Stream<GrupoModel?> observar(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GrupoModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Busca one-shot (não stream) — usada pelo `RachaController.finalizar`
  /// pra ler a configuração padrão do Grupo na hora de gerar a próxima
  /// ocorrência (Fluxo 5).
  Future<GrupoModel?> buscarPorId(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return GrupoModel.fromMap(doc.id, doc.data()!);
  }

  Stream<List<GrupoModel>> observarPorAdmin(String adminId) {
    return _collection.where('adminId', isEqualTo: adminId).snapshots().map(
        (snap) =>
            snap.docs.map((d) => GrupoModel.fromMap(d.id, d.data())).toList());
  }

  /// Grava a lista de membros fixos (User) convidados automaticamente toda
  /// vez que uma nova rodada do grupo nasce (Fluxo 5).
  Future<void> atualizarMembrosFixos(String grupoId, List<String> membrosFixos) {
    return _collection.doc(grupoId).update({'membrosFixos': membrosFixos});
  }

  /// Apaga só o Grupo — as rodadas (rachas) já geradas a partir dele não
  /// são apagadas junto (não têm delete permitido pelas regras), só param
  /// de aparecer na Home porque o Grupo dono sumiu.
  Future<void> remover(String id) {
    return _collection.doc(id).delete();
  }
}
