import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_theme.dart';

/// Desenhos do app (ver T26 em docs/tarefas.md). Os arquivos ficam em
/// `assets/ilustracoes/` e são SVG: desenho feito de formas, e não de
/// pixels, então fica nítido em qualquer tamanho de tela.
///
/// Os SVGs foram desenhados para o tema escuro, com três cores só: verde
/// (#1DB954), branco (#FFFFFF) e quase preto (#121212). No tema claro um
/// desenho branco sumiria no fundo claro — então, na hora de desenhar, o
/// [_TrocaDeCores] troca o branco por escuro e o escuro pela cor de fundo.
/// O verde nunca muda: é a cor da marca.
enum Ilustracao {
  bola('bola.svg'),
  balanca('balanca.svg'),
  camisas('camisas.svg'),

  /// Mesmo desenho do ícone do app. Tem fundo verde próprio, então fica
  /// igual nos dois temas (ver [adaptaAoTema]).
  campo('campo.svg');

  const Ilustracao(this.arquivo);
  final String arquivo;

  String get caminho => 'assets/ilustracoes/$arquivo';

  /// Só os desenhos sem fundo precisam trocar de cor com o tema.
  bool get adaptaAoTema => this != Ilustracao.campo;
}

/// Mostra uma [Ilustracao] com a altura pedida, nas cores do tema atual.
class IlustracaoSvg extends StatelessWidget {
  const IlustracaoSvg(this.ilustracao, {super.key, this.altura = 120, this.trocarCores});

  final Ilustracao ilustracao;
  final double altura;

  /// Força ligar/desligar a troca de cores do tema claro. Nulo = usa o
  /// padrão da ilustração ([Ilustracao.adaptaAoTema]).
  final bool? trocarCores;

  @override
  Widget build(BuildContext context) {
    final trocar = trocarCores ?? ilustracao.adaptaAoTema;
    return SvgPicture(
      SvgAssetLoader(
        ilustracao.caminho,
        colorMapper: trocar ? _TrocaDeCores.doTema(context) : null,
      ),
      height: altura,
      // Leitores de tela pulam a imagem: ela é enfeite, o texto ao lado é
      // que explica a tela.
      excludeFromSemantics: true,
    );
  }
}

/// As duas camisas com os números "1" e "2" por cima, no topo do resultado
/// dos times.
///
/// Os números são widgets `Text` sobrepostos, e não texto dentro do SVG,
/// porque o flutter_svg não desenha `<text>` de forma confiável (depende de
/// fonte instalada).
class CamisasNumeradas extends StatelessWidget {
  const CamisasNumeradas({super.key, this.altura = 90});

  final double altura;

  @override
  Widget build(BuildContext context) {
    final troca = _TrocaDeCores.doTema(context);
    // O SVG das camisas tem 512 x 240 de área (ver o viewBox do arquivo).
    final largura = altura * 512 / 240;
    TextStyle estilo(Color cor) => TextStyle(
          color: cor,
          fontWeight: FontWeight.w900,
          fontSize: altura * 0.42,
        );

    return SizedBox(
      width: largura,
      height: altura,
      child: Stack(
        children: [
          Positioned.fill(child: IlustracaoSvg(Ilustracao.camisas, altura: altura)),
          // Alignment vai de -1 (borda esquerda/topo) a 1 (direita/baixo).
          // Os centros das camisas, no desenho, estão em x=140 e x=372 de
          // 512, e o peito em y=280 (de 140 a 380) — daí estes números.
          Align(
            alignment: const Alignment(-0.453, 0.17),
            // Camisa 1 é branca (escura no claro): o número usa a cor do
            // contorno, que é sempre o oposto dela.
            child: Text('1', style: estilo(troca.mapear(_escuro))),
          ),
          Align(
            alignment: const Alignment(0.453, 0.17),
            // Camisa 2 é verde nos dois temas: número sempre preto, como o
            // texto dos botões verdes.
            child: Text('2', style: estilo(_escuro)),
          ),
        ],
      ),
    );
  }
}

/// Marca de racha sem foto: um "R" verde bem grosso com uma bola no canto
/// de baixo, sobre a perna do R (desenho 3, escolhido pelo Abreu).
///
/// O desenho original é de 512 x 512. Tudo aqui é calculado em cima dele e
/// multiplicado por `k` (tamanho / 512), para ficar igual em qualquer tamanho.
///
/// O "R" é um `Text`, e não parte do SVG, pelo mesmo motivo dos números das
/// camisas: o flutter_svg não desenha `<text>` de forma confiável. A bola
/// reaproveita `bola.svg`, que tem a mesma proporção de linha.
///
/// Cores: no escuro, fundo #121212 e R #1DB954. No claro, o fundo é o verde
/// diluído que o card já usava e o R vira o verde de texto (#117A37), que
/// tem contraste em fundo claro. A bola fica branca nos dois.
class MarcaRacha extends StatelessWidget {
  const MarcaRacha({super.key, required this.tamanho, required this.raio});

  final double tamanho;
  final BorderRadius raio;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final claro = Theme.of(context).brightness == Brightness.light;
    final k = tamanho / 512;
    // No bola.svg a bola tem raio 150 dentro de uma área de 512. Para ela
    // sair com raio 62 aqui, a área do SVG tem que ser 512 * 62/150 maior.
    final ladoBola = 512 * 62 / 150 * k;

    return Container(
      width: tamanho,
      height: tamanho,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: claro ? cores.verde.withValues(alpha: 0.15) : _escuro,
        borderRadius: raio,
      ),
      child: Stack(
        children: [
          // No desenho, o R está centrado em x=236 e vai de y=140 a y=380
          // (meio em y=260). Alignment vai de -1 a 1: 236/256 - 1 ≈ -0.08.
          // O y fica um pouco abaixo do meio porque a caixa do texto reserva
          // espaço embaixo para letras como "g" e "p", que o R não usa.
          Align(
            alignment: const Alignment(-0.08, 0.12),
            child: Text(
              'R',
              style: TextStyle(
                color: cores.verdeTexto,
                fontWeight: FontWeight.w900,
                fontSize: 330 * k,
                height: 1,
              ),
            ),
          ),
          // Bola com centro em (372, 370) e raio 62 no desenho.
          Positioned(
            left: 372 * k - ladoBola / 2,
            top: 370 * k - ladoBola / 2,
            width: ladoBola,
            height: ladoBola,
            child: IlustracaoSvg(Ilustracao.bola, altura: ladoBola, trocarCores: false),
          ),
        ],
      ),
    );
  }
}

// --- Desenhos pequenos, no lugar de ícones ----------------------------------
//
// Num ícone de 18–24 px o desenho grande vira borrão, então estes dois são
// versões simplificadas (linhas mais grossas, menos detalhes). E, como
// ícone, precisam ter a mesma cor que o `Icon` do lugar teria, que pode ser
// qualquer cor do tema. Por isso o SVG é montado aqui como texto, já com as
// cores certas, em vez de ler um arquivo de assets/.

/// Campo de futebol (desenho 2) em tamanho de ícone. Usado em "Tipo de
/// campo". Só o contorno, a linha do meio e o círculo central: as áreas
/// sumiam em 18 px.
class DesenhoCampoPequeno extends StatelessWidget {
  const DesenhoCampoPequeno({super.key, this.tamanho = 18, this.cor});

  final double tamanho;

  /// Cor das linhas. Nulo = a mesma do ícone do `InfoTile`.
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = _hex(cor ?? context.cores.textoSecundario);
    // viewBox recortado em volta do campo (x 96–416, y 56–456, mais a
    // espessura da linha), para o desenho ocupar o quadrado inteiro.
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="34 34 444 444">'
        '<g fill="none" stroke="$c" stroke-width="44">'
        '<rect x="96" y="56" width="320" height="400" rx="24"/>'
        '<line x1="96" y1="256" x2="416" y2="256"/>'
        '<circle cx="256" cy="256" r="62"/>'
        '</g></svg>';
    return SvgPicture.string(svg, width: tamanho, height: tamanho, excludeFromSemantics: true);
  }
}

/// Bola em movimento (desenho 6) em tamanho de ícone. Usado em "Gols".
/// Sem o fundo dividido do original: só a bola e as três linhas de
/// velocidade.
///
/// Cores, como pedido: o que era branco vira a cor do ícone ([cor]) e o que
/// era #121212 vira a cor da superfície onde ele está (o card), então a bola
/// aparece "recortada" do fundo nos dois temas.
class DesenhoGols extends StatelessWidget {
  const DesenhoGols({super.key, this.tamanho = 24, required this.cor});

  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final c = _hex(cor);
    final fundo = _hex(context.cores.superficie);
    // Conteúdo vai de x 40 a x 420 (380 de largura); o viewBox é um
    // quadrado de 380 centrado na altura da bola (y 256).
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="40 66 380 380">'
        '<g stroke="$c" stroke-width="22" stroke-linecap="round" opacity="0.85">'
        '<line x1="70" y1="210" x2="160" y2="210"/>'
        '<line x1="50" y1="256" x2="160" y2="256"/>'
        '<line x1="80" y1="302" x2="160" y2="302"/>'
        '</g>'
        // Linha da bola mais grossa que a do original (10) para não sumir
        // em 24 px.
        '${_bolaSvg(300, 256, 110, c, fundo, 16)}'
        '</svg>';
    return SvgPicture.string(svg, width: tamanho, height: tamanho, excludeFromSemantics: true);
  }
}

/// A BOLA de todos os desenhos: círculo, pentágono no meio (raio 0,38 r,
/// ponta para cima) e cinco linhas do pentágono até a borda. Os pontos são
/// calculados com seno e cosseno a cada 72 graus (360 / 5).
String _bolaSvg(double cx, double cy, double r, String fill, String linha, double esp) {
  final pentagono = <String>[];
  final linhas = StringBuffer();
  for (var i = 0; i < 5; i++) {
    final angulo = (-90 + 72 * i) * math.pi / 180;
    final px = cx + 0.38 * r * math.cos(angulo), py = cy + 0.38 * r * math.sin(angulo);
    final bx = cx + r * math.cos(angulo), by = cy + r * math.sin(angulo);
    pentagono.add('${px.toStringAsFixed(1)},${py.toStringAsFixed(1)}');
    linhas.write('<line x1="${px.toStringAsFixed(1)}" y1="${py.toStringAsFixed(1)}" '
        'x2="${bx.toStringAsFixed(1)}" y2="${by.toStringAsFixed(1)}" '
        'stroke="$linha" stroke-width="$esp" stroke-linecap="round"/>');
  }
  return '<circle cx="$cx" cy="$cy" r="$r" fill="$fill" stroke="$linha" stroke-width="$esp"/>'
      '$linhas'
      '<polygon points="${pentagono.join(' ')}" fill="$linha" stroke="$linha" '
      'stroke-width="$esp" stroke-linejoin="round"/>';
}

/// Cor do Flutter → texto "#RRGGBB" do SVG (sem a transparência).
String _hex(Color cor) =>
    '#${(cor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

const _branco = Color(0xFFFFFFFF);
const _escuro = Color(0xFF121212);

/// Troca as cores do SVG conforme o tema. O flutter_svg chama [substitute]
/// para cada cor que encontra no arquivo, antes de desenhar.
class _TrocaDeCores extends ColorMapper {
  const _TrocaDeCores({required this.claro, required this.paraBranco, required this.paraEscuro});

  factory _TrocaDeCores.doTema(BuildContext context) {
    final cores = context.cores;
    return _TrocaDeCores(
      claro: Theme.of(context).brightness == Brightness.light,
      paraBranco: cores.texto,
      paraEscuro: cores.fundo,
    );
  }

  final bool claro;
  final Color paraBranco;
  final Color paraEscuro;

  /// No escuro, devolve a cor como está no arquivo.
  Color mapear(Color cor) {
    if (!claro) return cor;
    // Compara pelo número da cor (0xAARRGGBB), que não depende de como o
    // flutter_svg montou o objeto `Color` ao ler o arquivo.
    if (cor.toARGB32() == _branco.toARGB32()) return paraBranco;
    if (cor.toARGB32() == _escuro.toARGB32()) return paraEscuro;
    return cor;
  }

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) =>
      mapear(color);

  // O flutter_svg guarda o desenho em cache usando o ColorMapper como parte
  // da chave; com == e hashCode, trocas iguais reaproveitam o cache em vez
  // de reprocessar o arquivo a cada redesenho.
  @override
  bool operator ==(Object other) =>
      other is _TrocaDeCores &&
      other.claro == claro &&
      other.paraBranco == paraBranco &&
      other.paraEscuro == paraEscuro;

  @override
  int get hashCode => Object.hash(claro, paraBranco, paraEscuro);
}
