import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Escolha de aparência (Claro / Escuro / Seguir o celular) — ver T35 em
/// docs/tarefas.md.
///
/// Fica salva **só no aparelho** (shared_preferences), não no Firestore:
/// é uma preferência de tela, não um dado do jogador. Por isso este provider
/// NÃO observa `uidLogadoProvider` como os de dados — trocar de conta no
/// mesmo celular mantém a aparência, que é o esperado.

/// Chave usada no armazenamento do aparelho.
const _chaveTema = 'aparencia';

/// O `SharedPreferences` aberto. Ele é carregado no `main()` antes do app
/// subir e entra aqui por `overrideWithValue` — assim a leitura abaixo é
/// imediata e o app já abre no tema certo, sem piscar no tema errado.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Sobrescrito no main()'),
);

/// Tema escolhido. A tela de Perfil lê com `ref.watch(temaProvider)` e muda
/// com `ref.read(temaProvider.notifier).escolher(...)`; o `MaterialApp` em
/// `main.dart` observa e redesenha o app inteiro.
final temaProvider = NotifierProvider<TemaController, ThemeMode>(TemaController.new);

class TemaController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final salvo = ref.read(sharedPreferencesProvider).getString(_chaveTema);
    return modoDoTexto(salvo);
  }

  Future<void> escolher(ThemeMode modo) async {
    // Muda a tela primeiro e salva depois: a troca é instantânea mesmo se
    // a gravação demorar um pouco.
    state = modo;
    await ref.read(sharedPreferencesProvider).setString(_chaveTema, textoDoModo(modo));
  }
}

/// Converte para texto antes de salvar. Guardamos um texto nosso, e não o
/// índice do enum, para que reordenar o `ThemeMode` nunca troque a escolha
/// salva de alguém.
String textoDoModo(ThemeMode modo) => switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'escuro',
      ThemeMode.system => 'sistema',
    };

/// O contrário de [textoDoModo]. Nada salvo (primeira vez) ou um valor
/// desconhecido vira "Seguir o celular", que é o padrão do app.
ThemeMode modoDoTexto(String? texto) => switch (texto) {
      'claro' => ThemeMode.light,
      'escuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
