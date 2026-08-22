import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Atualiza os dados pessoais do usuário logado (nome, idade, peso, foto).
/// Email e senha não entram aqui — são geridos pelo Firebase Auth, não pelo
/// documento do User no Firestore.
class PerfilController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> atualizar({
    required String nome,
    required int idade,
    required double peso,
    File? novaFoto,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      final userRepository = ref.read(userRepositoryProvider);
      final atual = await userRepository.buscarPorId(uid);
      if (atual == null) return;

      var fotoBase64 = atual.fotoPerfilBase64;
      if (novaFoto != null) {
        fotoBase64 = await ref.read(storageServiceProvider).uploadFotoPerfil(
              userId: uid,
              arquivo: novaFoto,
            );
      }

      final atualizado = atual.copyWith(
        nome: nome,
        idade: idade,
        peso: peso,
        fotoPerfilBase64: fotoBase64,
      );
      await userRepository.atualizar(atualizado);
    });
  }
}

final perfilControllerProvider =
    AsyncNotifierProvider<PerfilController, void>(PerfilController.new);
