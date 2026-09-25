import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Título que separa blocos de uma lista ("Meus rachas", "Convites").
///
/// Ele precisa se distinguir do conteúdo **sem competir com ele**. Antes era
/// só um texto em negrito, do mesmo tamanho e da mesma cor dos nomes dos
/// rachas logo abaixo — o olho não tinha como saber o que era rótulo e o que
/// era item.
///
/// A separação aqui vem de três sinais ao mesmo tempo, nenhum deles sendo
/// "maior e mais forte": caixa alta, corpo menor, letras espaçadas e cor de
/// apoio. O resultado é um rótulo que se lê como rótulo, e deixa o nome do
/// racha como a informação mais pesada da tela.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao});

  final String texto;

  /// Botão opcional à direita (ex: "ver todos").
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.textoSecundario,
              ),
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}
