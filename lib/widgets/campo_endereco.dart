import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/firebase_providers.dart';
import '../services/geocoding_service.dart';

/// Campo "Local" que sugere endereços enquanto a pessoa digita.
///
/// Continua sendo um campo de texto livre: dá para escrever "Quadra do Zé"
/// e seguir sem escolher sugestão nenhuma. Tocar numa sugestão só preenche
/// o texto — o local do racha continua guardado como texto (a posição no
/// mapa do grupo segue no botão "Localização no mapa").
class CampoEndereco extends ConsumerStatefulWidget {
  const CampoEndereco({
    super.key,
    required this.controller,
    this.label = 'Local',
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  ConsumerState<CampoEndereco> createState() => _CampoEnderecoState();
}

class _CampoEnderecoState extends ConsumerState<CampoEndereco> {
  final _foco = FocusNode();
  Timer? _espera;
  List<EnderecoEncontrado> _sugestoes = const [];
  bool _buscando = false;

  /// Posição do aparelho para ordenar por proximidade. Buscada uma vez só,
  /// na primeira busca, e só se a localização já estiver permitida.
  GeoPoint? _perto;
  bool _jaProcurouPosicao = false;

  /// Texto que acabou de ser preenchido por uma sugestão — não deve disparar
  /// uma nova busca por ele mesmo.
  String? _textoEscolhido;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_aoDigitar);
    _foco.addListener(() {
      if (!_foco.hasFocus && mounted) setState(() => _sugestoes = const []);
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    widget.controller.removeListener(_aoDigitar);
    _foco.dispose();
    super.dispose();
  }

  void _aoDigitar() {
    final texto = widget.controller.text;
    if (texto == _textoEscolhido || !_foco.hasFocus) return;
    _espera?.cancel();
    if (texto.trim().length < 3) {
      setState(() => _sugestoes = const []);
      return;
    }
    // Espera a pessoa parar de digitar por meio segundo antes de buscar:
    // uma consulta por palavra, não uma por tecla.
    _espera = Timer(const Duration(milliseconds: 500), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    setState(() => _buscando = true);
    if (!_jaProcurouPosicao) {
      _jaProcurouPosicao = true;
      _perto = await ref.read(locationServiceProvider).posicaoSemPerguntar();
    }
    List<EnderecoEncontrado> achados;
    try {
      achados = await ref.read(geocodingServiceProvider).sugerir(
            texto,
            perto: _perto == null
                ? null
                : (latitude: _perto!.latitude, longitude: _perto!.longitude),
          );
    } catch (_) {
      // Sem internet ou serviço fora do ar: o campo continua funcionando
      // como texto livre, só sem sugestões.
      achados = const [];
    }
    if (!mounted) return;
    setState(() {
      _buscando = false;
      // Uma resposta atrasada de uma busca antiga não pode sobrescrever a
      // da busca atual.
      if (widget.controller.text == texto) _sugestoes = achados;
    });
  }

  void _escolher(EnderecoEncontrado endereco) {
    _textoEscolhido = endereco.descricao;
    widget.controller.text = endereco.descricao;
    setState(() => _sugestoes = const []);
    _foco.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _foco,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Nome do lugar, endereço ou CEP',
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.place_outlined),
          ),
        ),
        if (_sugestoes.isNotEmpty)
          // Sem o `TextFieldTapRegion`, encostar numa sugestão contaria como
          // tocar fora do campo: ele perderia o foco, a lista sumiria antes
          // de o toque terminar e a escolha nunca chegaria.
          TextFieldTapRegion(
            child: Card(
              margin: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  for (final s in _sugestoes)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, color: AppColors.verde),
                      title: Text(s.descricao,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _escolher(s),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
