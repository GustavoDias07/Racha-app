import 'package:cloud_firestore/cloud_firestore.dart';

/// Jogador cadastrado no app.
///
/// Não guardamos senha/hash aqui: o Firebase Authentication já cuida do
/// armazenamento seguro de credenciais. Reimplementar isso no Firestore
/// seria redundante e menos seguro que usar o que o Auth já oferece.
class UserModel {
  final String id;
  final String nome;
  final String email;
  // Provisório: guarda a foto em base64 direto no documento (ver
  // StorageService). Quando o Firebase Storage for ativado, isso volta a
  // ser uma URL de download — o nome do campo muda para fotoPerfilUrl.
  final String? fotoPerfilBase64;
  final int idade;
  final double peso;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.nome,
    required this.email,
    this.fotoPerfilBase64,
    required this.idade,
    required this.peso,
    required this.createdAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      nome: map['nome'] as String,
      email: map['email'] as String,
      fotoPerfilBase64: map['fotoPerfilBase64'] as String?,
      idade: map['idade'] as int,
      peso: (map['peso'] as num).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'fotoPerfilBase64': fotoPerfilBase64,
      'idade': idade,
      'peso': peso,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? nome,
    String? email,
    String? fotoPerfilBase64,
    int? idade,
    double? peso,
  }) {
    return UserModel(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      fotoPerfilBase64: fotoPerfilBase64 ?? this.fotoPerfilBase64,
      idade: idade ?? this.idade,
      peso: peso ?? this.peso,
      createdAt: createdAt,
    );
  }
}
