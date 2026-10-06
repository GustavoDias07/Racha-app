import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/imagem_base64.dart';

/// Avatar com botão de câmera. É a peça que atende o requisito de hardware
/// da disciplina (uso da câmera do aparelho) — só abre a câmera nativa via
/// ImageSource.camera, nunca a galeria.
class FotoPerfilPicker extends StatefulWidget {
  const FotoPerfilPicker({
    super.key,
    required this.onFotoSelecionada,
    this.fotoAtualBase64,
  });

  /// Entrega os bytes da foto, e não um `File`.
  ///
  /// `File` vem de `dart:io`, que não existe no navegador: no Chrome, tirar
  /// a foto funcionava, mas ler o arquivo quebrava — e o cadastro falhava, ou
  /// a conta era criada sem foto. Bytes funcionam igual em qualquer
  /// plataforma.
  final ValueChanged<Uint8List> onFotoSelecionada;

  /// Foto já salva do usuário (edição de perfil), mostrada até que uma nova
  /// seja tirada. Deixar nulo no cadastro, onde ainda não existe foto.
  final String? fotoAtualBase64;

  @override
  State<FotoPerfilPicker> createState() => _FotoPerfilPickerState();
}

class _FotoPerfilPickerState extends State<FotoPerfilPicker> {
  Uint8List? _nova;

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (foto == null) return;

    final bytes = await foto.readAsBytes();
    if (!mounted) return;
    setState(() => _nova = bytes);
    widget.onFotoSelecionada(bytes);
  }

  @override
  Widget build(BuildContext context) {
    // A foto recém-tirada tem prioridade sobre a já salva; sem nenhuma das
    // duas, aparece o ícone.
    final bytes = _nova ?? bytesDaFoto(widget.fotoAtualBase64);

    return Column(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: AppColors.superficieAlta,
          backgroundImage: bytes != null ? MemoryImage(bytes) : null,
          child: bytes == null
              ? const Icon(Icons.person,
                  size: 56, color: AppColors.textoSecundario)
              : null,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _tirarFoto,
          icon: const Icon(Icons.camera_alt),
          label: Text(bytes != null ? 'Tirar outra foto' : 'Tirar foto'),
        ),
      ],
    );
  }
}
