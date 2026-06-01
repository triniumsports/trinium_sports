# DECISIONS — TRINIUM SPORTS

## Decisão estrutural do MVP
O MVP deixou de ser centrado no motor automático e passou a ser centrado em:
- marketplace
- vínculo atleta ↔ profissional
- criação manual de prescrição
- publicação
- visualização pelo atleta

## Motivo
O motor estava adicionando complexidade excessiva e travando a entrega da jornada principal do produto.

## Decisão de prescrição
O sistema passa a trabalhar com dois tipos principais:
1. treinos de endurance
2. treinos de força

## Decisão de modelagem
Treinos de endurance permanecem em:
- `prescribed_workout_steps`

Treinos de força passam a usar:
- `prescribed_strength_exercises`

## Decisão de catálogo
O catálogo de força será próprio do Trinium, inspirado na experiência da Garmin, mas não dependente de uma lista pública oficial da Garmin.

## Decisão de vínculos
Um atleta pode ter múltiplos profissionais ativos ao mesmo tempo.
O sistema evita duplicidade do mesmo profissional com o mesmo atleta, mas não bloqueia coexistência entre especialidades.

## Decisão de builder
Para endurance:
- step simples
- bloco de repetição
- zona como alvo principal

Para força:
- exercício
- grupo muscular
- equipamento
- meta
- carga
- descanso
- observações

## Decisão de produto
A sincronização com relógio continua no roadmap, mas não é mais pré-requisito para validar o MVP.
