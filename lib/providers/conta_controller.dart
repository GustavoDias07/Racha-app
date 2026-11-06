import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import 'firebase_providers.dart';

/// Exclusão da própria conta (RF24 no Trello, T21 em docs/tarefas.md —
/// exigência da Play Store para qualquer app com login).
class ContaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Exclui a conta de quem está logado. Ordem dos passos:
  ///
  /// 1. Recusa se a pessoa é admin de algum grupo. Sem isso o grupo ficaria
  ///    sem dono e ninguém mais conseguiria editá-lo, finalizar rodadas ou
  ///    aprovar entradas. Ela precisa apagar o grupo antes.
  /// 2. Confere a senha de novo (o Firebase também exige login recente).
  /// 3. Sai dos grupos em que é membro e recusa os convites de rodadas
  ///    ainda abertas — senão continuaria contando como confirmada.
  /// 4. Apaga perfil, avisos e ranking global num batch só.
  /// 5. Por último apaga o login. Fica no fim porque, depois dele, as regras
  ///    do Firestore já não reconhecem a pessoa e nada mais pode ser apagado.
  ///
  /// Notas e estatísticas de rodadas passadas NÃO são apagadas: elas também
  /// fazem parte do ranking e do MVP dos outros jogadores. Ficam sem nome,
  /// porque o perfil some.
  Future<void> excluirConta({required String senha}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      final uid = authService.currentUser!.uid;
      final grupoRepo = ref.read(grupoRepositoryProvider);

      final gruposComoAdmin = await grupoRepo.observarPorAdmin(uid).first;
      if (gruposComoAdmin.isNotEmpty) {
        final nomes = gruposComoAdmin.map((g) => g.nome).join(', ');
        throw Exception(
          'Você é admin de: $nomes. Apague esse(s) grupo(s) antes de excluir '
          'a conta, para eles não ficarem sem dono.',
        );
      }

      try {
        await authService.reautenticar(senha: senha);
      } on FirebaseAuthException {
        throw Exception('Senha incorreta.');
      }

      for (final grupo in await grupoRepo.observarPorMembro(uid).first) {
        await grupoRepo.sair(grupo.id, uid);
      }

      final participanteRepo = ref.read(participanteRepositoryProvider);
      final rachaRepo = ref.read(rachaRepositoryProvider);
      for (final p in await participanteRepo.buscarPorUser(uid)) {
        if (p.statusConfirmacao == StatusConfirmacao.recusado) continue;
        final racha = await rachaRepo.observar(p.rachaId).first;
        if (racha == null || racha.status == RachaStatus.finalizado) continue;
        await participanteRepo.atualizarStatus(
          rachaId: p.rachaId,
          participanteId: p.id,
          status: StatusConfirmacao.recusado,
        );
      }

      final batch = ref.read(firestoreProvider).batch();
      await ref.read(avisoRepositoryProvider).removerTodosEmLote(batch, uid);
      ref.read(rankingRepositoryProvider).removerEmLote(batch, uid);
      ref.read(userRepositoryProvider).removerEmLote(batch, uid);
      await batch.commit();

      // Ao apagar o login o app volta sozinho para a tela de login: o
      // roteador observa o estado de autenticação.
      await authService.excluirContaAtual();
    });
  }
}

final contaControllerProvider =
    AsyncNotifierProvider<ContaController, void>(ContaController.new);
