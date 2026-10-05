# Onde paramos — 23/08/2026

> Ponto de retomada. Para o detalhe de cada item (o que era o problema, o que
> foi feito e por quê), ver `docs/tarefas.md`, que é o registro completo.
> Este arquivo é só o suficiente para você sentar amanhã e continuar.

---

## ⚠️ Antes de qualquer coisa: nada foi commitado

**33 arquivos modificados e 5 novos**, tudo em cima do commit `1975549`. Um
dia inteiro de trabalho existe só no disco. Vale commitar antes de mexer em
qualquer outra coisa.

Sugestão de mensagem, já que foram várias frentes:

```
Balanceamento por nota e posicao, presenca e pontualidade

- Times equilibrados pela media real de avaliacao (antes todos entravam
  com nota fixa)
- Balanceamento por setor a partir da posicao main, com a secundaria
  cobrindo setor em falta
- Posicao obrigatoria ao confirmar presenca
- Chamada do dia (compareceu/atrasou/faltou) e anotadores delegados
- Ranking unificado numa unica agregacao
- Correcoes de fluxo em grupos, solicitacoes e criacao de racha
```

---

## Estado do projeto

| | |
|---|---|
| `flutter analyze` | limpo |
| `flutter test` | 34/34 passando |
| Regras do Firestore | publicadas (último deploy hoje) |
| Índices do Firestore | publicados |
| APK | `build/app/outputs/flutter-apk/app-release.apk` — **desatualizado**, foi gerado antes das mudanças de presença e anotadores |

Projeto Firebase: `racha-app-ghad-108ab` (não há `.firebaserc`, então todo
comando precisa de `--project racha-app-ghad-108ab`).

---

## A pergunta que ficou aberta

Antes de implementar a **T16** (pontuação de presença), preciso de uma
decisão sua:

**A janela de 10 rodadas conta rodadas do grupo ou rodadas em que a pessoa
foi convidada?**

Isso muda o resultado para quem entrou no grupo há pouco tempo. Contando
rodadas do grupo, quem chegou há três semanas carrega sete rodadas "vazias"
puxando a pontuação para baixo sem ter feito nada de errado.

**Minha sugestão:** contar rodadas **em que a pessoa foi convidada**, e exigir
um mínimo de umas 3 rodadas antes de a pontuação valer para prioridade.
Abaixo disso o jogador entra no meio da fila — nem privilegiado por ser novo,
nem punido por não ter histórico.

---

## Próximos passos, na ordem

### 1. T16 — Pontuação de presença
Depende da resposta acima. Já está decidido:

- Eixo **separado** da nota de habilidade (a média de avaliação equilibra os
  times; a pontuação de presença decide quem joga)
- Janela móvel das últimas ~10 rodadas, não saldo acumulado
- Escala: compareceu no horário **+3**, atrasado **+1**, recusou com
  antecedência **0**, confirmou e não apareceu **−5**, não respondeu **−1**
- Absorve a T7: o campo `totalRachas` passa a se chamar
  `totalRachasAvaliados` nessa mesma mudança

⚠️ **Cuidado:** esse rename toca o `firestore.rules`. Código e regras precisam
subir **juntos** — uma tentativa isolada hoje quebrou as escritas de ranking
por alguns minutos.

### 2. T17 — Banco ordenado
Hoje **nada limita o elenco**: se 18 confirmarem num society de 7v7, o
balanceador monta dois times de 9. O conceito de não jogar nunca existiu.

- `ResultadoBalanceamento` ganha um terceiro campo (`banco`)
- `BalanceadorTimes.gerar` passa a receber o limite de vagas
- Ordem do banco = pontuação de presença (é a ordem de entrada)
- Atraso custa a vaga do dia, **mas os pontos continuam mandando**: um
  atrasado bem pontuado passa na frente de um pontual mal pontuado

### 3. Bloco 5 — Pré-requisitos da Play Store
Comece pela **T18** — é o único item verdadeiramente irreversível.

- **T18** trocar o `applicationId` (hoje `com.example.racha_app`, que o Google
  rejeita; e depois de publicado não dá mais para mudar)
- **T19** chave de assinatura de upload (hoje usa a de debug)
- **T20** cálculo de ranking no servidor — hoje **qualquer usuário logado
  pode sobrescrever o ranking de qualquer outro**
- **T21** exclusão de conta dentro do app (exigência do Google)
- **T22** política de privacidade e formulário de segurança de dados

---

## Coisas que é fácil esquecer

**O APK precisa ser regerado** antes do próximo teste no celular:
`flutter build apk --release`. Para mandar por WhatsApp, `--split-per-abi`
derruba de 58 MB para uns 20 MB (instalar o `arm64-v8a`).

**Para trabalhar interface, use cabo em vez de APK.** Depuração USB ligada no
celular e `flutter run --release` dá hot reload: a mudança aparece na tela em
segundos, sem reinstalar.

**Deploy das regras:**
`firebase deploy --only firestore:rules --project racha-app-ghad-108ab`

**Os dados do Firestore foram tratados como descartáveis** nas mudanças de
hoje (o `grupoId` em avaliações e estatísticas não foi migrado para
documentos antigos). Da próxima vez que houver dado que importe, mudanças
assim vão exigir script de backfill.

---

## Decisões de produto tomadas hoje

Registro rápido, porque são as que mais custam a reconstruir de memória:

- **O balanceamento tem duas prioridades que valem juntas**: posição main e
  nota. Não é uma depois da outra — depois de montar os times por setor, um
  ajuste final troca jogadores do mesmo setor até as médias ficarem próximas.
- **Presença é eixo separado de habilidade.** Ser assíduo não pode fazer o
  algoritmo achar que a pessoa joga melhor.
- **Recusar com antecedência é neutro, não negativo.** Punir quem avisa ensina
  o jogador a ficar calado, que é o pior resultado para quem organiza.
- **O admin não nasce mais confirmado** — quem organiza nem sempre joga.
- **Recusa de pedido de entrada só o admin reabre**, sem prazo automático:
  vale tanto para um dia quanto para um ano.
- **O anotador só mexe em presença.** Não é co-administração.
