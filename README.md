# TRINIUM SPORTS

TRINIUM SPORTS é uma plataforma para conectar atletas e profissionais do esporte com foco em:
- marketplace de treinadores e nutricionistas
- vínculo atleta ↔ profissional
- geração automática de treinos
- revisão e publicação pelo treinador
- visualização pelo atleta
- gestão de carga e periodização

---

## Stack
- Backend: Supabase
- Frontend: Flutter Web
- Ambiente: GitHub Codespaces
- Repositório: GitHub

---

## Situação atual
### Já funcionando
- autenticação
- cadastro de atletas
- cadastro de profissionais
- marketplace de profissionais
- vínculo atleta ↔ treinador
- geração de treinos
- revisão/publicação de treinos
- visualização pelo atleta
- dashboard inicial do treinador

### Em evolução
- consolidação final do dashboard do treinador
- evolução do motor para calendar-aware
- edição avançada dos steps

---

## Fonte de verdade do backend

### Atleta
Tabela:
- `public.athletes`

Campos principais:
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

### Provas alvo
Tabela:
- `public.target_races`

Campos principais:
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

---

## Fluxo principal
1. atleta escolhe o treinador
2. treinador aceita o atleta
3. motor gera os treinos
4. treinador revisa
5. treinador publica
6. atleta visualiza o que foi publicado

---

## Documentos importantes de continuidade
- `PROJECT_STATE.md`
- `ROADMAP.md`
- `DECISIONS.md`
- `README.md`
- `BACKEND_SCHEMA_SNAPSHOT.md`
- `FRONTEND_STATE.md`
- `GENERATOR_ENGINE_NOTES.md`

Esses arquivos devem ser atualizados a cada etapa importante do projeto.
