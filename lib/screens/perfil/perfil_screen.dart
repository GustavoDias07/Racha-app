import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/info_tile.dart';
import '../../providers/firebase_providers.dart';

/// Tela de perfil do jogador logado: foto, dados pessoais e o resumo do seu
/// Ranking (média de avaliação, MVPs, gols, assistências, rachas avaliados).
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final user = userAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar perfil',
              onPressed: () => context.push('/perfil/editar', extra: user),
            ),
        ],
      ),
      body: SafeArea(
        child: userAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Perfil não encontrado.'));
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundImage: user.fotoPerfilBase64 != null
                        ? MemoryImage(base64Decode(user.fotoPerfilBase64!))
                        : null,
                    child: user.fotoPerfilBase64 == null
                        ? const Icon(Icons.person, size: 56)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(user.nome, style: Theme.of(context).textTheme.titleLarge),
                ),
                const SizedBox(height: 24),
                InfoTile(icone: Icons.email, label: 'Email', valor: user.email),
                InfoTile(icone: Icons.cake, label: 'Idade', valor: '${user.idade} anos'),
                InfoTile(
                  icone: Icons.monitor_weight,
                  label: 'Peso',
                  valor: '${user.peso.toStringAsFixed(1)} kg',
                ),
                InfoTile(
                  icone: Icons.event,
                  label: 'Membro desde',
                  valor: DateFormat('dd/MM/yyyy', 'pt_BR').format(user.createdAt),
                ),
                const SizedBox(height: 24),
                Text('Histórico e estatísticas', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _RankingResumo(userId: user.id),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar perfil: $e')),
        ),
      ),
    );
  }
}

class _RankingResumo extends ConsumerWidget {
  const _RankingResumo({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingPorUserIdProvider(userId));

    return rankingAsync.when(
      data: (ranking) {
        if (ranking == null || ranking.totalRachas == 0) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Ainda sem avaliações registradas em nenhum racha.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _EstatisticaResumo(
                  icone: Icons.star,
                  valor: ranking.mediaAvaliacoes.toStringAsFixed(1),
                  label: 'Nota média',
                ),
                _EstatisticaResumo(
                  icone: Icons.emoji_events,
                  valor: '${ranking.totalMvps}',
                  label: 'MVPs',
                ),
                _EstatisticaResumo(
                  icone: Icons.sports_soccer,
                  valor: '${ranking.totalGols}',
                  label: 'Gols',
                ),
                _EstatisticaResumo(
                  icone: Icons.assistant,
                  valor: '${ranking.totalAssistencias}',
                  label: 'Assist.',
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro ao carregar estatísticas: $e'),
    );
  }
}

class _EstatisticaResumo extends StatelessWidget {
  const _EstatisticaResumo({required this.icone, required this.valor, required this.label});

  final IconData icone;
  final String valor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icone, color: Colors.amber),
        const SizedBox(height: 4),
        Text(valor, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}
