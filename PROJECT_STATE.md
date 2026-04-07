# PROJECT_STATE

## Projeto
TRINIUM SPORTS

## Visão do produto
Plataforma para conectar atletas a treinadores e nutricionistas, com:
- marketplace de profissionais
- vínculo atleta ↔ profissional
- geração automática de treinos
- revisão e publicação pelo treinador
- visualização pelo atleta
- gestão de carga e periodização baseada em literatura

## Estado atual do sistema

### Backend
- Supabase como backend principal
- Auth funcionando
- tabelas centrais funcionando
- vínculo atleta ↔ coach funcionando
- geração de treinos funcionando
- publicação de treinos funcionando
- treinos publicados aparecem para o atleta

### Frontend
- fluxo de cadastro e login funcionando
- marketplace de profissionais funcionando
- atleta consegue selecionar treinador
- treinador consegue aceitar atleta
- treinador consegue gerar plano
- treinador consegue revisar e publicar treinos
- atleta consegue visualizar treinos publicados

## Estado atual do dashboard do treinador
### Implementado
- lista de atletas ativos
- prova alvo por atleta
- contagem de treinos pendentes/publicados
- tela de revisão de treinos por atleta
- resumo global de treinos
- resumo semanal
- distribuição por prova alvo × fase × atividade
- calendário de provas alvo

### Ponto ainda em ajuste
- contexto do atleta ainda precisa validar leitura real da tabela `athletes` no frontend
- calendário precisa consolidar segmentos multiesporte com máxima robustez
- o motor ainda não está calendar-aware

## Fonte de verdade do contexto do atleta
Tabela: `public.athletes`

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

## Fonte de verdade do calendário esportivo
Tabela: `public.target_races`

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

## Segmentação de provas multiesporte
Documentação mostra duas possibilidades:
- `target_race_segments`
- `race_segments`

O frontend deve:
1. tentar `target_race_segments`
2. se não houver retorno, usar `race_segments` como fallback

## Situação atual do motor
- o `path_b_generate_plan(...)` gera treinos com sucesso
- o motor atual gera plano por uma prova por execução
- ainda não considera o calendário completo do atleta como conjunto
- a lógica atual tende a concentrar mais carga em `build`, refletindo a parametrização atual do backend

## Próxima prioridade
1. validar 100% o contexto do atleta vindo de `athletes`
2. consolidar leitura dos segmentos de prova
3. evoluir o motor para planejamento calendar-aware
4. depois avançar para edição avançada dos steps
