import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/info_tile.dart';
import '../../models/enums.dart';
import '../../models/grupo_model.dart';
import '../../providers/firebase_providers.dart';
import '../racha/racha_tabs_section.dart';

/// Tela do racha (grupo recorrente): configuração fixa do grupo num cabeçalho
/// fixo + abas com o conteúdo da rodada aberta atual (participantes,
/// convidados, estatísticas, confirmação).
///
/// Placeholder: definição de posições e geração de times entram aqui nas
/// próximas etapas.
class GrupoDetalheScreen extends ConsumerWidget {
  const GrupoDetalheScreen({super.key, required this.grupo});

  final GrupoModel grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaAtualDoGrupoProvider(grupo.id));

    return Scaffold(
      appBar: AppBar(title: Text(grupo.nome)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  InfoTile(icone: Icons.place, label: 'Local', valor: grupo.localPadrao),
                  InfoTile(
                    icone: Icons.event_repeat,
                    label: 'Quando',
                    valor: '${grupo.diaSemana.label}, ${grupo.horario}',
                  ),
                  InfoTile(
                    icone: Icons.sports_soccer,
                    label: 'Tipo de campo',
                    valor:
                        '${grupo.tipoCampoPadrao.label} • ${grupo.qtdJogadoresLinhaPadrao} jogadores de linha',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rachaAsync.when(
                data: (racha) {
                  if (racha == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma rodada aberta no momento.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    );
                  }
                  return RachaTabsSection(racha: racha);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro ao carregar rodada: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
