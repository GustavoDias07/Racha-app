import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatar_jogador.dart';
import '../../core/widgets/confirmar_dialog.dart';
import '../../core/widgets/titulo_secao.dart';
import '../../models/enums.dart';
import '../../providers/auth_controller.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/racha_controller.dart';
import '../../widgets/foto_racha.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(currentUserModelProvider);
    final grupos = ref.watch(meusGruposProvider);
    final gruposQueParticipo = ref.watch(gruposQueParticipoProvider);
    final rachasAvulsos = ref.watch(meusRachasAvulsosProvider);
    final meuUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    final proximasRodadas = ref.watch(proximasRodadasProvider);

    final avisos = ref.watch(meusAvisosProvider).valueOrNull ?? const [];
    // Só conta o que ainda espera resposta E ainda vai acontecer. Antes
    // somava qualquer participação pendente, inclusive de rodadas de meses
    // atrás, e o sino ficava com um número que nunca zerava.
    final pendentes = proximasRodadas.valueOrNull
            ?.where((r) =>
                r.participacao.statusConfirmacao == StatusConfirmacao.pendente)
            .length ??
        0;
    final naCaixa = pendentes + avisos.length;

    return Scaffold(
      appBar: AppBar(
        // O nome do app, não o da seção: "Meus rachas" agora é um título de
        // seção dentro da lista, junto com os outros, e a barra de cima
        // passa a identificar o aplicativo.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.verde,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_soccer, size: 18, color: Colors.black),
            ),
            const SizedBox(width: 10),
            const Text('Racha App'),
          ],
        ),
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
            // A própria foto no lugar do ícone genérico: é o atalho para o
            // perfil e, de quebra, mostra de relance com qual conta se está
            // — útil para quem alterna entre contas de teste.
            icon: AvatarJogador(
              nome: userModel.valueOrNull?.nome ?? '',
              fotoBase64: userModel.valueOrNull?.fotoPerfilBase64,
              raio: 14,
            ),
            tooltip: 'Meu perfil',
            onPressed: () => context.push('/perfil'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair da conta',
            onPressed: () async {
              final sair = await confirmar(
                context,
                titulo: 'Sair da conta',
                mensagem: 'Você vai precisar entrar com email e senha de novo '
                    'para voltar.',
                rotuloConfirmar: 'Sair',
              );
              if (!sair) return;
              await ref.read(authControllerProvider.notifier).logout();
            },
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TituloSecao('Meus rachas'),
                    ...lista.map((grupo) => _RachaTile(
                          fotoBase64: grupo.fotoBase64,
                          nome: grupo.nome,
                          detalhe:
                              '${grupo.localPadrao} • ${grupo.diaSemana.label}, ${grupo.horario}',
                          etiqueta: grupo.tipoCampoPadrao.label,
                          onTap: () =>
                              context.push('/grupos/${grupo.id}', extra: grupo),
                        )),
                  ],
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TituloSecao('Rachas avulsos'),
                    ...lista.map((racha) => _RachaTile(
                          nome: racha.nome,
                          detalhe: '${racha.local} • '
                              '${DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(racha.dataHora)}',
                          etiqueta: racha.tipoCampo.label,
                          onTap: () => context.push('/rachas/${racha.id}'),
                        )),
                  ],
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
                    const TituloSecao('Rachas que participo'),
                    ...lista.map(
                      (grupo) => _RachaTile(
                        fotoBase64: grupo.fotoBase64,
                        nome: grupo.nome,
                        detalhe:
                            '${grupo.localPadrao} • ${grupo.diaSemana.label}, ${grupo.horario}',
                        etiqueta: grupo.tipoCampoPadrao.label,
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
            proximasRodadas.maybeWhen(
              data: (lista) {
                if (lista.isEmpty || meuUid == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TituloSecao('Próximas rodadas'),
                    ...lista.map((r) => _RodadaTile(rodada: r)),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            // O FAB flutua sobre a lista; sem esta folga ele cobre o último
            // item quando a lista chega ao fim.
            const SizedBox(height: 88),
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

/// Um racha na lista da tela inicial.
///
/// Substituiu o `ListTile` simples por um card com fundo próprio. A razão é
/// hierarquia: no fundo escuro, itens sem superfície própria ficavam colados
/// uns nos outros e nos títulos de seção, e a lista virava um bloco de texto
/// corrido. O card dá a cada racha um limite visível, e o nome em branco
/// contra o detalhe em cinza deixa claro o que é o quê.
class _RachaTile extends StatelessWidget {
  const _RachaTile({
    required this.nome,
    required this.detalhe,
    required this.etiqueta,
    required this.onTap,
    this.fotoBase64,
  });

  final String nome;
  final String detalhe;
  final String etiqueta;
  final VoidCallback onTap;

  /// Foto do grupo. Racha avulso não tem (não há grupo para guardá-la),
  /// e nesse caso a miniatura mostra a bola, como antes.
  final String? fotoBase64;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                MiniaturaDoRacha(fotoBase64: fotoBase64, tamanho: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detalhe,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.superficieAlta,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    etiqueta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          // Mesma fonte da seção "Próximas rodadas": o que já passou não
          // espera mais resposta de ninguém e não deve ocupar a caixa.
          final pendentes =
              (ref.watch(proximasRodadasProvider).valueOrNull ?? const [])
                  .where((r) =>
                      r.participacao.statusConfirmacao ==
                      StatusConfirmacao.pendente)
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
                const TituloSecao('Avisos'),
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
                const TituloSecao('Rodadas esperando resposta'),
                ...pendentes.map((r) => _RodadaTile(rodada: r)),
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
                  child: Text(erro!, style: const TextStyle(color: AppColors.recusado)),
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
class _RodadaTile extends StatelessWidget {
  const _RodadaTile({required this.rodada});

  final RodadaConvidada rodada;

  @override
  Widget build(BuildContext context) {
    final racha = rodada.racha;
    final status = rodada.participacao.statusConfirmacao;

    final (rotulo, cor) = switch (status) {
      StatusConfirmacao.confirmado => ('Confirmado', AppColors.confirmado),
      StatusConfirmacao.recusado => ('Recusado', AppColors.recusado),
      StatusConfirmacao.pendente => ('Responder', AppColors.pendente),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push('/rachas/${racha.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    status == StatusConfirmacao.pendente
                        ? Icons.help_outline
                        : Icons.event_available,
                    size: 20,
                    color: cor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        racha.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${racha.local} \u2022 '
                        '${DateFormat("dd/MM 'a\u0300s' HH:mm", 'pt_BR').format(racha.dataHora)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rotulo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
