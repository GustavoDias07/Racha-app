import 'package:flutter/material.dart';

/// Cores do app, num lugar só — agora com uma versão para o tema escuro e
/// outra para o claro (ver T35 em docs/tarefas.md).
///
/// Duas famílias, e a diferença entre elas importa:
///
///  - As de **marca** (fundo, superfície, verde) definem a aparência. Mudar
///    uma delas muda o app inteiro.
///  - As **semânticas** (confirmado, pendente, recusado…) carregam
///    significado. A regra é: verde deu certo, âmbar está esperando, vermelho
///    deu errado. Nunca usar uma cor dessas por ser bonita — só pelo que ela
///    quer dizer.
///
/// Por que `ThemeExtension` e não mais `static const`: uma constante tem um
/// valor só, para sempre. Com dois temas, a cor certa depende de qual tema
/// está ligado *naquele momento* — então ela tem que vir do `Theme` da tela.
/// O `ThemeExtension` é o jeito oficial do Flutter de pendurar cores próprias
/// no tema, e o `MaterialApp` troca o conjunto inteiro quando o tema muda.
///
/// Nas telas, use `context.cores.texto`, `context.cores.recusado` etc.
/// (a extensão `CoresDoTema` lá embaixo). Nenhuma tela deve escrever
/// `Colors.alguma` direto: uma cor fixa fica boa num tema e some no outro.
@immutable
class AppCores extends ThemeExtension<AppCores> {
  const AppCores({
    required this.fundo,
    required this.superficie,
    required this.superficieAlta,
    required this.verde,
    required this.verdeTexto,
    required this.texto,
    required this.textoSecundario,
    required this.borda,
    required this.confirmado,
    required this.pendente,
    required this.recusado,
    required this.sobreRecusado,
    required this.destaque,
    required this.info,
    required this.neutro,
  });

  // --- Marca ---------------------------------------------------------------

  /// Fundo das telas.
  final Color fundo;

  /// Cards e caixas que precisam se destacar do fundo.
  final Color superficie;

  /// Um degrau acima da superfície — menus, campos de texto, chips.
  final Color superficieAlta;

  /// A cor do app, para **preencher** coisas: botões, fundo do logo, a
  /// trilha do switch. É o mesmo #1DB954 nos dois temas — é a identidade.
  final Color verde;

  /// Verde para **texto e ícones**. No escuro é o próprio [verde]; no claro
  /// é um tom mais fechado, porque o #1DB954 em cima de fundo branco tem
  /// contraste baixo (letra verde-clara no branco fica difícil de ler).
  final Color verdeTexto;

  final Color texto;

  /// Texto de apoio: legendas, datas, contagens.
  final Color textoSecundario;

  /// Bordas e divisórias.
  final Color borda;

  // --- Semânticas ----------------------------------------------------------
  // No tema claro elas ficam mais escuras que no escuro, pelo mesmo motivo
  // do [verdeTexto]: são usadas quase sempre como texto/ícone sobre o fundo.

  /// Confirmado, aprovado, compareceu. Mesmo verde do [verdeTexto]: não faz
  /// sentido ter dois verdes diferentes querendo dizer a mesma coisa.
  final Color confirmado;

  /// Pendente, aguardando resposta, atrasou.
  final Color pendente;

  /// Recusado, faltou, erro.
  final Color recusado;

  /// Texto em cima de um botão preenchido com [recusado] (ex: "Excluir").
  /// No escuro o vermelho é claro e pede letra preta; no claro o vermelho é
  /// fechado e pede letra branca.
  final Color sobreRecusado;

  /// Troféu de MVP e estrela de nota — dourado, distinto do âmbar de
  /// "pendente" para os dois não se confundirem numa mesma tela.
  final Color destaque;

  /// Informação neutra, sem juízo de valor (ex: convidado "Oficializado").
  final Color info;

  /// Ausência de status, item desligado.
  final Color neutro;

  /// Tema escuro: exatamente as cores que o app sempre teve.
  static const escuro = AppCores(
    // Não é preto puro de propósito: preto absoluto num OLED cria um
    // contraste duro demais nas bordas dos cards.
    fundo: Color(0xFF121212),
    superficie: Color(0xFF1E1E1E),
    superficieAlta: Color(0xFF2A2A2A),
    verde: Color(0xFF1DB954),
    verdeTexto: Color(0xFF1DB954),
    texto: Color(0xFFFFFFFF),
    textoSecundario: Color(0xFFB3B3B3),
    borda: Color(0xFF3E3E3E),
    confirmado: Color(0xFF1DB954),
    pendente: Color(0xFFFBBF24),
    recusado: Color(0xFFF87171),
    sobreRecusado: Color(0xFF000000),
    destaque: Color(0xFFFFC107),
    info: Color(0xFF60A5FA),
    neutro: Color(0xFF8A8A8A),
  );

  /// Tema claro. Fundo levemente cinza e cards brancos: assim o card se
  /// separa do fundo sem precisar de sombra (mesma ideia do escuro, onde o
  /// card é um degrau mais claro que o fundo).
  static const claro = AppCores(
    fundo: Color(0xFFF4F4F4),
    superficie: Color(0xFFFFFFFF),
    superficieAlta: Color(0xFFE8E8E8),
    verde: Color(0xFF1DB954),
    verdeTexto: Color(0xFF117A37),
    texto: Color(0xFF121212),
    textoSecundario: Color(0xFF5E5E5E),
    borda: Color(0xFFD0D0D0),
    confirmado: Color(0xFF117A37),
    pendente: Color(0xFFB45309),
    recusado: Color(0xFFC62828),
    sobreRecusado: Color(0xFFFFFFFF),
    destaque: Color(0xFFD97706),
    info: Color(0xFF1D4ED8),
    neutro: Color(0xFF757575),
  );

  // Os dois métodos abaixo são exigidos por `ThemeExtension`. O `lerp` é o
  // que deixa a troca de tema animada (as cores "deslizam" de uma para a
  // outra em vez de piscar).

  @override
  AppCores copyWith({
    Color? fundo,
    Color? superficie,
    Color? superficieAlta,
    Color? verde,
    Color? verdeTexto,
    Color? texto,
    Color? textoSecundario,
    Color? borda,
    Color? confirmado,
    Color? pendente,
    Color? recusado,
    Color? sobreRecusado,
    Color? destaque,
    Color? info,
    Color? neutro,
  }) {
    return AppCores(
      fundo: fundo ?? this.fundo,
      superficie: superficie ?? this.superficie,
      superficieAlta: superficieAlta ?? this.superficieAlta,
      verde: verde ?? this.verde,
      verdeTexto: verdeTexto ?? this.verdeTexto,
      texto: texto ?? this.texto,
      textoSecundario: textoSecundario ?? this.textoSecundario,
      borda: borda ?? this.borda,
      confirmado: confirmado ?? this.confirmado,
      pendente: pendente ?? this.pendente,
      recusado: recusado ?? this.recusado,
      sobreRecusado: sobreRecusado ?? this.sobreRecusado,
      destaque: destaque ?? this.destaque,
      info: info ?? this.info,
      neutro: neutro ?? this.neutro,
    );
  }

  @override
  AppCores lerp(AppCores? other, double t) {
    if (other == null) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppCores(
      fundo: m(fundo, other.fundo),
      superficie: m(superficie, other.superficie),
      superficieAlta: m(superficieAlta, other.superficieAlta),
      verde: m(verde, other.verde),
      verdeTexto: m(verdeTexto, other.verdeTexto),
      texto: m(texto, other.texto),
      textoSecundario: m(textoSecundario, other.textoSecundario),
      borda: m(borda, other.borda),
      confirmado: m(confirmado, other.confirmado),
      pendente: m(pendente, other.pendente),
      recusado: m(recusado, other.recusado),
      sobreRecusado: m(sobreRecusado, other.sobreRecusado),
      destaque: m(destaque, other.destaque),
      info: m(info, other.info),
      neutro: m(neutro, other.neutro),
    );
  }
}

/// Atalho para as telas: `context.cores.texto` em vez de
/// `Theme.of(context).extension<AppCores>()!.texto`.
extension CoresDoTema on BuildContext {
  AppCores get cores => Theme.of(this).extension<AppCores>()!;
}

class AppTheme {
  AppTheme._();

  /// Tema escuro (o visual original do app).
  static ThemeData get dark => _construir(AppCores.escuro, Brightness.dark);

  /// Tema claro, com as mesmas regras de forma — só as cores mudam.
  static ThemeData get light => _construir(AppCores.claro, Brightness.light);

  /// Um único construtor para os dois temas: assim um ajuste de formato
  /// (raio dos botões, estilo dos campos) vale para os dois de uma vez, e o
  /// claro nunca fica "esquecido" para trás.
  static ThemeData _construir(AppCores c, Brightness brilho) {
    // O fromSeed preenche as dezenas de encaixes que o Material 3 tem
    // (containers, variantes, estados); logo abaixo fixamos à mão só os que
    // definem a identidade, porque o tom que o algoritmo gera a partir da
    // semente é mais apagado do que o verde que queremos.
    final base = ColorScheme.fromSeed(
      seedColor: c.verde,
      brightness: brilho,
    );

    final colorScheme = base.copyWith(
      primary: c.verde,
      // Texto preto sobre o verde, nos dois temas: é o que dá o contraste
      // alto característico desse estilo. Texto branco sobre verde vibrante
      // fica ilegível.
      onPrimary: Colors.black,
      surface: c.fundo,
      onSurface: c.texto,
      onSurfaceVariant: c.textoSecundario,
      surfaceContainerLowest: c.fundo,
      surfaceContainerLow: c.superficie,
      surfaceContainer: c.superficie,
      surfaceContainerHigh: c.superficieAlta,
      surfaceContainerHighest: c.superficieAlta,
      outline: c.borda,
      outlineVariant: c.borda,
      error: c.recusado,
      onError: c.sobreRecusado,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.fundo,
      // Pendura as nossas cores no tema — é daqui que `context.cores` lê.
      extensions: [c],

      appBarTheme: AppBarThemeData(
        backgroundColor: c.fundo,
        foregroundColor: c.texto,
        // Sem sombra e sem mudar de cor ao rolar: a barra some no fundo e a
        // tela fica sendo uma superfície só.
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: c.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // A borda some; o preenchimento é o que delimita o campo.
      //
      // Borda de sublinhado (estilo "filled" do Material), e não de contorno:
      // com `OutlineInputBorder` o rótulo flutuante é desenhado EM CIMA da
      // linha de cima do campo, e como a linha aqui é invisível o rótulo
      // ficava meio para fora da caixa ("Data", "Tipo de campo"). Com o
      // sublinhado o rótulo sobe para dentro do campo. O `borderRadius` nas
      // quatro pontas mantém o preenchimento arredondado.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.superficieAlta,
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.verde, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.recusado),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.recusado, width: 2),
        ),
        labelStyle: TextStyle(color: c.textoSecundario),
        hintStyle: TextStyle(color: c.neutro),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.verdeTexto,
        unselectedLabelColor: c.textoSecundario,
        indicatorColor: c.verde,
        dividerColor: c.borda,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.superficieAlta,
        selectedColor: c.verde,
        labelStyle: TextStyle(color: c.texto),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.texto,
          side: BorderSide(color: c.borda),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        // Botão de texto é letra verde sobre o fundo: usa o verde de texto.
        style: TextButton.styleFrom(foregroundColor: c.verdeTexto),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.textoSecundario,
        textColor: c.texto,
      ),

      dividerTheme: DividerThemeData(
        color: c.borda,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.superficieAlta,
        contentTextStyle: TextStyle(color: c.texto),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.superficie,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.superficie,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.verde,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? Colors.black
              : c.textoSecundario,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? c.verde
              : c.superficieAlta,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.verde,
        foregroundColor: Colors.black,
      ),
    );
  }
}
