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
- `lib/screens/professional_profile_form_screen.dart`

## Fluxo atual do atleta
- completa perfil
- busca profissionais
- solicita vínculo
- acessa agenda
- visualiza treinos publicados
- visualiza treino de endurance com steps
- visualiza treino de força com exercício, meta, carga e descanso

## Fluxo atual do profissional
- completa perfil
- aceita vínculo
- cria treino manual de endurance
- cria treino manual de força
- publica treino para atleta

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
O frontend precisará evoluir para suportar:
- tela “Meus profissionais” do atleta
- tela “Resumo global do atleta” para profissionais
- tela de documentos/exames
- visualização de restrições físicas / lesões
- futura visualização de dieta no lado do atleta

## Pendências visuais e de UX
- melhorar ainda mais a experiência do builder de força
- tornar o layout mais próximo do modelo de referência
- melhorar navegação entre tipos de treino
- mostrar profissionais ativos do atleta em tela dedicada
- separar visualmente treinos, dieta, profissionais e provas
- limpar warnings antigos

## Situação técnica
Frontend funcional no fluxo principal do MVP, com treinos de endurance e força já operacionais.
