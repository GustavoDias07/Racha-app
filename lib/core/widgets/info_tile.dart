import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Um dado de cabeçalho: rótulo pequeno em cima, valor embaixo.
///
/// Era um `ListTile`, que impõe uma altura mínima de 56 a 72 pixels por
/// linha. Com três ou quatro deles empilhados, o cabeçalho comia metade da
/// tela antes de as abas começarem, e sobrava pouco espaço para o conteúdo
/// que importa. Esta versão usa uma `Row` com espaçamento próprio e ocupa
/// perto da metade da altura, sem perder a distinção entre rótulo e valor —
/// que aqui vem do tamanho e da cor, não do espaço em branco.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icone,
    required this.label,
    required this.valor,
  });

  final IconData icone;
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icone, size: 18, color: AppColors.textoSecundario),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textoSecundario,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.texto,
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
