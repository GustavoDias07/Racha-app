# App de Racha — Estrutura do Projeto (Flutter)

## 1. Visão geral

App para organizar "rachas" de futebol, com cadastro de jogadores, criação de eventos (rachas), convite de participantes, geração automática de times balanceados, avaliação pós-jogo e ranking acumulado.

**Requisito de hardware atendido:** câmera (captura de foto de perfil).

---

## 2. Modelo de dados (entidades principais)

### `User` (jogador cadastrado)
- id
- nome
- email
- senha (hash)
- foto_perfil (via câmera)
- idade
- peso
- created_at

### `Grupo` (racha recorrente)
- id
- nome (ex: "Racha da Quarta")
- local_padrao
- tipo_campo_padrao
- qtd_jogadores_linha_padrao
- dia_semana
- horario
- admin_id
- membros_fixos (lista de user_id — jogadores convidados automaticamente toda semana)

### `Racha` (evento — uma ocorrência, ligada ou não a um Grupo)
- id
- grupo_id (nullable — se veio de um Grupo recorrente ou foi criado avulso)
- nome/local
- data_hora
- tipo_campo (enum: campao, society, futsal, minicampo)
- qtd_jogadores_linha (fixo para campão/futsal, configurável para society/minicampo — ver seção 2.1)
- formacao (derivada do tipo_campo + qtd_jogadores_linha)
- admin_id (User que criou)
- status (aberto, em_andamento, finalizado)

### 2.1 Tipos de campo e formação

| Tipo de campo | Goleiro | Linha | Total | Configurável? |
|---|---|---|---|---|
| Campão | 1 | 10 | 11 | Não |
| Futsal | 1 | 4 | 5 | Não |
| Society | 1 | 6 (padrão) | 7 (padrão) | Sim — admin pode ajustar nº de linha ao criar o racha |
| Minicampo | 1 | 7 (padrão) | 8 (padrão) | Sim — admin pode ajustar nº de linha ao criar o racha |

> Society e minicampo variam bastante de racha pra racha, então ao criar o racha o admin escolhe o tipo de campo (que já sugere um valor padrão de jogadores de linha) e pode ajustar esse número manualmente se quiser.

> **Decisão:** vagas livres. O algoritmo garante apenas o goleiro fixo; o restante das vagas de linha é preenchido livremente com base em posição main/usual dos jogadores disponíveis, sem exigir número fixo de zagueiros/meias/atacantes. Reflete a variação natural de racha pra racha.

### `Participante` (User dentro de um Racha específico)
- id
- racha_id
- user_id
- posicao_main
- posicao_usual
- time (A ou B, definido após o algoritmo)
- confirmado (bool)

### `Convidado` (perfil temporário, sem login)
- id
- racha_id
- convidado_por (user_id)
- nome
- idade_aproximada
- peso_aproximado
- posicao_main
- posicao_usual
- aprovado_pelo_admin (bool)
- time (A ou B)

> Nota: no algoritmo de balanceamento, `Participante` e `Convidado` podem ser tratados como um tipo unificado ("Jogador Elegível"), diferindo só na origem do dado.

> **Oficialização do convidado:** a qualquer momento, o convidado pode optar por criar uma conta (virar `User`). Ao fazer isso, o histórico de `Avaliacao` e `Estatistica` vinculado ao `convidado_id` é migrado/reatribuído ao novo `user_id`, preservando ranking e média já construídos como convidado.

### `Avaliacao`
- id
- racha_id
- avaliador_id (quem avaliou — User)
- avaliado_id (User ou Convidado)
- nota

Regra: cada jogador avalia os companheiros do próprio time + 1 jogador do time adversário.

### `Estatistica`
- id
- racha_id
- jogador_id (User ou Convidado)
- gols
- assistencias
- cartoes

### `Ranking` (calculado/acumulado)
- user_id
- media_avaliacoes
- total_mvps
- total_gols
- total_assistencias
- total_rachas

---

## 3. Telas principais

1. **Cadastro / Login** — nome, email, senha, idade, peso, foto (câmera)
2. **Home** — lista de rachas do usuário (criados ou convidado), botão "Criar racha"
3. **Criar Racha** — nome/local, data/hora, tipo de campo (sugere formação padrão; society e minicampo permitem ajustar a quantidade de jogadores de linha), opção "tornar recorrente" (vira um `Grupo`, com dia da semana/horário fixo e lista de membros fixos)
4. **Detalhes do Racha** — lista de participantes (com status: confirmado / pendente / recusado), convidados pendentes, botão "Confirmar presença" (jogador convidado ainda não confirma automaticamente), botão "Convidar", botão "Gerar times" (habilitado só quando houver confirmados suficientes para a formação mínima; admin)
5. **Convidar Jogador** — buscar usuário cadastrado (por email/nome) OU cadastrar convidado (mini-formulário: nome, idade aprox., peso aprox., posições)
6. **Aprovação de Convidados** (admin) — lista de convidados pendentes para aprovar/recusar
7. **Definir Posições** (participante, ao entrar no racha) — escolher posição main e usual
8. **Times Gerados** — visualização dos dois times montados pelo algoritmo
9. **Avaliação Pós-Jogo** — avaliar companheiros de time + 1 adversário
10. **Registrar Estatísticas** (admin ou destaque) — gols, assistências, cartões
11. **Perfil do Jogador** — foto, dados pessoais, histórico, estatísticas acumuladas
12. **Ranking** — lista geral ordenada por média de avaliação / MVPs / gols

---

## 4. Fluxos principais

**Fluxo 1 — Cadastro**
Usuário se cadastra → tira foto com câmera → perfil pronto → apto a ser convidado para rachas.

**Fluxo 2 — Criação e montagem de racha**
Admin cria racha → define tipo de campo (formação é derivada) → convida jogadores cadastrados e/ou adiciona convidados → jogador convidado recebe notificação e **confirma presença** (ou recusa) → participantes confirmados definem posição main/usual → convidados entram com nota neutra (sem histórico) → admin aciona "Gerar times" (só considera quem confirmou presença — participantes pendentes/recusados ficam de fora) → algoritmo monta os times.

> Se o número de confirmados for menor que o mínimo exigido pela formação (ex: 7 no society padrão), o app deve avisar o admin, que pode aguardar mais confirmações, ajustar `qtd_jogadores_linha` (se o campo permitir) ou adicionar convidados pra fechar o número.

**Fluxo 3 — Convidado**
Jogador cadastrado adiciona convidado (mini-perfil) → fica pendente → admin aprova → convidado entra no racha com nota neutra.

**Fluxo 3.1 — Oficialização do convidado**
Convidado (ou o jogador que o cadastrou) decide oficializar → convidado cria conta própria (email, senha, foto via câmera) → sistema vincula o `user_id` novo ao histórico de avaliações/estatísticas que ele acumulou como `Convidado` → perfil temporário é encerrado, dados são unificados no perfil oficial.

**Fluxo 4 — Pós-jogo**
Racha finalizado → cada jogador avalia companheiros de time + 1 do time adversário → sistema calcula MVP (mais avaliações/melhor nota) → estatísticas (gol, assistência, cartão) são registradas → tudo alimenta o ranking e os próximos algoritmos de balanceamento.

---

**Fluxo 5 — Recorrência automática**
Racha vinculado a um `Grupo` é marcado como `finalizado` (após estatísticas/avaliações registradas) → sistema automaticamente cria o próximo `Racha` daquele grupo (próxima ocorrência, mesmo local/tipo de campo/horário padrão) → convites de confirmação de presença são enviados automaticamente para todos os `membros_fixos` do grupo → o ciclo de confirmação da próxima semana já começa sem o admin precisar criar nada manualmente.

> O admin ainda pode ajustar a ocorrência gerada automaticamente (trocar data, adicionar/remover convidados extras) antes de fechar as confirmações.

**Pré-requisito:** o algoritmo só considera participantes com `confirmado = true` e convidados com `aprovado_pelo_admin = true`. Quem não confirmou presença não entra no cálculo dos times, mesmo que tenha sido convidado.

**Estágio 1 — Preencher posições**
- Formação definida pelo tipo de campo determina quantas vagas existem por posição.
- Prioriza alocar primeiro jogadores com apenas uma opção de posição (menos flexíveis), depois os versáteis (main ≠ usual) preenchem o que sobrar.

**Estágio 2 — Balancear por nota**
- Com as posições preenchidas dos dois lados, usa a média de avaliação (e talvez idade/peso como critério secundário) para decidir a distribuição final, buscando que os dois times fiquem com média de avaliação parecida.
- Jogadores novos/convidados entram com nota neutra (ex: média geral do sistema) até acumularem histórico.

---

## 6. Decisões já tomadas
- Vagas de linha são livres (sem sub-cota fixa por posição) — só o goleiro é obrigatório
- Backend: Firebase (sugestão do professor)

## 7. Próximos passos possíveis
- Preparar o prompt-resumo para colar no Claude Code