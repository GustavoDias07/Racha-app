import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/info_tile.dart';
import '../../models/convidado_model.dart';
import '../../models/enums.dart';
import '../../models/estatistica_model.dart';
import '../../models/participante_model.dart';
import '../../models/racha_model.dart';
import '../../models/user_model.dart';
import '../../providers/convidado_controller.dart';
import '../../providers/estatistica_controller.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/participante_controller.dart';
import '../../providers/racha_controller.dart';
import '../../providers/ranking_controller.dart';
import '../../providers/times_controller.dart';

/// Conteúdo de dentro de um racha, organizado em abas — Participantes,
/// Convidados, Estatísticas e Próximo racha (confirmação). Usado tanto na
/// tela de detalhe do grupo (visão do admin) quanto na tela de detalhe do
/// racha (visão de quem só foi convidado).
class RachaTabsSection extends StatelessWidget {
  const RachaTabsSection({super.key, required this.racha});

  final RachaModel racha;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Participantes'),
              Tab(text: 'Convidados'),
              Tab(text: 'Times'),
              Tab(text: 'Estatísticas'),
              Tab(text: 'Próximo racha'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ParticipantesTab(racha: racha),
                _ConvidadosTab(racha: racha),
                _TimesTab(racha: racha),
                _EstatisticasTab(racha: racha),
                _ProximoRachaTab(racha: racha),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantesTab extends ConsumerWidget {
  const _ParticipantesTab({required this.racha});

  final RachaModel racha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAdmin = racha.adminId == uid;
    final participantes = ref.watch(participantesDoRachaProvider(racha.id));

    // A chamada só faz sentido a partir da hora do jogo — antes disso não há
    // o que registrar, e o botão só atrapalharia quem está organizando.
    final podeChamar = racha.podeFazerChamada(uid) &&
        DateTime.now().isAfter(racha.dataHora) &&
        racha.status != RachaStatus.finalizado;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (podeChamar) ...[
              FilledButton.icon(
                onPressed: () => _mostrarChamada(context, racha),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Fazer chamada'),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.tonalIcon(
              onPressed: () => context.push('/rachas/${racha.id}/convidar', extra: uid),
              icon: const Icon(Icons.person_add),
              label: const Text('Convidar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        participantes.when(
          data: (lista) {
            if (lista.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Ninguém convidado ainda.'),
              );
            }

            // Agrupado por status (confirmado/pendente/recusado), não uma
            // lista só — senão fica fácil perder de vista quem ainda não
            // respondeu no meio de quem já confirmou.
            final confirmados = lista
                .where((p) => p.statusConfirmacao == StatusConfirmacao.confirmado)
                .toList();
            final pendentes = lista
                .where((p) => p.statusConfirmacao == StatusConfirmacao.pendente)
                .toList();
            final recusados = lista
                .where((p) => p.statusConfirmacao == StatusConfirmacao.recusado)
                .toList();

            Widget grupo(String titulo, List<ParticipanteModel> pessoas) {
              if (pessoas.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      '$titulo (${pessoas.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...pessoas.map((p) => _ParticipanteTile(
                        racha: racha,
                        participante: p,
                        meuUid: uid,
                        isAdmin: isAdmin,
                      )),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                grupo('Confirmados', confirmados),
                grupo('Pendentes', pendentes),
                grupo('Recusados', recusados),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro: $e'),
        ),
      ],
    );
  }
}

class _ConvidadosTab extends ConsumerWidget {
  const _ConvidadosTab({required this.racha});

  final RachaModel racha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAdmin = racha.adminId == uid;
    final convidados = ref.watch(convidadosDoRachaProvider(racha.id));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        convidados.when(
          data: (lista) {
            if (lista.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum convidado adicionado ainda.'),
              );
            }
            return Column(
              children: lista
                  .map((c) => _ConvidadoTile(
                        rachaId: racha.id,
                        convidado: c,
                        isAdmin: isAdmin,
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro: $e'),
        ),
      ],
    );
  }
}

/// Botão "Gerar times" (admin) + visualização dos dois times montados pelo
/// `BalanceadorTimes`. O mínimo de confirmados pra habilitar o botão é
/// `racha.totalVagas * 2` — dois times completos, não só um. Gerar times
/// com menos que isso sempre deixa um lado capenga (ex: 3x2 num Futsal que
/// pede 5x5), o que não é "vagas livres" (docs/estrutura.md), é time
/// incompleto.
class _TimesTab extends ConsumerWidget {
  const _TimesTab({required this.racha});

  final RachaModel racha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAdmin = racha.adminId == uid;
    final participantesAsync = ref.watch(participantesDoRachaProvider(racha.id));
    final convidadosAsync = ref.watch(convidadosDoRachaProvider(racha.id));
    final timesState = ref.watch(timesControllerProvider);
    final rankingState = ref.watch(rankingControllerProvider);

    return participantesAsync.when(
      data: (participantes) => convidadosAsync.when(
        data: (convidados) {
          final confirmados = participantes.where((p) => p.confirmado).toList();
          final aprovados = convidados.where((c) => c.aprovado).toList();
          final totalElegiveis = confirmados.length + aprovados.length;
          final minimo = racha.totalVagas * 2;
          final suficiente = totalElegiveis >= minimo;

          // O balanceamento é feito pela posição principal de cada um (ver
          // core/balanceamento/setores.dart), então vale avisar o admin antes
          // de gerar: sem goleiro declarado nenhum time ganha goleiro fixo, e
          // quem não escolheu posição vira tapa-buraco de setor.
          final semPosicao = confirmados.where((p) => p.posicaoMain == null).length +
              aprovados.where((c) => c.posicaoMain == null).length;
          final semGoleiro = !confirmados.any((p) => p.posicaoMain == Posicao.goleiro) &&
              !aprovados.any((c) => c.posicaoMain == Posicao.goleiro);

          int porPosicao(Posicao? p) => p == Posicao.goleiro ? 0 : 1;
          final timeAParticipantes =
              confirmados.where((p) => p.time == TimeRacha.A).toList()
                ..sort((a, b) => porPosicao(a.posicaoMain).compareTo(porPosicao(b.posicaoMain)));
          final timeBParticipantes =
              confirmados.where((p) => p.time == TimeRacha.B).toList()
                ..sort((a, b) => porPosicao(a.posicaoMain).compareTo(porPosicao(b.posicaoMain)));
          final timeAConvidados = aprovados.where((c) => c.time == TimeRacha.A).toList()
            ..sort((a, b) => porPosicao(a.posicaoMain).compareTo(porPosicao(b.posicaoMain)));
          final timeBConvidados = aprovados.where((c) => c.time == TimeRacha.B).toList()
            ..sort((a, b) => porPosicao(a.posicaoMain).compareTo(porPosicao(b.posicaoMain)));
          final jaGerado = timeAParticipantes.isNotEmpty ||
              timeBParticipantes.isNotEmpty ||
              timeAConvidados.isNotEmpty ||
              timeBConvidados.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (isAdmin) ...[
                Text(
                  suficiente
                      ? '$totalElegiveis confirmado(s) — pronto pra gerar os times.'
                      : 'Faltam confirmados: $totalElegiveis de $minimo necessários '
                          'pra fechar os dois times (formação ${racha.tipoCampo.label}).',
                  style: TextStyle(
                    color: suficiente ? Colors.black87 : Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (semGoleiro || semPosicao > 0) ...[
                  const SizedBox(height: 8),
                  _AvisoEscalacao(semPosicao: semPosicao, semGoleiro: semGoleiro),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (suficiente && !timesState.isLoading)
                      ? () => ref.read(timesControllerProvider.notifier).gerar(racha)
                      : null,
                  icon: timesState.isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shuffle),
                  label: Text(jaGerado ? 'Gerar times novamente' : 'Gerar times'),
                ),
                if (timesState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Erro: ${timesState.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              if (!jaGerado)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Os times ainda não foram gerados.'),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.push('/rachas/${racha.id}/avaliar'),
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Avaliar jogadores'),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Calcular MVP da rodada',
                        onPressed: rankingState.isLoading
                            ? null
                            : () => ref
                                .read(rankingControllerProvider.notifier)
                                .calcularMvpDaRodada(racha),
                        icon: const Icon(Icons.emoji_events_outlined),
                      ),
                    ],
                  ],
                ),
                if (isAdmin && rankingState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Erro: ${rankingState.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (racha.mvpUserId != null) ...[
                  const SizedBox(height: 8),
                  _MvpBanner(userId: racha.mvpUserId!),
                ],
                const SizedBox(height: 16),
                _TimeSection(
                  titulo: 'Time A',
                  participantes: timeAParticipantes,
                  convidados: timeAConvidados,
                ),
                const SizedBox(height: 16),
                _TimeSection(
                  titulo: 'Time B',
                  participantes: timeBParticipantes,
                  convidados: timeBConvidados,
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 24),
                  _FinalizarRachaSection(racha: racha),
                ],
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Erro: $e'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro: $e'),
    );
  }
}

/// Encerra a rodada (admin) — se ela vier de um Grupo recorrente, a
/// próxima já nasce automaticamente com os membros fixos convidados
/// (Fluxo 5, docs/estrutura.md). Ação irreversível pela UI, por isso pede
/// confirmação antes de disparar.
class _FinalizarRachaSection extends ConsumerWidget {
  const _FinalizarRachaSection({required this.racha});

  final RachaModel racha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rachaControllerProvider);

    if (racha.status == RachaStatus.finalizado) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Racha finalizado', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: state.isLoading
              ? null
              : () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Finalizar racha'),
                      content: Text(
                        racha.grupoId == null
                            ? 'Isso encerra a rodada. Não dá pra voltar atrás.'
                            : 'Isso encerra a rodada e já cria a próxima automaticamente, '
                                'convidando os membros fixos do grupo. Não dá pra voltar atrás.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Finalizar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    await ref.read(rachaControllerProvider.notifier).finalizar(racha);
                  }
                },
          icon: state.isLoading
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.flag_outlined),
          label: const Text('Finalizar racha'),
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Erro: ${state.error}', style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

class _MvpBanner extends ConsumerWidget {
  const _MvpBanner({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(userId));
    return Row(
      children: [
        const Icon(Icons.emoji_events, color: Colors.amber),
        const SizedBox(width: 8),
        Text(
          'MVP da rodada: ${userAsync.valueOrNull?.nome ?? '...'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TimeSection extends StatelessWidget {
  const _TimeSection({
    required this.titulo,
    required this.participantes,
    required this.convidados,
  });

  final String titulo;
  final List<ParticipanteModel> participantes;
  final List<ConvidadoModel> convidados;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            for (final p in participantes) _ParticipanteTimeTile(participante: p),
            for (final c in convidados)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(c.nome),
                subtitle: c.posicaoMain != null ? Text(c.posicaoMain!.label) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipanteTimeTile extends ConsumerWidget {
  const _ParticipanteTimeTile({required this.participante});

  final ParticipanteModel participante;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(participante.userId));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person),
      title: Text(userAsync.valueOrNull?.nome ?? 'Carregando...'),
      subtitle:
          participante.posicaoMain != null ? Text(participante.posicaoMain!.label) : null,
    );
  }
}

/// Registro de gols, assistências e cartões de quem jogou a rodada (só
/// entra aqui quem já tem `time` definido pelo algoritmo de balanceamento).
/// Editável pelo admin (qualquer jogador) ou pelo próprio User na sua
/// própria linha — Convidados só o admin edita, já que não têm login.
class _EstatisticasTab extends ConsumerWidget {
  const _EstatisticasTab({required this.racha});

  final RachaModel racha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAdmin = racha.adminId == uid;
    final participantesAsync = ref.watch(participantesDoRachaProvider(racha.id));
    final convidadosAsync = ref.watch(convidadosDoRachaProvider(racha.id));
    final estatisticasAsync = ref.watch(estatisticasDoRachaProvider(racha.id));

    return participantesAsync.when(
      data: (participantes) => convidadosAsync.when(
        data: (convidados) => estatisticasAsync.when(
          data: (estatisticas) {
            final jogaram = [
              ...participantes.where((p) => p.time != null),
              ...convidados.where((c) => c.time != null),
            ];
            if (jogaram.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Os times ainda não foram gerados pra essa rodada.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final porJogador = {for (final e in estatisticas) e.jogadorId: e};

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                for (final jogador in participantes.where((p) => p.time != null))
                  _EstatisticaParticipanteTile(
                    racha: racha,
                    participante: jogador,
                    estatistica: porJogador[jogador.userId],
                    podeEditar: isAdmin || jogador.userId == uid,
                  ),
                for (final jogador in convidados.where((c) => c.time != null))
                  _EstatisticaConvidadoTile(
                    racha: racha,
                    convidado: jogador,
                    estatistica: porJogador[jogador.id],
                    podeEditar: isAdmin,
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro: $e'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Erro: $e'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro: $e'),
    );
  }
}

class _EstatisticaParticipanteTile extends ConsumerWidget {
  const _EstatisticaParticipanteTile({
    required this.racha,
    required this.participante,
    required this.estatistica,
    required this.podeEditar,
  });

  final RachaModel racha;
  final ParticipanteModel participante;
  final EstatisticaModel? estatistica;
  final bool podeEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(participante.userId));
    return _EstatisticaTile(
      nome: userAsync.valueOrNull?.nome ?? 'Carregando...',
      estatistica: estatistica,
      podeEditar: podeEditar,
      onEditar: () => _mostrarDialogoEstatistica(
        context,
        ref,
        rachaId: racha.id,
        grupoId: racha.grupoId,
        jogadorId: participante.userId,
        jogadorTipo: TipoJogador.user,
        estatistica: estatistica,
      ),
    );
  }
}

class _EstatisticaConvidadoTile extends ConsumerWidget {
  const _EstatisticaConvidadoTile({
    required this.racha,
    required this.convidado,
    required this.estatistica,
    required this.podeEditar,
  });

  final RachaModel racha;
  final ConvidadoModel convidado;
  final EstatisticaModel? estatistica;
  final bool podeEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EstatisticaTile(
      nome: convidado.nome,
      estatistica: estatistica,
      podeEditar: podeEditar,
      onEditar: () => _mostrarDialogoEstatistica(
        context,
        ref,
        rachaId: racha.id,
        grupoId: racha.grupoId,
        jogadorId: convidado.id,
        jogadorTipo: TipoJogador.convidado,
        estatistica: estatistica,
      ),
    );
  }
}

class _EstatisticaTile extends StatelessWidget {
  const _EstatisticaTile({
    required this.nome,
    required this.estatistica,
    required this.podeEditar,
    required this.onEditar,
  });

  final String nome;
  final EstatisticaModel? estatistica;
  final bool podeEditar;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final gols = estatistica?.gols ?? 0;
    final assistencias = estatistica?.assistencias ?? 0;
    final amarelos = estatistica?.cartoesAmarelos ?? 0;
    final vermelhos = estatistica?.cartoesVermelhos ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person),
      title: Text(nome),
      subtitle: Text(
        '⚽ $gols  🎯 $assistencias  🟨 $amarelos  🟥 $vermelhos',
      ),
      trailing: podeEditar
          ? IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Registrar estatísticas',
              onPressed: onEditar,
            )
          : null,
    );
  }
}

/// Diálogo pra registrar/editar gols, assistências e cartões de um jogador
/// num racha. Salva sempre os 4 valores de uma vez (upsert — ver
/// `EstatisticaRepository.salvar`).
Future<void> _mostrarDialogoEstatistica(
  BuildContext context,
  WidgetRef ref, {
  required String rachaId,
  required String? grupoId,
  required String jogadorId,
  required TipoJogador jogadorTipo,
  required EstatisticaModel? estatistica,
}) {
  final golsController =
      TextEditingController(text: '${estatistica?.gols ?? 0}');
  final assistenciasController =
      TextEditingController(text: '${estatistica?.assistencias ?? 0}');
  final amarelosController =
      TextEditingController(text: '${estatistica?.cartoesAmarelos ?? 0}');
  final vermelhosController =
      TextEditingController(text: '${estatistica?.cartoesVermelhos ?? 0}');

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Estatísticas'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: golsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Gols'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: assistenciasController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Assistências'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: amarelosController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Cartões amarelos'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: vermelhosController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Cartões vermelhos'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(estatisticaControllerProvider.notifier).salvar(
                  rachaId: rachaId,
                  grupoId: grupoId,
                  jogadorId: jogadorId,
                  jogadorTipo: jogadorTipo,
                  gols: int.tryParse(golsController.text) ?? 0,
                  assistencias: int.tryParse(assistenciasController.text) ?? 0,
                  cartoesAmarelos: int.tryParse(amarelosController.text) ?? 0,
                  cartoesVermelhos: int.tryParse(vermelhosController.text) ?? 0,
                );
            Navigator.of(context).pop();
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

class _ProximoRachaTab extends ConsumerWidget {
  const _ProximoRachaTab({required this.racha});

  final RachaModel racha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAdmin = racha.adminId == uid;
    final participantes = ref.watch(participantesDoRachaProvider(racha.id));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        InfoTile(
          icone: Icons.calendar_today,
          label: 'Próxima rodada',
          valor: DateFormat("EEEE, dd/MM 'às' HH:mm", 'pt_BR').format(racha.dataHora),
        ),
        InfoTile(icone: Icons.place, label: 'Local', valor: racha.local),
        InfoTile(
          icone: Icons.sports_soccer,
          label: 'Tipo de campo',
          valor: '${racha.tipoCampo.label} • ${racha.qtdJogadoresLinha} jogadores de linha',
        ),
        if (isAdmin) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _mostrarDialogoCodigo(context, racha),
                icon: const Icon(Icons.qr_code),
                label: const Text('Compartilhar código'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/rachas/${racha.id}/editar', extra: racha),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar racha'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        participantes.maybeWhen(
          data: (lista) {
            ParticipanteModel? meuParticipante;
            for (final p in lista) {
              if (p.userId == uid) {
                meuParticipante = p;
                break;
              }
            }
            if (meuParticipante == null ||
                meuParticipante.statusConfirmacao != StatusConfirmacao.pendente) {
              return const SizedBox.shrink();
            }
            final participanteId = meuParticipante.id;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Você foi convidado pra essa rodada. Confirma presença?'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(participanteControllerProvider.notifier)
                                  .atualizarStatus(
                                    rachaId: racha.id,
                                    participanteId: participanteId,
                                    status: StatusConfirmacao.confirmado,
                                  );
                              await ref
                                  .read(localNotificationServiceProvider)
                                  .agendarLembrete(racha);
                            },
                            child: const Text('Confirmar presença'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(participanteControllerProvider.notifier)
                                  .atualizarStatus(
                                    rachaId: racha.id,
                                    participanteId: participanteId,
                                    status: StatusConfirmacao.recusado,
                                  );
                              await ref
                                  .read(localNotificationServiceProvider)
                                  .cancelarLembrete(racha.id);
                            },
                            child: const Text('Recusar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Mostra o código pra convidar gente por fora do fluxo de busca por
/// nome/email — o código é o próprio id do racha (ver
/// `RachaController.entrarComCodigo`), sem nada extra pra gerar/guardar.
void _mostrarDialogoCodigo(BuildContext context, RachaModel racha) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Código do racha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Compartilhe esse código — quem entrar com ele na Home '
              'já fica confirmado direto:'),
          const SizedBox(height: 12),
          SelectableText(
            racha.id,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: racha.id));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Código copiado!')));
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar'),
        ),
      ],
    ),
  );
}

class _ParticipanteTile extends ConsumerWidget {
  const _ParticipanteTile({
    required this.racha,
    required this.participante,
    required this.meuUid,
    required this.isAdmin,
  });

  final RachaModel racha;
  final ParticipanteModel participante;
  final String? meuUid;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaId = racha.id;
    final userAsync = ref.watch(userPorIdProvider(participante.userId));
    final souEu = participante.userId == meuUid;
    final pendente = participante.statusConfirmacao == StatusConfirmacao.pendente;
    final confirmado = participante.confirmado;
    final mostrarTrailing = (souEu && (pendente || confirmado)) || isAdmin;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person),
      title: Text(userAsync.valueOrNull?.nome ?? 'Carregando...'),
      subtitle: Row(
        children: [
          _StatusChip(status: participante.statusConfirmacao),
          if (participante.posicaoMain != null) ...[
            const SizedBox(width: 8),
            Text('• ${participante.posicaoMain!.label}'),
          ] else if (confirmado) ...[
            const SizedBox(width: 8),
            Text(
              '• Sem posição',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ],
          if (participante.presenca != null) ...[
            const SizedBox(width: 8),
            Text(
              '• ${participante.presenca!.label}',
              style: TextStyle(
                color: switch (participante.presenca!) {
                  PresencaFinal.compareceu => Colors.green[700],
                  PresencaFinal.atrasou => Colors.orange[800],
                  PresencaFinal.faltou => Colors.red[700],
                },
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      trailing: mostrarTrailing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (souEu && confirmado)
                  IconButton(
                    icon: const Icon(Icons.edit_note),
                    tooltip: participante.posicaoMain == null
                        ? 'Definir posição'
                        : 'Editar posição',
                    onPressed: () =>
                        _mostrarDialogoPosicao(context, ref, racha, participante),
                  ),
                if (souEu && pendente) ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Confirmar presença',
                    // Confirmar e escolher posição viraram um passo só: quem
                    // entra no racha já diz onde joga, senão o balanceamento
                    // fica sem o dado principal dele. Quem já tinha posição
                    // (voltou atrás depois de recusar) não é perguntado de novo.
                    onPressed: () async {
                      if (participante.posicaoMain == null) {
                        final definiu = await _mostrarDialogoPosicao(
                            context, ref, racha, participante);
                        if (!definiu) return;
                      }
                      await ref
                          .read(participanteControllerProvider.notifier)
                          .atualizarStatus(
                            rachaId: rachaId,
                            participanteId: participante.id,
                            status: StatusConfirmacao.confirmado,
                          );
                      await ref.read(localNotificationServiceProvider).agendarLembrete(racha);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'Recusar',
                    onPressed: () async {
                      await ref
                          .read(participanteControllerProvider.notifier)
                          .atualizarStatus(
                            rachaId: rachaId,
                            participanteId: participante.id,
                            status: StatusConfirmacao.recusado,
                          );
                      await ref.read(localNotificationServiceProvider).cancelarLembrete(rachaId);
                    },
                  ),
                ],
                if (isAdmin && !souEu)
                  IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    tooltip: 'Remover do racha',
                    onPressed: () => _confirmarERemoverParticipante(
                      context,
                      ref,
                      rachaId,
                      participante,
                      userAsync.valueOrNull?.nome ?? 'esse jogador',
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

Future<void> _confirmarERemoverParticipante(
  BuildContext context,
  WidgetRef ref,
  String rachaId,
  ParticipanteModel participante,
  String nome,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover jogador'),
      content: Text('Tirar $nome desse racha?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remover'),
        ),
      ],
    ),
  );
  if (confirmar != true) return;

  await ref
      .read(participanteControllerProvider.notifier)
      .remover(rachaId: rachaId, participanteId: participante.id);
}

/// Lista de chamada do dia. Aparece pra quem tem permissão (admin ou
/// anotador) a partir do horário do racha.
///
/// Só lista quem **confirmou presença**: a chamada existe pra comparar o que
/// a pessoa disse que ia fazer com o que ela fez. Quem recusou com
/// antecedência não está sendo cobrado de nada — avisar é o comportamento
/// correto, e aparecer numa lista de chamada sugeriria o contrário.
void _mostrarChamada(BuildContext context, RachaModel racha) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final confirmados =
              (ref.watch(participantesDoRachaProvider(racha.id)).valueOrNull ?? [])
                  .where((p) => p.confirmado)
                  .toList();

          if (confirmados.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Ninguém confirmou presença nessa rodada.'),
            );
          }

          final faltaRegistrar =
              confirmados.where((p) => p.presenca == null).length;

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chamada',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      faltaRegistrar == 0
                          ? 'Todo mundo registrado.'
                          : 'Faltam $faltaRegistrar de ${confirmados.length}.',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              ...confirmados.map(
                (participante) => _LinhaChamada(racha: racha, participante: participante),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    ),
  );
}

class _LinhaChamada extends ConsumerWidget {
  const _LinhaChamada({required this.racha, required this.participante});

  final RachaModel racha;
  final ParticipanteModel participante;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(participante.userId));

    return ListTile(
      dense: true,
      title: Text(userAsync.valueOrNull?.nome ?? 'Carregando...'),
      trailing: SegmentedButton<PresencaFinal>(
        showSelectedIcon: false,
        emptySelectionAllowed: true,
        segments: const [
          ButtonSegment(
            value: PresencaFinal.compareceu,
            icon: Icon(Icons.check, size: 18),
            tooltip: 'Chegou no horário',
          ),
          ButtonSegment(
            value: PresencaFinal.atrasou,
            icon: Icon(Icons.schedule, size: 18),
            tooltip: 'Chegou atrasado',
          ),
          ButtonSegment(
            value: PresencaFinal.faltou,
            icon: Icon(Icons.close, size: 18),
            tooltip: 'Não apareceu',
          ),
        ],
        selected: {if (participante.presenca != null) participante.presenca!},
        onSelectionChanged: (selecao) {
          if (selecao.isEmpty) return;
          ref.read(participanteControllerProvider.notifier).registrarPresenca(
                rachaId: racha.id,
                participanteId: participante.id,
                presenca: selecao.first,
              );
        },
      ),
    );
  }
}

/// Avisa o admin do que vai faltar quando os times forem gerados. Não
/// bloqueia nada — dá pra jogar sem goleiro declarado, só é melhor saber
/// disso antes de apertar o botão do que depois.
class _AvisoEscalacao extends StatelessWidget {
  const _AvisoEscalacao({required this.semPosicao, required this.semGoleiro});

  final int semPosicao;
  final bool semGoleiro;

  @override
  Widget build(BuildContext context) {
    final avisos = [
      if (semGoleiro)
        'Ninguém escolheu goleiro — os dois times vão entrar sem goleiro fixo.',
      if (semPosicao > 0)
        semPosicao == 1
            ? '1 jogador ainda não escolheu posição e vai entrar onde estiver faltando gente.'
            : '$semPosicao jogadores ainda não escolheram posição e vão entrar onde estiver faltando gente.',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final aviso in avisos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(aviso, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Diálogo em que o jogador escolhe onde joga. Aparece na hora de confirmar
/// presença (e não escondido atrás de um botão depois), porque sem a posição
/// main o algoritmo não sabe montar os setores nem quem é goleiro — ver
/// `lib/core/balanceamento/setores.dart`.
///
/// Mostra a formação do racha junto: a escolha muda de sentido dependendo do
/// campo (num futsal de 4 de linha não existe "ala esquerdo puro"), então o
/// jogador decide vendo onde vai jogar.
///
/// Devolve `true` se as posições foram salvas.
Future<bool> _mostrarDialogoPosicao(
  BuildContext context,
  WidgetRef ref,
  RachaModel racha,
  ParticipanteModel participante,
) async {
  var main = participante.posicaoMain;
  // A secundária só existe quando é diferente da principal — guardar as duas
  // iguais é o mesmo que não ter secundária.
  var secundaria = participante.posicaoUsual == participante.posicaoMain
      ? null
      : participante.posicaoUsual;

  final salvou = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Onde você joga?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${racha.tipoCampo.label} • ${racha.qtdJogadoresLinha} na linha '
                '+ goleiro',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Posicao>(
                initialValue: main,
                decoration: const InputDecoration(
                  labelText: 'Posição principal',
                  helperText: 'É por ela que o time é montado',
                ),
                items: Posicao.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (p) => setState(() => main = p),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Posicao?>(
                initialValue: secundaria,
                decoration: const InputDecoration(
                  labelText: 'Também joga de (opcional)',
                  helperText: 'Só usada se faltar gente nesse setor',
                ),
                items: [
                  const DropdownMenuItem<Posicao?>(
                    value: null,
                    child: Text('Só a principal'),
                  ),
                  ...Posicao.values.map(
                    (p) => DropdownMenuItem<Posicao?>(value: p, child: Text(p.label)),
                  ),
                ],
                onChanged: (p) => setState(() => secundaria = p),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: main == null
                ? null
                : () {
                    ref
                        .read(participanteControllerProvider.notifier)
                        .definirPosicoes(
                          rachaId: racha.id,
                          participanteId: participante.id,
                          posicaoMain: main!,
                          posicaoUsual: secundaria ?? main!,
                        );
                    Navigator.of(context).pop(true);
                  },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );

  return salvou ?? false;
}

class _ConvidadoTile extends ConsumerWidget {
  const _ConvidadoTile({required this.rachaId, required this.convidado, required this.isAdmin});

  final String rachaId;
  final ConvidadoModel convidado;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendente = convidado.statusAprovacao == StatusAprovacao.pendente;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(convidado.nome),
      subtitle: convidado.oficializado
          ? const Text('Oficializado', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600))
          : _StatusChip(statusAprovacao: convidado.statusAprovacao),
      trailing: isAdmin
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pendente) ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Aprovar',
                    onPressed: () => ref
                        .read(convidadoControllerProvider.notifier)
                        .atualizarAprovacao(
                          rachaId: rachaId,
                          convidadoId: convidado.id,
                          status: StatusAprovacao.aprovado,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'Recusar',
                    onPressed: () => ref
                        .read(convidadoControllerProvider.notifier)
                        .atualizarAprovacao(
                          rachaId: rachaId,
                          convidadoId: convidado.id,
                          status: StatusAprovacao.recusado,
                        ),
                  ),
                ],
                if (!convidado.oficializado)
                  IconButton(
                    icon: const Icon(Icons.badge_outlined),
                    tooltip: 'Oficializar (virar jogador cadastrado)',
                    onPressed: () =>
                        _mostrarDialogoOficializar(context, ref, rachaId, convidado),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: 'Remover do racha',
                  onPressed: () =>
                      _confirmarERemoverConvidado(context, ref, rachaId, convidado),
                ),
              ],
            )
          : null,
    );
  }
}

Future<void> _confirmarERemoverConvidado(
  BuildContext context,
  WidgetRef ref,
  String rachaId,
  ConvidadoModel convidado,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover convidado'),
      content: Text('Tirar ${convidado.nome} desse racha?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remover'),
        ),
      ],
    ),
  );
  if (confirmar != true) return;

  await ref
      .read(convidadoControllerProvider.notifier)
      .remover(rachaId: rachaId, convidadoId: convidado.id);
}

/// Fluxo 3.1 (docs/estrutura.md): o convidado já criou a própria conta em
/// outro momento (Cadastro normal) — aqui o admin só busca esse User por
/// email e vincula ao histórico que ele acumulou como convidado.
Future<void> _mostrarDialogoOficializar(
  BuildContext context,
  WidgetRef ref,
  String rachaId,
  ConvidadoModel convidado,
) {
  final buscaController = TextEditingController();
  // Fora do builder do StatefulBuilder de propósito — ver o comentário
  // equivalente em `_mostrarDialogoAdicionarMembro`
  // (grupo_detalhe_screen.dart): declarar isso dentro do builder faz o
  // resultado da busca sumir a cada rebuild disparada pelo próprio
  // setState.
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
          title: Text('Oficializar ${convidado.nome}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Busque a conta que essa pessoa já criou pra migrar o '
                  'histórico de avaliações e estatísticas dela.',
                ),
                const SizedBox(height: 12),
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
                        ref.read(convidadoControllerProvider.notifier).oficializar(
                              rachaId: rachaId,
                              convidadoId: convidado.id,
                              userId: user.id,
                            );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Vincular'),
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
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({this.status, this.statusAprovacao})
      : assert(status != null || statusAprovacao != null);

  final StatusConfirmacao? status;
  final StatusAprovacao? statusAprovacao;

  @override
  Widget build(BuildContext context) {
    final (texto, cor) = switch ((status, statusAprovacao)) {
      (StatusConfirmacao.confirmado, _) => ('Confirmado', Colors.green),
      (StatusConfirmacao.recusado, _) => ('Recusado', Colors.red),
      (StatusConfirmacao.pendente, _) => ('Pendente', Colors.orange),
      (_, StatusAprovacao.aprovado) => ('Aprovado', Colors.green),
      (_, StatusAprovacao.recusado) => ('Recusado', Colors.red),
      (_, StatusAprovacao.pendente) => ('Pendente', Colors.orange),
      _ => ('', Colors.grey),
    };
    return Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w600));
  }
}
