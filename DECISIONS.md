# DECISIONS

## Decisões vigentes

1. A tabela oficial do contexto do atleta é `public.athletes`.
2. A tabela oficial do calendário de provas é `public.target_races`.
3. Para provas multiesporte, usar `target_race_segments` e fallback em `race_segments`.
4. O atleta só vê treinos publicados.
5. O treinador continua sendo o revisor final do motor.
6. O motor é peça central do produto.
7. A próxima prioridade estrutural é tornar o motor calendar-aware.

## Atualização — disponibilidade semanal do atleta
A disponibilidade semanal real do atleta será modelada em `weekly_constraints` com suporte a:
- `slot_order`
- `max_duration_sec`
- `is_primary`
- `can_pair_same_day`

Objetivo:
- representar a rotina real de treinadores e atletas
- permitir até 2 opções/modalidades por dia
- permitir que o motor use tempo disponível e modalidade disponível como restrição real
