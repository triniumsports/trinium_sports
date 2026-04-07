# BACKEND_SCHEMA_SNAPSHOT

## Snapshot funcional do backend confirmado na documentação

---

## 1. Tabela `public.athletes`
Campos confirmados:
- `id`
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

Uso no sistema:
- contexto global do atleta
- referência para dashboard do treinador
- base para interpretação da prescrição

---

## 2. Tabela `public.target_races`
Campos confirmados:
- `id`
- `athlete_id`
- `activity_type_id`
- `name`
- `race_date`
- `distance_meters`
- `elevation_gain_m`
- `priority`
- `status`
- `calculated_race_category_id`

Uso no sistema:
- calendário esportivo do atleta
- prova alvo principal
- classificação esportiva da prova
- priorização do planejamento

---

## 3. Segmentos de prova multiesporte
A documentação mostra duas estruturas possíveis:

### Opção A
`public.target_race_segments`
Campos esperados:
- `target_race_id`
- `activity_type_id`
- `distance_meters`
- `segment_order`

### Opção B
`public.race_segments`
Campos esperados:
- `target_race_id`
- `activity_type_id`
- `distance_meters`
- `segment_order`

Uso no sistema:
- detalhamento por atividade em provas multiesporte
- exemplo: swimrun com corrida + natação

---

## 4. Tabela `public.prescribed_workouts`
Uso no sistema:
- armazenar treinos gerados
- permitir revisão pelo treinador
- controlar publicação para o atleta

Fluxo:
- `pending` → revisão
- `published` → visível para o atleta

---

## 5. Função de geração
Função principal:
- `public.path_b_generate_plan(...)`

Estado atual:
- gera por uma prova por execução
- ainda não considera o calendário inteiro do atleta

---

## 6. Base de periodização
Tabela:
- `public.knowledge_base_periodization`

Uso:
- semanas recomendadas
- parâmetros de volume
- apoio à definição da lógica de fase

---

## 7. Observação estratégica
O frontend deve sempre refletir o backend documentado.
Evitar decisões por suposição quando o schema já estiver disponível.
