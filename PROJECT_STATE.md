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
- provas alvo
- disponibilidade semanal estruturada
- feedback do atleta ao concluir treino
- restrições / lesões
- exames e documentos
- dashboard planned vs executed
- carga por modalidade
- carga muscular estimada
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
- `target_races`
- `weekly_constraints`
- `athlete_injuries_restrictions`
- `athlete_medical_documents`
- `athlete_document_access`
- `athlete_document_access_logs`
- `modality_muscle_load_map`

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
- `v_athlete_training_load`
- `v_athlete_training_load_weekly`
- `v_athlete_muscle_load_weekly`

## Regras já estabilizadas
- múltiplos profissionais podem estar ativos para o mesmo atleta
- o sistema evita duplicidade do mesmo profissional com o mesmo atleta
- treinos de endurance usam `prescribed_workout_steps`
- treinos de força usam `prescribed_strength_exercises`
- provas alvo já podem ser cadastradas em múltiplos registros
- disponibilidade semanal já foi estruturada com opção principal/secundária
- o atleta já consegue visualizar treinos publicados dos dois tipos
- o builder de força já usa catálogo com filtro por grupo muscular e equipamento
- o ecossistema inclui médico como papel previsto na arquitetura
- a carga muscular estimada já combina força real + estimativa por modalidade

## Diretriz fisiológica atual
Campos fisiológicos do atleta foram mantidos na arquitetura, mas a responsabilidade de preenchimento passa a ser:
- treinador
- integrações com relógios
- exames clínicos / ergométricos

Ou seja, o atleta não deve preencher manualmente:
- FC repouso
- FC máxima clínica
- VO2
- BMR
- fase

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
- `athlete_target_races_screen.dart`
- `athlete_weekly_availability_edit_screen.dart`
- `athlete_my_professionals_screen.dart`
- `coach_athlete_summary_screen.dart`
- `athlete_injuries_restrictions_screen.dart`
- `athlete_medical_documents_screen.dart`
- `professional_profile_form_screen.dart`
- `professional_home_dashboard_screen.dart`

## Nova direção do produto
O Trinium passa a se posicionar como plataforma colaborativa de performance, saúde e prevenção, conectando:
- treinadores
- preparadores físicos
- nutricionistas
- fisioterapeutas
- médicos

## Próxima macrofase
Controle de risco e mapa corporal:
- tradução total do dashboard para português
- score de sobrecarga
- mapa corporal visual
- cruzamento entre carga, dor e lesão
- leitura mais executiva para profissionais

## Situação do analyze
Projeto compilando e abrindo corretamente com servidor SPA fallback, com warnings antigos ainda pendentes de limpeza.
