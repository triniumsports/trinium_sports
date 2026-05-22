# PROJECT STATE — TRINIUM SPORTS

## Status atual
MVP redirecionado com sucesso do modelo centrado no motor para um modelo centrado em:
- marketplace de profissionais
- vínculo atleta ↔ profissional
- criação manual de treinos
- revisão/publicação
- agenda do atleta
- base preparada para sincronização futura com relógios

## Backend
Foram saneadas e/ou padronizadas as estruturas:
- coaches
- coach_athlete_relation
- prescribed_workouts
- prescribed_workout_steps
- v_professionals_marketplace
- v_athlete_professional_links
- v_prescribed_workouts_mvp

Também foram criados os campos mínimos para sincronização e retorno de execução:
- sync_status
- sync_provider
- external_workout_id
- execution_status
- executed_at
- actual_duration_sec
- actual_rpe
- completion_source
- workout_execution_logs
- funções auxiliares para marcar sync e registrar execução

## Frontend
Fluxo principal ajustado:
- home_router_screen.dart
- athlete_search_professionals_screen.dart
- coach_requests_screen.dart
- coach_athlete_workouts_review_screen.dart
- athlete_agenda_screen.dart
- athlete_profile_form_screen.dart
- professional_profile_form_screen.dart
- coach_workout_edit_screen.dart
- coach_create_workout_screen.dart

## Fluxo atual do MVP
1. atleta faz login
2. atleta completa perfil
3. atleta busca profissional no marketplace
4. atleta solicita vínculo
5. profissional aceita vínculo
6. profissional cria treino manual
7. profissional revisa/edita treino
8. profissional publica treino
9. atleta visualiza treino na agenda
10. atleta marca treino como concluído
11. base já está preparada para futura sincronização com relógio e ingestão do executado

## Situação do analyze
Projeto compilando com warnings antigos, sem erro bloqueante.
