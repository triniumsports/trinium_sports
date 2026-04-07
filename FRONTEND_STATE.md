# FRONTEND_STATE

## Projeto
TRINIUM SPORTS - Frontend Flutter Web

## Estado atual do frontend

### Fluxos já funcionando
- autenticação
- cadastro de atleta
- cadastro de profissional
- marketplace de profissionais
- seleção de treinador pelo atleta
- aceite do atleta pelo treinador
- geração de plano
- revisão de treinos
- publicação de treinos
- visualização dos treinos publicados pelo atleta

---

## Dashboard do treinador

### Implementado
- lista de atletas ativos
- contagem de treinos pendentes/publicados
- visualização de treinos por atleta
- calendário de provas alvo
- resumo global de treinos
- resumo semanal
- distribuição por prova alvo × fase × atividade

### Fonte de verdade do contexto do atleta
Tabela:
- `public.athletes`

Campos confirmados:
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

### Fonte de verdade do calendário esportivo
Tabela:
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

### Segmentos de prova
Tabelas possíveis:
- `target_race_segments`
- `race_segments`

Regra de frontend:
1. tentar `target_race_segments`
2. usar `race_segments` como fallback

---

## Ajustes pendentes no frontend
- melhorar storytelling visual do dashboard
- melhorar a visualização da linha do tempo de provas
- melhorar a visualização da carga por prova alvo
- melhorar a apresentação de distribuição por atividade
- depois disso, evoluir para edição avançada dos steps

---

## Observação importante
O frontend deve sempre refletir o backend documentado.
Não tomar decisão por suposição quando houver schema confirmado no repositório.
