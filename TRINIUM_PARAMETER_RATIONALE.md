# TRINIUM_PARAMETER_RATIONALE.md

## 1. Objetivo do documento

Este documento registra o racional técnico dos parâmetros usados pelo Método Trinium. Seu papel é garantir que a prescrição automatizada não dependa de regras opacas ou escondidas no código, mas de parâmetros auditáveis, revisáveis e vinculados a tabelas específicas do banco de dados.

O Trinium parte do princípio de que um motor de prescrição precisa deixar claro:

- qual parâmetro está sendo usado;
- onde ele está armazenado;
- qual o significado operacional desse parâmetro;
- qual o racional técnico por trás do valor;
- se esse racional vem de literatura, consenso técnico ou heurística interna;
- quais pontos ainda precisam de validação futura.

Este documento não substitui a bibliografia científica nem a validação profissional. Ele organiza a governança técnica do método.

---

## 2. Classificação da origem dos parâmetros

Todo parâmetro do Trinium deve ser classificado em uma das três categorias abaixo.

### 2.1 Baseado em literatura
Usado quando existe uma referência bibliográfica ou documento técnico formal que sustenta diretamente o racional do parâmetro.

### 2.2 Consenso técnico
Usado quando o parâmetro decorre de consenso entre treinadores, fisiologistas, médicos do esporte, experiência aplicada ou prática consolidada, mas ainda sem referência bibliográfica formal explicitamente vinculada no sistema.

### 2.3 Heurística Trinium
Usado quando o parâmetro é uma decisão operacional própria do método, criada para viabilizar automação, escalabilidade ou governança do produto, e ainda sujeita a refinamento futuro.

---

## 3. Regras de governança

### 3.1 Parâmetro não vive no código
Sempre que possível, o parâmetro deve existir em tabela, e não codificado diretamente na lógica do motor.

### 3.2 Todo parâmetro relevante deve ser documentado
Parâmetros que influenciam:
- volume
- frequência
- intensidade
- taper
- recuperação
- conflito entre provas
- equivalência entre modalidades
- risco

devem constar neste documento.

### 3.3 Toda mudança deve ser rastreável
Toda alteração relevante deve responder:
- o que mudou;
- por que mudou;
- qual a nova lógica;
- se houve nova referência ou validação profissional;
- a partir de quando a mudança passou a valer.

---

## 4. Blocos principais de parâmetros do Método Trinium

---

## 4.1 Periodização geral do ciclo

### Finalidade
Definir o tamanho do bloco de preparação, a fase do ciclo e a distribuição geral de carga até a prova-alvo.

### Tabelas envolvidas
- `knowledge_base_periodization`
- `phase_volume_targets`

### Parâmetros principais
- semanas recomendadas por categoria de prova
- volume semanal mínimo
- volume semanal ótimo
- multiplicadores por fase do ciclo

### Racional técnico
A periodização organiza a preparação em blocos com objetivos diferentes. A intenção não é apenas distribuir treino no tempo, mas modular adaptação, fadiga e prontidão competitiva.

### Status atual
**Consenso técnico / heurística Trinium**, até formalização bibliográfica completa.

### Observações
Esse bloco é central para a coerência do motor. Qualquer mudança aqui afeta:
- duração do ciclo
- peso relativo das fases
- teto esperado de carga semanal

---

## 4.2 Fases do ciclo

### Finalidade
Definir o papel fisiológico e operacional de cada fase:
- base (`base`)
- construção (`build`)
- pico (`peak`)
- redução de carga pré-prova (`taper`)
- semana de prova (`race`)

### Tabelas envolvidas
- `knowledge_base_periodization`
- `phase_volume_targets`
- `session_rules`

### Parâmetros principais
- nome da fase
- fator de volume por fase
- padrão esperado de foco por dia
- intervalo de duração e RPE por fase

### Racional técnico
Cada fase existe por um motivo:
- **base**: construir fundação aeróbica, técnica e tolerância à carga;
- **construção**: aumentar especificidade e qualidade;
- **pico**: maximizar prontidão específica;
- **redução de carga pré-prova**: reduzir fadiga sem perder adaptação;
- **prova**: organizar a semana em torno do evento competitivo.

### Status atual
**Consenso técnico**, com parte da distribuição operacional ainda em **heurística Trinium**.

---

## 4.3 Matriz de risco por modalidade e distância

### Finalidade
Controlar risco fisiológico e teto prudente de carga por modalidade e faixa de distância.

### Tabela envolvida
- `knowledge_base_risk_matrix`

### Parâmetros principais
- `risk_class`
- `ideal_peak_hours_week`
- `mvp_safety_factor`
- faixa de distância por atividade

### Racional técnico
Nem toda modalidade e distância suportam o mesmo pico de carga. Esse bloco existe para impedir que o motor extrapole de forma perigosa o volume ou a duração das sessões.

### Status atual
**Consenso técnico / heurística Trinium**, até documentação bibliográfica detalhada.

### Observações
Esse bloco deve ser revisto com literatura de:
- gestão de carga;
- risco de lesão;
- taper;
- resposta à fadiga por modalidade.

---

## 4.4 Necessidade semanal por atividade

### Finalidade
Definir quantas sessões e quantas horas por atividade devem existir em determinada semana, considerando categoria da prova, fase e nível do atleta.

### Tabela envolvida
- `knowledge_base_activity_requirements`

### Parâmetros principais
- `weekly_sessions_optimal`
- `weekly_hours_optimal`
- `priority_weight`
- `is_key_activity`

### Racional técnico
A prova-alvo precisa ser decomposta em necessidades operacionais semanais. Esse bloco é o que transforma o objetivo competitivo em demanda concreta de treinamento.

### Status atual
**Consenso técnico**, com parte dos pesos e equivalências ainda em **heurística Trinium**.

### Observações
Esse é um dos blocos mais sensíveis do motor. Ele define o que a semana precisa entregar antes da análise de viabilidade da agenda.

---

## 4.5 Regras por dia da semana

### Finalidade
Definir o papel esperado de cada dia da semana em cada fase do ciclo.

### Tabela envolvida
- `session_rules`

### Parâmetros principais
- `day_of_week`
- `activity_type_id`
- `focus_pillar`
- `time_min_sec`
- `time_max_sec`
- `rpe_min`
- `rpe_max`

### Racional técnico
O sistema precisa ter uma lógica semanal coerente para distribuir técnica, endurance, força, recuperação e descanso. Essas regras não devem depender de improviso do código.

### Status atual
**Heurística Trinium com base em consenso técnico.**

### Observações
A tabela `session_rules` foi corrigida para cobrir de forma consistente os dias `1..7`, o que era essencial para alinhar a lógica do motor à agenda do atleta.

---

## 4.6 Compatibilidade entre modalidades

### Finalidade
Representar transferências parciais entre modalidades compatíveis.

### Tabela envolvida
- `activity_compatibility_map`

### Parâmetros principais
- atividade ideal
- atividade disponível compatível
- tipo de compatibilidade
- fator de cobertura (`coverage_factor`)

### Exemplos atuais
- `running` <- `trail_running`
- `open_water_swimming` <- `swimming`

### Racional técnico
Em cenários reais, nem sempre o atleta terá a modalidade exata disponível na agenda. Algumas modalidades cobrem parcialmente a necessidade de outra, mas sem substituição total da especificidade.

### Status atual
**Heurística Trinium**, a validar progressivamente com profissionais.

### Observações
Esse bloco é essencial para o relatório de viabilidade e para a futura prescrição adaptada.

---

## 4.7 Viabilidade da agenda do atleta

### Finalidade
Comparar a prescrição ideal com a disponibilidade real do atleta, sem deformar silenciosamente a lógica do motor.

### Tabelas envolvidas
- `weekly_constraints`
- `coach_feasibility_reports`
- `activity_compatibility_map`

### Parâmetros principais
- quantidade de slots disponíveis
- horas totais disponíveis
- duração máxima por slot
- cobertura efetiva por compatibilidade
- lacuna em sessões
- lacuna em horas
- lacuna por sessão

### Racional técnico
A agenda do atleta não deve redefinir automaticamente a prescrição ideal. Ela deve ser usada como camada diagnóstica para orientar o treinador.

### Status atual
**Heurística Trinium operacionalmente validada**, com forte valor prático para o fluxo do treinador.

---

## 4.8 Impacto fisiológico e papel da prova no calendário

### Finalidade
Representar o impacto competitivo e fisiológico de cada prova, evitando que o motor trate todas as provas como equivalentes.

### Tabela envolvida
- `knowledge_base_race_impact_profiles`

### Parâmetros principais
- `physiological_impact_score`
- `fatigue_cost_score`
- `calendar_disruption_score`
- `default_taper_days`
- `default_recovery_days`
- `conflict_window_days`
- `can_be_primary`
- `can_be_secondary`
- `can_be_training_event`
- `multi_a_allowed`

### Racional técnico
Nem toda prova merece taper completo, recuperação longa ou status de prova principal. Esse bloco existe para organizar:
- provas A, B e C;
- eventos de preparação;
- conflitos entre provas;
- calendários encavalados.

### Status atual
**Heurística Trinium estruturada para futura validação técnica.**

---

## 4.9 Hierarquia de provas A/B/C

### Finalidade
Evitar que todas as provas declaradas pelo atleta sejam tratadas automaticamente como provas principais.

### Tabelas envolvidas
- `target_races`
- `knowledge_base_race_impact_profiles`

### Parâmetros principais
- prioridade declarada pelo atleta
- prioridade técnica sugerida pelo sistema
- prioridade final do treinador
- papel da prova no bloco

### Racional técnico
Em calendários reais, o atleta pode marcar várias provas como “A”, mas nem todas podem receber pico, taper e recuperação completos. O método precisa reclassificar tecnicamente os eventos quando houver conflito.

### Status atual
**Consenso técnico / heurística Trinium.**

---

## 4.10 Biblioteca estruturada do treinador

### Finalidade
Permitir escalabilidade e padronização sem depender de texto livre.

### Tabelas envolvidas
- `coach_workout_library`
- `coach_workout_library_steps`

### Parâmetros principais
- atividade
- foco
- duração padrão
- RPE padrão
- steps estruturados
- tags
- favorito / ativo

### Racional técnico
Treinadores precisam editar, reutilizar e publicar sessões com velocidade. O sistema deve preservar estrutura compatível com relógio e permitir reaproveitamento inteligente.

### Status atual
**Decisão de produto baseada em governança técnica.**

---

## 5. Estrutura recomendada para futura rastreabilidade bibliográfica

O Trinium deve evoluir para uma tabela específica de referências, associando parâmetros e campos do banco a sua origem técnica.

### Tabela sugerida
- `knowledge_base_parameter_references`

### Campos sugeridos
- `table_name`
- `column_name`
- `parameter_key`
- `reference_title`
- `reference_authors`
- `reference_year`
- `reference_type`
- `evidence_level`
- `rationale_summary`
- `status`
- `notes`
- `is_active`

### Status possíveis
- `literature_based`
- `expert_consensus`
- `trinium_heuristic`

---

## 6. Regras de manutenção deste documento

Sempre que um parâmetro relevante for alterado, este documento deve ser atualizado.

Mudanças mínimas a registrar:
- tabela e coluna afetadas;
- valor antigo e novo;
- motivo da mudança;
- origem da revisão;
- impacto esperado no método.

---

## 7. Síntese

O Método Trinium não deve depender de regras escondidas no código. Seus parâmetros precisam ser:
- auditáveis;
- explicáveis;
- revisáveis;
- classificáveis por origem;
- compatíveis com governança técnica.

Este documento existe para garantir que a automação da prescrição continue:
- tecnicamente defensável;
- evolutiva;
- e profissionalmente apresentável aos treinadores.
