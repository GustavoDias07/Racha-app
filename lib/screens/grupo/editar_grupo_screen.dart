import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/grupo_model.dart';
import '../../providers/grupo_controller.dart';
import 'localizacao_picker_screen.dart';

/// Edita a configuração padrão de um Grupo já criado — nome, local, dia da
/// semana, horário, tipo de campo. Só vale pras próximas rodadas que ainda
/// vão nascer (Fluxo 5); a rodada aberta atual tem edição própria
/// (`EditarRachaScreen`).
class EditarGrupoScreen extends ConsumerStatefulWidget {
  const EditarGrupoScreen({super.key, required this.grupo});

  final GrupoModel grupo;

  @override
  ConsumerState<EditarGrupoScreen> createState() => _EditarGrupoScreenState();
}

class _EditarGrupoScreenState extends ConsumerState<EditarGrupoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _localController;
  late final TextEditingController _qtdController;

  late DiaSemana _diaSemana;
  late TipoCampo _tipoCampo;
  late TimeOfDay _horario;
  GeoPoint? _localizacao;
  late bool _abertoParaNovosMembros;

  @override
  void initState() {
    super.initState();
    final grupo = widget.grupo;
    _nomeController = TextEditingController(text: grupo.nome);
    _localController = TextEditingController(text: grupo.localPadrao);
    _qtdController =
        TextEditingController(text: grupo.qtdJogadoresLinhaPadrao.toString());
    _diaSemana = grupo.diaSemana;
    _tipoCampo = grupo.tipoCampoPadrao;
    final partes = grupo.horario.split(':');
    _horario = TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
    _localizacao = grupo.localizacao;
    _abertoParaNovosMembros = grupo.abertoParaNovosMembros;
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

  Future<void> _escolherHorario() async {
    final horario = await showTimePicker(context: context, initialTime: _horario);
    if (horario != null) setState(() => _horario = horario);
  }

  Future<void> _escolherLocalizacao() async {
    final ponto = await escolherLocalizacaoNoMapa(context, inicial: _localizacao);
    if (ponto != null) setState(() => _localizacao = ponto);
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    // "Aberto para novos jogadores" sem coordenadas é um grupo que nunca
    // aparece na busca por proximidade (a tela filtra por distância e não
    // tem como calcular a de um grupo sem ponto no mapa) — barra aqui em vez
    // de deixar o admin achar que publicou o racha.
    if (_abertoParaNovosMembros && _localizacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Marque a localização no mapa pra o racha aparecer em "Rachas Próximos".',
          ),
        ),
      );
      return;
    }

    final horarioFormatado =
        '${_horario.hour.toString().padLeft(2, '0')}:${_horario.minute.toString().padLeft(2, '0')}';

    await ref.read(grupoControllerProvider.notifier).atualizar(
          grupoId: widget.grupo.id,
          nome: _nomeController.text.trim(),
          localPadrao: _localController.text.trim(),
          diaSemana: _diaSemana,
          horario: horarioFormatado,
          tipoCampoPadrao: _tipoCampo,
          qtdJogadoresLinhaPadrao: int.parse(_qtdController.text),
          localizacao: _localizacao,
          abertoParaNovosMembros: _abertoParaNovosMembros,
        );

    final erro = ref.read(grupoControllerProvider).error;
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
    final state = ref.watch(grupoControllerProvider);
    final carregando = state.isLoading;
    final horarioFormatado = _horario.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar grupo')),
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
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _escolherLocalizacao,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(
                      _localizacao == null
                          ? 'Escolher localização no mapa'
                          : 'Localização marcada ✓ (toque pra ajustar)',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<DiaSemana>(
                        initialValue: _diaSemana,
                        decoration:
                            const InputDecoration(labelText: 'Dia da semana'),
                        items: DiaSemana.values
                            .map((dia) => DropdownMenuItem(
                                value: dia, child: Text(dia.label)))
                            .toList(),
                        onChanged: (dia) {
                          if (dia != null) setState(() => _diaSemana = dia);
                        },
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
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aberto para novos jogadores'),
                  subtitle: const Text(
                    'Aparece na aba "Rachas Próximos" pra qualquer jogador logado perto '
                    'daqui, que pode solicitar entrada.',
                  ),
                  value: _abertoParaNovosMembros,
                  onChanged: (v) => setState(() => _abertoParaNovosMembros = v),
                ),
                const SizedBox(height: 12),
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
