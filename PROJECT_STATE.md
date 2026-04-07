# PROJECT_STATE

## TRINIUM SPORTS
Estado atual do projeto.

## Backend confirmado pelo schema
### athletes
Campos confirmados para contexto do atleta:
- birth_date
- gender
- height_cm
- weight_kg
- experience_level
- resting_hr
- max_hr
- vo2_max
- garmin_connected
- fitness_level
- phase

### target_races
Campos confirmados:
- id
- athlete_id
- activity_type_id
- name
- race_date
- distance_meters
- elevation_gain_m
- priority
- status
- calculated_race_category_id

### segmentos de prova
A documentação mostra duas estruturas:
- target_race_segments
- race_segments

O frontend deve tentar target_race_segments primeiro e usar race_segments como fallback.

## Motor de geração
- path_b_generate_plan gera por uma prova por execução
- ainda não é calendar-aware
- próxima evolução estrutural: planejar o calendário completo

## Dashboard do treinador
### Implementado
- lista de atletas ativos
- visualização de treinos do atleta
- publicação de treinos
- resumo semanal
- resumo global
- distribuição por prova alvo × fase × atividade

### Corrigido nesta etapa
- contexto do atleta baseado exclusivamente em athletes
- calendário baseado em target_races.name e elevation_gain_m
- segmentos baseados em target_race_segments com fallback para race_segments
