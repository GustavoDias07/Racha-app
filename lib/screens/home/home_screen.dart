import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/participante_model.dart';
import '../../providers/auth_controller.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/racha_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(currentUserModelProvider);
    final grupos = ref.watch(meusGruposProvider);
    final gruposQueParticipo = ref.watch(gruposQueParticipoProvider);
    final rachasAvulsos = ref.watch(meusRachasAvulsosProvider);
    final convites = ref.watch(meusConvitesProvider);
    final meuUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    final avisos = ref.watch(meusAvisosProvider).valueOrNull ?? const [];
    final pendentes = convites.valueOrNull
            ?.where((p) => p.statusConfirmacao == StatusConfirmacao.pendente)
            .length ??
        0;
    final naCaixa = pendentes + avisos.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus rachas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.travel_explore_outlined),
            tooltip: 'Rachas próximos',
            onPressed: () => context.push('/proximos'),
          ),
          IconButton(
            icon: Badge(
              label: Text('$naCaixa'),
              isLabelVisible: naCaixa > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: naCaixa > 0
                ? '$naCaixa item(ns) esperando você'
                : 'Nada esperando você',
            onPressed: naCaixa == 0
                ? null
                : () => _mostrarCaixaDeEntrada(context, meuUid),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Meu perfil',
            onPressed: () => context.push('/perfil'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            grupos.when(
              data: (lista) {
                if (lista.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: lista
                      .map((grupo) => ListTile(
                            title: Text(grupo.nome),
                            subtitle: Text(
                              '${grupo.localPadrao} • ${grupo.diaSemana.label}, ${grupo.horario}',
                            ),
                            trailing: Text(grupo.tipoCampoPadrao.label),
                            onTap: () =>
                                context.push('/grupos/${grupo.id}', extra: grupo),
                          ))
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro: $e'),
              ),
            ),
            rachasAvulsos.when(
              data: (lista) {
                if (lista.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: lista
                      .map((racha) => ListTile(
                            title: Text(racha.nome),
                            subtitle: Text(
                              '${racha.local} • '
                              '${DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(racha.dataHora)}',
                            ),
                            trailing: Text(racha.tipoCampo.label),
                            onTap: () => context.push('/rachas/${racha.id}'),
                          ))
                      .toList(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro: $e'),
              ),
            ),
            // Grupos em que sou só membro fixo (entrei por solicitação
            // aprovada na aba "Rachas Próximos" ou o admin me adicionou).
            // Sem essa seção o grupo era invisível pra quem participa: só
            // chegava o convite solto de cada rodada, sem caminho pro
            // ranking, histórico ou pra sair do grupo.
            gruposQueParticipo.maybeWhen(
              data: (lista) {
                if (lista.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Rachas que participo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...lista.map(
                      (grupo) => ListTile(
                        title: Text(grupo.nome),
                        subtitle: Text(
                          '${grupo.localPadrao} • ${grupo.diaSemana.label}, ${grupo.horario}',
                        ),
                        trailing: Text(grupo.tipoCampoPadrao.label),
                        onTap: () => context.push('/grupos/${grupo.id}', extra: grupo),
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            if (grupos.valueOrNull != null &&
                grupos.valueOrNull!.isEmpty &&
                rachasAvulsos.valueOrNull != null &&
                rachasAvulsos.valueOrNull!.isEmpty &&
                (gruposQueParticipo.valueOrNull?.isEmpty ?? true))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  userModel.valueOrNull?.nome == null
                      ? 'Nenhum racha ainda.'
                      : 'Olá, ${userModel.valueOrNull!.nome}! Nenhum racha ainda.',
                ),
              ),
            convites.maybeWhen(
              data: (lista) {
                if (lista.isEmpty || meuUid == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Convites', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...lista.map(
                      (p) => _ConviteTile(participante: p, meuUid: meuUid),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarOpcoesCriarRacha(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Criar racha'),
      ),
    );
  }
}

/// Fluxo 2 (docs/estrutura.md) prevê que "o jogador convidado recebe
/// notificação" ao ser chamado pra um racha. Sem push (exigiria FCM,
/// service worker no build web, etc. — fora do escopo aqui), o sino com
/// contador na AppBar cumpre a mesma função dentro do app: deixa óbvio que
/// tem coisa esperando resposta assim que a Home abre.
///
/// Junta as duas coisas que chegam pra pessoa: convites pra rodadas e avisos
/// (ver `AvisoModel`), que contam o que aconteceu quando não sobrou nenhuma
/// tela pra mostrar — o caso típico é o grupo que ela pediu pra entrar ter
/// sido apagado.
///
/// O conteúdo é um `Consumer` de propósito: dispensar um aviso apaga o
/// documento, e a folha precisa se redesenhar sozinha em vez de continuar
/// mostrando o que já não existe.
void _mostrarCaixaDeEntrada(BuildContext context, String? meuUid) {
  if (meuUid == null) return;

  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final avisos = ref.watch(meusAvisosProvider).valueOrNull ?? const [];
          final pendentes = (ref.watch(meusConvitesProvider).valueOrNull ?? [])
              .where((p) => p.statusConfirmacao == StatusConfirmacao.pendente)
              .toList();

          if (avisos.isEmpty && pendentes.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nada esperando você por aqui.'),
            );
          }

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (avisos.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Avisos', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...avisos.map((aviso) => ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(aviso.mensagem),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Dispensar',
                        onPressed: () => ref.read(avisoRepositoryProvider).dispensar(
                              userId: meuUid,
                              avisoId: aviso.id,
                            ),
                      ),
                    )),
              ],
              if (pendentes.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Convites pendentes',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...pendentes.map((p) => _ConviteTile(participante: p, meuUid: meuUid)),
              ],
            ],
          );
        },
      ),
    ),
  );
}

/// Tela 3 (docs/estrutura.md) prevê "criar racha" com opção de marcar
/// "tornar recorrente" — como as duas configurações (data específica x dia
/// da semana fixo) são bem diferentes, ficam em telas separadas
/// (`CriarRachaScreen` x `CriarGrupoScreen`) e essa folha só decide qual
/// abrir.
void _mostrarOpcoesCriarRacha(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Racha avulso'),
            subtitle: const Text('Uma data específica, sem repetição'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/rachas/criar');
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat),
            title: const Text('Racha recorrente'),
            subtitle: const Text('Toda semana, no mesmo dia e horário'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/grupos/criar');
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Entrar com código'),
            subtitle: const Text('Alguém já criou o racha e te passou o código'),
            onTap: () {
              Navigator.of(context).pop();
              _mostrarDialogoEntrarComCodigo(context, ref);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Item 6 do plano de melhorias: entrar num racha só sabendo o código
/// (que é o próprio id do documento — ver `RachaController.entrarComCodigo`),
/// sem precisar que o admin te encontre por nome/email.
void _mostrarDialogoEntrarComCodigo(BuildContext context, WidgetRef ref) {
  final codigoController = TextEditingController();
  // Fora do builder do StatefulBuilder de propósito — ver o comentário em
  // `_mostrarDialogoAdicionarMembro` (grupo_detalhe_screen.dart).
  var carregando = false;
  String? erro;

  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> entrar() async {
          final codigo = codigoController.text.trim();
          if (codigo.isEmpty) return;
          setState(() {
            carregando = true;
            erro = null;
          });
          try {
            final rachaId =
                await ref.read(rachaControllerProvider.notifier).entrarComCodigo(codigo);
            if (!context.mounted) return;
            if (rachaId == null) {
              setState(() {
                carregando = false;
                erro = 'Código inválido — nenhum racha encontrado.';
              });
              return;
            }
            Navigator.of(context).pop();
            context.push('/rachas/$rachaId');
          } catch (e) {
            setState(() {
              carregando = false;
              erro = 'Código inválido — nenhum racha encontrado.';
            });
          }
        }

        return AlertDialog(
          title: const Text('Entrar com código'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigoController,
                decoration: const InputDecoration(labelText: 'Código do racha'),
                onSubmitted: (_) => entrar(),
              ),
              if (erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(erro!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: carregando ? null : entrar,
              child: carregando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
          ],
        );
      },
    ),
  );
}

/// Uma rodada em que o usuário foi convidado (não é admin). Ignora silenciosamente
/// rachas em que ele é admin — essas já aparecem em "Meus rachas".
class _ConviteTile extends ConsumerWidget {
  const _ConviteTile({required this.participante, required this.meuUid});

  final ParticipanteModel participante;
  final String meuUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaPorIdProvider(participante.rachaId));

    return rachaAsync.maybeWhen(
      data: (racha) {
        if (racha == null || racha.adminId == meuUid) return const SizedBox.shrink();
        final statusLabel = switch (participante.statusConfirmacao) {
          StatusConfirmacao.confirmado => 'Confirmado',
          StatusConfirmacao.recusado => 'Recusado',
          StatusConfirmacao.pendente => 'Pendente',
        };
        return ListTile(
          title: Text(racha.nome),
          subtitle: Text(
            '${racha.local} • ${DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(racha.dataHora)}',
          ),
          trailing: Text(statusLabel),
          onTap: () => context.push('/rachas/${racha.id}'),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
