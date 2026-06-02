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
- `lib/screens/professional_profile_form_screen.dart`

## Fluxo atual do atleta
- completa perfil
- busca profissionais
- solicita vínculo
- acessa agenda
- visualiza treinos publicados
- visualiza treino de endurance com steps
- visualiza treino de força com exercício, meta, carga e descanso
- cadastra provas alvo
- edita disponibilidade semanal
- informa feedback ao concluir treino

## Fluxo atual do profissional
- completa perfil
- aceita vínculo
- cria treino manual de endurance
- cria treino manual de força
- publica treino para atleta
- visualiza resumo global do atleta

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

## Pendências visuais e de UX
- corrigir carregamento de profissionais ativos na home do atleta
- melhorar a experiência da home do atleta
- melhorar a experiência da home do profissional
- consolidar cards editáveis em página única
- estruturar dashboard de carga
- preparar futura visualização corporal/muscular
- limpar warnings antigos

## Situação técnica
Frontend funcional no fluxo principal do MVP, com treinos de endurance e força já operacionais, e evolução em andamento para dashboards 360°.
