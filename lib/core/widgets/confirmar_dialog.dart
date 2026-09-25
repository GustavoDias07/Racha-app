import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Diálogo de confirmação padrão do app.
///
/// Devolve `true` só quando a pessoa toca no botão de confirmar. Cancelar,
/// tocar fora do diálogo ou apertar o botão de voltar devolvem `false` — daí
/// o `?? false` no fim: `showDialog` devolve nulo quando é fechado por fora,
/// e sem isso uma dispensa acidental viraria uma confirmação.
///
/// Existe para as confirmações não ficarem cada uma de um jeito. Antes cada
/// tela montava o seu `AlertDialog` na mão, com rótulos e cores diferentes
/// para a mesma pergunta.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String rotuloConfirmar = 'Confirmar',
  String rotuloCancelar = 'Cancelar',

  /// Pinta o botão de confirmar de vermelho. Use em ação que apaga dados ou
  /// não tem volta — nunca numa saída comum, senão o vermelho perde o peso.
  bool destrutivo = false,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(rotuloCancelar),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: destrutivo
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.recusado,
                  foregroundColor: Colors.black,
                )
              : null,
          child: Text(rotuloConfirmar),
        ),
      ],
    ),
  );
  return resposta ?? false;
}
