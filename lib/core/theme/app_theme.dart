import 'package:flutter/material.dart';

/// Cores do app, num lugar só.
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
/// Nenhuma tela deve escrever `Colors.alguma` direto: no tema escuro, os tons
/// prontos do Material (`Colors.black54` e parentes) somem no fundo.
class AppColors {
  AppColors._();

  // --- Marca ---------------------------------------------------------------

  /// Fundo das telas. Não é preto puro de propósito: preto absoluto num
  /// OLED cria um contraste duro demais nas bordas dos cards.
  static const fundo = Color(0xFF121212);

  /// Cards e caixas que precisam se destacar do fundo.
  static const superficie = Color(0xFF1E1E1E);

  /// Um degrau acima da superfície — menus, campos de texto, chips.
  static const superficieAlta = Color(0xFF2A2A2A);

  /// A cor do app. Botões, abas ativas, links, qualquer coisa clicável.
  static const verde = Color(0xFF1DB954);

  static const texto = Color(0xFFFFFFFF);

  /// Texto de apoio: legendas, datas, contagens. Substitui o antigo
  /// `Colors.black54`, que era invisível no escuro.
  static const textoSecundario = Color(0xFFB3B3B3);

  /// Bordas e divisórias.
  static const borda = Color(0xFF3E3E3E);

  // --- Semânticas ----------------------------------------------------------

  /// Confirmado, aprovado, compareceu. É o mesmo verde da marca: não faz
  /// sentido ter dois verdes diferentes querendo dizer a mesma coisa.
  static const confirmado = verde;

  /// Pendente, aguardando resposta, atrasou.
  static const pendente = Color(0xFFFBBF24);

  /// Recusado, faltou, erro.
  static const recusado = Color(0xFFF87171);

  /// Troféu de MVP e estrela de nota — dourado, distinto do âmbar de
  /// "pendente" para os dois não se confundirem numa mesma tela.
  static const destaque = Color(0xFFFFC107);

  /// Informação neutra, sem juízo de valor (ex: convidado "Oficializado").
  static const info = Color(0xFF60A5FA);

  /// Ausência de status, item desligado.
  static const neutro = Color(0xFF8A8A8A);
}

class AppTheme {
  AppTheme._();

  /// Tema único do app. Não existe versão clara: o app é sempre escuro,
  /// independente da configuração do celular, para ficar igual em qualquer
  /// aparelho.
  static ThemeData get dark {
    // O fromSeed preenche as dezenas de encaixes que o Material 3 tem
    // (containers, variantes, estados); logo abaixo fixamos à mão só os que
    // definem a identidade, porque o tom que o algoritmo gera a partir da
    // semente é mais apagado do que o verde que queremos.
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.verde,
      brightness: Brightness.dark,
    );

    final colorScheme = base.copyWith(
      primary: AppColors.verde,
      // Texto preto sobre o verde: é o que dá o contraste alto característico
      // desse estilo. Texto branco sobre verde vibrante fica ilegível.
      onPrimary: Colors.black,
      surface: AppColors.fundo,
      onSurface: AppColors.texto,
      onSurfaceVariant: AppColors.textoSecundario,
      surfaceContainerLowest: AppColors.fundo,
      surfaceContainerLow: AppColors.superficie,
      surfaceContainer: AppColors.superficie,
      surfaceContainerHigh: AppColors.superficieAlta,
      surfaceContainerHighest: AppColors.superficieAlta,
      outline: AppColors.borda,
      outlineVariant: AppColors.borda,
      error: AppColors.recusado,
      onError: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.fundo,

      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.fundo,
        foregroundColor: AppColors.texto,
        // Sem sombra e sem mudar de cor ao rolar: a barra some no fundo e a
        // tela fica sendo uma superfície só.
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      cardTheme: const CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // No escuro a borda some; o preenchimento é o que delimita o campo.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficieAlta,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.verde, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.recusado),
        ),
        labelStyle: const TextStyle(color: AppColors.textoSecundario),
        hintStyle: const TextStyle(color: AppColors.neutro),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.verde,
        unselectedLabelColor: AppColors.textoSecundario,
        indicatorColor: AppColors.verde,
        dividerColor: AppColors.borda,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.superficieAlta,
        selectedColor: AppColors.verde,
        labelStyle: const TextStyle(color: AppColors.texto),
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
          foregroundColor: AppColors.texto,
          side: const BorderSide(color: AppColors.borda),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.verde),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textoSecundario,
        textColor: AppColors.texto,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borda,
        thickness: 1,
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.superficieAlta,
        contentTextStyle: TextStyle(color: AppColors.texto),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.superficie,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.superficie,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.verde,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? Colors.black
              : AppColors.textoSecundario,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? AppColors.verde
              : AppColors.superficieAlta,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.verde,
        foregroundColor: Colors.black,
      ),
    );
  }
}
