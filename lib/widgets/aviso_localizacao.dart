import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/firebase_providers.dart';

/// Tela de explicação mostrada ANTES do pedido de localização do Android
/// (RF28 no Trello, T25 em docs/tarefas.md).
///
/// A Play Store exige essa "divulgação em destaque": o app precisa dizer com
/// as próprias palavras por que quer a localização e o que faz com ela antes
/// de o sistema perguntar. Pedir direto, sem aviso, é motivo de recusa na
/// revisão.
///
/// Devolve `true` se pode seguir para o pedido do sistema: a pessoa tocou em
/// "Continuar", ou a permissão já estava dada e não há o que explicar.
/// Devolve `false` se ela escolheu "Agora não" — aí o app nem chega a
/// perguntar, e a tela que chamou trata como permissão negada.
Future<bool> explicarLocalizacaoSePreciso(BuildContext context, WidgetRef ref) async {
  final precisa = await ref.read(locationServiceProvider).precisaPedirPermissao();
  if (!precisa || !context.mounted) return true;

  final resposta = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.location_on_outlined, color: AppColors.verde),
      title: const Text('Por que pedimos sua localização'),
      content: const Text(
        'O Racha App usa a sua localização aproximada só para duas coisas:\n\n'
        '• mostrar os rachas abertos perto de você, em "Rachas Próximos";\n'
        '• marcar no mapa onde fica o campo do seu racha.\n\n'
        'Ela é usada só enquanto você está nessas telas. Sua posição não é '
        'salva e ninguém mais vê onde você está — só o local do campo fica '
        'guardado no grupo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  // Fechar tocando fora conta como "Agora não": o sistema só pergunta quando
  // a pessoa escolheu seguir.
  return resposta ?? false;
}
