// =============================================================================
// RACHA APP — TELAS DE LOGIN E CADASTRO
// =============================================================================
//
// Arquivo único e executável. Duas formas de rodar:
//
//   1. Num projeto Flutter novo, cole este arquivo por cima de lib/main.dart
//      e rode normal (o botão de play do IntelliJ). É o caminho mais simples.
//   2. Dentro do projeto racha_app, onde ele convive com o app de verdade:
//      flutter run -t lib/apresentacao_auth.dart
//
// Só Flutter puro. A única importação é `package:flutter/material.dart` —
// nenhum pacote externo, nenhum banco de dados, nenhuma internet. Por isso
// não é preciso mexer no pubspec.yaml nem rodar `flutter pub get`.
//
// O QUE TEM AQUI:
//   - Três telas (login, cadastro e uma tela inicial)
//   - Formulários com validação (Form, TextFormField, validator)
//   - Navegação entre telas (Navigator.push, pop e pushReplacement)
//   - Estado de tela com StatefulWidget e setState
//
// Os usuários cadastrados ficam numa lista na memória do aparelho. Some tudo
// quando o app fecha — é só para as telas funcionarem de verdade durante a
// apresentação, e está explicado na PARTE 2.
// =============================================================================

import 'package:flutter/material.dart';

// =============================================================================
// PARTE 1 — PONTO DE ENTRADA
// =============================================================================

void main() {
  runApp(const RachaApp());
}

class RachaApp extends StatelessWidget {
  const RachaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Racha App',

      // Tira a faixa vermelha de "DEBUG" do canto da tela.
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        // A partir de UMA cor, o Flutter gera a paleta inteira do app
        // (botões, campos, textos). O verde é o do racha.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),

        // Faz TODOS os campos de texto do app terem borda, sem precisar
        // repetir isso em cada TextFormField.
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),

      // A primeira tela que aparece quando o app abre.
      home: const LoginScreen(),
    );
  }
}

// =============================================================================
// PARTE 2 — O MODELO E A LISTA DE USUÁRIOS
// =============================================================================

/// Um jogador cadastrado no app.
///
/// É uma classe comum de Dart: só guarda os dados juntos, para não ficar
/// passando nome, email, idade e peso soltos de uma tela para outra.
class Usuario {
  final String nome;
  final String email;
  final String senha;
  final int idade;
  final double peso;

  const Usuario({
    required this.nome,
    required this.email,
    required this.senha,
    required this.idade,
    required this.peso,
  });
}

/// "Banco de dados" da apresentação: uma lista guardada na memória do app.
///
/// ATENÇÃO — duas coisas que valem saber explicar, porque podem ser
/// perguntadas:
///
///   1. A lista some quando o app fecha. Não existe banco de dados nem
///      servidor aqui; isso é o assunto de uma etapa seguinte do projeto.
///   2. A senha está guardada como texto puro. Num app de verdade isso nunca
///      se faz — a senha vai para um serviço de autenticação que guarda só um
///      hash dela. Aqui é assim para a tela de login poder ser demonstrada
///      sem depender de internet.
final List<Usuario> usuariosCadastrados = [];

/// Procura um usuário que tenha esse email E essa senha.
/// Devolve `null` quando não acha — é o que a tela de login usa para saber se
/// deixa entrar ou mostra a mensagem de erro.
Usuario? procurarUsuario(String email, String senha) {
  for (final usuario in usuariosCadastrados) {
    if (usuario.email == email && usuario.senha == senha) {
      return usuario;
    }
  }
  return null;
}

/// Diz se já existe alguém cadastrado com esse email. Usado pela tela de
/// cadastro para não criar duas contas iguais.
bool emailJaCadastrado(String email) {
  for (final usuario in usuariosCadastrados) {
    if (usuario.email == email) {
      return true;
    }
  }
  return false;
}

/// Deixa a primeira letra de cada palavra maiúscula e o resto minúscula —
/// "gustavo dias" vira "Gustavo Dias". Serve para o nome aparecer sempre do
/// mesmo jeito, independente de como a pessoa digitou.
String capitalizarNome(String nome) {
  return nome
      .trim()
      .split(' ')
      .where((palavra) => palavra.isNotEmpty)
      .map((palavra) =>
          palavra[0].toUpperCase() + palavra.substring(1).toLowerCase())
      .join(' ');
}

// =============================================================================
// PARTE 3 — TELA DE LOGIN
// =============================================================================

/// É StatefulWidget (e não Stateless) porque esta tela PRECISA GUARDAR COISAS
/// que mudam enquanto ela está aberta: o texto digitado nos campos e a
/// mensagem de erro. Um StatelessWidget não guarda nada.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Chave que dá acesso ao estado do Form. É por ela que o botão consegue
  /// mandar validar todos os campos de uma vez só.
  final _formKey = GlobalKey<FormState>();

  /// Cada controller fica "grudado" num campo e permite ler o que foi
  /// digitado nele (`_emailController.text`).
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  /// Mensagem mostrada em vermelho quando o email ou a senha estão errados.
  /// Fica nula enquanto não há erro nenhum.
  String? _erro;

  /// Chamado automaticamente pelo Flutter quando a tela sai de cena.
  /// Os controllers seguram espaço na memória; sem liberá-los aqui, esse
  /// espaço nunca é devolvido (é o que se chama de vazamento de memória).
  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _entrar() {
    // Dispara o `validator` de TODOS os campos do Form de uma vez.
    // Se algum devolver uma mensagem, o próprio Form mostra o texto em
    // vermelho embaixo do campo e a gente para aqui.
    if (!_formKey.currentState!.validate()) return;

    final usuario = procurarUsuario(
      _emailController.text.trim().toLowerCase(),
      _senhaController.text,
    );

    if (usuario == null) {
      // setState avisa o Flutter: "algo mudou, desenhe a tela de novo".
      // Sem o setState, a variável até mudaria, mas a tela continuaria
      // mostrando o conteúdo antigo.
      setState(() => _erro = 'Email ou senha inválidos.');
      return;
    }

    // pushReplacement TROCA a tela atual pela nova, em vez de empilhar por
    // cima. É o certo aqui: depois de entrar, o botão "voltar" do Android não
    // deve trazer a pessoa de volta para a tela de login.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(usuario: usuario)),
    );
  }

  Future<void> _irParaCadastro() async {
    // push EMPILHA a tela de cadastro por cima desta.
    //
    // O `await` espera essa tela ser fechada. O `<Usuario>` diz que, quando
    // ela fechar, pode vir um Usuario de volta — é o que a tela de cadastro
    // manda no Navigator.pop (ver PARTE 4).
    final novoUsuario = await Navigator.push<Usuario>(
      context,
      MaterialPageRoute(builder: (context) => const CadastroScreen()),
    );

    // Se voltou null, a pessoa apertou o botão de voltar sem se cadastrar.
    if (novoUsuario == null) return;

    // Já preenche o email de quem acabou de se cadastrar, para ela não
    // precisar digitar de novo.
    setState(() {
      _emailController.text = novoUsuario.email;
      _erro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea afasta o conteúdo do entalhe da câmera e da barra do
      // sistema, para nada ficar escondido embaixo deles.
      body: SafeArea(
        child: Center(
          // Sem o SingleChildScrollView, quando o teclado sobe ele cobre
          // metade da tela e o Flutter reclama que o conteúdo não cabe.
          // Com ele, a tela simplesmente rola.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                // stretch = os filhos ocupam toda a largura disponível.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // min = a Column ocupa só a altura necessária, em vez da
                // tela inteira. É o que mantém tudo centralizado.
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 64,
                    // Pega a cor principal definida lá no tema (PARTE 1),
                    // em vez de repetir o código da cor aqui.
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Racha App',
                    textAlign: TextAlign.center,
                    // Mesma ideia: pega um tamanho de texto já definido no
                    // tema, em vez de escolher um número na mão.
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),

                  // SizedBox usado só como espaçador entre os widgets.
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _emailController,
                    // Faz o teclado do celular já abrir com "@" e ".com".
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    // O validator devolve NULL quando está tudo certo, ou a
                    // mensagem de erro quando não está.
                    validator: (valor) {
                      if (valor == null || !valor.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _senhaController,
                    // Esconde os caracteres, mostrando bolinhas.
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: (valor) {
                      if (valor == null || valor.isEmpty) {
                        return 'Informe a senha';
                      }
                      return null;
                    },
                  ),

                  // Este bloco só entra na tela quando existe erro.
                  // O "if" dentro de uma lista de widgets é um recurso do
                  // Dart: se a condição for falsa, nada é adicionado.
                  if (_erro != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _erro!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _entrar,
                    child: const Text('Entrar'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _irParaCadastro,
                    child: const Text('Não tenho conta — cadastrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PARTE 4 — TELA DE CADASTRO
// =============================================================================

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _idadeController = TextEditingController();
  final _pesoController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  void _cadastrar() {
    if (!_formKey.currentState!.validate()) return;

    final usuario = Usuario(
      nome: capitalizarNome(_nomeController.text),
      email: _emailController.text.trim().toLowerCase(),
      senha: _senhaController.text,
      // Aqui pode usar `parse` (que quebra se o texto não for número)
      // porque o validator do campo JÁ garantiu que é. Ver o comentário
      // sobre parse/tryParse no campo de idade, mais abaixo.
      idade: int.parse(_idadeController.text),
      // Brasileiro digita "72,5"; o Dart só entende "72.5".
      peso: double.parse(_pesoController.text.replaceAll(',', '.')),
    );

    usuariosCadastrados.add(usuario);

    // SnackBar é a tarjinha que sobe do rodapé da tela.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conta criada! Bem-vindo, ${usuario.nome}.')),
    );

    // pop FECHA esta tela e volta para a anterior (o login).
    //
    // O segundo argumento é o que vai ser DEVOLVIDO para quem abriu esta
    // tela — é exatamente o valor que o `await Navigator.push<Usuario>` da
    // tela de login está esperando (ver PARTE 3).
    Navigator.pop(context, usuario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A AppBar já vem com o botão de voltar sozinha, porque esta tela foi
      // aberta com push (tem uma tela embaixo dela). Esse botão faz um
      // Navigator.pop sem devolver nada — daí o `null` lá na PARTE 3.
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 48,
                  child: Icon(Icons.person, size: 48),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Informe o nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (valor) {
                    if (valor == null || !valor.contains('@')) {
                      return 'Email inválido';
                    }
                    // O validator não serve só para o formato: dá para usar
                    // para qualquer regra. Aqui ele impede duas contas com
                    // o mesmo email.
                    if (emailJaCadastrado(valor.trim().toLowerCase())) {
                      return 'Já existe uma conta com esse email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  validator: (valor) {
                    if (valor == null || valor.length < 6) {
                      return 'Mínimo de 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Row coloca os widgets lado a lado (na horizontal).
                // Expanded faz cada campo ocupar metade da largura — sem
                // ele, os campos tentariam ter largura infinita dentro do
                // Row e o app mostraria a faixa amarela e preta de erro.
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _idadeController,
                        // Teclado só de números.
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Idade'),
                        validator: (valor) {
                          // tryParse devolve null quando o texto não é um
                          // número, em vez de quebrar o app como o parse
                          // faria. É isso que permite usá-lo como teste.
                          if (int.tryParse(valor ?? '') == null) {
                            return 'Idade inválida';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pesoController,
                        // Teclado de números COM vírgula, diferente do campo
                        // de idade.
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Peso (kg)'),
                        validator: (valor) {
                          final texto = (valor ?? '').replaceAll(',', '.');
                          if (double.tryParse(texto) == null) {
                            return 'Peso inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _cadastrar,
                  child: const Text('Cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PARTE 5 — TELA INICIAL
// =============================================================================

/// Esta é StatelessWidget porque não guarda nada que mude: ela só mostra o
/// usuário que recebeu pronto da tela de login.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.usuario});

  /// O dado que veio da tela anterior, passado pelo construtor.
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Racha App'),
        // A AppBar NÃO mostra botão de voltar aqui, porque esta tela entrou
        // com pushReplacement: não há nada empilhado embaixo dela.
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            // Sair é o caminho inverso: troca esta tela pela de login.
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 56,
              child: Icon(Icons.person, size: 56),
            ),
            const SizedBox(height: 16),
            Text(
              'Bem-vindo, ${usuario.nome}!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(usuario.email),
            // toStringAsFixed(1) mostra o peso com uma casa decimal:
            // 72.0 em vez de 72.
            Text('${usuario.idade} anos · ${usuario.peso.toStringAsFixed(1)} kg'),
          ],
        ),
      ),
    );
  }
}
