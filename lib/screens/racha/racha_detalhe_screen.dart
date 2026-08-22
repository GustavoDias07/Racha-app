import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/racha_model.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/racha_controller.dart';
import 'racha_tabs_section.dart';

/// Tela de um racha — usada tanto por quem só foi convidado quanto pelo
/// admin de um racha avulso (rodadas de Grupo usam GrupoDetalheScreen).
/// Local, tipo de campo e data ficam na aba "Próximo racha"
/// (RachaTabsSection), não duplicados aqui.
class RachaDetalheScreen extends ConsumerWidget {
  const RachaDetalheScreen({super.key, required this.rachaId});

  final String rachaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaPorIdProvider(rachaId));
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final racha = rachaAsync.valueOrNull;
    final podeApagar = racha != null && racha.grupoId == null && racha.adminId == uid;
    final state = ref.watch(rachaControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(racha?.nome ?? 'Racha'),
        actions: [
          if (podeApagar)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Apagar racha',
              onPressed:
                  state.isLoading ? null : () => _confirmarERemoverRacha(context, ref, racha),
            ),
        ],
      ),
      body: SafeArea(
        child: rachaAsync.when(
          data: (racha) {
            if (racha == null) {
              return const Center(child: Text('Racha não encontrado.'));
            }
            return RachaTabsSection(racha: racha);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar racha: $e')),
        ),
      ),
    );
  }
}

/// Apaga um racha avulso (admin), com confirmação — ação irreversível pela
/// UI. Rodadas vindas de Grupo não têm esse caminho (ver
/// `RachaRepository.remover`).
Future<void> _confirmarERemoverRacha(
  BuildContext context,
  WidgetRef ref,
  RachaModel racha,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Apagar racha'),
      content: Text('Isso apaga "${racha.nome}" pra sempre. Não dá pra voltar atrás.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  if (confirmar != true) return;

  await ref.read(rachaControllerProvider.notifier).remover(racha.id);
  if (context.mounted) Navigator.of(context).pop();
}
