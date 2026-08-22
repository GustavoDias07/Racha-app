import 'dart:convert';
import 'dart:io';

/// Prepara a foto de perfil para ser salva.
///
/// Provisório: o Firebase Storage exige o plano Blaze (pay-as-you-go), que
/// ainda não foi ativado no projeto. Enquanto isso, a foto (já comprimida
/// pelo FotoPerfilPicker) é codificada em base64 e salva direto no
/// documento do usuário no Firestore. Quando o Storage for ativado, trocar
/// aqui para fazer upload real e devolver a URL de download — quem chama
/// este service não precisa mudar.
class StorageService {
  Future<String> uploadFotoPerfil({
    required String userId,
    required File arquivo,
  }) async {
    final bytes = await arquivo.readAsBytes();
    return base64Encode(bytes);
  }
}
