import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/utils/imagem_base64.dart';
import '../../models/enums.dart';
import '../../models/grupo_model.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/solicitacao_controller.dart';
import '../../services/location_service.dart';

const _raiosKm = [5, 10, 25, 50];

/// Aba "Rachas Próximos": mostra os grupos que o admin marcou como "aberto
/// pra novos jogadores" (`GrupoModel.abertoParaNovosMembros`), filtrados por
/// distância até a posição atual do usuário. Ver
/// `lib/core/utils/geo_utils.dart` pra por que isso é filtrado no cliente em
/// vez de geoquery no servidor.
class RachasProximosScreen extends ConsumerStatefulWidget {
  const RachasProximosScreen({super.key});

  @override
  ConsumerState<RachasProximosScreen> createState() =>
      _RachasProximosScreenState();
}

class _RachasProximosScreenState extends ConsumerState<RachasProximosScreen> {
  PosicaoAtual? _minhaPosicao;
  String? _erro;
  bool _carregando = true;
  int _raioKm = _raiosKm[1];

  @override
  void initState() {
    super.initState();
    _buscarMinhaPosicao();
  }

  Future<void> _buscarMinhaPosicao() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final posicao = await ref
          .read(locationServiceProvider)
          .obterPosicaoAtual();
      if (!mounted) return;
      setState(() {
        _minhaPosicao = posicao;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = '$e';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rachas Próximos')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _buscarMinhaPosicao,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final minhaPosicao = _minhaPosicao!.ponto;
    final gruposAsync = ref.watch(rachasAbertosProvider);
    final meuUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Column(
      children: [
        if (_minhaPosicao!.imprecisa)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              color: AppColors.superficieAlta,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location,
                      size: 20,
                      color: AppColors.pendente,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sua localização está aproximada '
                        '(${_minhaPosicao!.precisaoLegivel}), então as distâncias '
                        'abaixo são estimativas grosseiras. No computador o '
                        'navegador calcula por Wi-Fi; no celular, com GPS, fica '
                        'preciso.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              for (final raio in _raiosKm)
                ChoiceChip(
                  label: Text('$raio km'),
                  selected: _raioKm == raio,
                  onSelected: (_) => setState(() => _raioKm = raio),
                ),
            ],
          ),
        ),
        Expanded(
          child: gruposAsync.when(
            data: (grupos) {
              // O funil é peneirado em etapas, e cada etapa é guardada, porque
              // é isso que permite explicar ao usuário POR QUE a lista veio
              // vazia. Antes havia só o resultado final e uma mensagem única,
              // que não distinguia "não existe racha aberto" de "existe, mas
              // longe" — e não havia como saber qual era o caso.

              // Grupo que já é meu (dono ou membro fixo) não é "descoberta":
              // ele aparece na Home, e deixar o card aqui só oferecia um
              // botão de solicitar entrada em algo em que já estou dentro.
              final deOutros = grupos
                  .where(
                    (g) =>
                        g.adminId != meuUid && !g.membrosFixos.contains(meuUid),
                  )
                  .toList();

              // Grupo sem ponto no mapa não tem como entrar no cálculo de
              // distância. Só acontece em grupos criados antes de a tela de
              // mapa existir — hoje a localização é obrigatória para abrir.
              final comLocal = deOutros
                  .where((g) => g.localizacao != null)
                  .toList();

              final ordenados =
                  comLocal
                      .map(
                        (g) => (
                          grupo: g,
                          distancia: distanciaKm(minhaPosicao, g.localizacao!),
                        ),
                      )
                      .toList()
                    ..sort((a, b) => a.distancia.compareTo(b.distancia));

              final proximos = ordenados
                  .where((par) => par.distancia <= _raioKm)
                  .toList();

              if (proximos.isEmpty) {
                return _Vazio(
                  totalAbertos: grupos.length,
                  deOutros: deOutros.length,
                  comLocal: comLocal.length,
                  distanciaMaisProximo: ordenados.isEmpty
                      ? null
                      : ordenados.first.distancia,
                  raioKm: _raioKm,
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final par in proximos)
                    _RachaProximoTile(
                      grupo: par.grupo,
                      distanciaKm: par.distancia,
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
        ),
      ],
    );
  }
}

/// Explica por que a lista veio vazia, em vez de só dizer que veio.
///
/// São quatro motivos possíveis e a diferença entre eles é o que a pessoa
/// precisa saber para agir: aumentar o raio não adianta se o problema é que
/// nenhum racha está aberto, e esperar não adianta se o problema é que o
/// único racha aberto é o seu.
class _Vazio extends StatelessWidget {
  const _Vazio({
    required this.totalAbertos,
    required this.deOutros,
    required this.comLocal,
    required this.distanciaMaisProximo,
    required this.raioKm,
  });

  final int totalAbertos;
  final int deOutros;
  final int comLocal;
  final double? distanciaMaisProximo;
  final int raioKm;

  @override
  Widget build(BuildContext context) {
    final (icone, titulo, detalhe) = switch (0) {
      _ when totalAbertos == 0 => (
        Icons.explore_off_outlined,
        'Nenhum racha aberto ainda',
        'Só aparecem aqui os rachas que o organizador marcou como "aberto '
            'para novos jogadores" ao criar o grupo.',
      ),
      _ when deOutros == 0 => (
        Icons.person_outline,
        'Os rachas abertos são seus',
        'Esta aba é para descobrir rachas de outras pessoas, então os que '
            'você organiza ou já participa ficam de fora. Eles continuam na '
            'tela inicial.',
      ),
      _ when comLocal == 0 => (
        Icons.location_off_outlined,
        'Sem localização no mapa',
        'Existem rachas abertos, mas nenhum deles tem um ponto marcado no '
            'mapa — sem isso não dá para calcular a distância.',
      ),
      _ => (
        Icons.social_distance_outlined,
        'Nenhum racha dentro de $raioKm km',
        'O mais próximo está a ${distanciaMaisProximo!.toStringAsFixed(1)} km '
            'daqui. Toque num raio maior acima para alcançá-lo.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: AppColors.neutro),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              detalhe,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

class _RachaProximoTile extends ConsumerWidget {
  const _RachaProximoTile({required this.grupo, required this.distanciaKm});

  final GrupoModel grupo;
  final double distanciaKm;

  Future<void> _solicitar(BuildContext context, WidgetRef ref) async {
    final resultado = await ref
        .read(solicitacaoControllerProvider.notifier)
        .solicitar(grupo);
    if (!context.mounted) return;

    final mensagem = switch (resultado) {
      ResultadoSolicitacao.enviada =>
        'Pedido enviado! O admin do racha precisa aprovar.',
      ResultadoSolicitacao.jaSolicitou =>
        'Você já tem um pedido pendente aqui.',
      ResultadoSolicitacao.jaEraMembro => 'Você já é membro desse racha.',
      ResultadoSolicitacao.recusadoAntes =>
        'Seu pedido foi recusado. Só o organizador pode reabrir.',
      ResultadoSolicitacao.erro =>
        'Não deu pra enviar o pedido. Tente de novo.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitacao = ref
        .watch(minhaSolicitacaoProvider(grupo.id))
        .valueOrNull;
    final solicitacaoState = ref.watch(solicitacaoControllerProvider);

    // Recusa trava o botão de vez: quem decide se a pessoa pode tentar de
    // novo é o organizador, reabrindo o pedido na tela do grupo. Sem isso o
    // recusado pedia de novo no segundo seguinte, e o admin ficava recusando
    // a mesma pessoa pra sempre.
    final status = solicitacao?.status;
    final bloqueado = status != null || solicitacaoState.isLoading;
    final rotulo = switch (status) {
      StatusAprovacao.pendente => 'Pedido pendente',
      StatusAprovacao.aprovado => 'Pedido aprovado',
      StatusAprovacao.recusado => 'Pedido recusado',
      null => 'Solicitar entrada',
    };

    final capa = bytesDaFoto(grupo.fotoBase64);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nesta aba a foto pesa mais que em qualquer outra: quem está
          // decidindo se pede para entrar num racha de desconhecidos quer ver
          // o campo antes. Por isso aqui ela vem grande, e não miniatura.
          if (capa != null)
            AspectRatio(
              aspectRatio: 21 / 9,
              child: Image.memory(
                capa,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        grupo.nome,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text('a ${distanciaLegivel(distanciaKm)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${grupo.localPadrao} • ${grupo.diaSemana.label}, ${grupo.horario}',
                ),
                Text(
                  '${grupo.tipoCampoPadrao.label} • ${grupo.qtdJogadoresLinhaPadrao} de linha',
                ),
                if (status == StatusAprovacao.recusado)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Pedido recusado — fale com o organizador se quiser tentar de novo.',
                      style: TextStyle(color: AppColors.recusado, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: bloqueado
                        ? null
                        : () => _solicitar(context, ref),
                    child: Text(rotulo),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
