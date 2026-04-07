# TRINIUM SPORTS

TRINIUM SPORTS é uma plataforma para conectar atletas e profissionais do esporte, com foco em:
- marketplace de treinadores e nutricionistas
- gestão de vínculo atleta ↔ profissional
- geração automática de treinos
- revisão e publicação pelo treinador
- visualização pelo atleta
- gestão de carga e periodização

---

## Arquitetura
- **Backend:** Supabase
- **Frontend:** Flutter Web
- **Ambiente de desenvolvimento:** GitHub Codespaces
- **Repositório:** GitHub

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
- leitura consolidada do contexto do atleta
- leitura consolidada do calendário completo de provas
- motor calendar-aware
- edição avançada dos steps

---

## Fonte de verdade do backend
### Contexto do atleta
Tabela: `public.athletes`

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
Tabela: `public.target_races`

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

## Fluxo funcional do treino
1. atleta escolhe o treinador
2. treinador aceita o atleta
3. motor gera os treinos
4. treinador revisa o plano
5. treinador publica o treino
6. atleta visualiza os treinos publicados

---

## Direção do produto
O motor de geração deve evoluir para:
- considerar o calendário inteiro do atleta
- respeitar provas principais e secundárias
- balancear melhor carga por fase
- balancear melhor carga por atividade
- aumentar produtividade em assessorias esportivas

---

## Documentos importantes do repositório
- `PROJECT_STATE.md`
- `ROADMAP.md`
- `DECISIONS.md`
- `BACKEND_SCHEMA_SNAPSHOT.md`

Esses arquivos devem ser mantidos sempre atualizados para continuidade do projeto entre chats.
