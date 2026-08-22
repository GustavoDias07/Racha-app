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

  Stream<List<GrupoModel>> observarPorAdmin(String adminId) {
    return _collection.where('adminId', isEqualTo: adminId).snapshots().map(
        (snap) =>
            snap.docs.map((d) => GrupoModel.fromMap(d.id, d.data())).toList());
  }
}
