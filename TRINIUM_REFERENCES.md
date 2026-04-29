# TRINIUM_REFERENCES.md

## 1. Objetivo deste documento

Este documento organiza a base bibliográfica e técnico-conceitual que sustenta o Método Trinium. Seu papel é dar rastreabilidade às decisões de modelagem usadas na prescrição automatizada, deixando claro:

- quais temas têm lastro bibliográfico mais direto;
- quais temas hoje dependem mais de consenso técnico;
- quais temas ainda são tratados como heurística Trinium;
- quais referências devem ser priorizadas para validação futura com profissionais.

Este documento não afirma que todo parâmetro do sistema já está validado por literatura formal. Seu objetivo é organizar a trilha de validação do método.

---

## 2. Como este documento deve ser usado

Cada referência listada aqui deve servir a pelo menos um destes objetivos:

1. sustentar uma decisão de modelagem do Método Trinium;
2. orientar revisão de parâmetros em tabela;
3. servir de base para discussão com treinadores e profissionais de saúde;
4. apoiar a evolução da tabela `knowledge_base_parameter_references`.

Sempre que possível, cada referência deve ser relacionada a:
- um bloco do método;
- uma ou mais tabelas do banco;
- um racional técnico específico.

---

## 3. Classificação das referências

### 3.1 Referência central
Referência com forte impacto sobre a lógica principal do método.

### 3.2 Referência complementar
Referência útil para aprofundar ou ajustar parâmetros específicos.

### 3.3 Referência de validação futura
Referência ainda não vinculada a parâmetro específico, mas importante para revisão posterior.

---

## 4. Blocos bibliográficos prioritários

Os temas abaixo são os mais relevantes para o Método Trinium neste momento:

1. periodização do treinamento;
2. fases do ciclo;
3. redução de carga pré-prova;
4. recuperação pós-prova;
5. gestão de carga e fadiga;
6. risco e prevenção de lesão;
7. especificidade e transferência entre modalidades;
8. governança de calendário competitivo;
9. múltiplas provas no mesmo ciclo;
10. treinamento de endurance e multiesporte.

---

## 5. Estrutura recomendada para registrar referências

Cada referência adicionada neste documento deve seguir, sempre que possível, este formato:

### Título
### Autores
### Ano
### Tipo de material
- artigo científico
- livro
- consenso
- revisão
- guideline
- capítulo
- posicionamento oficial

### Tema principal
### Aplicação no Método Trinium
### Tabelas potencialmente impactadas
### Status atual no método
- baseado em literatura
- consenso técnico
- heurística Trinium
- validação futura

---

## 6. Referências-base iniciais por tema

> Importante: esta seção organiza os temas prioritários e o tipo de referência que o projeto precisa consolidar. Ela pode começar incompleta e ser enriquecida progressivamente.

---

## 6.1 Periodização do treinamento

### Tema principal
Como organizar a progressão do treinamento ao longo do tempo, distribuindo carga, especificidade e recuperação de forma coerente.

### Aplicação no Método Trinium
Base para:
- `knowledge_base_periodization`
- `phase_volume_targets`
- distribuição das fases do ciclo
- lógica de progressão do bloco dominante

### Perguntas que essa bibliografia precisa responder
- como estruturar ciclos de treinamento de endurance;
- como modular volume e intensidade por fase;
- como adaptar periodização para modalidades diferentes;
- como conviver com calendário competitivo real.

### Status atual no método
Consenso técnico com necessidade de fortalecimento bibliográfico.

---

## 6.2 Fases do ciclo

### Tema principal
Função fisiológica e operacional das fases:
- base;
- construção;
- pico;
- redução de carga pré-prova;
- prova;
- recuperação.

### Aplicação no Método Trinium
Base para:
- definição de fase em `knowledge_base_periodization`;
- multiplicadores em `phase_volume_targets`;
- comportamento semanal em `session_rules`.

### Perguntas que essa bibliografia precisa responder
- por que a fase de base existe;
- quando a construção deve aumentar especificidade;
- qual o papel do pico;
- como modular a redução de carga;
- como tratar recuperação após eventos com impactos distintos.

### Status atual no método
Consenso técnico com documentação conceitual já escrita, mas precisando de ligação formal com referências.

---

## 6.3 Redução de carga pré-prova

### Tema principal
Como reduzir carga antes da prova preservando adaptação e melhorando prontidão.

### Aplicação no Método Trinium
Base para:
- `knowledge_base_race_impact_profiles.default_taper_days`
- multiplicadores de fase
- lógica de prova A, B e C
- governança de prova dominante no bloco

### Perguntas que essa bibliografia precisa responder
- quantos dias de redução de carga são razoáveis por tipo de prova;
- como a redução varia por distância e modalidade;
- quando uma prova secundária merece mini redução de carga;
- quando uma prova C não deve gerar redução de carga real.

### Status atual no método
Heurística Trinium estruturada para futura validação.

---

## 6.4 Recuperação pós-prova

### Tema principal
Quanto de recuperação uma prova exige e como isso afeta o bloco seguinte.

### Aplicação no Método Trinium
Base para:
- `knowledge_base_race_impact_profiles.default_recovery_days`
- lógica de provas encavaladas
- conflito entre provas A/B/C
- bloqueios operacionais após eventos maiores

### Perguntas que essa bibliografia precisa responder
- quanto tempo de recuperação é razoável após provas curtas, médias e longas;
- quando a recuperação pode ser curta;
- quando o evento compromete a progressão do bloco;
- como o custo fisiológico muda com modalidade e distância.

### Status atual no método
Heurística Trinium com forte necessidade de validação técnica formal.

---

## 6.5 Gestão de carga e fadiga

### Tema principal
Relação entre carga de treino, adaptação, desempenho e fadiga acumulada.

### Aplicação no Método Trinium
Base para:
- `knowledge_base_risk_matrix`
- `knowledge_base_activity_requirements`
- `phase_volume_targets`
- `knowledge_base_race_impact_profiles`

### Perguntas que essa bibliografia precisa responder
- como calibrar carga semanal;
- como evitar extrapolação de volume;
- como distribuir sessões por atividade;
- como relacionar carga e risco.

### Status atual no método
Consenso técnico com necessidade de apoio bibliográfico progressivo.

---

## 6.6 Risco e prevenção de lesão

### Tema principal
Como o risco muda conforme modalidade, volume, frequência, intensidade e histórico de carga.

### Aplicação no Método Trinium
Base para:
- `knowledge_base_risk_matrix.risk_class`
- `ideal_peak_hours_week`
- `mvp_safety_factor`

### Perguntas que essa bibliografia precisa responder
- como calibrar risco por modalidade;
- como lidar com volume elevado;
- como usar fatores de segurança;
- como evitar que o motor extrapole a tolerância provável do atleta.

### Status atual no método
Consenso técnico, com necessidade de bibliografia voltada a endurance e gestão de carga.

---

## 6.7 Especificidade e transferência entre modalidades

### Tema principal
O que pode e o que não pode ser tratado como transferência parcial de estímulo entre modalidades diferentes.

### Aplicação no Método Trinium
Base para:
- `activity_compatibility_map`
- relatório de viabilidade
- eventual futura prescrição adaptada

### Exemplos relevantes no método
- `trail_running` cobrindo parcialmente `running`
- `swimming` cobrindo parcialmente `open_water_swimming`

### Perguntas que essa bibliografia precisa responder
- quando a transferência entre modalidades é aceitável;
- quando ela é parcial;
- quando ela não pode substituir a especificidade;
- como comunicar isso ao treinador sem falsa equivalência.

### Status atual no método
Heurística Trinium com necessidade de validação progressiva por profissionais.

---

## 6.8 Calendário competitivo e múltiplas provas

### Tema principal
Como tratar calendário com provas encavaladas, provas preparatórias e múltiplos objetivos no mesmo ciclo.

### Aplicação no Método Trinium
Base para:
- classificação A/B/C
- `knowledge_base_race_impact_profiles`
- governança de conflitos entre provas
- definição da prova dominante do bloco

### Perguntas que essa bibliografia precisa responder
- quando duas provas podem coexistir como principais;
- quando uma deve ser rebaixada para B;
- quando uma deve funcionar como treino C;
- como diferentes modalidades convivem no mesmo calendário.

### Status atual no método
Principalmente heurística Trinium com base em racional técnico e experiência prática.

---

## 7. Estrutura sugerida para preenchimento progressivo

Sempre que uma referência real for adicionada, usar o seguinte modelo:

### Referência
[Título completo]

### Autores
[Autores]

### Ano
[Ano]

### Tipo de material
[Artigo, revisão, guideline, consenso, livro, capítulo]

### Tema principal
[Ex.: periodização, taper, recuperação, carga, risco]

### Aplicação no Método Trinium
[Descrever onde essa referência impacta o método]

### Tabelas impactadas
- `nome_da_tabela`
- `outra_tabela`

### Status atual
[baseado em literatura / consenso técnico / validação futura]

### Observações
[Notas adicionais]

---

## 8. Regras para expansão deste documento

### 8.1 Não adicionar referência sem contexto
Toda referência deve estar associada a um tema e a uma aplicação no método.

### 8.2 Não usar bibliografia apenas como ornamentação
A referência precisa ajudar a:
- explicar um parâmetro;
- revisar uma regra;
- defender uma decisão de modelagem;
- ou registrar uma limitação conhecida.

### 8.3 Distinguir claramente literatura de heurística
Quando não houver base direta suficiente, isso deve ser assumido de forma transparente.

---

## 9. Ligação com a tabela do banco

Este documento deve evoluir em paralelo à tabela:

- `knowledge_base_parameter_references`

A ideia é que, progressivamente, cada bloco aqui documentado possa ser vinculado a:
- tabela;
- coluna;
- parâmetro;
- racional resumido;
- referência bibliográfica;
- tipo de evidência;
- status.

---

## 10. Síntese

O Método Trinium precisa ser defensável não apenas como software, mas como sistema técnico de apoio à prescrição. Para isso, a bibliografia não pode existir apenas como lista solta: ela precisa estar conectada ao método, aos parâmetros e à governança de evolução do produto.

Este documento é o ponto de partida para essa trilha de validação.

---

## 11. Primeira bibliografia real priorizada

### Referência 1
**Título:** Effects of tapering on performance: a meta-analysis  
**Autores:** Bosquet L, Montpetit J, Arvisais D, Mujika I  
**Ano:** 2007  
**Tipo de material:** Meta-análise  
**Tema principal:** Redução de carga pré-prova  
**Aplicação no Método Trinium:**  
Base importante para justificar parâmetros de redução de carga pré-prova, especialmente duração do taper e redução progressiva de volume em atletas de endurance.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_race_impact_profiles`  
- `phase_volume_targets`  
- `knowledge_base_periodization`  
**Status atual no método:** baseado em literatura  
**Observações:** A meta-análise encontrou melhor efeito com aproximadamente duas semanas de taper e redução de volume na faixa de 41% a 60%, com manutenção relativa de intensidade e frequência.

---

### Referência 2
**Título:** Intense training: the key to optimal performance before and during the taper  
**Autores:** Mujika I  
**Ano:** 2010  
**Tipo de material:** Revisão / artigo conceitual  
**Tema principal:** Redução de carga pré-prova e manutenção de intensidade  
**Aplicação no Método Trinium:**  
Ajuda a sustentar a lógica de que o taper não significa “parar de treinar”, mas reduzir fadiga preservando estímulos relevantes para a competição.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_race_impact_profiles`  
- `phase_volume_targets`  
- `session_rules`  
**Status atual no método:** baseado em literatura  
**Observações:** Reforça a ideia de redução de carga com preservação de prontidão competitiva.

---

### Referência 3
**Título:** New horizons for the methodology and physiology of training periodization  
**Autores:** Issurin VB  
**Ano:** 2010  
**Tipo de material:** Revisão  
**Tema principal:** Periodização e organização por blocos  
**Aplicação no Método Trinium:**  
Base importante para sustentar a organização do ciclo em fases e a ideia de blocos dominantes no calendário.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_periodization`  
- `phase_volume_targets`  
- `knowledge_base_race_impact_profiles`  
**Status atual no método:** baseado em literatura  
**Observações:** Útil para justificar a lógica de organização do ciclo e a separação entre blocos com objetivos diferentes.

---

### Referência 4
**Título:** Biological Background of Block Periodized Endurance Training: A Review  
**Autores:** Issurin VB  
**Ano:** 2019  
**Tipo de material:** Revisão  
**Tema principal:** Periodização em endurance  
**Aplicação no Método Trinium:**  
Apoia a lógica de blocos e a necessidade de estruturar objetivos fisiológicos específicos ao longo do ciclo.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_periodization`  
- `phase_volume_targets`  
- `knowledge_base_activity_requirements`  
**Status atual no método:** baseado em literatura  
**Observações:** Especialmente útil para sustentar a coerência do método em esportes de endurance.

---

### Referência 5
**Título:** Monitoring Athlete Training Loads: Consensus Statement  
**Autores:** Bourdon PC et al.  
**Ano:** 2017  
**Tipo de material:** Consenso  
**Tema principal:** Monitoramento de carga  
**Aplicação no Método Trinium:**  
Base importante para justificar o uso de parâmetros de carga, necessidade de monitoramento e relação entre prescrição, fadiga e ajuste operacional.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_risk_matrix`  
- `knowledge_base_activity_requirements`  
- `coach_feasibility_reports`  
**Status atual no método:** baseado em literatura  
**Observações:** Útil para justificar por que o sistema separa prescrição ideal, viabilidade e revisão do treinador.

---

### Referência 6
**Título:** How much is too much? (Part 1) International Olympic Committee consensus statement on load in sport and risk of injury  
**Autores:** Soligard T et al.  
**Ano:** 2016  
**Tipo de material:** Consenso  
**Tema principal:** Carga e risco de lesão  
**Aplicação no Método Trinium:**  
Base central para sustentar fatores de segurança, governança de carga e preocupação com risco em função da exposição esportiva.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_risk_matrix`  
- `knowledge_base_race_impact_profiles`  
- `knowledge_base_activity_requirements`  
**Status atual no método:** baseado em literatura  
**Observações:** Muito útil para a defesa técnica da necessidade de modular carga e risco no motor.

---

### Referência 7
**Título:** How much is too much? (Part 2) International Olympic Committee consensus statement on load in sport and risk of illness  
**Autores:** Schwellnus M et al.  
**Ano:** 2016  
**Tipo de material:** Consenso  
**Tema principal:** Carga, fadiga e risco sistêmico  
**Aplicação no Método Trinium:**  
Complementa a base de risco, especialmente para suportar o racional de fadiga acumulada e custo competitivo das provas no calendário.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_risk_matrix`  
- `knowledge_base_race_impact_profiles`  
**Status atual no método:** baseado em literatura  
**Observações:** Útil para discutir o custo fisiológico e a disrupção do calendário competitivo.

---

### Referência 8
**Título:** Training principles and issues for ultra-endurance athletes  
**Autores:** Zaryski C, Smith DJ  
**Ano:** 2005  
**Tipo de material:** Revisão  
**Tema principal:** Especificidade, tolerância estrutural e endurance prolongado  
**Aplicação no Método Trinium:**  
Ajuda a sustentar a importância da especificidade, da tolerância à carga repetitiva e da individualização em esportes de endurance prolongado.  
**Tabelas potencialmente impactadas:**  
- `knowledge_base_periodization`  
- `knowledge_base_activity_requirements`  
- `knowledge_base_risk_matrix`  
**Status atual no método:** baseado em literatura  
**Observações:** Especialmente útil para categorias mais longas, como ultra trail e provas longas de endurance.
