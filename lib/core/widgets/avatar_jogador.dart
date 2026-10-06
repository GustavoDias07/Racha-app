import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import '../theme/app_theme.dart';
import '../utils/imagem_base64.dart';

/// Iniciais de um nome: "Gustavo Dias" vira "GD", "Djalminha" vira "D".
String _iniciais(String nome) {
  final partes =
      nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes.first[0] + partes.last[0]).toUpperCase();
}

/// Foto redonda de um jogador, ou as iniciais dele quando não há foto.
///
/// Antes as telas de racha mostravam um ícone genérico de pessoa para todo
/// mundo, mesmo com a foto já carregada — o documento do usuário vinha
/// completo, foto incluída, e ela só não era desenhada. As iniciais no lugar
/// do ícone servem para o mesmo fim quando não há foto: dá para distinguir
/// as pessoas de relance numa lista.
class AvatarJogador extends StatelessWidget {
  const AvatarJogador({
    super.key,
    required this.nome,
    this.fotoBase64,
    this.raio = 20,
    this.convidado = false,
  });

  final String nome;
  final String? fotoBase64;
  final double raio;

  /// Convidado não tem conta nem foto. Aparece com um tom diferente para
  /// não ser confundido com um jogador cadastrado que só não pôs foto.
  final bool convidado;

  @override
  Widget build(BuildContext context) {
    final bytes = bytesDaFoto(fotoBase64);
    if (bytes != null) {
      return CircleAvatar(
        radius: raio,
        backgroundColor: AppColors.superficieAlta,
        backgroundImage: MemoryImage(bytes),
      );
    }

    return CircleAvatar(
      radius: raio,
      backgroundColor: convidado
          ? AppColors.superficieAlta
          : AppColors.verde.withValues(alpha: 0.18),
      child: Text(
        _iniciais(nome),
        style: TextStyle(
          fontSize: raio * 0.72,
          fontWeight: FontWeight.w600,
          color: convidado ? AppColors.textoSecundario : AppColors.verde,
        ),
      ),
    );
  }
}

/// [AvatarJogador] para quem só tem o id do usuário em mãos.
///
/// Usa o `userPorIdProvider`, que o Riverpod compartilha por id: se a mesma
/// tela já pediu o nome dessa pessoa, a foto vem da mesma leitura, sem ir ao
/// Firestore de novo.
class AvatarDoUsuario extends ConsumerWidget {
  const AvatarDoUsuario({super.key, required this.userId, this.raio = 20});

  final String userId;
  final double raio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userPorIdProvider(userId)).valueOrNull;
    return AvatarJogador(
      nome: user?.nome ?? '',
      fotoBase64: user?.fotoPerfilBase64,
      raio: raio,
    );
  }
}
