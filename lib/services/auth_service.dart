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

  Future<void> logout() {
    return _firebaseAuth.signOut();
  }
}
