import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/racha_model.dart';

/// Lembrete local (sem servidor, sem FCM) avisando um confirmado que o
/// racha está chegando — item 7 do plano de melhorias. Diferente da
/// notificação push (`NotificationService`), não depende de ninguém
/// disparar nada: é o próprio dispositivo que agenda e mostra sozinho.
class LocalNotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _antecedencia = Duration(hours: 2);
  static const _canalId = 'rachas_lembretes';

  Future<void> inicializar() async {
    tzdata.initializeTimeZones();
    try {
      final fuso = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(fuso.identifier));
    } catch (_) {
      // Sem detectar o fuso, o pacote timezone já cai em UTC por padrão —
      // o lembrete ainda dispara, só que sem ajustar pro fuso do aparelho.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
  }

  /// Agenda um lembrete `_antecedencia` antes do racha começar. Não
  /// agenda (e não dá erro) se esse horário já passou — não faz sentido
  /// avisar de algo que já era.
  Future<void> agendarLembrete(RachaModel racha) async {
    final horarioLembrete = racha.dataHora.subtract(_antecedencia);
    if (horarioLembrete.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: _idNotificacao(racha.id),
      title: 'Racha chegando',
      body: '${racha.nome} começa às ${DateFormat('HH:mm').format(racha.dataHora)} '
          '— ${racha.local}',
      scheduledDate: tz.TZDateTime.from(horarioLembrete, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalId,
          'Lembretes de racha',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancela o lembrete de um racha — usado quando o confirmado muda de
  /// ideia e recusa presença, pra não sobrar um aviso de um jogo que ele
  /// não vai mais jogar.
  Future<void> cancelarLembrete(String rachaId) {
    return _plugin.cancel(id: _idNotificacao(rachaId));
  }

  /// Precisa caber num int 32-bit (exigência do Android) — `hashCode` do
  /// Dart pode passar disso, daí o `& 0x7fffffff` só pra garantir que o
  /// resultado sempre cabe e nunca vem negativo.
  int _idNotificacao(String rachaId) => rachaId.hashCode & 0x7fffffff;
}
