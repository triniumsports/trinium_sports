# PROJECT STATE — TRINIUM SPORTS

## Status atual
O MVP evoluiu de um app de marketplace + treino para uma plataforma colaborativa de acompanhamento esportivo com visão 360° do atleta.

Hoje o produto já cobre:
- marketplace de profissionais
- vínculo atleta ↔ profissional
- múltiplos profissionais ativos por atleta
- criação manual de treinos de endurance
- criação manual de treinos de força
- publicação e visualização de treinos no app
- base preparada para nutrição, fisioterapia e médico
- base preparada para futura sincronização com relógios

## Backend
Foram estruturados e/ou ajustados:
- `profiles`
- `athletes`
- `coaches`
- `coach_athlete_relation`
- `prescribed_workouts`
- `prescribed_workout_steps`
- `prescribed_strength_exercises`
- `strength_muscle_groups`
- `strength_equipment_types`
- `strength_exercises_catalog`

## Novas estruturas da camada 360°
Foram modeladas para suportar visão clínica e compartilhada do atleta:
- `athlete_injuries_restrictions`
- `athlete_medical_documents`
- `athlete_document_access`
- `athlete_document_access_logs`

## Views principais
- `v_professionals_marketplace`
- `v_athlete_professional_links`
- `v_professional_active_athletes`
- `v_athlete_active_professionals`
- `v_athlete_care_team`
- `v_athlete_global_summary`
- `v_prescribed_workouts_mvp`
- `v_strength_exercises_catalog`
- `v_prescribed_strength_exercises`

## Regras já estabilizadas
- múltiplos profissionais podem estar ativos para o mesmo atleta
- o sistema evita duplicidade do mesmo profissional com o mesmo atleta
- treinos de endurance usam `prescribed_workout_steps`
- treinos de força usam `prescribed_strength_exercises`
- o atleta já consegue visualizar treinos publicados dos dois tipos
- o builder de força já usa catálogo com filtro por grupo muscular e equipamento
- o ecossistema agora inclui médico como papel previsto na arquitetura

## Frontend
Fluxo principal ajustado:
- `home_router_screen.dart`
- `athlete_search_professionals_screen.dart`
- `coach_requests_screen.dart`
- `coach_create_workout_screen.dart`
- `coach_workout_edit_screen.dart`
- `coach_athlete_workouts_review_screen.dart`
- `athlete_agenda_screen.dart`
- `athlete_approved_workouts_screen.dart`
- `athlete_profile_form_screen.dart`
- `professional_profile_form_screen.dart`

## Fluxo atual do MVP
1. atleta faz login
2. atleta completa perfil
3. atleta busca profissionais no marketplace
4. atleta solicita vínculo
5. profissional aceita vínculo
6. profissional cria treino manual
7. profissional publica treino
8. atleta visualiza treinos publicados
9. atleta acompanha agenda
10. treinos de endurance e força já aparecem de forma adequada no app

## Nova direção do produto
O Trinium passa a se posicionar como plataforma colaborativa de performance, saúde e prevenção, conectando:
- treinadores
- preparadores físicos
- nutricionistas
- fisioterapeutas
- médicos

## Situação do analyze
Projeto compilando sem erro bloqueante, com warnings antigos ainda pendentes de limpeza.
