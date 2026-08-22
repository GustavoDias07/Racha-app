import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.users);

  Future<void> criar(UserModel user) {
    return _collection.doc(user.id).set(user.toMap());
  }

  Future<UserModel?> buscarPorId(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Stream<UserModel?> observar(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> atualizar(UserModel user) {
    return _collection.doc(user.id).update(user.toMap());
  }

  Future<List<UserModel>> buscarPorNomeOuEmail(String termo) async {
    final termoBusca = termo.trim().toLowerCase();
    if (termoBusca.isEmpty) return [];

    final porEmail = await _collection
        .where('email', isEqualTo: termoBusca)
        .limit(10)
        .get();

    return porEmail.docs
        .map((doc) => UserModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
