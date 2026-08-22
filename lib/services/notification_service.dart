import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Fica só com o lado do app (registrar token, pedir permissão, escutar
/// mensagens) — não existe, ainda, nada que dispare um push de verdade.
/// Isso exigiria uma Cloud Function (gatilho no Firestore) rodando no
/// plano pago do Firebase, decisão que ficou pra outra etapa. Enquanto
/// isso, dá pra testar manualmente colando o token salvo no perfil do User
/// (ver `UserRepository.atualizarFcmToken`) no compositor do Firebase
/// Console (Cloud Messaging > Enviar sua primeira mensagem).
class NotificationService {
  NotificationService(this._messaging);

  final FirebaseMessaging _messaging;

  /// Pede permissão e devolve o token do dispositivo — nulo se a
  /// permissão foi negada ou se está rodando na web (que precisa de uma
  /// VAPID key configurada no Firebase Console antes de funcionar, o que
  /// não foi feito pra esse projeto ainda).
  Future<String?> registrar() async {
    if (kIsWeb) return null;

    final settings = await _messaging.requestPermission();
    final concedida = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!concedida) return null;

    return _messaging.getToken();
  }

  /// Dispara de novo sempre que o Firebase troca o token do dispositivo
  /// (reinstalação, restauração de backup, etc.) — sem reagir a isso, o
  /// token salvo no perfil do User ficaria desatualizado e um envio
  /// futuro nunca chegaria.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Mensagens recebidas com o app aberto em primeiro plano — nesse caso o
  /// sistema operacional não mostra a notificação sozinho (diferente de
  /// segundo plano/fechado), então é o app que decide o que fazer.
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
