# BACKEND_SCHEMA_SNAPSHOT

## Tabelas-chave confirmadas

### public.athletes
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

### public.target_races
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

### Segmentos de prova
Estruturas documentadas:
- `target_race_segments`
- `race_segments`

### public.prescribed_workouts
Uso:
- treinos gerados
- revisão do treinador
- publicação para o atleta

### Função principal do motor
- `public.path_b_generate_plan(...)`

Estado atual:
- gera por uma prova por execução
- ainda não é calendar-aware
