# FRONTEND STATE — TRINIUM SPORTS

## Arquivos principais ajustados
- `lib/screens/home_router_screen.dart`
- `lib/screens/athlete_search_professionals_screen.dart`
- `lib/screens/coach_requests_screen.dart`
- `lib/screens/coach_create_workout_screen.dart`
- `lib/screens/coach_workout_edit_screen.dart`
- `lib/screens/coach_athlete_workouts_review_screen.dart`
- `lib/screens/athlete_agenda_screen.dart`
- `lib/screens/athlete_approved_workouts_screen.dart`
- `lib/screens/athlete_profile_form_screen.dart`
- `lib/screens/athlete_target_races_screen.dart`
- `lib/screens/athlete_weekly_availability_edit_screen.dart`
- `lib/screens/athlete_my_professionals_screen.dart`
- `lib/screens/coach_athlete_summary_screen.dart`
- `lib/screens/athlete_injuries_restrictions_screen.dart`
- `lib/screens/athlete_medical_documents_screen.dart`
- `lib/screens/professional_profile_form_screen.dart`
- `lib/screens/professional_home_dashboard_screen.dart`

## Fluxo atual do atleta
- completa perfil
- busca profissionais
- solicita vínculo
- acessa home unificada
- visualiza treinos publicados
- visualiza planned vs executed
- visualiza carga muscular estimada
- visualiza profissionais ativos
- cadastra provas alvo
- edita disponibilidade semanal
- edita restrições alimentares
- cadastra restrições / lesões
- sobe exames e documentos
- informa feedback ao concluir treino

## Fluxo atual do profissional
- completa perfil
- aceita vínculo
- acessa home unificada de portfólio
- visualiza prioridades de gestão
- cria treino manual de endurance
- cria treino manual de força
- publica treino para atleta
- visualiza resumo global do atleta
- visualiza planned vs executed
- visualiza carga muscular estimada

## Builder de endurance
- etapas simples
- repetição
- zonas
- fluxo funcional

## Builder de força
- grupo muscular
- equipamento
- busca de exercício
- seleção de exercício do catálogo
- meta com unidade automática
- carga
- descanso
- observações

## Nova direção de frontend
O frontend deverá convergir para:
- home do atleta unificada
- home do profissional unificada
- dashboards de leitura + edição rápida
- menos navegação entre telas separadas
- layouts responsivos para mobile e desktop
- tradução total da camada analítica para português

## Pendências visuais e de UX
- traduzir grupos musculares e labels técnicos
- destacar melhor a carga muscular estimada
- criar score visual de risco
- estruturar mapa corporal visual
- consolidar leitura executiva para profissionais
- limpar warnings antigos

## Situação técnica
Frontend funcional no fluxo principal do MVP, com:
- treinos de endurance e força operacionais
- restrições/lesões operacionais
- exames/documentos operacionais
- planned vs executed operacional
- carga muscular estimada operacional
- abertura estável via servidor SPA fallback
