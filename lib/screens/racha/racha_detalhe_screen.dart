import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import 'racha_tabs_section.dart';

/// Tela de um racha vista por quem foi convidado (não é admin do grupo).
/// Alcançada pela seção "Convites" da Home — o admin usa GrupoDetalheScreen,
/// que já mostra a mesma coisa a partir do Grupo dono do racha. Local, tipo
/// de campo e data ficam na aba "Próximo racha" (RachaTabsSection), não
/// duplicados aqui.
class RachaDetalheScreen extends ConsumerWidget {
  const RachaDetalheScreen({super.key, required this.rachaId});

  final String rachaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaPorIdProvider(rachaId));

    return Scaffold(
      appBar: AppBar(title: Text(rachaAsync.valueOrNull?.nome ?? 'Racha')),
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
