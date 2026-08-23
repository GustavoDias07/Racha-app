import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/info_tile.dart';
import '../../models/enums.dart';
import '../../models/grupo_model.dart';
import '../../models/solicitacao_model.dart';
import '../../models/user_model.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/grupo_controller.dart';
import '../../providers/solicitacao_controller.dart';
import '../racha/racha_tabs_section.dart';

enum _AcaoGrupo { editar, apagar, sair }

/// Tela do racha (grupo recorrente): configuração fixa do grupo num cabeçalho
/// fixo + abas com o conteúdo da rodada aberta atual (participantes,
/// convidados, estatísticas, confirmação).
class GrupoDetalheScreen extends ConsumerWidget {
  const GrupoDetalheScreen({super.key, required this.grupo});

  final GrupoModel grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaAtualDoGrupoProvider(grupo.id));
    // O `grupo` que chega por `extra` na navegação é o snapshot do momento
    // em que a Home foi desenhada; o stream mantém nome/local/membros em dia
    // enquanto a tela está aberta (e some quando o grupo é apagado).
    final grupoAtual = ref.watch(grupoPorIdProvider(grupo.id)).valueOrNull ?? grupo;
    final meuUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAdmin = grupoAtual.adminId == meuUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(grupoAtual.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Ranking do grupo',
            onPressed: () =>
                context.push('/grupos/${grupoAtual.id}/ranking', extra: grupoAtual),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico de rodadas',
            onPressed: () =>
                context.push('/grupos/${grupoAtual.id}/historico', extra: grupoAtual),
          ),
          // Editar/apagar são do dono; quem só participa tem a ação
          // inversa (sair). Sem o menu não sobraria caminho nenhum pra
          // deixar um grupo em que a pessoa entrou por solicitação.
          PopupMenuButton<_AcaoGrupo>(
            onSelected: (acao) {
              switch (acao) {
                case _AcaoGrupo.editar:
                  context.push('/grupos/${grupoAtual.id}/editar', extra: grupoAtual);
                case _AcaoGrupo.apagar:
                  _confirmarERemoverGrupo(context, ref, grupoAtual);
                case _AcaoGrupo.sair:
                  _confirmarESairDoGrupo(context, ref, grupoAtual);
              }
            },
            itemBuilder: (context) => isAdmin
                ? const [
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
                  ]
                : const [
                    PopupMenuItem(
                      value: _AcaoGrupo.sair,
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Sair do grupo'),
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
                  InfoTile(
                      icone: Icons.place, label: 'Local', valor: grupoAtual.localPadrao),
                  InfoTile(
                    icone: Icons.event_repeat,
                    label: 'Quando',
                    valor: '${grupoAtual.diaSemana.label}, ${grupoAtual.horario}',
                  ),
                  InfoTile(
                    icone: Icons.sports_soccer,
                    label: 'Tipo de campo',
                    valor:
                        '${grupoAtual.tipoCampoPadrao.label} • ${grupoAtual.qtdJogadoresLinhaPadrao} jogadores de linha',
                  ),
                  const SizedBox(height: 8),
                  _MembrosFixosSection(grupo: grupoAtual, isAdmin: isAdmin),
                  if (isAdmin) ...[
                    _SolicitacoesSection(grupo: grupoAtual),
                    _RecusadasSection(grupo: grupoAtual),
                  ],
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

/// Sai de um grupo em que o usuário é só membro fixo — para de ser
/// convidado automaticamente pras próximas rodadas (Fluxo 5). Não mexe nas
/// rodadas em que ele já foi convidado: pra essas, recusar a presença
/// continua sendo a ação certa, dentro da própria rodada.
Future<void> _confirmarESairDoGrupo(
  BuildContext context,
  WidgetRef ref,
  GrupoModel grupo,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sair do grupo'),
      content: Text(
        'Você para de ser convidado automaticamente pras próximas rodadas de '
        '"${grupo.nome}". Os convites que você já recebeu continuam valendo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (confirmar != true) return;

  await ref.read(grupoControllerProvider.notifier).sair(grupo);
  if (!context.mounted) return;

  final erro = ref.read(grupoControllerProvider).error;
  if (erro != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Erro ao sair do grupo: $erro')));
    return;
  }
  Navigator.of(context).pop();
}

/// Lista de membros fixos do grupo (convidados automaticamente toda vez
/// que uma nova rodada nasce — ver Fluxo 5, docs/estrutura.md) + busca por
/// email pra adicionar/remover.
class _MembrosFixosSection extends ConsumerWidget {
  const _MembrosFixosSection({required this.grupo, required this.isAdmin});

  final GrupoModel grupo;

  /// Quem só participa enxerga a lista (é útil saber com quem joga) mas não
  /// mexe nela — adicionar/remover membro é do dono do grupo, e a regra do
  /// Firestore recusaria a escrita de qualquer forma.
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membrosFixos = grupo.membrosFixos;

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
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Adicionar membro fixo',
                onPressed: () => _mostrarDialogoAdicionarMembro(context, ref, grupo),
              ),
          ],
        ),
        if (membrosFixos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 32, bottom: 4),
            child: Text('Nenhum membro fixo ainda.', style: TextStyle(color: Colors.black54)),
          )
        else ...[
          for (final userId in membrosFixos)
            _MembroFixoTile(grupo: grupo, userId: userId, isAdmin: isAdmin),
          if (isAdmin)
            const Padding(
              padding: EdgeInsets.only(left: 32, top: 4, bottom: 4),
              child: Text(
                'O ícone de prancheta libera o jogador a fazer a chamada do dia.',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
        ],
      ],
    );
  }
}

class _MembroFixoTile extends ConsumerWidget {
  const _MembroFixoTile({
    required this.grupo,
    required this.userId,
    required this.isAdmin,
  });

  final GrupoModel grupo;
  final String userId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(userId));
    final anotador = grupo.auxiliares.contains(userId);

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Expanded(child: Text(userAsync.valueOrNull?.nome ?? 'Carregando...')),
          if (isAdmin)
            IconButton(
              icon: Icon(
                anotador ? Icons.fact_check : Icons.fact_check_outlined,
                size: 18,
                color: anotador ? Colors.green[700] : Colors.black38,
              ),
              tooltip: anotador
                  ? 'Tirar a permissão de fazer a chamada'
                  : 'Deixar fazer a chamada',
              onPressed: () => ref
                  .read(grupoControllerProvider.notifier)
                  .alternarAnotador(grupo, userId),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remover do grupo',
              onPressed: () => _removerMembroFixo(
                context,
                ref,
                grupo,
                userId,
                userAsync.valueOrNull?.nome ?? 'Esse jogador',
              ),
            ),
        ],
      ),
    );
  }
}

/// O que fazer com a rodada aberta quando o admin tira alguém do grupo.
enum _SaidaDoGrupo { soDoGrupo, grupoERodada }

/// Remove o jogador dos membros fixos. Se ele já confirmou presença na
/// rodada aberta, pergunta antes: tirar alguém que se comprometeu com o jogo
/// de sábado é uma decisão do admin, não um efeito colateral de encerrar a
/// recorrência. Quem ainda está pendente (ou já recusou) sai das duas coisas
/// direto, espelhando a aprovação de solicitação, que também coloca a pessoa
/// no grupo e na rodada de uma vez.
Future<void> _removerMembroFixo(
  BuildContext context,
  WidgetRef ref,
  GrupoModel grupo,
  String userId,
  String nome,
) async {
  final rachaAtual = ref.read(rachaAtualDoGrupoProvider(grupo.id)).valueOrNull;
  final participante = rachaAtual == null
      ? null
      : await ref
          .read(participanteRepositoryProvider)
          .buscarPorUserId(rachaAtual.id, userId);
  if (!context.mounted) return;

  var removerDaRodada = participante != null;

  if (participante != null && participante.confirmado) {
    final escolha = await showDialog<_SaidaDoGrupo>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do grupo'),
        content: Text(
          '$nome já confirmou presença na rodada aberta. '
          'Tirar do grupo também tira dessa rodada?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_SaidaDoGrupo.soDoGrupo),
            child: const Text('Deixar jogar essa'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_SaidaDoGrupo.grupoERodada),
            child: const Text('Tirar das duas'),
          ),
        ],
      ),
    );
    if (escolha == null) return;
    removerDaRodada = escolha == _SaidaDoGrupo.grupoERodada;
  }

  await ref.read(grupoControllerProvider.notifier).removerMembroFixo(
        grupo,
        userId,
        removerDaRodadaAberta: removerDaRodada,
      );
  if (!context.mounted) return;

  final erro = ref.read(grupoControllerProvider).error;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        erro != null
            ? 'Não deu pra remover: $erro'
            : removerDaRodada
                ? '$nome saiu do grupo e da rodada aberta.'
                : '$nome saiu do grupo, mas segue na rodada aberta.',
      ),
    ),
  );
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

/// Pedidos de entrada pendentes (aba "Rachas Próximos" de quem ainda não é
/// membro) — só aparece pro admin quando há pelo menos um pendente, mesmo
/// que o grupo já tenha sido fechado de novo nesse meio tempo.
class _SolicitacoesSection extends ConsumerWidget {
  const _SolicitacoesSection({required this.grupo});

  final GrupoModel grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitacoesAsync = ref.watch(solicitacoesPendentesProvider(grupo.id));
    final solicitacoes = solicitacoesAsync.valueOrNull ?? const [];
    if (solicitacoes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_outlined, size: 20, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Solicitações de entrada (${solicitacoes.length})',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          for (final solicitacao in solicitacoes)
            _SolicitacaoTile(grupo: grupo, solicitacao: solicitacao),
        ],
      ),
    );
  }
}

class _SolicitacaoTile extends ConsumerWidget {
  const _SolicitacaoTile({required this.grupo, required this.solicitacao});

  final GrupoModel grupo;
  final SolicitacaoModel solicitacao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(solicitacao.solicitanteId));
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Expanded(child: Text(userAsync.valueOrNull?.nome ?? 'Carregando...')),
          IconButton(
            icon: const Icon(Icons.check, size: 18, color: Colors.green),
            tooltip: 'Aprovar',
            onPressed: () => ref
                .read(solicitacaoControllerProvider.notifier)
                .aprovar(grupo, solicitacao),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            tooltip: 'Recusar',
            onPressed: () => ref
                .read(solicitacaoControllerProvider.notifier)
                .recusar(grupo, solicitacao),
          ),
        ],
      ),
    );
  }
}


/// Pedidos que o admin já recusou. Ficam à mão porque a recusa é definitiva
/// do lado do jogador — ele não consegue pedir de novo — então reabrir aqui é
/// o único caminho de volta. Serve tanto pra uma recusa de ontem quanto pra
/// uma de um ano atrás: a decisão é de quando o racha precisar da pessoa.
class _RecusadasSection extends ConsumerWidget {
  const _RecusadasSection({required this.grupo});

  final GrupoModel grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recusadas =
        ref.watch(solicitacoesRecusadasProvider(grupo.id)).valueOrNull ?? const [];
    if (recusadas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_off_outlined, size: 20, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pedidos recusados (${recusadas.length})',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          for (final solicitacao in recusadas)
            _RecusadaTile(grupo: grupo, solicitacao: solicitacao),
        ],
      ),
    );
  }
}

class _RecusadaTile extends ConsumerWidget {
  const _RecusadaTile({required this.grupo, required this.solicitacao});

  final GrupoModel grupo;
  final SolicitacaoModel solicitacao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(solicitacao.solicitanteId));
    final nome = userAsync.valueOrNull?.nome ?? 'Carregando...';

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(nome, style: const TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(solicitacaoControllerProvider.notifier)
                  .reabrir(grupo, solicitacao);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pedido de $nome voltou para a fila.'),
                ),
              );
            },
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );
  }
}
