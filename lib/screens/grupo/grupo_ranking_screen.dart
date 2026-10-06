import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatar_jogador.dart';
import '../../models/ranking_model.dart';
import '../../providers/firebase_providers.dart';

/// Ranking desse Grupo só — quem tem mais MVPs e melhor desempenho nas
/// rodadas jogadas ali. Nada de ranking geral do app: comparar jogadores
/// de grupos diferentes, que nem se conhecem, não fazia sentido.
class GrupoRankingScreen extends ConsumerWidget {
  const GrupoRankingScreen({super.key, required this.grupoId, required this.grupoNome});

  final String grupoId;
  final String grupoNome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingDoGrupoProvider(grupoId));

    return Scaffold(
      appBar: AppBar(title: Text('Ranking — $grupoNome')),
      body: SafeArea(
        child: rankingAsync.when(
          data: (lista) {
            if (lista.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Ainda não há avaliações suficientes pra formar um ranking '
                    'nesse grupo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: lista.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) =>
                  _RankingTile(posicao: index + 1, ranking: lista[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar ranking: $e')),
        ),
      ),
    );
  }
}

class _RankingTile extends ConsumerWidget {
  const _RankingTile({required this.posicao, required this.ranking});

  final int posicao;
  final RankingModel ranking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userPorIdProvider(ranking.userId));

    return ListTile(
      contentPadding: EdgeInsets.zero,
      // Foto com a posição num selo no canto, em vez de só o número: no
      // ranking o que se procura é a pessoa, e o rosto acha mais rápido que
      // o nome. O primeiro lugar ganha o selo dourado.
      leading: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AvatarJogador(
              nome: userAsync.valueOrNull?.nome ?? '',
              fotoBase64: userAsync.valueOrNull?.fotoPerfilBase64,
              raio: 23,
            ),
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: posicao == 1
                      ? AppColors.destaque
                      : AppColors.superficieAlta,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.fundo, width: 2),
                ),
                child: Text(
                  '$posicao',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: posicao == 1 ? Colors.black : AppColors.texto,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      title: Text(userAsync.valueOrNull?.nome ?? 'Carregando...'),
      subtitle: Text(
        '${ranking.totalRachas} racha(s) avaliado(s) • ${ranking.totalGols} gol(s) • '
        '${ranking.totalAssistencias} assistência(s)',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                color: ranking.mediaAvaliacoes > 0
                    ? AppColors.destaque
                    : AppColors.neutro,
                size: 16,
              ),
              const SizedBox(width: 2),
              // Zero aqui quer dizer "ainda não foi avaliado", não "joga
              // mal". Com 0.0 e estrela, o jogador parecia o pior do grupo.
              Text(
                ranking.mediaAvaliacoes > 0
                    ? ranking.mediaAvaliacoes.toStringAsFixed(1)
                    : '—',
              ),
            ],
          ),
          if (ranking.totalMvps > 0)
            Text(
              '${ranking.totalMvps} MVP${ranking.totalMvps > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
            ),
        ],
      ),
    );
  }
}
