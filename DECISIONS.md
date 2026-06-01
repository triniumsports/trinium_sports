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
O sistema trabalha com dois tipos principais:
1. treinos de endurance
2. treinos de força

## Decisão de modelagem
Treinos de endurance usam:
- `prescribed_workout_steps`

Treinos de força usam:
- `prescribed_strength_exercises`

## Decisão de catálogo
O catálogo de força é próprio do Trinium, inspirado na experiência da Garmin, mas sem depender de uma lista pública oficial da Garmin.

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

## Nova decisão de produto
O Trinium evolui para uma plataforma colaborativa 360° do atleta, e não apenas um app de treino.

## Implicações dessa decisão
Profissionais ativos do atleta devem ter visão compartilhada do contexto esportivo e de saúde, respeitando permissões:
- provas e objetivos
- restrições físicas / lesões
- restrições alimentares
- treinos prescritos
- carga consolidada
- exames e documentos compartilhados

## Decisão sobre saúde/documentos
O atleta poderá subir exames, laudos e documentos em PDF.
O acesso a esses documentos será controlado por permissão.

## Decisão sobre papéis profissionais
O ecossistema passa a incluir formalmente:
- treinador
- treinador de corrida
- treinador de natação
- treinador de trail
- treinador de triathlon
- preparador físico
- nutricionista
- fisioterapeuta
- médico

## Decisão de produto
A sincronização com relógio continua no roadmap, mas não é pré-requisito para validar o MVP funcional.
