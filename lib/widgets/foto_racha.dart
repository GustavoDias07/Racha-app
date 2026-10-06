import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/imagem_base64.dart';

/// O que a pessoa decidiu no seletor de foto do racha.
///
/// `null` como retorno de [escolherFotoDoRacha] quer dizer "cancelou, não
/// mexa em nada" — diferente de [FotoEscolhida.remover], que quer dizer
/// "tire a foto que está lá". Sem essa distinção, fechar o menu por engano
/// apagaria a foto.
class FotoEscolhida {
  const FotoEscolhida(this.base64);
  const FotoEscolhida.remover() : base64 = null;

  /// A nova foto, ou `null` quando a escolha foi remover.
  final String? base64;
}

/// Teto da foto já codificada. A compressão abaixo deixa uma foto comum de
/// celular em 60 a 120 KB, então isto só barra o caso em que ela não pega —
/// um PNG grande, por exemplo, em que `imageQuality` não tem efeito. Este
/// documento é lido em toda lista de grupos; uma imagem de 800 KB ali
/// deixaria a tela inicial lenta para todo mundo do racha.
const _tetoBase64 = 350 * 1024;

/// Abre o menu com câmera, galeria e (se já houver foto) remover.
///
/// Diferente da foto de perfil, que é só câmera por ser o requisito de
/// hardware da disciplina, aqui a galeria faz sentido: a foto do campo
/// normalmente já está no celular, tirada num dia de jogo.
Future<FotoEscolhida?> escolherFotoDoRacha(
  BuildContext context, {
  required bool temFoto,
}) async {
  final origem = await showModalBottomSheet<Object>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          if (temFoto)
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.recusado),
              title: const Text('Remover foto',
                  style: TextStyle(color: AppColors.recusado)),
              onTap: () => Navigator.pop(sheetContext, 'remover'),
            ),
        ],
      ),
    ),
  );

  if (origem == null) return null;
  if (origem == 'remover') return const FotoEscolhida.remover();

  final foto = await ImagePicker().pickImage(
    source: origem as ImageSource,
    // Bem mais apertado que a foto de perfil (1024 px / 80%): a capa aparece
    // grande só na tela do grupo; nas listas vira miniatura de 40 px.
    maxWidth: 800,
    imageQuality: 70,
  );
  if (foto == null) return null;

  // `readAsBytes` em vez de `File(foto.path)`: no navegador não existe
  // caminho de arquivo, e o `File` quebra. Assim funciona no Chrome também.
  final bytes = await foto.readAsBytes();
  final base64 = base64Encode(bytes);

  if (base64.length > _tetoBase64) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Essa imagem ficou grande demais. Tente uma foto tirada com a '
            'câmera, ou um print da imagem.',
          ),
        ),
      );
    }
    return null;
  }

  return FotoEscolhida(base64);
}

/// Miniatura quadrada do racha, para cards de lista.
///
/// Sem foto, mostra a bola sobre verde diluído — o mesmo visual que os cards
/// tinham antes, então rachas sem foto continuam com cara de racha.
class MiniaturaDoRacha extends StatelessWidget {
  const MiniaturaDoRacha({super.key, this.fotoBase64, this.tamanho = 38});

  final String? fotoBase64;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final bytes = bytesDaFoto(fotoBase64);
    final raio = BorderRadius.circular(tamanho * 0.26);

    if (bytes != null) {
      return ClipRRect(
        borderRadius: raio,
        child: Image.memory(
          bytes,
          width: tamanho,
          height: tamanho,
          fit: BoxFit.cover,
          // Sem isso o Flutter decodifica a imagem no tamanho original para
          // desenhar 38 px — desperdício de memória numa lista com várias.
          cacheWidth: (tamanho * 3).round(),
          gaplessPlayback: true,
        ),
      );
    }

    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: AppColors.verde.withValues(alpha: 0.15),
        borderRadius: raio,
      ),
      child: Icon(Icons.sports_soccer,
          size: tamanho * 0.53, color: AppColors.verde),
    );
  }
}

/// Faixa de capa no topo da tela do grupo.
///
/// Sem foto e sem permissão de editar, não ocupa espaço nenhum: uma área
/// vazia no topo de todo grupo sem foto seria ruído. Para o admin, a área
/// vazia vira um convite para adicionar a foto.
class CapaDoRacha extends StatelessWidget {
  const CapaDoRacha({
    super.key,
    this.fotoBase64,
    required this.podeEditar,
    this.onEditar,
    this.margem = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final String? fotoBase64;
  final bool podeEditar;
  final VoidCallback? onEditar;

  /// Espaço em volta. O padrão serve para a tela do grupo, onde a capa
  /// encosta nas bordas da tela; dentro de um formulário que já tem margem
  /// própria, passe `EdgeInsets.zero` para não somar as duas.
  final EdgeInsets margem;

  @override
  Widget build(BuildContext context) {
    final bytes = bytesDaFoto(fotoBase64);

    if (bytes == null && !podeEditar) return const SizedBox.shrink();

    if (bytes == null) {
      return Padding(
        padding: margem,
        child: Material(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onEditar,
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              height: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.textoSecundario),
                  SizedBox(width: 8),
                  Text(
                    'Adicionar foto do racha',
                    style: TextStyle(color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: margem,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            AspectRatio(
              // Larga e baixa: é capa, não a atração da tela — o conteúdo do
              // racha logo abaixo continua sendo o principal.
              aspectRatio: 21 / 9,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            if (podeEditar)
              Positioned(
                right: 8,
                bottom: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                    tooltip: 'Trocar foto',
                    onPressed: onEditar,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
