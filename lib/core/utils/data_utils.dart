import '../../models/enums.dart';

extension DiaSemanaWeekday on DiaSemana {
  /// Índice ISO (segunda = 1 ... domingo = 7), igual ao `DateTime.weekday`.
  int get weekday => DiaSemana.values.indexOf(this) + 1;
}

/// Primeira data, a partir de agora, que cai no [diaSemana] informado, no
/// horário "HH:mm". Se hoje já for o dia da semana mas o horário já passou,
/// pula pra próxima semana.
DateTime proximaOcorrencia(DiaSemana diaSemana, String horarioHHmm) {
  final partes = horarioHHmm.split(':');
  final hora = int.parse(partes[0]);
  final minuto = int.parse(partes[1]);

  final agora = DateTime.now();
  var data = DateTime(agora.year, agora.month, agora.day, hora, minuto);

  var diasParaSomar = (diaSemana.weekday - data.weekday) % 7;
  data = data.add(Duration(days: diasParaSomar));
  if (!data.isAfter(agora)) {
    data = data.add(const Duration(days: 7));
  }
  return data;
}
