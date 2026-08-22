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
import '../../providers/convidado_controller.dart';
import '../../providers/estatistica_controller.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/participante_controller.dart';
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
    final participantes = ref.watch(participantesDoRachaProvider(racha.id));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: () => context.push('/rachas/${racha.id}/convidar', extra: uid),
            icon: const Icon(Icons.person_add),
            label: const Text('Convidar'),
          ),
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
            return Column(
              children: lista
                  .map((p) =>
                      _ParticipanteTile(rachaId: racha.id, participante: p, meuUid: uid))
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
/// `racha.totalVagas` (formação de um time só — ver docs/estrutura.md,
/// Fluxo 2, exemplo "7 no society padrão").
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
          final minimo = racha.totalVagas;
          final suficiente = totalElegiveis >= minimo;

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
                          '(formação ${racha.tipoCampo.label}).',
                  style: TextStyle(
                    color: suficiente ? Colors.black87 : Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                            onPressed: () =>
                                ref.read(participanteControllerProvider.notifier).atualizarStatus(
                                      rachaId: racha.id,
                                      participanteId: participanteId,
                                      status: StatusConfirmacao.confirmado,
                                    ),
                            child: const Text('Confirmar presença'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                ref.read(participanteControllerProvider.notifier).atualizarStatus(
                                      rachaId: racha.id,
                                      participanteId: participanteId,
                                      status: StatusConfirmacao.recusado,
                                    ),
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

class _ParticipanteTile extends ConsumerWidget {
  const _ParticipanteTile({required this.rachaId, required this.participante, required this.meuUid});

  final String rachaId;
  final ParticipanteModel participante;
  final String? meuUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(participante.userId));
    final souEu = participante.userId == meuUid;
    final pendente = participante.statusConfirmacao == StatusConfirmacao.pendente;
    final confirmado = participante.confirmado;

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
          ],
        ],
      ),
      trailing: (souEu && (pendente || confirmado))
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (confirmado)
                  IconButton(
                    icon: const Icon(Icons.edit_note),
                    tooltip: participante.posicaoMain == null
                        ? 'Definir posição'
                        : 'Editar posição',
                    onPressed: () =>
                        _mostrarDialogoPosicao(context, ref, rachaId, participante),
                  ),
                if (pendente) ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Confirmar presença',
                    onPressed: () => ref
                        .read(participanteControllerProvider.notifier)
                        .atualizarStatus(
                          rachaId: rachaId,
                          participanteId: participante.id,
                          status: StatusConfirmacao.confirmado,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'Recusar',
                    onPressed: () => ref
                        .read(participanteControllerProvider.notifier)
                        .atualizarStatus(
                          rachaId: rachaId,
                          participanteId: participante.id,
                          status: StatusConfirmacao.recusado,
                        ),
                  ),
                ],
              ],
            )
          : null,
    );
  }
}

/// Diálogo pra o próprio participante escolher posição main/usual — usadas
/// pelo Estágio 1 do algoritmo de balanceamento (goleiro fixo + versáteis
/// por último). Sem isso, `Participante.posicaoMain` nunca é preenchido e o
/// algoritmo nunca sabe quem é goleiro.
Future<void> _mostrarDialogoPosicao(
  BuildContext context,
  WidgetRef ref,
  String rachaId,
  ParticipanteModel participante,
) {
  var main = participante.posicaoMain ?? Posicao.zagueiro;
  var usual = participante.posicaoUsual ?? Posicao.zagueiro;

  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Suas posições'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Posicao>(
              initialValue: main,
              decoration: const InputDecoration(labelText: 'Posição main'),
              items: Posicao.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: (p) {
                if (p != null) setState(() => main = p);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Posicao>(
              initialValue: usual,
              decoration: const InputDecoration(labelText: 'Posição usual'),
              items: Posicao.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: (p) {
                if (p != null) setState(() => usual = p);
              },
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
              ref.read(participanteControllerProvider.notifier).definirPosicoes(
                    rachaId: rachaId,
                    participanteId: participante.id,
                    posicaoMain: main,
                    posicaoUsual: usual,
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
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
      subtitle: _StatusChip(statusAprovacao: convidado.statusAprovacao),
      trailing: (isAdmin && pendente)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            )
          : null,
    );
  }
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
