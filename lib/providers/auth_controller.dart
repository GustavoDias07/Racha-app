import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'firebase_providers.dart';

/// Orquestra os passos de cadastro/login: chama AuthService, sobe a foto
/// pro Storage, cria o doc do User no Firestore. Telas só observam o
/// `AsyncValue<void>` pra mostrar loading/erro e chamam os métodos abaixo.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required int idade,
    required double peso,
    File? fotoPerfil,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final authService = ref.read(authServiceProvider);
        final storageService = ref.read(storageServiceProvider);
        final userRepository = ref.read(userRepositoryProvider);

        // Normalizado em minúsculas: é o que `UserRepository.buscarPorNomeOuEmail`
        // usa pra comparar, e sem isso a busca por email falha para qualquer
        // conta cadastrada com letra maiúscula (ex: "Fulano@Gmail.com" nunca
        // seria encontrada buscando "fulano@gmail.com").
        final emailNormalizado = email.trim().toLowerCase();
        final credential =
            await authService.cadastrar(email: emailNormalizado, senha: senha);
        final uid = credential.user!.uid;

        String? fotoBase64;
        if (fotoPerfil != null) {
          fotoBase64 = await storageService.uploadFotoPerfil(
            userId: uid,
            arquivo: fotoPerfil,
          );
        }

        final user = UserModel(
          id: uid,
          nome: nome,
          email: emailNormalizado,
          fotoPerfilBase64: fotoBase64,
          idade: idade,
          peso: peso,
          createdAt: DateTime.now(),
        );
        await userRepository.criar(user);
      } on FirebaseAuthException {
        // Mensagem genérica de propósito: não expõe se o email já tem
        // conta nem detalhes internos do Firebase — evita que alguém use a
        // tela de cadastro pra descobrir emails já cadastrados no app.
        throw Exception(
          'Não foi possível criar a conta. Verifique os dados e tente novamente.',
        );
      }
    });
  }

  Future<void> login({required String email, required String senha}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authServiceProvider)
          .login(email: email.trim().toLowerCase(), senha: senha);
    });
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
