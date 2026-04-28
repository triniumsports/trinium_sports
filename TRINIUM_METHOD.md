# TRINIUM_METHOD.md

## 1. Propósito do Método Trinium

O Método Trinium é a base técnica que sustenta a prescrição automatizada de treinos no ecossistema Trinium. Seu objetivo não é substituir o treinador, mas acelerar a construção de treinos coerentes, auditáveis e escaláveis, preservando o papel do profissional na validação final da prescrição.

O método foi desenhado para operar em cenários reais de atletas de endurance e multiesporte, incluindo calendários complexos, provas encavaladas, múltiplas modalidades e restrições de agenda. Em vez de depender de textos livres como núcleo da prescrição, o Trinium trabalha com regras parametrizadas, bibliotecas estruturadas e lógica de decisão separada entre:

1. prescrição no Método Trinium;
2. relatório de viabilidade;
3. validação e ajuste pelo treinador.

O princípio central é simples: o motor deve primeiro sugerir a **prescrição tecnicamente ideal**, e só depois o sistema deve comparar essa prescrição com a disponibilidade real do atleta. A eventual adaptação não deve distorcer silenciosamente a prescrição. Ela deve ser explícita, rastreável e supervisionada pelo treinador.

---

## 2. Princípios Centrais do Método

### 2.1 Especificidade

A prescrição deve respeitar a especificidade da prova-alvo. Quanto mais próxima a prova, maior deve ser o peso das sessões que reproduzem a demanda fisiológica, mecânica e técnica da modalidade principal.

Exemplos:
- provas de swimrun exigem corrida, natação em águas abertas e, idealmente, sessões específicas de swimrun;
- provas de trail exigem corrida em terreno variável, ganho altimétrico e tolerância mecânica específica;
- provas de águas abertas exigem exposição à especificidade da modalidade, e não apenas transferência integral da piscina.

### 2.2 Progressão de Carga

A carga deve evoluir de forma progressiva, respeitando fase, nível do atleta, composição da prova e tolerância esperada à fadiga. O Trinium não pressupõe crescimento linear infinito. Toda progressão deve conviver com períodos de estabilização, recuperação e transição.

### 2.3 Gestão de Fadiga e Risco

A prescrição não deve buscar apenas desempenho. Ela também deve respeitar limites operacionais de risco. Por isso, o método separa:
- necessidade ideal de treino;
- risco fisiológico da modalidade e distância;
- custo de fadiga acumulada;
- impacto competitivo da prova no calendário.

### 2.4 Redução de Carga Pré-Prova (Taper) e Recuperação

O método entende que provas diferentes geram impactos diferentes no planejamento. Nem toda prova pede uma redução de carga completa. Nem toda prova merece recuperação longa. A relação entre prioridade da prova, exigência fisiológica e posição no calendário define o papel competitivo daquele evento.

### 2.5 Compatibilidade Parcial entre Modalidades

Algumas modalidades oferecem transferência parcial de estímulo. Exemplo:
- corrida em trilha (trail running) pode cobrir parte da necessidade de corrida (running);
- natação em piscina (swimming) pode cobrir parte da necessidade de natação em águas abertas (open water swimming).

Essa equivalência não é total. O método reconhece coberturas parciais como apoio operacional, sem confundir compatibilidade com substituição integral da especificidade.

### 2.6 O Treinador como Autoridade Final

O Trinium não publica automaticamente a “verdade final” do treino. O sistema sugere, diagnostica e organiza. A validação final continua sendo do treinador, que pode:
- publicar a sugestão como está;
- editar a sessão;
- trocar por um item da própria biblioteca;
- rejeitar a prescrição automática.

---

## 3. Arquitetura Conceitual do Método

O método opera em três camadas complementares.

### 3.1 Prescrição no Método Trinium

A prescrição no Método Trinium é a proposta técnica sugerida pelo motor sem considerar, neste primeiro momento, a agenda do atleta. Ela nasce a partir de:
- perfil do atleta;
- prova-alvo;
- categoria da prova;
- fase do ciclo;
- matriz de risco;
- regras de sessão;
- biblioteca de modelos de treino (templates) e etapas estruturadas (steps).

A prescrição no Método Trinium deve responder à pergunta:

**“O que este atleta deveria treinar nesta semana, considerando a prova e o contexto fisiológico, se a agenda fosse ideal?”**

### 3.2 Relatório de Viabilidade

Depois da prescrição no Método Trinium, o sistema confronta a proposta com a agenda real do atleta. O relatório de viabilidade não altera a prescrição automaticamente. Ele apenas informa:
- o que cabe integralmente;
- o que cabe parcialmente;
- o que não cabe;
- a lacuna em sessões;
- a lacuna em horas totais;
- a lacuna por sessão;
- a natureza do conflito.

O relatório deve responder à pergunta:

**“Quanto da prescrição ideal é compatível com a disponibilidade atual do atleta?”**

### 3.3 Decisão do Treinador

A partir da prescrição no Método Trinium e do relatório de viabilidade, o treinador decide:
- manter;
- ajustar;
- substituir;
- reclassificar sessões;
- renegociar agenda com o atleta.

Esse desenho evita um erro comum em motores de treino: adaptar silenciosamente a prescrição até ela perder sentido esportivo.

---

## 4. Fases do Ciclo de Treinamento

O Método Trinium organiza a preparação em fases. Cada fase existe por um motivo fisiológico e operacional. O objetivo não é apenas distribuir treinos no calendário, mas construir desempenho de forma progressiva e controlada.

### 4.1 Base (base)

A fase de base tem como objetivo construir a fundação do ciclo. Nela, o foco principal costuma estar em:
- aumento gradual da capacidade aeróbica;
- consolidação de rotina de treino;
- desenvolvimento técnico;
- tolerância ao volume;
- preparação estrutural para cargas maiores no futuro.

Em termos práticos, a fase de base existe porque o atleta precisa criar suporte fisiológico e mecânico para suportar fases mais exigentes. Sem base adequada, fases mais intensas tendem a aumentar risco de fadiga excessiva, quebra de consistência e lesão.

### 4.2 Construção (build)

A fase de construção aprofunda o trabalho iniciado na base e começa a direcionar o treinamento para a prova-alvo. Nela, aumenta o peso de:
- estímulos específicos da modalidade;
- intensidade controlada;
- sessões-chave;
- combinação entre volume e qualidade;
- aproximação progressiva da exigência competitiva.

A fase de construção existe para transformar capacidade geral em desempenho mais específico. É nela que a preparação sai do “genérico” e se aproxima mais claramente da prova.

### 4.3 Pico (peak)

A fase de pico busca levar o atleta ao maior nível de prontidão específica do ciclo. Em geral, ela concentra:
- sessões muito direcionadas à prova;
- ajustes finos de intensidade;
- manutenção do que foi construído;
- controle mais rigoroso da fadiga.

A fase de pico existe porque desempenho não depende apenas de acumular treino, mas de chegar a um ponto alto de especificidade sem exceder a fadiga tolerável.

### 4.4 Redução de Carga Pré-Prova (taper)

A fase de redução de carga pré-prova tem como objetivo reduzir fadiga acumulada sem perder adaptação relevante. Nela, o sistema tende a reduzir:
- volume total;
- densidade de estímulos;
- custo de fadiga.

Ao mesmo tempo, mantém parte da ativação específica da modalidade.

A redução de carga existe porque chegar muito treinado, porém excessivamente fatigado, costuma prejudicar a prova. O objetivo não é “parar de treinar”, mas chegar mais fresco, preservando prontidão.

### 4.5 Semana de Prova (race)

A fase de prova organiza os dias finais ao redor do evento competitivo. Ela pode incluir:
- sessões leves de ativação;
- descanso estratégico;
- ajustes mínimos de carga;
- o próprio evento como sessão central da semana.

Essa fase existe para reconhecer que a competição não é apenas “mais um treino”, mas o ponto de convergência do bloco.

### 4.6 Recuperação Pós-Prova

Embora nem sempre apareça como fase isolada em todas as versões do ciclo, a recuperação pós-prova é parte essencial da lógica do método. O objetivo é:
- absorver o impacto do evento;
- reduzir fadiga residual;
- restaurar capacidade para o bloco seguinte;
- evitar transição imediata e inadequada para nova carga alta.

Em calendários complexos, essa recuperação pode ser completa, reduzida ou apenas parcial, dependendo do papel da prova no calendário.

---

## 5. Como o Motor Deve Pensar

### 5.1 O motor prescreve o ideal

A agenda do atleta não deve deformar a prescrição ideal. O motor deve primeiro montar a prescrição tecnicamente correta.

### 5.2 A agenda entra depois

A tabela de restrições semanais do atleta (`weekly_constraints`) deve ser usada no relatório de viabilidade, e não como filtro primário da prescrição ideal.

### 5.3 A publicação final é humana

A publicação final do treino deve passar pela validação do treinador. O motor gera rascunhos (`draft`, rascunho) e o treinador decide o que será publicado (`published`, publicado).

---

## 6. Hierarquia de Provas no Calendário

O Método Trinium não trata todas as provas como equivalentes. Cada evento precisa assumir um papel no calendário.

### 6.1 Prova A

É a prova principal do bloco. Recebe:
- pico principal;
- redução de carga principal;
- recuperação principal.

### 6.2 Prova B

É prova relevante, porém subordinada à A. Pode receber:
- mini redução de carga;
- ajuste de carga;
- recuperação curta;
- papel de ponto de verificação competitivo.

### 6.3 Prova C

É evento de treino. Pode:
- substituir treino-chave da semana;
- servir como estímulo especial;
- entrar no calendário sem gerar redução de carga completa nem reorientar o macro.

### 6.4 Regra de Governança

O atleta pode sugerir prioridade, mas o sistema deve:
- calcular prioridade técnica sugerida;
- detectar conflito entre provas;
- reclassificar quando necessário;
- deixar a decisão final com o treinador.

---

## 7. Calendários Encavalados

O método foi concebido para atletas que convivem com:
- provas preparatórias;
- provas de modalidades diferentes;
- blocos sobrepostos;
- calendário imperfeito.

Quando houver encavalamento, o sistema deve trabalhar com:
- prova dominante do bloco;
- provas satélite;
- eventos de treino;
- alerta de conflito de redução de carga e recuperação.

Nem toda prova marcada como “A” pelo atleta deve ser tratada como A dominante pelo sistema.

---

## 8. Biblioteca Estruturada do Treinador

O Trinium entende que escalabilidade para o treinador depende de reaproveitamento inteligente, e não de texto livre puro.

Por isso, o método prevê:
- modelos padrão do sistema (`workout_templates`, modelos de treino do sistema);
- biblioteca própria do treinador (`coach_workout_library`, biblioteca do treinador);
- etapas estruturadas do treino (`steps`, etapas do treino);
- treino prescrito individual do atleta.

Texto livre pode existir como observação, mas não como núcleo da sessão. O núcleo deve ser estruturado, reutilizável e compatível com exportação futura para relógios.

---

## 9. Tipos de Origem da Prescrição

A origem de uma sessão precisa ser rastreável.

### 9.1 `ai_engine` (motor automático)
Sessão gerada automaticamente pelo motor.

### 9.2 `coach_library` (biblioteca do treinador)
Sessão trazida da biblioteca do treinador.

### 9.3 `human` (ajuste humano/manual)
Sessão criada ou ajustada manualmente de forma direta.

Esse rastreamento é essencial para auditoria, evolução do método e análise futura de desempenho do motor.

---

## 10. Estados de Validação

O método separa estado operacional de execução e estado de validação profissional.

### 10.1 `status` (estado operacional)
Representa o estado operacional do treino para o atleta:
- `pending` (pendente)
- `completed` (concluído)
- `missed` (não realizado)
- `skipped` (pulado)

### 10.2 `validation_status` (estado de validação)
Representa o estado técnico de revisão:
- `draft` (rascunho)
- `pending` (pendente de revisão)
- `published` (publicado)
- `rejected` (rejeitado)

Essa separação é obrigatória para permitir:
- geração automática sem publicação automática;
- revisão do treinador;
- publicação controlada.

---

## 11. Parâmetros e Tabelas de Governança

O método foi desenhado para evitar lógica rígida no código. Sempre que possível, regras vivem em tabela.

Exemplos:
- matriz de risco;
- regras por dia da semana;
- metas de volume por fase;
- compatibilidade entre atividades;
- impacto fisiológico e papel competitivo das provas.

A intenção é que o método evolua por parametrização, e não por reescrita constante de código.

---

## 12. Natureza dos Parâmetros

Nem todo parâmetro do Trinium tem a mesma origem. Para manter honestidade técnica, o método assume três categorias:

### 12.1 Baseado em literatura
Quando houver referência formal identificável.

### 12.2 Consenso técnico
Quando a regra vier de consenso entre treinadores, fisiologistas, médicos do esporte e experiência prática consolidada.

### 12.3 Heurística Trinium
Quando a regra for uma decisão operacional própria do método, criada para viabilizar automação e ainda sujeita a refinamento.

O sistema não deve mascarar heurística como se fosse evidência de alto nível. Toda regra precisa ser classificável e auditável.

---

## 13. Limitações Assumidas

O Método Trinium não pretende:
- substituir julgamento clínico ou profissional;
- prometer individualização absoluta sem supervisão;
- tratar toda compatibilidade entre modalidades como equivalência total;
- resolver automaticamente todos os conflitos de calendário.

O método organiza a decisão. Ele não elimina a necessidade de validação profissional.

---

## 14. Governança e Evolução

Toda mudança futura no método deve responder:

1. qual parâmetro foi alterado;
2. por que foi alterado;
3. se a mudança veio de literatura, consenso técnico ou heurística;
4. a partir de quando a regra passou a valer;
5. qual impacto esperado no motor.

Essa governança é parte do produto, e não apenas da documentação.

---

## 15. Síntese do Método

O Método Trinium pode ser resumido assim:

- o motor prescreve o ideal;
- o sistema mede a viabilidade;
- o treinador decide;
- os parâmetros vivem em tabela;
- a evolução do método é documentada e auditável.

Esse desenho busca equilibrar:
- ciência;
- prática esportiva;
- escalabilidade;
- governança técnica;
- responsabilidade profissional.
