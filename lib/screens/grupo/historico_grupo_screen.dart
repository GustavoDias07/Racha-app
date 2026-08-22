import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/firebase_providers.dart';

/// Rodadas já finalizadas de um Grupo — complementa o Fluxo 5
/// (finalizar → próxima rodada automática): sem essa tela, uma rodada
/// passada virava dado morto assim que a próxima nascia.
class HistoricoGrupoScreen extends ConsumerWidget {
  const HistoricoGrupoScreen({super.key, required this.grupoId, required this.grupoNome});

  final String grupoId;
  final String grupoNome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historicoAsync = ref.watch(historicoDoGrupoProvider(grupoId));

    return Scaffold(
      appBar: AppBar(title: Text('Histórico — $grupoNome')),
      body: SafeArea(
        child: historicoAsync.when(
          data: (lista) {
            if (lista.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma rodada finalizada ainda nesse grupo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: lista.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final racha = lista[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(
                    DateFormat("EEEE, dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(racha.dataHora),
                  ),
                  subtitle: Text(racha.local),
                  trailing: racha.mvpUserId != null
                      ? _MvpChip(userId: racha.mvpUserId!)
                      : null,
                  onTap: () => context.push('/rachas/${racha.id}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar histórico: $e')),
        ),
      ),
    );
  }
}

class _MvpChip extends ConsumerWidget {
  const _MvpChip({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(userId));
    final nome = userAsync.valueOrNull?.nome;
    if (nome == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
        const SizedBox(width: 4),
        Text(nome, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
