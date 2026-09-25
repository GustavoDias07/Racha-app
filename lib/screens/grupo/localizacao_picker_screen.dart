import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../core/theme/app_theme.dart';
import '../../services/geocoding_service.dart';
import '../../providers/firebase_providers.dart';

/// Fallback de centro do mapa quando não há localização inicial nem GPS
/// disponível — Praça da Sé (SP), só pra abrir o mapa em algum lugar do
/// Brasil em vez de no meio do oceano (0,0).
const _centroPadrao = latlong.LatLng(-23.5505, -46.6333);

/// Empurra o seletor de localização em tela cheia e devolve o ponto
/// escolhido (ou nulo se o usuário voltar sem confirmar). Usado por
/// criar/editar grupo pra capturar `GrupoModel.localizacao`.
Future<GeoPoint?> escolherLocalizacaoNoMapa(
  BuildContext context, {
  GeoPoint? inicial,
}) {
  return Navigator.of(context).push<GeoPoint>(
    MaterialPageRoute(builder: (_) => LocalizacaoPickerScreen(inicial: inicial)),
  );
}

class LocalizacaoPickerScreen extends ConsumerStatefulWidget {
  const LocalizacaoPickerScreen({super.key, this.inicial});

  final GeoPoint? inicial;

  @override
  ConsumerState<LocalizacaoPickerScreen> createState() =>
      _LocalizacaoPickerScreenState();
}

class _LocalizacaoPickerScreenState extends ConsumerState<LocalizacaoPickerScreen> {
  final _mapController = MapController();
  late latlong.LatLng _selecionado;
  bool _buscandoLocalizacao = false;

  /// Por que o GPS não funcionou, quando não funcionou. Fica visível num
  /// aviso sobre o mapa em vez de só sumir: sem isso a tela abre no centro
  /// de São Paulo (o fallback) sem explicar nada, e parece defeito.
  String? _erroLocalizacao;

  final _buscaController = TextEditingController();
  bool _buscando = false;
  List<EnderecoEncontrado> _resultados = const [];
  String? _semResultado;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  /// Procura o endereço ou CEP digitado e mostra os resultados.
  ///
  /// Dispara no envio do campo, nunca a cada tecla: o Nominatim é um serviço
  /// gratuito e a política dele pede no máximo uma consulta por segundo.
  Future<void> _buscarEndereco() async {
    final termo = _buscaController.text.trim();
    if (termo.length < 3) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _buscando = true;
      _semResultado = null;
      _resultados = const [];
    });

    try {
      final achados =
          await ref.read(geocodingServiceProvider).buscar(termo);
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _resultados = achados;
        _semResultado = achados.isEmpty
            ? 'Não achei esse endereço. Tente incluir a cidade, ou marque o '
                'ponto direto no mapa.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _semResultado = 'Não consegui consultar agora. Verifique a internet.';
      });
    }
  }

  void _escolherResultado(EnderecoEncontrado endereco) {
    final ponto = latlong.LatLng(endereco.latitude, endereco.longitude);
    setState(() {
      _selecionado = ponto;
      _resultados = const [];
      _semResultado = null;
      _erroLocalizacao = null;
      _buscaController.text = endereco.descricao.split(',').take(2).join(',');
    });
    _mapController.move(ponto, 17);
  }

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    _selecionado = inicial != null
        ? latlong.LatLng(inicial.latitude, inicial.longitude)
        : _centroPadrao;
    // Sem localização inicial (grupo novo) — tenta centralizar no GPS assim
    // que a tela abre, sem travar a UI se a permissão for negada.
    if (inicial == null) _usarMinhaLocalizacao(automatico: true);
  }

  /// [automatico] distingue a tentativa da abertura da tela do toque no
  /// botão. Na automática o erro vira um aviso fixo sobre o mapa; no toque
  /// vira um SnackBar, porque a pessoa está esperando uma resposta imediata.
  Future<void> _usarMinhaLocalizacao({bool automatico = false}) async {
    setState(() {
      _buscandoLocalizacao = true;
      _erroLocalizacao = null;
    });
    try {
      final posicao = await ref.read(locationServiceProvider).obterPosicaoAtual();
      if (!mounted) return;
      final ponto =
          latlong.LatLng(posicao.ponto.latitude, posicao.ponto.longitude);
      setState(() {
        _selecionado = ponto;
        _buscandoLocalizacao = false;
      });
      _mapController.move(ponto, 16);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoLocalizacao = false;
        _erroLocalizacao = '$e';
      });
      if (!automatico) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher localização'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirmar',
            onPressed: () => Navigator.of(context)
                .pop(GeoPoint(_selecionado.latitude, _selecionado.longitude)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _buscaController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscarEndereco(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar endereço ou CEP',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward, size: 20),
                        tooltip: 'Buscar',
                        onPressed: _buscarEndereco,
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selecionado,
              initialZoom: 15,
              onTap: (_, ponto) => setState(() => _selecionado = ponto),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gustavodias.rachaapp',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selecionado,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
                  ),
                ],
              ),
              // A licença do OpenStreetMap (ODbL) exige crédito visível em
              // qualquer tela que mostre os tiles — sem isso o uso é
              // irregular, e a Play Store trata violação de licença de
              // terceiros como motivo de remoção.
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (_resultados.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                color: AppColors.superficieAlta,
                child: ConstrainedBox(
                  // Teto de altura: com cinco resultados longos a lista
                  // cobriria o mapa inteiro, e a pessoa não veria para onde
                  // o alfinete vai.
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _resultados.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final achado = _resultados[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, size: 20),
                        title: Text(
                          achado.descricao,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _escolherResultado(achado),
                      );
                    },
                  ),
                ),
              ),
            )
          else if (_semResultado != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                color: AppColors.superficieAlta,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_off,
                          size: 20, color: AppColors.pendente),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _semResultado!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_erroLocalizacao != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                color: AppColors.superficieAlta,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_outlined,
                          size: 20, color: AppColors.pendente),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Não consegui pegar sua localização, então o mapa abriu '
                          'num ponto qualquer. Marque no mapa ou toque no alvo '
                          'para tentar de novo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              color: AppColors.superficieAlta,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Toque no mapa pra marcar o local do racha.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _buscandoLocalizacao ? null : () => _usarMinhaLocalizacao(),
        tooltip: 'Usar minha localização atual',
        child: _buscandoLocalizacao
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}
