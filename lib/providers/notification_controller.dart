import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Mantém `users/{uid}.fcmToken` em dia: registra (pede permissão + grava
/// o token) toda vez que alguém loga, e regrava sozinho se o Firebase
/// trocar o token do dispositivo depois. Só o lado do app — nada aqui
/// dispara uma notificação de verdade (isso precisaria de uma Cloud
/// Function; ver `NotificationService`).
///
/// Ativado observando esse provider uma vez lá em cima da árvore de
/// widgets (`RachaApp`), sem consumir o valor — ele só existe pelo efeito
/// colateral dos listeners registrados aqui.
final notificationSyncProvider = Provider<void>((ref) {
  ref.read(localNotificationServiceProvider).inicializar();

  Future<void> registrarToken(String uid) async {
    try {
      final token = await ref.read(notificationServiceProvider).registrar();
      if (token != null) {
        await ref.read(userRepositoryProvider).atualizarFcmToken(uid, token);
      }
    } catch (e) {
      // Nunca deve travar o login por causa disso — notificação é um
      // extra, não um requisito pra usar o app.
      debugPrint('Falha ao registrar token de notificação: $e');
    }
  }

  ref.listen(authStateChangesProvider, (previous, next) {
    final uid = next.valueOrNull?.uid;
    if (uid != null) registrarToken(uid);
  });

  final tokenRefreshSub =
      ref.read(notificationServiceProvider).onTokenRefresh.listen((token) {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    ref.read(userRepositoryProvider).atualizarFcmToken(uid, token);
  });
  ref.onDispose(tokenRefreshSub.cancel);

  final foregroundSub =
      ref.read(notificationServiceProvider).onMessage.listen((RemoteMessage message) {
    debugPrint(
      'Notificação recebida em primeiro plano: '
      '${message.notification?.title} — ${message.notification?.body}',
    );
  });
  ref.onDispose(foregroundSub.cancel);
});
