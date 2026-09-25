import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Campo que abre um seletor ao ser tocado, com a aparência dos campos de
/// texto ao redor.
///
/// Existe porque data, horário e localização eram botões soltos no meio do
/// formulário. Dois problemas com aquilo: não pareciam campos, então o olho
/// não os lia como parte do que precisava ser preenchido; e o rótulo ficava
/// dentro do botão, sumindo assim que um valor era escolhido — a tela
/// mostrava "22/08/2026" sem dizer que aquilo era a data do racha.
///
/// Aqui o rótulo fica sempre acima do valor, como nos demais campos, e um
/// traço em tom apagado marca o que ainda não foi preenchido.
class CampoDeToque extends StatelessWidget {
  const CampoDeToque({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.icone,
    required this.onTap,
    this.erro,
  });

  final String rotulo;

  /// Nulo enquanto nada foi escolhido.
  final String? valor;
  final IconData icone;
  final VoidCallback onTap;

  /// Mensagem de erro, no mesmo lugar em que os outros campos mostram a
  /// deles — senão a validação deste campo apareceria só como um SnackBar,
  /// longe de onde o problema está.
  final String? erro;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          errorText: erro,
          prefixIcon: Icon(icone, size: 18),
        ),
        child: Text(
          valor ?? '--',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valor == null ? AppColors.neutro : AppColors.texto,
          ),
        ),
      ),
    );
  }
}
