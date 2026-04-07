# DECISIONS

## Decisões estruturais do projeto

### 1. Fonte oficial do contexto do atleta
A tabela oficial para o contexto do atleta no dashboard é:
- `public.athletes`

Campos confirmados como relevantes:
- `birth_date`
- `gender`
- `height_cm`
- `weight_kg`
- `experience_level`
- `resting_hr`
- `max_hr`
- `vo2_max`
- `garmin_connected`
- `fitness_level`
- `phase`

---

### 2. Fonte oficial do calendário de provas
A tabela oficial do calendário esportivo é:
- `public.target_races`

Campos confirmados:
- `name`
- `race_date`
- `distance_meters`
- `elevation_gain_m`
- `priority`
- `status`
- `activity_type_id`
- `calculated_race_category_id`

---

### 3. Provas multiesporte
Para distâncias por atividade, o frontend deve:
1. tentar `target_race_segments`
2. usar `race_segments` como fallback

---

### 4. Publicação de treinos
Fluxo oficial:
1. motor gera
2. treinador revisa
3. treinador publica
4. atleta visualiza apenas o que foi publicado

---

### 5. Papel do motor
O motor é peça central do produto e deve:
- aumentar produtividade de treinadores com muitos atletas
- respeitar tempo, nível e contexto do atleta
- reduzir pontos cegos na periodização
- servir como agente de apoio à decisão, não substituto cego do treinador

---

### 6. Limitação atual do motor
O motor atual gera por uma prova por execução.
Ele ainda não é calendar-aware.

---

### 7. Prioridade estratégica
Antes de sofisticar edição de steps, o foco deve ser:
1. consolidar dashboard do treinador
2. evoluir o motor para considerar o calendário inteiro
3. depois aprofundar a edição fina dos treinos
