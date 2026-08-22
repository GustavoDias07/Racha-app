import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/info_tile.dart';
import '../../models/enums.dart';
import '../../models/grupo_model.dart';
import '../../models/user_model.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/grupo_controller.dart';
import '../racha/racha_tabs_section.dart';

enum _AcaoGrupo { editar, apagar }

/// Tela do racha (grupo recorrente): configuração fixa do grupo num cabeçalho
/// fixo + abas com o conteúdo da rodada aberta atual (participantes,
/// convidados, estatísticas, confirmação).
class GrupoDetalheScreen extends ConsumerWidget {
  const GrupoDetalheScreen({super.key, required this.grupo});

  final GrupoModel grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaAtualDoGrupoProvider(grupo.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(grupo.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Ranking do grupo',
            onPressed: () => context.push('/grupos/${grupo.id}/ranking', extra: grupo),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico de rodadas',
            onPressed: () => context.push('/grupos/${grupo.id}/historico', extra: grupo),
          ),
          PopupMenuButton<_AcaoGrupo>(
            onSelected: (acao) {
              switch (acao) {
                case _AcaoGrupo.editar:
                  context.push('/grupos/${grupo.id}/editar', extra: grupo);
                case _AcaoGrupo.apagar:
                  _confirmarERemoverGrupo(context, ref, grupo);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AcaoGrupo.editar,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar grupo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _AcaoGrupo.apagar,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Apagar grupo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
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
                  const SizedBox(height: 8),
                  _MembrosFixosSection(grupo: grupo),
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

/// Apaga o grupo (admin), com confirmação — ação irreversível pela UI. As
/// rodadas já geradas a partir dele não somem junto (ver
/// `GrupoRepository.remover`).
Future<void> _confirmarERemoverGrupo(
  BuildContext context,
  WidgetRef ref,
  GrupoModel grupo,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Apagar grupo'),
      content: Text(
        'Isso apaga "${grupo.nome}" e ele para de gerar novas rodadas. '
        'Rodadas já criadas não são apagadas. Não dá pra voltar atrás.',
      ),
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

  await ref.read(grupoControllerProvider.notifier).remover(grupo);
  if (context.mounted) Navigator.of(context).pop();
}

/// Lista de membros fixos do grupo (convidados automaticamente toda vez
/// que uma nova rodada nasce — ver Fluxo 5, docs/estrutura.md) + busca por
/// email pra adicionar/remover.
class _MembrosFixosSection extends ConsumerWidget {
  const _MembrosFixosSection({required this.grupo});

  final GrupoModel grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupoAsync = ref.watch(grupoPorIdProvider(grupo.id));
    final membrosFixos = grupoAsync.valueOrNull?.membrosFixos ?? grupo.membrosFixos;
    final grupoAtual = grupoAsync.valueOrNull ?? grupo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, size: 20, color: Colors.black54),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Membros fixos', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Adicionar membro fixo',
              onPressed: () => _mostrarDialogoAdicionarMembro(context, ref, grupoAtual),
            ),
          ],
        ),
        if (membrosFixos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 32, bottom: 4),
            child: Text('Nenhum membro fixo ainda.', style: TextStyle(color: Colors.black54)),
          )
        else
          for (final userId in membrosFixos)
            _MembroFixoTile(grupo: grupoAtual, userId: userId),
      ],
    );
  }
}

class _MembroFixoTile extends ConsumerWidget {
  const _MembroFixoTile({required this.grupo, required this.userId});

  final GrupoModel grupo;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(userId));
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Expanded(child: Text(userAsync.valueOrNull?.nome ?? 'Carregando...')),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remover',
            onPressed: () =>
                ref.read(grupoControllerProvider.notifier).removerMembroFixo(grupo, userId),
          ),
        ],
      ),
    );
  }
}

Future<void> _mostrarDialogoAdicionarMembro(
  BuildContext context,
  WidgetRef ref,
  GrupoModel grupo,
) {
  final buscaController = TextEditingController();
  // Precisam viver fora do builder do StatefulBuilder: esse builder roda de
  // novo a cada setState (é o que redesenha o diálogo), então uma variável
  // declarada dentro dele reseta pro valor inicial em toda rebuild — a
  // busca "funcionava" (a query rodava certo) mas o resultado nunca
  // aparecia, porque a rebuild disparada pelo próprio setState(resultados
  // = ...) já recriava `resultados` como lista vazia antes de desenhar.
  var buscando = false;
  List<UserModel> resultados = [];

  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> buscar() async {
          final termo = buscaController.text.trim();
          if (termo.isEmpty) return;
          setState(() => buscando = true);
          final encontrados =
              await ref.read(userRepositoryProvider).buscarPorNomeOuEmail(termo);
          setState(() {
            resultados = encontrados;
            buscando = false;
          });
        }

        return AlertDialog(
          title: const Text('Adicionar membro fixo'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: buscaController,
                        decoration: const InputDecoration(labelText: 'Nome ou email'),
                        onSubmitted: (_) => buscar(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: buscando ? null : buscar,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                for (final user in resultados)
                  ListTile(
                    title: Text(user.nome),
                    subtitle: Text(user.email),
                    trailing: FilledButton(
                      onPressed: () {
                        ref
                            .read(grupoControllerProvider.notifier)
                            .adicionarMembroFixo(grupo, user.id);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Adicionar'),
                    ),
                  ),
                if (!buscando && resultados.isEmpty && buscaController.text.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nenhum jogador encontrado.'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    ),
  );
}
