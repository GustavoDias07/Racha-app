import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/geo_utils.dart';
import '../../models/enums.dart';
import '../../models/grupo_model.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/solicitacao_controller.dart';

const _raiosKm = [5, 10, 25, 50];

/// Aba "Rachas Próximos": mostra os grupos que o admin marcou como "aberto
/// pra novos jogadores" (`GrupoModel.abertoParaNovosMembros`), filtrados por
/// distância até a posição atual do usuário. Ver
/// `lib/core/utils/geo_utils.dart` pra por que isso é filtrado no cliente em
/// vez de geoquery no servidor.
class RachasProximosScreen extends ConsumerStatefulWidget {
  const RachasProximosScreen({super.key});

  @override
  ConsumerState<RachasProximosScreen> createState() => _RachasProximosScreenState();
}

class _RachasProximosScreenState extends ConsumerState<RachasProximosScreen> {
  GeoPoint? _minhaPosicao;
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
      final posicao = await ref.read(locationServiceProvider).obterPosicaoAtual();
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

    final minhaPosicao = _minhaPosicao!;
    final gruposAsync = ref.watch(rachasAbertosProvider);
    final meuUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Column(
      children: [
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
              // Grupo que já é meu (dono ou membro fixo) não é "descoberta":
              // ele aparece na Home, e deixar o card aqui só oferecia um
              // botão de solicitar entrada em algo em que já estou dentro.
              final proximos = grupos
                  .where((g) =>
                      g.localizacao != null &&
                      g.adminId != meuUid &&
                      !g.membrosFixos.contains(meuUid))
                  .map((g) => (grupo: g, distancia: distanciaKm(minhaPosicao, g.localizacao!)))
                  .where((par) => par.distancia <= _raioKm)
                  .toList()
                ..sort((a, b) => a.distancia.compareTo(b.distancia));

              if (proximos.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhum racha aberto encontrado nesse raio.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final par in proximos)
                    _RachaProximoTile(grupo: par.grupo, distanciaKm: par.distancia),
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

class _RachaProximoTile extends ConsumerWidget {
  const _RachaProximoTile({required this.grupo, required this.distanciaKm});

  final GrupoModel grupo;
  final double distanciaKm;

  Future<void> _solicitar(BuildContext context, WidgetRef ref) async {
    final resultado =
        await ref.read(solicitacaoControllerProvider.notifier).solicitar(grupo);
    if (!context.mounted) return;

    final mensagem = switch (resultado) {
      ResultadoSolicitacao.enviada =>
        'Pedido enviado! O admin do racha precisa aprovar.',
      ResultadoSolicitacao.jaSolicitou => 'Você já tem um pedido pendente aqui.',
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
    final solicitacao = ref.watch(minhaSolicitacaoProvider(grupo.id)).valueOrNull;
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(grupo.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text('~${distanciaKm.toStringAsFixed(1)} km'),
              ],
            ),
            const SizedBox(height: 4),
            Text('${grupo.localPadrao} • ${grupo.diaSemana.label}, ${grupo.horario}'),
            Text('${grupo.tipoCampoPadrao.label} • ${grupo.qtdJogadoresLinhaPadrao} de linha'),
            if (status == StatusAprovacao.recusado)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Pedido recusado — fale com o organizador se quiser tentar de novo.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: bloqueado ? null : () => _solicitar(context, ref),
                child: Text(rotulo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
