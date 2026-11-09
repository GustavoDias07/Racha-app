import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presenca/pontuacao_presenca.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatar_jogador.dart';
import '../../models/grupo_model.dart';
import '../../providers/firebase_providers.dart';

/// Tabela de pontuação de presença do grupo (RF22). Todo membro vê a tabela
/// inteira — decisão do grupo: a regra do banco é pública, então os números
/// também são.
class GrupoPresencaScreen extends ConsumerWidget {
  const GrupoPresencaScreen({super.key, required this.grupo});

  final GrupoModel grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stream do grupo: a tabela muda sozinha quando o admin finaliza uma
    // rodada com a tela aberta.
    final grupoAtual = ref.watch(grupoPorIdProvider(grupo.id)).valueOrNull ?? grupo;

    // Todo membro aparece, mesmo sem nenhuma rodada pontuada ainda — quem
    // não está na tabela poderia achar que ficou de fora da regra.
    final membros = {grupoAtual.adminId, ...grupoAtual.membrosFixos};
    final linhas = [
      for (final uid in membros)
        (uid, PontuacaoPresenca(grupoAtual.presencas[uid] ?? const [])),
    ]..sort((a, b) {
        if (a.$2.valida != b.$2.valida) return a.$2.valida ? -1 : 1;
        return b.$2.total.compareTo(a.$2.total);
      });

    return Scaffold(
      appBar: AppBar(title: Text('Presença — ${grupoAtual.nome}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _ExplicacaoRegra(),
            const SizedBox(height: 16),
            for (final (uid, pontuacao) in linhas) ...[
              _LinhaPresenca(userId: uid, pontuacao: pontuacao),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExplicacaoRegra extends StatelessWidget {
  const _ExplicacaoRegra();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Confirmou e foi: +$pontosCompareceu  ·  Confirmou e faltou: $pontosFaltou  ·  '
          'Disse que não vai: $pontosNaoVai\n\n'
          'Contam as últimas $janelaRodadas rodadas para as quais você foi '
          'convidado, a partir de $minimoRodadasParaValer. Quando confirma mais '
          'gente do que cabe nos dois times, quem tem menos pontos fica no '
          'banco. Quem atrasou vai para o fim da fila só naquela rodada.',
          style: TextStyle(color: context.cores.textoSecundario),
        ),
      ),
    );
  }
}

class _LinhaPresenca extends ConsumerWidget {
  const _LinhaPresenca({required this.userId, required this.pontuacao});

  final String userId;
  final PontuacaoPresenca pontuacao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userPorIdProvider(userId)).valueOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AvatarJogador(nome: user?.nome ?? '', fotoBase64: user?.fotoPerfilBase64),
      title: Text(user?.nome ?? 'Carregando...'),
      subtitle: Text(
        pontuacao.valida
            ? '${pontuacao.rodadas} rodada(s) contadas'
            : 'Ainda em avaliação (${pontuacao.rodadas} de $minimoRodadasParaValer rodadas)',
      ),
      trailing: Text(
        pontuacao.valida ? '${pontuacao.total} pts' : '—',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
