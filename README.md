# Racha App

App em Flutter para organizar rachas de futebol: cadastro de jogadores, convite de participantes, geração automática de times balanceados por posição e nota, avaliação pós-jogo e ranking acumulado. Backend em Firebase (Auth, Firestore, Storage).

---

## O caminho mais curto para ver rodando

```bash
git clone https://github.com/GustavoDias07/Racha-app.git
cd Racha-app
flutter pub get
flutter run -d chrome
```

O app abre no Chrome, você cria uma conta e já está dentro. **Não precisa configurar Firebase, nem pedir chave para ninguém** — a configuração do projeto já está no repositório e qualquer pessoa pode se cadastrar.

Se der erro de versão, confira o Flutter: o projeto foi desenvolvido na **3.47.0 (stable)**, com Dart 3.13.0.

```bash
flutter --version
flutter doctor
```

Para rodar no Android, é o mesmo comando com um emulador aberto ou um celular ligado por USB:

```bash
flutter run
```

> Um guia de instalação do zero — Flutter, PATH, IDE, emulador, problemas comuns — está em `docs/racha-app-como-rodar-do-zero.pdf`, para quem nunca montou um ambiente Flutter.

---

## O Firebase: o que dá e o que não dá sem acesso

Esta é a dúvida que mais aparece, então vale separar com clareza.

O `lib/firebase_options.dart` e o `android/app/google-services.json` estão versionados e apontam para o projeto **`racha-app-ghad-108ab`**. Essas chaves são públicas por natureza (todo app Flutter+Firebase as embute no binário); quem protege os dados são as regras do Firestore, não o segredo delas.

| O que você quer fazer | Precisa de acesso ao projeto Firebase? |
| --- | --- |
| Rodar o app, criar conta, usar tudo | **Não.** Funciona assim que clonar |
| Ver os dados no console | Sim |
| Publicar regras ou índices | Sim |
| Mexer em autenticação, planos, cobrança | Sim |

Para ganhar acesso, peça ao dono do projeto para adicionar seu e-mail em **Configurações do projeto → Usuários e permissões**.

### Se preferir um Firebase próprio

Dá para apontar o app para outro projeto sem tocar no código:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=SEU_PROJETO
```

Isso regenera `firebase_options.dart` e `google-services.json`. Depois é preciso ligar **Authentication (e-mail/senha)** e **Firestore** no console, e publicar as regras e os índices (abaixo). O app não sobe sem os índices: as consultas compostas falham com um erro pedindo exatamente isso.

---

## Publicar regras e índices

As regras de segurança e os índices do Firestore moram no repositório e precisam ser publicados sempre que mudarem:

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules,firestore:indexes --project racha-app-ghad-108ab
```

| Arquivo | O que é |
| --- | --- |
| `firestore.rules` | Quem pode ler e escrever o quê. **A segurança inteira do app está aqui** |
| `firestore.indexes.json` | Índices compostos. Sem eles, consultas com mais de um filtro falham |
| `storage.rules` | Regras do Storage (ainda não usado — ver `StorageService`) |
| `firebase.json` | Aponta o CLI para os arquivos acima |

---

## Estrutura

```
lib/
  core/        utilitários puros, tema, rotas, widgets compartilhados
  models/      as entidades (User, Grupo, Racha, Participante...)
  services/    conversa com o mundo externo (Auth, GPS, geocoding)
  repositories/ leitura e escrita no Firestore
  providers/   injeção de dependência e estado (Riverpod)
  screens/     as telas
test/          51 testes, só de lógica pura
docs/          documentação e histórico de decisões
```

A separação que mais importa: **`services/` e `repositories/` são as únicas camadas que conhecem o Firebase**. Telas e `core/` não importam nada do SDK — é o que permite testar a lógica sem subir emulador.

### Dois arquivos para ler antes de mexer

- **`docs/tarefas.md`** — o registro completo: cada problema encontrado, o que foi feito e por quê. É aqui que está o roadmap, incluindo o Bloco 5, com os pré-requisitos para publicar na Play Store.
- **`firestore.rules`** — os comentários no topo explicam as limitações conhecidas da arquitetura (sem Cloud Functions, ranking calculado no cliente).

---

## Testes

```bash
flutter test
flutter analyze
```

São 51 testes cobrindo balanceamento de times, cálculo de MVP, agregação de ranking, distância geográfica, busca de endereço e o tema. Não há teste de tela: isso exigiria mocks dos plugins do Firebase, que ainda não fazem parte do projeto.

---

## Build de release

```bash
flutter build appbundle --release
```

⚠️ **O arquivo `android/key.properties` não está no repositório** — ele guarda a senha do keystore de assinatura. Sem ele o build **não quebra**, mas sai assinado com a chave de debug e emite um aviso no log; a Play Store recusa um pacote assim.

Quem for publicar precisa gerar a própria chave. O passo a passo está em `docs/tarefas.md`, item **T19**.

---

## Limitações conhecidas

Nenhuma delas é bug — são decisões registradas, com o motivo, em `docs/tarefas.md`:

- **Sem push notification.** O token do FCM é registrado, mas nada dispara envio: exigiria Cloud Functions e o plano Blaze. Os avisos dentro do app (o sino da tela inicial) cobrem o essencial.
- **Ranking calculado no cliente.** As regras validam o formato, não quem escreve. Num app público isso seria vulnerabilidade — item T20.
- **Foto de perfil em base64 no Firestore**, em vez do Storage, que exige o plano pago. Encostando no limite de 1 MB por documento — item T23.
