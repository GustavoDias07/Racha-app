import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/racha_model.dart';
import '../../providers/racha_controller.dart';

/// Edita um racha já criado — avulso ou rodada de um Grupo. Ver Fluxo 2,
/// docs/estrutura.md: "o admin ainda pode ajustar a ocorrência gerada
/// automaticamente (trocar data, ...) antes de fechar as confirmações".
/// Não mexe em `grupoId`/`status`/`mvpUserId` — só os campos que o admin
/// preenche na criação.
class EditarRachaScreen extends ConsumerStatefulWidget {
  const EditarRachaScreen({super.key, required this.racha});

  final RachaModel racha;

  @override
  ConsumerState<EditarRachaScreen> createState() => _EditarRachaScreenState();
}

class _EditarRachaScreenState extends ConsumerState<EditarRachaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _localController;
  late final TextEditingController _qtdController;

  late TipoCampo _tipoCampo;
  late DateTime _data;
  late TimeOfDay _horario;

  @override
  void initState() {
    super.initState();
    final racha = widget.racha;
    _nomeController = TextEditingController(text: racha.nome);
    _localController = TextEditingController(text: racha.local);
    _qtdController = TextEditingController(text: racha.qtdJogadoresLinha.toString());
    _tipoCampo = racha.tipoCampo;
    _data = DateTime(racha.dataHora.year, racha.dataHora.month, racha.dataHora.day);
    _horario = TimeOfDay(hour: racha.dataHora.hour, minute: racha.dataHora.minute);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _localController.dispose();
    _qtdController.dispose();
    super.dispose();
  }

  void _onTipoCampoChanged(TipoCampo? tipo) {
    if (tipo == null) return;
    setState(() {
      _tipoCampo = tipo;
      if (!tipo.qtdConfiguravel) {
        _qtdController.text = tipo.qtdJogadoresLinhaPadrao.toString();
      }
    });
  }

  Future<void> _escolherData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (data != null) setState(() => _data = data);
  }

  Future<void> _escolherHorario() async {
    final horario = await showTimePicker(context: context, initialTime: _horario);
    if (horario != null) setState(() => _horario = horario);
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    final dataHora =
        DateTime(_data.year, _data.month, _data.day, _horario.hour, _horario.minute);

    await ref.read(rachaControllerProvider.notifier).atualizar(
          rachaId: widget.racha.id,
          nome: _nomeController.text.trim(),
          local: _localController.text.trim(),
          dataHora: dataHora,
          tipoCampo: _tipoCampo,
          qtdJogadoresLinha: int.parse(_qtdController.text),
        );

    final erro = ref.read(rachaControllerProvider).error;
    if (erro != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $erro')),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rachaControllerProvider);
    final carregando = state.isLoading;
    final dataFormatada = '${_data.day.toString().padLeft(2, '0')}/'
        '${_data.month.toString().padLeft(2, '0')}/${_data.year}';
    final horarioFormatado = _horario.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar racha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome do racha'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _localController,
                  decoration: const InputDecoration(labelText: 'Local'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o local' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _escolherData,
                        child: Text(dataFormatada),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _escolherHorario,
                        child: Text(horarioFormatado),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoCampo>(
                  initialValue: _tipoCampo,
                  decoration: const InputDecoration(labelText: 'Tipo de campo'),
                  items: TipoCampo.values
                      .map((tipo) =>
                          DropdownMenuItem(value: tipo, child: Text(tipo.label)))
                      .toList(),
                  onChanged: _onTipoCampoChanged,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qtdController,
                  enabled: _tipoCampo.qtdConfiguravel,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jogadores de linha (sem contar o goleiro)',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Quantidade inválida';
                    return null;
                  },
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
