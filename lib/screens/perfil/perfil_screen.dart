import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/info_tile.dart';
import '../../providers/conta_controller.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/tema_controller.dart';

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
                const SizedBox(height: 24),
                Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const _SeletorAparencia(),
                const SizedBox(height: 40),
                Center(
                  child: TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _ExcluirContaDialog(),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Excluir conta'),
                    style: TextButton.styleFrom(foregroundColor: context.cores.recusado),
                  ),
                ),
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

/// Escolha entre tema Claro, Escuro ou Seguir o celular (T35).
///
/// `SegmentedButton` e não uma lista de opções: são só três escolhas
/// curtas, e assim as três ficam visíveis lado a lado, sem abrir diálogo.
class _SeletorAparencia extends ConsumerWidget {
  const _SeletorAparencia();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(temaProvider);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Claro'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Escuro'),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.phone_android),
            label: Text('Celular'),
            tooltip: 'Seguir o tema do celular',
          ),
        ],
        selected: {modo},
        // O SegmentedButton devolve um conjunto (ele também serve para
        // múltipla escolha); aqui sempre vem exatamente um item.
        onSelectionChanged: (escolha) =>
            ref.read(temaProvider.notifier).escolher(escolha.first),
      ),
    );
  }
}

/// Confirmação da exclusão de conta (RF24): explica o que some, pede a
/// senha de novo e só exclui no botão vermelho. Cancelar, tocar fora ou
/// voltar não fazem nada.
///
/// A senha fica nesta tela e não num `confirmar()` simples porque o próprio
/// Firebase exige login recente para excluir — ver `AuthService.reautenticar`.
class _ExcluirContaDialog extends ConsumerStatefulWidget {
  const _ExcluirContaDialog();

  @override
  ConsumerState<_ExcluirContaDialog> createState() => _ExcluirContaDialogState();
}

class _ExcluirContaDialogState extends ConsumerState<_ExcluirContaDialog> {
  final _senha = TextEditingController();

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _excluir() async {
    await ref.read(contaControllerProvider.notifier).excluirConta(senha: _senha.text);
    // Deu certo: o login sumiu e o roteador já está levando para a tela de
    // login. Deu errado: o erro aparece no próprio diálogo.
    if (mounted && !ref.read(contaControllerProvider).hasError) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(contaControllerProvider);
    return AlertDialog(
      title: const Text('Excluir conta?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isso não tem volta. Seu perfil, sua foto, seus avisos e seu '
              'ranking serão apagados, e você sai de todos os grupos. As notas '
              'e estatísticas de rodadas já jogadas continuam, sem o seu nome, '
              'porque fazem parte do ranking dos outros jogadores.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _senha,
              obscureText: true,
              enabled: !estado.isLoading,
              decoration: const InputDecoration(labelText: 'Digite sua senha para confirmar'),
            ),
            if (estado.hasError) ...[
              const SizedBox(height: 8),
              Text(
                estado.error.toString().replaceFirst('Exception: ', ''),
                style: TextStyle(color: context.cores.recusado),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: estado.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: estado.isLoading ? null : _excluir,
          style: FilledButton.styleFrom(
            backgroundColor: context.cores.recusado,
            foregroundColor: context.cores.sobreRecusado,
          ),
          child: estado.isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Excluir'),
        ),
      ],
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
          return Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Ainda sem avaliações registradas em nenhum racha.',
                style: TextStyle(color: context.cores.textoSecundario),
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
        Icon(icone, color: context.cores.destaque),
        const SizedBox(height: 4),
        Text(valor, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: TextStyle(fontSize: 12, color: context.cores.textoSecundario)),
      ],
    );
  }
}
