import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Avatar com botão de câmera. É a peça que atende o requisito de hardware
/// da disciplina (uso da câmera do aparelho) — só abre a câmera nativa via
/// ImageSource.camera, nunca a galeria.
class FotoPerfilPicker extends StatefulWidget {
  const FotoPerfilPicker({
    super.key,
    required this.onFotoSelecionada,
    this.fotoAtualBase64,
  });

  final ValueChanged<File> onFotoSelecionada;

  /// Foto já salva do usuário (edição de perfil), mostrada até que uma nova
  /// seja tirada. Deixar nulo no cadastro, onde ainda não existe foto.
  final String? fotoAtualBase64;

  @override
  State<FotoPerfilPicker> createState() => _FotoPerfilPickerState();
}

class _FotoPerfilPickerState extends State<FotoPerfilPicker> {
  File? _arquivo;

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (foto == null) return;

    final arquivo = File(foto.path);
    setState(() => _arquivo = arquivo);
    widget.onFotoSelecionada(arquivo);
  }

  @override
  Widget build(BuildContext context) {
    final temFotoAtual = _arquivo == null && widget.fotoAtualBase64 != null;
    final temFoto = _arquivo != null || temFotoAtual;

    return Column(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundImage: _arquivo != null
              ? FileImage(_arquivo!)
              : temFotoAtual
                  ? MemoryImage(base64Decode(widget.fotoAtualBase64!))
                      as ImageProvider
                  : null,
          child: temFoto ? null : const Icon(Icons.person, size: 56),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _tirarFoto,
          icon: const Icon(Icons.camera_alt),
          label: Text(temFoto ? 'Tirar outra foto' : 'Tirar foto'),
        ),
      ],
    );
  }
}
