import 'package:cloud_firestore/cloud_firestore.dart';

/// Recado curto deixado para um jogador quando algo aconteceu **fora da
/// tela dele** e não sobrou nenhum documento para contar a história.
///
/// O caso que criou isso: o admin apaga um grupo, as solicitações de entrada
/// vão junto, e quem estava esperando resposta simplesmente veria o racha
/// desaparecer da busca sem nunca saber o que houve.
///
/// É de propósito uma coisa simples e descartável — uma frase e a data. Não
/// é um sistema de notificações: quem lê, dispensa, e o documento some.
class AvisoModel {
  final String id;
  final String mensagem;
  final DateTime criadoEm;

  const AvisoModel({
    required this.id,
    required this.mensagem,
    required this.criadoEm,
  });

  factory AvisoModel.fromMap(String id, Map<String, dynamic> map) {
    return AvisoModel(
      id: id,
      mensagem: map['mensagem'] as String,
      criadoEm: (map['criadoEm'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mensagem': mensagem,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
