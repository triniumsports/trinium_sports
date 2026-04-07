# DECISIONS

## Decisões registradas

1. A tabela oficial do contexto do atleta é public.athletes.
2. O dashboard não deve inferir campos fora do schema confirmado.
3. O calendário de provas deve usar public.target_races.
4. O nome da prova deve vir de target_races.name.
5. A altimetria deve vir de target_races.elevation_gain_m.
6. Os segmentos de prova devem usar target_race_segments e, se necessário, race_segments como fallback.
7. O motor atual gera uma prova por execução; a próxima grande evolução será torná-lo calendar-aware.
