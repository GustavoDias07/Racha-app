import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/racha_model.dart';
import 'firebase_providers.dart';

/// Cria um racha e já convida quem criou.
///
/// Estava duplicado em `RachaController.criar` (racha avulso) e em
/// `GrupoController.criar` (primeira rodada de um grupo recorrente): as duas
/// gravavam o racha e, em seguida, o participante do admin. Toda regra sobre
/// "como um racha nasce" mora aqui agora, num lugar só.
///
/// **O admin entra como pendente, igual a todo mundo.** Antes ele nascia
/// confirmado, o que partia de uma suposição errada — quem organiza nem
/// sempre joga. Na prática isso também inflava a contagem de confirmados que
/// libera a geração de times, e deixava o organizador como o único jogador
/// garantidamente sem posição definida, já que ele pulava a tela de
/// confirmação (onde a posição é escolhida).
///
/// As duas escritas vão num `WriteBatch`: ou nasce o racha com o admin
/// convidado, ou não nasce nada. Antes eram duas gravações soltas, e uma
/// falha de rede no meio deixava um racha sem nenhum participante.
Future<String> criarRachaComAdmin(Ref ref, RachaModel racha) async {
  final rachaRepo = ref.read(rachaRepositoryProvider);
  final batch = ref.read(firestoreProvider).batch();

  final docRef = rachaRepo.novoDocRef();
  rachaRepo.criarEmLote(batch, docRef, racha);
  ref.read(participanteRepositoryProvider).convidarEmLote(
        batch,
        rachaId: docRef.id,
        userId: racha.adminId,
      );

  await batch.commit();
  return docRef.id;
}
