import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/alvo_avaliacao.dart';
import '../../models/enums.dart';
import '../../providers/avaliacao_controller.dart';
import '../../providers/firebase_providers.dart';

/// Avaliação Pós-Jogo: cada jogador avalia os companheiros do próprio time
/// + 1 jogador do time adversário (docs/estrutura.md, Fluxo 4). Só fica
/// disponível depois que os times foram gerados pra esse racha.
class AvaliacaoScreen extends ConsumerStatefulWidget {
  const AvaliacaoScreen({super.key, required this.rachaId});

  final String rachaId;

  @override
  ConsumerState<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends ConsumerState<AvaliacaoScreen> {
  final Map<String, double> _notasCompanheiros = {};
  AlvoAvaliacao? _adversarioEscolhido;
  double? _notaAdversario;

  Future<void> _enviar(
    String rachaId,
    String avaliadorId,
    List<AlvoAvaliacao> companheiros,
  ) async {
    final adversario = _adversarioEscolhido;
    final notaAdversario = _notaAdversario;
    final alvosComNota = <(AlvoAvaliacao, double)>[
      for (final c in companheiros) (c, _notasCompanheiros[c.id]!),
      if (adversario != null && notaAdversario != null) (adversario, notaAdversario),
    ];

    await ref.read(avaliacaoControllerProvider.notifier).enviarAvaliacoes(
          rachaId: rachaId,
          avaliadorId: avaliadorId,
          alvosComNota: alvosComNota,
        );

    if (!mounted) return;
    final erro = ref.read(avaliacaoControllerProvider).error;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $erro')));
      return;
    }
    ref.invalidate(contextoAvaliacaoProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Avaliações enviadas. Obrigado!')));
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Não autenticado.')));
    }

    final contextoAsync =
        ref.watch(contextoAvaliacaoProvider((rachaId: widget.rachaId, uid: uid)));
    final enviando = ref.watch(avaliacaoControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Avaliação pós-jogo')),
      body: SafeArea(
        child: contextoAsync.when(
          data: (contexto) {
            if (contexto.jaAvaliou) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Você já avaliou este racha. Obrigado!'),
                ),
              );
            }
            if (contexto.meuTime == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Você só pode avaliar depois que os times forem gerados e você '
                    'tiver participado dessa rodada.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final companheiros = contexto.companheiros;
            final adversarios = contexto.adversarios;
            final companheirosOk =
                companheiros.every((c) => _notasCompanheiros[c.id] != null);
            final formCompleto = companheirosOk &&
                (adversarios.isEmpty ||
                    (_adversarioEscolhido != null && _notaAdversario != null));

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Companheiros de time', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (companheiros.isEmpty)
                  const Text('Nenhum companheiro pra avaliar.')
                else
                  for (final alvo in companheiros)
                    _AlvoTile(
                      alvo: alvo,
                      nota: _notasCompanheiros[alvo.id],
                      onNotaChanged: (n) => setState(() => _notasCompanheiros[alvo.id] = n),
                    ),
                const SizedBox(height: 24),
                Text('Escolha 1 adversário pra avaliar',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (adversarios.isEmpty)
                  const Text('Nenhum adversário disponível.')
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final alvo in adversarios)
                        _AdversarioChip(
                          alvo: alvo,
                          selecionado: _adversarioEscolhido?.id == alvo.id,
                          onSelected: () => setState(() => _adversarioEscolhido = alvo),
                        ),
                    ],
                  ),
                  if (_adversarioEscolhido != null) ...[
                    const SizedBox(height: 12),
                    _NotaSelector(
                      nota: _notaAdversario,
                      onChanged: (n) => setState(() => _notaAdversario = n),
                    ),
                  ],
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: (formCompleto && !enviando)
                      ? () => _enviar(widget.rachaId, uid, companheiros)
                      : null,
                  child: enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar avaliações'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        ),
      ),
    );
  }
}

class _AlvoNome extends ConsumerWidget {
  const _AlvoNome({required this.alvo});

  final AlvoAvaliacao alvo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alvo.tipo == TipoJogador.convidado) {
      return Text(alvo.nome ?? '');
    }
    final userAsync = ref.watch(userPorIdProvider(alvo.id));
    return Text(userAsync.valueOrNull?.nome ?? 'Carregando...');
  }
}

class _AlvoTile extends StatelessWidget {
  const _AlvoTile({required this.alvo, required this.nota, required this.onNotaChanged});

  final AlvoAvaliacao alvo;
  final double? nota;
  final ValueChanged<double> onNotaChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: _AlvoNome(alvo: alvo)),
          _NotaSelector(nota: nota, onChanged: onNotaChanged),
        ],
      ),
    );
  }
}

class _AdversarioChip extends ConsumerWidget {
  const _AdversarioChip({
    required this.alvo,
    required this.selecionado,
    required this.onSelected,
  });

  final AlvoAvaliacao alvo;
  final bool selecionado;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String nome;
    if (alvo.tipo == TipoJogador.convidado) {
      nome = alvo.nome ?? '';
    } else {
      nome = ref.watch(userPorIdProvider(alvo.id)).valueOrNull?.nome ?? '...';
    }
    return ChoiceChip(
      label: Text(nome),
      selected: selecionado,
      onSelected: (_) => onSelected(),
    );
  }
}

/// Seletor de nota de 1 a 5 estrelas.
class _NotaSelector extends StatelessWidget {
  const _NotaSelector({required this.nota, required this.onChanged});

  final double? nota;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              (nota ?? 0) >= i ? Icons.star : Icons.star_border,
              color: Colors.amber,
            ),
            onPressed: () => onChanged(i.toDouble()),
          ),
      ],
    );
  }
}
