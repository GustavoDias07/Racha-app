import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;

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

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    _selecionado = inicial != null
        ? latlong.LatLng(inicial.latitude, inicial.longitude)
        : _centroPadrao;
    // Sem localização inicial (grupo novo) — tenta centralizar no GPS assim
    // que a tela abre, sem travar a UI se a permissão for negada.
    if (inicial == null) _usarMinhaLocalizacao(centralizarSemMover: false);
  }

  Future<void> _usarMinhaLocalizacao({bool centralizarSemMover = false}) async {
    setState(() => _buscandoLocalizacao = true);
    try {
      final posicao = await ref.read(locationServiceProvider).obterPosicaoAtual();
      if (!mounted) return;
      final ponto = latlong.LatLng(posicao.latitude, posicao.longitude);
      setState(() {
        _selecionado = ponto;
        _buscandoLocalizacao = false;
      });
      _mapController.move(ponto, 16);
    } catch (e) {
      if (!mounted) return;
      setState(() => _buscandoLocalizacao = false);
      // Silencioso na abertura automática (não incomoda quem já vai marcar
      // o ponto manualmente); explícito quando a pessoa aperta o botão.
      if (!centralizarSemMover) {
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
                userAgentPackageName: 'com.example.racha_app',
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
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}
