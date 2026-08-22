import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/string_utils.dart';
import '../../models/enums.dart';
import '../../models/user_model.dart';
import '../../providers/convidado_controller.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/participante_controller.dart';

/// Convidar jogador para um Racha: busca um User já cadastrado (por email)
/// para convidar, ou cadastra um Convidado (mini-perfil sem login).
class ConvidarJogadorScreen extends ConsumerStatefulWidget {
  const ConvidarJogadorScreen({super.key, required this.rachaId, required this.convidadoPor});

  final String rachaId;
  final String convidadoPor;

  @override
  ConsumerState<ConvidarJogadorScreen> createState() => _ConvidarJogadorScreenState();
}

class _ConvidarJogadorScreenState extends ConsumerState<ConvidarJogadorScreen> {
  final _buscaController = TextEditingController();
  List<UserModel> _resultados = [];
  bool _buscando = false;

  final _formKeyConvidado = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _idadeController = TextEditingController();
  final _pesoController = TextEditingController();
  Posicao _posicaoMain = Posicao.zagueiro;
  Posicao _posicaoUsual = Posicao.zagueiro;

  @override
  void dispose() {
    _buscaController.dispose();
    _nomeController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final termo = _buscaController.text.trim();
    if (termo.isEmpty) return;
    setState(() => _buscando = true);
    final resultados =
        await ref.read(userRepositoryProvider).buscarPorNomeOuEmail(termo);
    if (!mounted) return;
    setState(() {
      _resultados = resultados;
      _buscando = false;
    });
  }

  Future<void> _convidarUser(UserModel user) async {
    await ref.read(participanteControllerProvider.notifier).convidar(
          rachaId: widget.rachaId,
          userId: user.id,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${user.nome} convidado!')));
    setState(() => _resultados = []);
    _buscaController.clear();
  }

  Future<void> _adicionarConvidado() async {
    if (!_formKeyConvidado.currentState!.validate()) return;

    await ref.read(convidadoControllerProvider.notifier).adicionar(
          rachaId: widget.rachaId,
          convidadoPor: widget.convidadoPor,
          nome: capitalizarNome(_nomeController.text),
          idadeAproximada: int.parse(_idadeController.text),
          pesoAproximado: double.parse(_pesoController.text.replaceAll(',', '.')),
          posicaoMain: _posicaoMain,
          posicaoUsual: _posicaoUsual,
        );

    final erro = ref.read(convidadoControllerProvider).error;
    if (erro != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao adicionar: $erro')));
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Convidado adicionado, aguardando aprovação.')),
    );
    _nomeController.clear();
    _idadeController.clear();
    _pesoController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final carregandoConvidado = ref.watch(convidadoControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Convidar jogador')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Jogador cadastrado', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    decoration: const InputDecoration(labelText: 'Nome ou email'),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _buscando ? null : _buscar,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            for (final user in _resultados)
              ListTile(
                title: Text(user.nome),
                subtitle: Text(user.email),
                trailing: FilledButton(
                  onPressed: () => _convidarUser(user),
                  child: const Text('Convidar'),
                ),
              ),
            if (!_buscando && _resultados.isEmpty && _buscaController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum jogador encontrado.'),
              ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text('Adicionar convidado (sem cadastro)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Form(
              key: _formKeyConvidado,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _idadeController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Idade aproximada'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Inválida';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pesoController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Peso aproximado (kg)'),
                          validator: (v) {
                            final n =
                                double.tryParse((v ?? '').replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Posicao>(
                          initialValue: _posicaoMain,
                          decoration:
                              const InputDecoration(labelText: 'Posição main'),
                          items: Posicao.values
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p.label)))
                              .toList(),
                          onChanged: (p) {
                            if (p != null) setState(() => _posicaoMain = p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<Posicao>(
                          initialValue: _posicaoUsual,
                          decoration:
                              const InputDecoration(labelText: 'Posição usual'),
                          items: Posicao.values
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p.label)))
                              .toList(),
                          onChanged: (p) {
                            if (p != null) setState(() => _posicaoUsual = p);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: carregandoConvidado ? null : _adicionarConvidado,
                    child: carregandoConvidado
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Adicionar convidado'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
