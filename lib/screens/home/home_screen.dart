import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/participante_model.dart';
import '../../providers/auth_controller.dart';
import '../../providers/firebase_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(currentUserModelProvider);
    final grupos = ref.watch(meusGruposProvider);
    final convites = ref.watch(meusConvitesProvider);
    final meuUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus rachas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Ranking',
            onPressed: () => context.push('/ranking'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Meu perfil',
            onPressed: () => context.push('/perfil'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            grupos.when(
              data: (lista) {
                if (lista.isEmpty) {
                  final nome = userModel.valueOrNull?.nome;
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(nome == null
                        ? 'Nenhum racha ainda.'
                        : 'Olá, $nome! Nenhum racha ainda.'),
                  );
                }
                return Column(
                  children: lista
                      .map((grupo) => ListTile(
                            title: Text(grupo.nome),
                            subtitle: Text(
                              '${grupo.localPadrao} • ${grupo.diaSemana.label}, ${grupo.horario}',
                            ),
                            trailing: Text(grupo.tipoCampoPadrao.label),
                            onTap: () =>
                                context.push('/grupos/${grupo.id}', extra: grupo),
                          ))
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro: $e'),
              ),
            ),
            convites.maybeWhen(
              data: (lista) {
                if (lista.isEmpty || meuUid == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Convites', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...lista.map(
                      (p) => _ConviteTile(participante: p, meuUid: meuUid),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/grupos/criar'),
        icon: const Icon(Icons.add),
        label: const Text('Criar racha'),
      ),
    );
  }
}

/// Uma rodada em que o usuário foi convidado (não é admin). Ignora silenciosamente
/// rachas em que ele é admin — essas já aparecem em "Meus rachas".
class _ConviteTile extends ConsumerWidget {
  const _ConviteTile({required this.participante, required this.meuUid});

  final ParticipanteModel participante;
  final String meuUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaPorIdProvider(participante.rachaId));

    return rachaAsync.maybeWhen(
      data: (racha) {
        if (racha == null || racha.adminId == meuUid) return const SizedBox.shrink();
        final statusLabel = switch (participante.statusConfirmacao) {
          StatusConfirmacao.confirmado => 'Confirmado',
          StatusConfirmacao.recusado => 'Recusado',
          StatusConfirmacao.pendente => 'Pendente',
        };
        return ListTile(
          title: Text(racha.nome),
          subtitle: Text(
            '${racha.local} • ${DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(racha.dataHora)}',
          ),
          trailing: Text(statusLabel),
          onTap: () => context.push('/rachas/${racha.id}'),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
