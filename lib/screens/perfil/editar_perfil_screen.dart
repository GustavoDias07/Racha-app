import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/string_utils.dart';
import '../../models/user_model.dart';
import '../../providers/perfil_controller.dart';
import '../../widgets/foto_perfil_picker.dart';

class EditarPerfilScreen extends ConsumerStatefulWidget {
  const EditarPerfilScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends ConsumerState<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(text: widget.user.nome);
  late final _idadeController = TextEditingController(text: widget.user.idade.toString());
  late final _pesoController = TextEditingController(text: widget.user.peso.toString());
  File? _novaFoto;

  @override
  void dispose() {
    _nomeController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(perfilControllerProvider.notifier).atualizar(
          nome: capitalizarNome(_nomeController.text),
          idade: int.parse(_idadeController.text),
          peso: double.parse(_pesoController.text.replaceAll(',', '.')),
          novaFoto: _novaFoto,
        );

    if (!mounted) return;
    final erro = ref.read(perfilControllerProvider).error;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $erro')),
      );
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(perfilControllerProvider);
    final carregando = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FotoPerfilPicker(
                  fotoAtualBase64: widget.user.fotoPerfilBase64,
                  onFotoSelecionada: (arquivo) => _novaFoto = arquivo,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _idadeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Idade'),
                        validator: (v) =>
                            (int.tryParse(v ?? '') == null) ? 'Idade inválida' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pesoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Peso (kg)'),
                        validator: (v) =>
                            (double.tryParse((v ?? '').replaceAll(',', '.')) == null)
                                ? 'Peso inválido'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: carregando ? null : _submeter,
                  child: carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
