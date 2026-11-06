import 'package:firebase_auth/firebase_auth.dart';

/// Camada fina sobre o FirebaseAuth. Não conhece Firestore nem modelos do
/// app — só autenticação.
class AuthService {
  AuthService(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> cadastrar({
    required String email,
    required String senha,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  Future<UserCredential> login({
    required String email,
    required String senha,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  Future<void> recuperarSenha({required String email}) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> logout() {
    return _firebaseAuth.signOut();
  }

  /// Confere a senha de novo antes de uma ação sem volta (excluir a conta).
  ///
  /// Além de ser uma segunda confirmação, o próprio Firebase exige: ele só
  /// deixa excluir a conta de quem fez login há poucos minutos, e sem isso o
  /// `delete()` falharia com `requires-recent-login` para quem está logado
  /// há dias.
  Future<void> reautenticar({required String senha}) {
    final user = _firebaseAuth.currentUser!;
    final credencial =
        EmailAuthProvider.credential(email: user.email!, password: senha);
    return user.reauthenticateWithCredential(credencial);
  }

  /// Apaga a conta de login. Último passo da exclusão — ver
  /// `ContaController.excluirConta`.
  Future<void> excluirContaAtual() {
    return _firebaseAuth.currentUser!.delete();
  }
}
