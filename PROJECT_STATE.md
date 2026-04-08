# PROJECT_STATE

## Projeto
TRINIUM SPORTS

## Estado atual consolidado

### Backend
- Supabase funcional
- auth funcional
- vínculo atleta ↔ treinador funcional
- geração de treinos funcional
- publicação de treinos funcional

### Frontend
- marketplace funcional
- aceite de atletas funcional
- geração de treinos funcional
- revisão/publicação funcional
- dashboard do treinador em evolução avançada
- contexto do atleta já validado via tabela `athletes`

### Motor
- funcional
- ainda orientado a uma prova por execução
- próxima grande evolução: calendar-aware planning

---

## Próxima etapa prioritária
Evoluir o motor de geração para considerar o calendário completo do atleta.

## Nova direção confirmada
O motor deverá usar a disponibilidade real do atleta, modelada em `weekly_constraints`, incluindo:
- até 2 opções por dia
- modalidade por slot
- duração disponível
- possibilidade de dupla sessão
