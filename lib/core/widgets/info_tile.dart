import 'package:flutter/material.dart';

class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.icone, required this.label, required this.valor});

  final IconData icone;
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone),
      title: Text(label),
      subtitle: Text(valor),
    );
  }
}
